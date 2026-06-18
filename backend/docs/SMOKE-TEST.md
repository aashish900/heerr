# SMOKE-TEST.md — heerr backend v3.1.0-rc1

End-to-end smoke test for the v3.1.0-rc1 release on a real home-server
deploy. Every step has a copy-paste shell command and the expected output.
If any step diverges from "expected", stop and capture the discrepancy — do
not promote `rc1 → 3.1.0` until every step is green.

Run from a host on the tailnet that can reach the backend's tailnet address.
This doc assumes the standard arr-stack deployment shape documented in
[CONTEXT.md](CONTEXT.md) (Postgres in compose, backend on host port 8000).

This release covers the following DEBT items: **C2, M1, T3, T4, N3, N6,
N7, N9, N11, N13, N14**. Each phase below targets one or more of those.

---

## 0. Setup

### 0.1 Environment

```bash
export HEERR=http://heerr-backend.tailnet:8000     # or http://<tailnet-ip>:8000
export NAVIDROME_USER=<your-navidrome-username>
export NAVIDROME_PASS=<your-navidrome-password>
```

### 0.2 Confirm the running version

```bash
curl -s "$HEERR/api/v1/openapi.json" | jq -r '.info.version'
```

**Expected:** `3.1.0` (no `-rc1` suffix — the build is just the wheel; the
git tag carries `rc1`).

### 0.3 Confirm the container is on the right image

```bash
ssh aashish@192.168.1.43 'docker inspect heerr-backend --format "{{.Config.Image}}"'
```

**Expected:** the image tag corresponds to `v3.1.0-rc1` (or whatever
publish workflow target you used).

---

## 1. Boot-time checks (C2, N11)

### 1.1 spotDL version logged at boot (N11)

```bash
ssh aashish@192.168.1.43 \
  'docker logs heerr-backend 2>&1 | grep "spotdl version probed" | head -1'
```

**Expected:** a single structured log line containing
`"spotdl_executable": "/opt/spotdl-venv/bin/spotdl"` and a
`"spotdl_version"` field that matches the pinned spotDL version
(currently `4.5.0`).

### 1.2 Orphaned-jobs recovery ran (C2)

```bash
ssh aashish@192.168.1.43 \
  'docker logs heerr-backend 2>&1 | grep -E "(orphaned jobs recovered at boot|no orphaned jobs at boot)" | head -1'
```

**Expected:** exactly one log line. Either:

- `"msg": "no orphaned jobs at boot"` (fresh DB or last shutdown was clean), or
- `"msg": "orphaned jobs recovered at boot", "count": N` with `N > 0`
  if the container was killed mid-download last time.

### 1.3 Lifespan integration — induce + recover an orphan (C2)

This proves boot recovery actually flips a stuck row, not just that the log
line fires.

```bash
# 1. Connect to Postgres via the heerr role.
ssh aashish@192.168.1.43 'docker exec -it heerr-postgres psql -U music_request_app -d music_request'
```

In psql:

```sql
-- Pick any token with download scope; insert a fake orphan job for it.
INSERT INTO jobs (source_url, source_type, state, created_by_token_id, user_id, started_at)
VALUES (
  'https://music.youtube.com/watch?v=smoketest-orphan',
  'song',
  'running',
  (SELECT id FROM tokens WHERE 'download' = ANY(scopes) LIMIT 1),
  (SELECT user_id FROM tokens WHERE 'download' = ANY(scopes) LIMIT 1),
  now() - interval '1 hour'
) RETURNING id;
\q
```

Restart the backend, then re-query state:

```bash
ssh aashish@192.168.1.43 'docker restart heerr-backend && sleep 5'
ssh aashish@192.168.1.43 \
  'docker exec heerr-postgres psql -U music_request_app -d music_request -tA \
     -c "SELECT state, error_msg FROM jobs WHERE source_url = '"'"'https://music.youtube.com/watch?v=smoketest-orphan'"'"';"'
```

**Expected:** `failed|orphaned at boot`. Clean up:

```bash
ssh aashish@192.168.1.43 \
  'docker exec heerr-postgres psql -U music_request_app -d music_request \
     -c "DELETE FROM jobs WHERE source_url = '"'"'https://music.youtube.com/watch?v=smoketest-orphan'"'"';"'
```

---

## 2. Health & readiness (N7)

### 2.1 `/health` is cheap (always 200)

```bash
curl -i "$HEERR/api/v1/health"
```

