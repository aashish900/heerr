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

> **Conventions used below.** Most calls use a one-shot `curlimages/curl`
> container attached to `arrnetwork`, because the backend binds *inside* the
> docker network at `172.39.0.51:8000` (also published on host `:8000` over the
> tailnet). After step 5 these shell shortcuts are assumed:
>
> ```bash
> NET="--network arrnetwork"
> IMG="curlimages/curl:8.10.1"
> BASE="http://172.39.0.51:8000/api/v1"
> ```

---

## 0. Prerequisites (verify once, before pulling)

Run these on the **arr-stack host** (SSH over tailnet):

```bash
cd ~/docker/arr-stack

# 0a. Compose file references the right image tag.
grep -nE 'image:\s*aashish010/heerr-backend' docker-compose.yml

# 0b. .env has the mandatory vars (NO values printed — just keys).
grep -E '^(POSTGRES_(USER|PASSWORD|DB)|DATABASE_URL|MUSIC_OUTPUT_DIR|NAVIDROME_URL)=' .env \
  | cut -d= -f1 | sort -u

# 0c. arrnetwork exists.
docker network ls --format '{{.Name}}' | grep -x arrnetwork

# 0d. Music dir exists (Navidrome must also be able to read this path).
ls -ld /data/media/music
```

Expected:
- 0a returns at least two lines (`heerr-migrate`, `heerr-backend`).
- 0b lists all six keys (`POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`,
  `DATABASE_URL`, `MUSIC_OUTPUT_DIR`, `NAVIDROME_URL`).
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
echo "exit=$?"
```

Expected: `exit=0`. On a host upgrading from a pre-M3 image you should see a
`Running upgrade 0009 -> 0010` line (adds `downloads.user_id` + per-user
unique) followed by `0010 -> 0011` (adds `users.settings` JSONB for the M5
per-user recommendation config). On a host already at head, zero upgrade lines
and a clean exit. If migrations fail, **stop** and inspect:

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

# 3b. Boot log shows the spotDL fingerprint + lifespan completed without
#     orphan-job recovery errors.
docker compose logs heerr-backend --tail=50 \
  | grep -E 'spotdl_version|orphaned|application startup complete'
```

Expected:
- `spotdl_version` log line shows `4.5.x`.
- An orphan-recovery line (zero or N recovered) — both are fine.
- "Application startup complete" from uvicorn.

If `status` is `unhealthy` or `Restarting`, **stop**:
```bash
docker compose logs heerr-backend --tail=200
```

---

## 4. Health + liveness checks (from the docker network)

```bash
NET="--network arrnetwork"
IMG="curlimages/curl:8.10.1"
BASE="http://172.39.0.51:8000/api/v1"

# 4a. /health — no auth required.
docker run --rm $NET $IMG -fsS $BASE/health ; echo
# Expect: {"status":"ok"}

# 4b. /ready — DB probe.
docker run --rm $NET $IMG -fsS $BASE/ready ; echo
# Expect: {"status":"ok"} (HTTP 503 if Postgres is down)
```

Expected: both return `200` with `{"status":"ok"}`.

---

## 5. Mint a smoke-test admin token

Run inside the backend container so it inherits the container's
`DATABASE_URL`. The token FK-links to the synthetic `system-admin` user
(the `--user` default).

```bash
docker compose exec heerr-backend python -m app.cli create-token \
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
> (step 13). Do not leave smoke tokens active.

---

## 6. Admin-gated OpenAPI + Swagger (DEBT N8 regression check)

These endpoints **must** reject unauthenticated requests and accept the
admin token from step 5.

```bash
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
`ping.view` succeeds. Use a **real** Navidrome account; first login lazily
creates the matching heerr `users` row.

> The request body field is `username` (NOT `navidrome_username` — that is a
> *response* field). See `app/schemas/auth.py::LoginRequest`.

```bash
read -s NAV_USER; export NAV_USER
read -s NAV_PASS; export NAV_PASS

docker run --rm $NET $IMG -s -w '\nhttp=%{http_code}\n' \
  -H "Content-Type: application/json" \
  -X POST $BASE/auth/login \
  -d "{\"username\":\"$NAV_USER\",\"password\":\"$NAV_PASS\"}"
```

