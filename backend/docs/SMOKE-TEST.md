# SMOKE-TEST.md

End-to-end smoke test for a freshly published `aashish010/heerr-backend` image
on the home server (the arr-stack host). Runs **on the arr-stack host over the
tailnet** — no public ingress at any step.

> **Assumptions.** Your arr-stack compose lives at
> `~/docker/arr-stack/docker-compose.yml`, has been merged with
> `heerr/docker-compose.snippet.yml`, and a populated `.env` sits next to it.
> Navidrome is already running on the same `arrnetwork` and reachable over
> the tailnet. If any of that is missing, see `backend/README.md` §
> "Deployment to the arr-stack" first.

---

## 0. Prerequisites (verify once, before pulling)

Run these on the **arr-stack host** (SSH over tailnet):

```bash
cd ~/docker/arr-stack

# 0a. Compose file references the right image tag.
grep -nE 'image:\s*aashish010/heerr-backend' docker-compose.yml

# 0b. .env has the four mandatory vars (NO values printed — just keys).
grep -E '^(POSTGRES_(USER|PASSWORD|DB)|DATABASE_URL|MUSIC_OUTPUT_DIR|NAVIDROME_URL)=' .env \
  | cut -d= -f1 | sort -u

# 0c. arrnetwork exists.
docker network ls --format '{{.Name}}' | grep -x arrnetwork

# 0d. Music dir exists and is writable by the backend UID (image runs as root
#     by default; Navidrome must also be able to read this path).
ls -ld /data/media/music
```

Expected:
- 0a returns at least two lines (`heerr-migrate`, `heerr-backend`).
- 0b lists all six keys.
- 0c prints `arrnetwork`.
- 0d shows the dir exists.

If any check fails, **stop** — fix before pulling.

---

## 1. Pull the new image

```bash
cd ~/docker/arr-stack

# 1a. Note the currently running image digest (for rollback reference).
docker inspect heerr-backend --format '{{.Image}}' 2>/dev/null || echo "not running"

# 1b. Pull the new tag. If your compose pins `:latest`, this updates it;
#     if it pins a specific version, `docker compose pull` is sufficient.
docker compose pull heerr-migrate heerr-backend

# 1c. Confirm the digest changed.
docker images --digests aashish010/heerr-backend | head
```

Expected: `pull` prints "Pulled" (not "up to date"). Digest in 1c differs
from the digest captured in 1a.

---

## 2. Apply migrations

`heerr-migrate` is a one-shot service. Run it explicitly so any failure
surfaces before the API restarts.

```bash
docker compose run --rm heerr-migrate
# Expected last line: "INFO  [alembic.runtime.migration] Will assume transactional DDL."
# followed by zero or more "Running upgrade XXXX -> YYYY" lines, then exit 0.
echo "exit=$?"
```

Expected: `exit=0`. If migrations fail, **stop** and inspect:

```bash
docker compose logs heerr-migrate --tail=200
```

---

## 3. Restart the backend

```bash
docker compose up -d heerr-backend

# 3a. Container is up and healthy (give the healthcheck ~30s).
sleep 30
docker compose ps heerr-backend
# Expect STATUS column to read "Up X seconds (healthy)".

# 3b. Boot log shows the right version + lifespan completed without
#     orphan-job recovery errors.
docker compose logs heerr-backend --tail=50 | grep -E 'spotdl_version|orphaned jobs|application startup complete'
```

Expected:
- `spotdl_version` log line shows `4.5.x`.
- Either "no orphaned jobs at boot" OR "orphaned jobs recovered at boot" with
  a count — both are fine.
- "Application startup complete" from uvicorn.

If `status` is `unhealthy` or `Restarting`, **stop**:
```bash
docker compose logs heerr-backend --tail=200
```

---

## 4. Health + liveness checks (from the host, on the docker network)

The backend binds inside the docker network at `172.39.0.51:8000`. Either
shell into another arr-stack container or use a one-shot `curlimages/curl`
attached to `arrnetwork`:

```bash
# 4a. /health — no auth required.
docker run --rm --network arrnetwork curlimages/curl:8.10.1 \
  -fsS http://172.39.0.51:8000/api/v1/health
# Expect: {"status":"ok"}

# 4b. /ready — DB probe.
docker run --rm --network arrnetwork curlimages/curl:8.10.1 \
  -fsS http://172.39.0.51:8000/api/v1/ready
# Expect: {"status":"ok"} (or HTTP 503 if Postgres is down)
```

Expected: both return `200` with `{"status":"ok"}`.