**Expected:** `200 OK` with body `{"status":"ok"}`. No DB call in this path.

### 2.2 `/ready` pings the DB

```bash
curl -i "$HEERR/api/v1/ready"
```

**Expected:** `200 OK` with body `{"status":"ok"}` when Postgres is up.

### 2.3 `/ready` returns 503 if DB is down (optional destructive check)

```bash
# Stop Postgres briefly.
ssh aashish@192.168.1.43 'docker stop heerr-postgres'
sleep 2
curl -i -o /tmp/ready.out -w "%{http_code}\n" "$HEERR/api/v1/ready"
ssh aashish@192.168.1.43 'docker start heerr-postgres'
cat /tmp/ready.out
```

**Expected:** `503` with body
`{"detail":"database unreachable"}`. Skip this step if you don't want
to perturb the running stack — the existing pytest suite already covers
it.

---

## 3. Auth — login & token bookkeeping (N3, N9, N13)

### 3.1 Login succeeds via Navidrome handshake

```bash
TOKEN=$(curl -s -X POST "$HEERR/api/v1/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"$NAVIDROME_USER\",\"password\":\"$NAVIDROME_PASS\"}" \
  | jq -r '.token')
echo "TOKEN=$TOKEN"
```

**Expected:** a 32-byte URL-safe string. Save it for later steps.

### 3.2 `last_used_at` is bumped on every authenticated request (N3)

```bash
# Hit any authed endpoint.
curl -s "$HEERR/api/v1/queue" -H "Authorization: Bearer $TOKEN" > /dev/null

# Inspect the row.
ssh aashish@192.168.1.43 \
  'docker exec heerr-postgres psql -U music_request_app -d music_request -tA \
     -c "SELECT last_used_at FROM tokens ORDER BY created_at DESC LIMIT 1;"'
```

**Expected:** a recent UTC timestamp (within the last few seconds), not
`NULL`.

### 3.3 Login with bad `NAVIDROME_URL` returns 503 (N13)

This is a destructive boot check. Only do it if you have a maintenance
window — it requires restarting the backend with a broken env value.

```bash
# Edit the arr-stack docker-compose to set NAVIDROME_URL=not-a-url for heerr-backend,
# then bring it up. Container should refuse to boot (pydantic ValidationError at
# Settings()).
```

**Expected at boot:** the container exits with a `ValidationError` for
`navidrome_url`. **No 500 should ever reach the client** — the misconfig
is caught at startup. Restore the correct value and bring the stack back.

### 3.4 Logout revokes the token

```bash
curl -i -X POST "$HEERR/api/v1/auth/logout" -H "Authorization: Bearer $TOKEN"
# Subsequent calls with the same token:
curl -i "$HEERR/api/v1/queue" -H "Authorization: Bearer $TOKEN"
```

**Expected:** `204` on logout, `401` with detail `"unknown or revoked
token"` on the follow-up.

### 3.5 Dangling user returns 401, not 500 (N9)