Expected: HTTP 200, body contains a `token` field (a non-admin heerr token,
scopes `["read","download"]`, minted on this login). Capture it for the
per-user check in step 10:

```bash
read -s NAV_TOKEN   # paste the "token" value from the response
export NAV_TOKEN
```

If you get **503 navidrome unreachable**: `NAVIDROME_URL` in `.env` is wrong
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
`source_url` starting with `https://music.youtube.com/watch?v=…` and
`already_downloaded: false` (assuming a clean track).

If 502/timeout: outbound HTTPS from the backend container is blocked.

---

## 9. End-to-end download smoke (download scope, exercises spotDL)

Pick **one** `source_url` from step 8 and POST it to `/download` as the admin
(`system-admin`) token.

```bash
YT_URL='https://music.youtube.com/watch?v=...'   # paste a result from step 8
export YT_URL

docker run --rm $NET $IMG -s -w '\nhttp=%{http_code}\n' \
  -H "Authorization: Bearer $SMOKE_TOKEN" \
  -H "Content-Type: application/json" \
  -X POST $BASE/download \
  -d "{\"source_url\":\"$YT_URL\",\"source_type\":\"song\"}"
# Expect: HTTP 202, body { "job_id": "<uuid>", "state": "queued", "deduped": false }
```

Capture the `job_id` and poll until `done`:

```bash
export JOB_ID='<paste-uuid>'

for i in $(seq 1 12); do
  docker run --rm $NET $IMG -s \
    -H "Authorization: Bearer $SMOKE_TOKEN" $BASE/status/$JOB_ID
  echo; sleep 10
done
```

Expected progression: `queued` → `running` → `done`. On `done` the payload
carries a non-null `output_path`. Verify the file landed where Navidrome
sees it:

```bash
ls -lh /data/media/music/ | tail
```

Within ~1 minute Navidrome's scanner picks it up — check the Navidrome web UI
(over tailnet) for the new track.

If the job goes to `failed`: read `error` from the status payload (now a typed
`SpotdlError` subclass name, e.g. `RegionLockedError`) and the worker logs:
```bash
docker compose logs heerr-backend --since=10m | grep -iE 'job|spotdl|error'
```

---

## 10. Per-user download isolation (DEBT M3 regression check)

Proves `downloads` rows are per-user: a second user re-downloading the same
track gets their **own** row and a correct `already_downloaded` hint. Reuses
`$NAV_TOKEN` (step 7) and `$YT_URL` (step 9) — no second Navidrome account
needed, since `system-admin` (step 9) and the Navidrome user are distinct.

```bash
# 10a. As the Navidrome user, the track is NOT yet in *their* history,
#      even though system-admin already downloaded the shared file.
docker run --rm $NET $IMG -s \
  -H "Authorization: Bearer $NAV_TOKEN" \
  -H "Content-Type: application/json" \
  -X POST $BASE/search \
  -d "{\"query\":\"<same query as step 8>\",\"type\":\"song\",\"limit\":3}" \
  | grep -o '"already_downloaded":[a-z]*' | head
# Expect: the entry whose source_url == $YT_URL shows already_downloaded:false

# 10b. The Navidrome user downloads the same URL — fresh job (not deduped),
#      because dedupe is per-user.
docker run --rm $NET $IMG -s -w '\nhttp=%{http_code}\n' \
  -H "Authorization: Bearer $NAV_TOKEN" \
  -H "Content-Type: application/json" \
  -X POST $BASE/download \
  -d "{\"source_url\":\"$YT_URL\",\"source_type\":\"song\"}"
# Expect: HTTP 202, "deduped": false, a NEW job_id (≠ step 9's JOB_ID)
```

Poll the new `job_id` to `done` (same loop as step 9, with `$NAV_TOKEN`).
The file is already on disk, so spotDL exits fast; the worker writes a
**second** `downloads` row owned by the Navidrome user. Then:

```bash
# 10c. Now the Navidrome user's per-user hint flips to true.
docker run --rm $NET $IMG -s \
  -H "Authorization: Bearer $NAV_TOKEN" \
  -H "Content-Type: application/json" \
  -X POST $BASE/search \
  -d "{\"query\":\"<same query as step 8>\",\"type\":\"song\",\"limit\":3}" \
  | grep -o '"already_downloaded":[a-z]*' | head
# Expect: the entry for $YT_URL now shows already_downloaded:true

# 10d. Two rows on disk for one URL — one per user.
docker compose exec heerr-postgres \
  psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc \
  "SELECT count(*) FROM downloads WHERE source_url = '$YT_URL';"
# Expect: 2
```

> Pre-M3 this was the bug: the second user's row was swallowed by the global
> `ON CONFLICT (source_url) DO NOTHING`, so 10c would have stayed `false` and
> 10d would have returned `1`.

---

## 11. Per-user recommendation settings (DEBT M5 regression check)

Proves `GET/PATCH /api/v1/settings` is per-user, partial, and never echoes the
ListenBrainz token. Any valid token manages **its own** user's settings — uses
`$NAV_TOKEN` (step 7, the Navidrome user) and `$SMOKE_TOKEN` (system-admin) to
show isolation.

```bash
# 11a. Defaults for the Navidrome user — nothing set yet.
docker run --rm $NET $IMG -s \
  -H "Authorization: Bearer $NAV_TOKEN" $BASE/settings ; echo
# Expect: {"lastfm_username":null,"listenbrainz_token_set":false}

# 11b. Set both keys (partial PATCH — only the keys you send change).
docker run --rm $NET $IMG -s -w '\nhttp=%{http_code}\n' \
  -H "Authorization: Bearer $NAV_TOKEN" \
  -H "Content-Type: application/json" \
  -X PATCH $BASE/settings \
  -d '{"lastfm_username":"smoke-user","listenbrainz_token":"lb-smoke-xxxx"}'
# Expect: HTTP 200, {"lastfm_username":"smoke-user","listenbrainz_token_set":true}
# NOTE: the response must NOT contain the raw "listenbrainz_token" value.

# 11c. Read back — persisted; token surfaces only as a bool.
docker run --rm $NET $IMG -s \
  -H "Authorization: Bearer $NAV_TOKEN" $BASE/settings ; echo
# Expect: {"lastfm_username":"smoke-user","listenbrainz_token_set":true}

# 11d. Per-user isolation — system-admin's settings are untouched.
docker run --rm $NET $IMG -s \
  -H "Authorization: Bearer $SMOKE_TOKEN" $BASE/settings ; echo
# Expect: lastfm_username is null (system-admin set nothing in 11b).

# 11e. Clear a key with an explicit null.
docker run --rm $NET $IMG -s \
  -H "Authorization: Bearer $NAV_TOKEN" \
  -H "Content-Type: application/json" \
  -X PATCH $BASE/settings -d '{"lastfm_username":null}' ; echo
# Expect: {"lastfm_username":null,"listenbrainz_token_set":true}

# 11f. Unknown field is rejected.
docker run --rm $NET $IMG -s -o /dev/null -w '%{http_code}\n' \
  -H "Authorization: Bearer $NAV_TOKEN" \
  -H "Content-Type: application/json" \
  -X PATCH $BASE/settings -d '{"nope":"x"}'
# Expect: 422
```

Expected: 11a defaults, 11b/11c the token is stored but never echoed (only
`listenbrainz_token_set:true`), 11d system-admin is unaffected, 11e the
`lastfm_username` clears while the token stays set, 11f returns `422`.

> Leave the Navidrome user's `listenbrainz_token` set or clear it — it only
> affects that user's `/recommend` results. No cleanup is mandatory; to reset:
> `PATCH $BASE/settings -d '{"listenbrainz_token":null}'`.

---

## 12. Admin smoke — listings + queue visibility

```bash
docker run --rm $NET $IMG -s \
  -H "Authorization: Bearer $SMOKE_TOKEN" $BASE/admin/users | head -c 400; echo
docker run --rm $NET $IMG -s \
  -H "Authorization: Bearer $SMOKE_TOKEN" "$BASE/admin/jobs?limit=5" | head -c 400; echo
docker run --rm $NET $IMG -s \
  -H "Authorization: Bearer $SMOKE_TOKEN" $BASE/admin/tokens | head -c 400; echo
```