---

## 5. Mint a smoke-test admin token

Run inside the backend container so it inherits the container's
`DATABASE_URL`:

```bash
docker compose exec heerr-backend python -m app.cli create-token \
  --owner=smoke-$(date +%Y%m%d) \
  --scopes=read,download \
  --admin
# Single line on stdout: the raw token. Copy it.
```

Stash it in a shell var on the host:

```bash
read -s SMOKE_TOKEN   # paste, press enter
export SMOKE_TOKEN
```

> **Cleanup reminder.** Revoke this token at the end of the smoke test
> (step 11). Do not leave smoke tokens active.

---

## 6. Admin-gated OpenAPI + Swagger (DEBT N8 regression check)

These endpoints **must** reject unauthenticated requests and accept the
admin token from step 5.

```bash
NET="--network arrnetwork"
IMG="curlimages/curl:8.10.1"
BASE="http://172.39.0.51:8000/api/v1"

# 6a. Default unauthenticated paths are gone.
docker run --rm $NET $IMG -s -o /dev/null -w '%{http_code}\n' http://172.39.0.51:8000/docs
docker run --rm $NET $IMG -s -o /dev/null -w '%{http_code}\n' http://172.39.0.51:8000/openapi.json
# Expect: 404, 404

# 6b. Versioned paths reject unauthenticated.
docker run --rm $NET $IMG -s -o /dev/null -w '%{http_code}\n' $BASE/openapi.json
docker run --rm $NET $IMG -s -o /dev/null -w '%{http_code}\n' $BASE/docs
# Expect: 401, 401

# 6c. Admin token unlocks the spec + the Swagger UI HTML.
docker run --rm $NET $IMG -s -o /dev/null -w '%{http_code}\n' \
  -H "Authorization: Bearer $SMOKE_TOKEN" $BASE/openapi.json
docker run --rm $NET $IMG -s -o /dev/null -w '%{http_code}\n' \
  -H "Authorization: Bearer $SMOKE_TOKEN" $BASE/docs
# Expect: 200, 200
```

Expected: `404 404 / 401 401 / 200 200`.

---

## 7. Auth smoke — Navidrome IdP round-trip

Confirms the backend can reach Navidrome over the tailnet and that Subsonic
`ping.view` succeeds.

```bash
# Replace with a real Navidrome user/pass that exists in your Navidrome.
read -s NAV_USER; export NAV_USER
read -s NAV_PASS; export NAV_PASS

docker run --rm $NET $IMG -s -w '\nhttp=%{http_code}\n' \
  -H "Content-Type: application/json" \
  -X POST $BASE/auth/login \
  -d "{\"navidrome_username\":\"$NAV_USER\",\"password\":\"$NAV_PASS\"}"
```

Expected: HTTP 200, body contains a `raw_token` field (this is a non-admin
heerr token minted on first login).

If you get **503 navidrome_unreachable**: `NAVIDROME_URL` in `.env` is wrong
or Navidrome isn't on `arrnetwork`. If **401**: the Navidrome creds are
wrong. Either way, fix before continuing.

---

## 8. Search smoke (read scope)

```bash
docker run --rm $NET $IMG -s -w '\nhttp=%{http_code}\n' \
  -H "Authorization: Bearer $SMOKE_TOKEN" \
  -H "Content-Type: application/json" \
  -X POST $BASE/search \
  -d '{"query":"blinding lights weeknd","type":"song","limit":3}'
```

Expected: HTTP 200, `results` array with ≥ 1 entry, each having
`source_url` starting with `https://music.youtube.com/watch?v=…`.

If 502/timeout: outbound HTTPS from the backend container is blocked.

---

## 9. End-to-end download smoke (download scope, exercises spotDL)

Pick **one** of the search results from step 8 and POST it to `/download`.

```bash
# Replace <YT_URL> with a source_url from step 8.
YT_URL='https://music.youtube.com/watch?v=...'

docker run --rm $NET $IMG -s -w '\nhttp=%{http_code}\n' \
  -H "Authorization: Bearer $SMOKE_TOKEN" \
  -H "Content-Type: application/json" \
  -X POST $BASE/download \
  -d "{\"source_url\":\"$YT_URL\",\"source_type\":\"song\"}"
# Expect: HTTP 202, body { "job_id": "<uuid>", "state": "queued", ... }
```

Capture the `job_id`:

```bash
export JOB_ID='<paste-uuid>'
```

Poll the job status:

```bash
for i in 1 2 3 4 5 6 7 8 9 10; do
  docker run --rm $NET $IMG -s \
    -H "Authorization: Bearer $SMOKE_TOKEN" \
    $BASE/status/$JOB_ID
  echo
  sleep 10
done
```

Expected progression: `queued` → `running` → `done`. A small song should
finish well under 2 minutes; a longer download can take several. On `done`,
`downloads` is non-empty.

Verify the file landed where Navidrome will see it:

```bash
ls -lh /data/media/music/ | tail
# Look for a newly-mtime'd .mp3 / .opus / .m4a.
```

Within ~1 minute Navidrome's scanner should pick it up — check the
Navidrome web UI (over tailnet) for the new track.

If the job goes to `failed`: pull `error_msg` from the status payload and
the worker logs:
```bash
docker compose logs heerr-backend --since=10m | grep -iE 'job|spotdl|error'
```

---

## 10. Admin smoke — listings + queue visibility

```bash
docker run --rm $NET $IMG -s \
  -H "Authorization: Bearer $SMOKE_TOKEN" $BASE/admin/users | head -c 400; echo
docker run --rm $NET $IMG -s \
  -H "Authorization: Bearer $SMOKE_TOKEN" $BASE/admin/jobs?limit=5 | head -c 400; echo
docker run --rm $NET $IMG -s \
  -H "Authorization: Bearer $SMOKE_TOKEN" $BASE/admin/tokens | head -c 400; echo
```

Expected: all three return 200 with JSON arrays. `/admin/jobs` should
include the job from step 9. `/admin/users` should include
`system-admin` plus your Navidrome user (created lazily on first login in
step 7).

---

## 11. Revoke the smoke token + clean up

```bash
# 11a. Find the smoke token row id.
docker compose exec heerr-backend python -m app.cli list-tokens \
  | grep "owner=smoke-$(date +%Y%m%d)"

# 11b. Revoke by id (UUID from 11a).
docker compose exec heerr-backend python -m app.cli revoke-token <uuid>

# 11c. Confirm the next request with that token returns 401.
docker run --rm $NET $IMG -s -o /dev/null -w '%{http_code}\n' \
  -H "Authorization: Bearer $SMOKE_TOKEN" $BASE/admin/users
# Expect: 401
```

Optionally delete the smoke-job row from the DB if you do not want it in
job history. The backend has no `/admin/jobs/{id} DELETE` — use `psql`:

```bash
docker compose exec heerr-postgres \
  psql -U $POSTGRES_USER -d $POSTGRES_DB \
  -c "DELETE FROM jobs WHERE id = '<job_id>';"
```

Unset the env vars on the host shell:

```bash
unset SMOKE_TOKEN NAV_USER NAV_PASS JOB_ID
```

---

## 12. Rollback (only if any of 3–9 failed)

```bash
cd ~/docker/arr-stack

# 12a. Pin the previous tag in compose (edit the image: line), OR pull by
#      digest captured in step 1a:
docker pull aashish010/heerr-backend@<previous-digest>
docker tag aashish010/heerr-backend@<previous-digest> aashish010/heerr-backend:latest

# 12b. Recreate the backend + migrate containers on the old image.
docker compose up -d --force-recreate heerr-migrate heerr-backend

# 12c. Re-run steps 4 + 7 to confirm the old image is healthy again.
```

If migrations ran successfully on the new image but the API failed
afterwards, the new schema is already in place — confirm the previous
image is still compatible with it before rolling back. If not, restore
from the most recent Postgres backup before bringing the old image up.

---

## Pass criteria summary

A smoke is **green** when, with no manual intervention between steps:

- §0 all four prerequisite checks pass.
- §1 a new digest is pulled.
- §2 `heerr-migrate` exits 0.
- §3 `heerr-backend` is `(healthy)` within 30 s and logs show
  `spotdl_version` + uvicorn startup.
- §4 `/health` + `/ready` return 200.
- §5 a raw token is printed once.
- §6 the six HTTP codes are `404 404 401 401 200 200`.
- §7 `/auth/login` returns 200 with a `raw_token`.
- §8 `/search` returns ≥ 1 result.
- §9 a real `/download` job reaches state `done`; the file appears under
  `/data/media/music` and Navidrome indexes it within ~1 min.
- §10 all three admin listings return 200 with the expected shape.
- §11 the smoke token is revoked and re-use returns 401.

If any step is red, **stop the rollout** and capture
`docker compose logs heerr-backend --tail=500` + the failing request's
`X-Request-ID` for correlation.