Hard to trigger from a happy-path deploy; covered by automated tests.
Skipped here unless you want to manually null a `tokens.user_id` row
via psql (recommend: don't).

---

## 4. Download flow with URL canonicalization (N14)

Re-login to get a fresh token (the previous one is revoked):

```bash
TOKEN=$(curl -s -X POST "$HEERR/api/v1/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"$NAVIDROME_USER\",\"password\":\"$NAVIDROME_PASS\"}" \
  | jq -r '.token')
```

### 4.1 POST a URL with `&list=...&index=...` (N14)

```bash
# A URL of the form spotDL used to choke on:
PROBE_URL='https://music.youtube.com/watch?v=dQw4w9WgXcQ&list=RDdQw4w9WgXcQ&index=2&pp=ygUE'
curl -s -X POST "$HEERR/api/v1/download" \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"source_url\":\"$PROBE_URL\",\"source_type\":\"song\",\"display_name\":\"smoke-test-N14\"}" \
  | jq
```

**Expected:** `202 Accepted` with a `job_id`.

### 4.2 Verify spotdl was invoked with the canonical URL

```bash
JOB_ID=$(curl -s -X POST "$HEERR/api/v1/download" \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"source_url\":\"$PROBE_URL\",\"source_type\":\"song\"}" \
  | jq -r '.job_id')

# Tail the access log + look for the spotdl subprocess command:
ssh aashish@192.168.1.43 'docker logs heerr-backend 2>&1 | grep -E "spotdl|download" | tail -20'
```

**Expected:** the URL spotdl gets is the bare `watch?v=dQw4w9WgXcQ`
form — no `list=`, `index=`, `pp=`, etc. The job eventually transitions
to `done` (poll `/status/{job_id}` — see 4.3).

### 4.3 Job reaches `done` and file lands on disk

```bash
# Poll until state changes.
for i in 1 2 3 4 5 6 7 8 9 10; do
  STATE=$(curl -s "$HEERR/api/v1/status/$JOB_ID" -H "Authorization: Bearer $TOKEN" | jq -r '.state')
  echo "attempt $i: state=$STATE"
  [ "$STATE" = "done" ] || [ "$STATE" = "failed" ] && break
  sleep 10
done

# Confirm the file landed.
ssh aashish@192.168.1.43 'ls -la /data/media/music | grep -i rick'
```

**Expected:** `state=done` within ~60 s; an mp3 named
`<title>-<artist>.mp3` in `/data/media/music`. Navidrome picks it up
within ~1 min.

---

## 5. Admin endpoint with M1 contract change

### 5.1 `POST /admin/tokens` now **requires** `navidrome_username` (M1)

Get an admin token (assumes you minted one at install time):

```bash
ADMIN_TOKEN=$(cat ~/.heerr-admin-token)
```

Old payload (pre-3.1.0) should fail:

```bash
curl -i -X POST "$HEERR/api/v1/admin/tokens" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"owner_label":"smoke-old-shape","scopes":["read"]}'
```

**Expected:** `422 Unprocessable Entity` with a Pydantic error citing
`navidrome_username`.

New payload (3.1.0 contract):

```bash
curl -s -X POST "$HEERR/api/v1/admin/tokens" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"owner_label\":\"smoke-new-shape\",\"scopes\":[\"read\"],\"navidrome_username\":\"$NAVIDROME_USER\"}" \
  | jq
```

**Expected:** `201 Created`. The response body contains a `raw_token`.

### 5.2 Unknown `navidrome_username` → 404 (M1)

```bash
curl -i -X POST "$HEERR/api/v1/admin/tokens" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"owner_label":"smoke-bad-user","scopes":["read"],"navidrome_username":"nobody-here"}'
```

**Expected:** `404 Not Found` with detail
`"unknown navidrome_username: nobody-here"`.

### 5.3 The minted token resolves to that user

```bash
RAW=$(curl -s -X POST "$HEERR/api/v1/admin/tokens" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{\"owner_label\":\"smoke-resolve\",\"scopes\":[\"read\",\"download\"],\"navidrome_username\":\"$NAVIDROME_USER\"}" \
  | jq -r '.raw_token')

# Verify the FK lands on the right user via the DB:
ssh aashish@192.168.1.43 \
  'docker exec heerr-postgres psql -U music_request_app -d music_request -tA \
     -c "SELECT u.navidrome_username FROM tokens t JOIN users u ON u.id = t.user_id WHERE t.owner_label = '"'"'smoke-resolve'"'"';"'
```

**Expected:** prints `$NAVIDROME_USER`, not `system-admin`.

---

## 6. T4 — INSERT without user_id fails loudly (M1, T4)

This is the safety net that catches any future code path that forgets to
set `user_id`. Run as raw SQL:

```bash
ssh aashish@192.168.1.43 'docker exec -it heerr-postgres psql -U music_request_app -d music_request'
```

In psql:

```sql
INSERT INTO tokens (token_hash, owner_label, scopes)
VALUES ('smoke-hash', 'smoke-t4', ARRAY['read']);
```

**Expected:** `ERROR: null value in column "user_id" of relation "tokens"
violates not-null constraint`.

```sql
-- Same for jobs.
INSERT INTO jobs (source_url, source_type, state, created_by_token_id)
VALUES ('https://x.com/watch?v=t4', 'song', 'queued',
        (SELECT id FROM tokens LIMIT 1));
```

**Expected:** same `NotNullViolation` on `user_id`. Exit psql.

Also confirm the column default is gone:

```sql
SELECT column_default
FROM information_schema.columns
WHERE table_name = 'tokens' AND column_name = 'user_id';
```

**Expected:** `NULL` (no default).

---

## 7. Request body size cap (N6)

```bash
# Build a payload over 1 MiB.
head -c 1200000 /dev/urandom | base64 > /tmp/big.txt
JUNK=$(cat /tmp/big.txt)

curl -i -X POST "$HEERR/api/v1/search" \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  --data-binary "{\"q\":\"$JUNK\",\"type\":\"song\"}"
```

**Expected:** `413 Payload Too Large` with body
`{"detail":"request body exceeds 1048576 bytes"}`. The backend rejected
the request before FastAPI's body parsing ran — no MB of garbage in
worker memory.

Sanity-check a normal-sized search still works:

```bash
curl -i -X POST "$HEERR/api/v1/search" \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"q":"never gonna give you up","type":"song"}'
```

**Expected:** `200 OK` with a non-empty `results` array.

---

## 8. Multi-user isolation regression (J7/J8 carry-over)

Quick sanity check that v3.1.0 didn't break Phase J behavior.

### 8.1 Two users, same URL, two jobs

```bash
TOKEN_A=$(curl -s -X POST "$HEERR/api/v1/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"user-a\",\"password\":\"$PASS_A\"}" | jq -r '.token')
TOKEN_B=$(curl -s -X POST "$HEERR/api/v1/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"user-b\",\"password\":\"$PASS_B\"}" | jq -r '.token')

PROBE='https://music.youtube.com/watch?v=multiUser'
A_JOB=$(curl -s -X POST "$HEERR/api/v1/download" -H "Authorization: Bearer $TOKEN_A" \
  -H 'Content-Type: application/json' \
  -d "{\"source_url\":\"$PROBE\",\"source_type\":\"song\"}" | jq -r '.job_id')
B_JOB=$(curl -s -X POST "$HEERR/api/v1/download" -H "Authorization: Bearer $TOKEN_B" \
  -H 'Content-Type: application/json' \
  -d "{\"source_url\":\"$PROBE\",\"source_type\":\"song\"}" | jq -r '.job_id')

[ "$A_JOB" != "$B_JOB" ] && echo "OK — separate jobs" || echo "BUG — same job!"
```

**Expected:** `OK — separate jobs`.

### 8.2 Cross-user `/status` returns 404 (not 403)

```bash
curl -i "$HEERR/api/v1/status/$A_JOB" -H "Authorization: Bearer $TOKEN_B"
```

**Expected:** `404 Not Found` — the response does not leak that the
job id exists for another user.

### 8.3 `/queue` is per-user scoped

```bash
curl -s "$HEERR/api/v1/queue" -H "Authorization: Bearer $TOKEN_A" \
  | jq '[.active[].job_id] | length'
curl -s "$HEERR/api/v1/queue" -H "Authorization: Bearer $TOKEN_B" \
  | jq '[.active[].job_id] | length'
```

**Expected:** each user sees only their own jobs.

---

## 9. Sign-off

| # | Check | Pass? |
|---|-------|-------|
| 1.1 | spotdl version logged at boot (N11) | ☐ |
| 1.2 | Orphan recovery log fired (C2) | ☐ |
| 1.3 | Manual orphan flipped to failed (C2) | ☐ |
| 2.1 | `/health` returns 200 (N7) | ☐ |
| 2.2 | `/ready` returns 200 (N7) | ☐ |
| 2.3 | `/ready` returns 503 with DB down (N7) | ☐ |
| 3.1 | `/auth/login` happy path | ☐ |
| 3.2 | `tokens.last_used_at` bumped (N3) | ☐ |
| 3.3 | Bad `NAVIDROME_URL` fails at boot (N13) | ☐ |
| 3.4 | `/auth/logout` revokes token | ☐ |
| 4.1 | `/download` accepts dirty YT URL (N14) | ☐ |
| 4.2 | spotdl invoked with canonical URL (N14) | ☐ |
| 4.3 | File lands on disk, job → done | ☐ |
| 5.1 | `/admin/tokens` requires `navidrome_username` (M1) | ☐ |
| 5.2 | Unknown username → 404 (M1) | ☐ |
| 5.3 | Minted token FK-resolves to real user | ☐ |
| 6 | Raw INSERT without user_id → NotNullViolation (T4) | ☐ |
| 7 | Body over 1 MiB → 413 (N6) | ☐ |
| 8.1 | Two users, same URL, two jobs (J7 regression) | ☐ |
| 8.2 | Cross-user `/status` returns 404 (J8 regression) | ☐ |
| 8.3 | `/queue` per-user scoped (J7 regression) | ☐ |

When every box is ticked, promote: tag `v3.1.0` on the same commit as
`v3.1.0-rc1`, push the tag, and append a CHANGELOG entry marking the
release final.