Expected: all three return 200 with JSON arrays. `/admin/jobs` includes the
jobs from steps 9 + 10. `/admin/users` includes `system-admin` plus your
Navidrome user (created lazily on first login in step 7).

---

## 13. Revoke the smoke token + clean up

`create-token` does not print the token id, so find it via `list-tokens`
(the smoke admin token is the newest `system-admin` row).

```bash
# 13a. List system-admin tokens; the smoke one is the most recent `active` row.
docker compose exec heerr-backend python -m app.cli list-tokens --user=system-admin
# Output rows look like:
#   <uuid> user=system-admin scopes=['download','read'] admin=True state=active created_at=...

# 13b. Revoke by id (UUID from 13a).
docker compose exec heerr-backend python -m app.cli revoke-token <uuid>
# Expect: "revoked"

# 13c. Confirm the next request with that token returns 401.
docker run --rm $NET $IMG -s -o /dev/null -w '%{http_code}\n' \
  -H "Authorization: Bearer $SMOKE_TOKEN" $BASE/admin/users
# Expect: 401
```

Optionally drop the smoke job/download rows (no DELETE endpoint exists — use
`psql`; `downloads` FK-references `jobs` with `ON DELETE RESTRICT`, so delete
downloads first):

```bash
docker compose exec heerr-postgres \
  psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c \
  "DELETE FROM downloads WHERE source_url = '$YT_URL';
   DELETE FROM jobs WHERE source_url = '$YT_URL';"
```

Unset the env vars on the host shell:

```bash
unset SMOKE_TOKEN NAV_TOKEN NAV_USER NAV_PASS JOB_ID YT_URL
```

---

## 14. Rollback (only if any of 3–11 failed)

```bash
cd ~/docker/arr-stack

# 14a. Pin the previous tag in compose (edit the image: line), OR pull by
#      digest captured in step 1a:
docker pull aashish010/heerr-backend@<previous-digest>
docker tag aashish010/heerr-backend@<previous-digest> aashish010/heerr-backend:latest

# 14b. Recreate the backend + migrate containers on the old image.
docker compose up -d --force-recreate heerr-migrate heerr-backend

# 14c. Re-run steps 4 + 7 to confirm the old image is healthy again.
```

> **Schema caution.** If migrations 0010/0011 ran (step 2) but the API failed
> afterwards, the new schema is already in place. The old image expects the
> pre-M3/pre-M5 schema and **will not** run cleanly against it. Either
> roll forward (fix and re-deploy the new image) or restore Postgres from
> backup before bringing the old image up — do not run the old image against
> the 0010 schema.

---

## Pass criteria summary

A smoke is **green** when, with no manual intervention between steps:

- §0 all four prerequisite checks pass.
- §1 a new digest is pulled.
- §2 `heerr-migrate` exits 0 (with `0009 -> 0010 -> 0011` on a pre-M3 host).
- §3 `heerr-backend` is `(healthy)` within 30 s and logs show `spotdl_version`
  plus uvicorn startup.
- §4 `/health` + `/ready` return 200.
- §5 a raw admin token is printed once.
- §6 the six HTTP codes are `404 404 401 401 200 200`.
- §7 `/auth/login` returns 200 with a `token`.
- §8 `/search` returns ≥ 1 result.
- §9 a real `/download` job reaches state `done`; the file appears under
  `/data/media/music` and Navidrome indexes it within ~1 min.
- §10 (M3) the second user sees `already_downloaded:false` → `true` across
  their own download, and the URL has exactly 2 `downloads` rows.
- §11 (M5) `/settings` round-trips per-user; the ListenBrainz token is stored
  but never echoed (`listenbrainz_token_set:true`), system-admin is unaffected,
  and an unknown field returns `422`.
- §12 all three admin listings return 200 with the expected shape.
- §13 the smoke token is revoked and re-use returns 401.

If any step is red, **stop the rollout** and capture
`docker compose logs heerr-backend --tail=500` + the failing request's
`X-Request-ID` header for correlation.
