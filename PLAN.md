# PLAN — Jam / remote control (phase JM)

Status: planned, nothing executed. Do one task at a time. After each task, tick its box and commit. Use TDD. Tests and lint must be green before and after every task:
- backend: `poetry run pytest`
- android: `flutter test` + `flutter analyze`

## 1. Goal

The host's phone is in the car, connected to Android Auto, playing heerr and running Maps. A passenger runs heerr on their own phone and controls the host's playback: play now, add to queue, play/pause, next/prev, seek. Audio plays only on the host's phone. The passenger's phone is just a remote.

## 2. Decisions (user-confirmed 2026-11-05)

- **Transport:** commands go through the existing heerr backend. Phone-to-phone was rejected because it needs a local server on the phone, device discovery, and has a Wi-Fi conflict with wireless Android Auto.
- **Guest access:** the guest reaches the backend through a **Tailscale node share** and logs in with their own Navidrome account (the existing Phase J login).
- **Remote scope:** full control (play now, enqueue, play/pause, next/prev, seek).
- **Pairing:** the host starts a session and its phone shows a short code. The guest types the code in. The session lives until the host stops it, or until a TTL runs out.

## 3. Facts (from code / docs)

**Constraints**
- No WebSocket, SSE or FCM. Polling is the contract (`android/CLAUDE.md` "Polling, not streaming", `android/docs/CONTEXT.md:17`).
- No Redis or queues (`backend/CLAUDE.md`). The backend has no long-poll, SSE or in-memory pub/sub today.
- There is one Navidrome library per heerr instance (`backend/docs/CONTEXT.md:32`), so a Navidrome song id means the same song on both phones.

**Backend**
- Auth deps: `require_scope("read")` (`backend/app/api/deps.py:96`) returns the token, and `tok.user_id` gives per-user isolation. `current_user` is at `deps.py:91`.
- Routers: one module per feature in `backend/app/api/v1/`, wired in `backend/app/api/v1/router.py:19-32`.
- DB: async SQLAlchemy 2.0 (`backend/app/db.py`). Migrations are hand-written Alembic (`target_metadata=None`, `alembic/env.py:26`). The head is `0014_jobs_episode.py`.
- Reference pattern: model `backend/app/models/podcast_progress.py`; endpoint `backend/app/api/v1/podcasts.py:409-436`; schemas `backend/app/schemas/podcast.py:108-115`.
- Tests: testcontainers Postgres. Fixtures `make_token`, `app_sm` (`backend/tests/conftest.py`). App-test pattern in `backend/tests/test_podcast_progress.py:15-36`. Schema guard `backend/tests/test_models_match_schema.py`.
- Version is `5.5.0` (`backend/pyproject.toml:3`, `backend/app/main.py:40`).

**Android: playback**
- Handler: `HeerrAudioHandler` (`android/app/lib/player/heerr_audio_handler.dart`).
  - `playSong` :254, `playAll(items, startIndex:)` :271, `addQueueItems` :190
  - `play` :326, `pause` :329, `seek` :338, `skipToNext` :341, `skipToPrevious` :348
  - `snapshotStream()` :418 returns `PlayerSnapshot {item, state}`
- **The `_isLoadingSource` guard (:97) silently drops a load issued while another load is in flight.**
- `MediaItem.id` is the playback URL. The Navidrome id lives in `extras['subsonicId']` (`player/song_to_media_item.dart`). The reverse map `songFromMediaItem` is in the same file.
- **Song to MediaItem:** `songItem(read, song, url:, user:, pass:)` (`player/play_core.dart`). It takes a `ProviderReader`, so `ProviderContainer.read` works.
- **No-UI play path to copy:** `playBrowseId` (`player/browse_play.dart:17-60`). It reads creds from `serverCredsProvider`, builds items, then calls `playAll`.
- **UI play wrappers**, all in `player/playback_actions.dart`, all take `(WidgetRef, BuildContext)`:
  - `playSongFromSubsonic` :77
  - `addSongsToQueue` :146 (plays instead when the queue is empty)
  - `playAllSongsFromSubsonic` :188
  - `shuffleAllSongsFromSubsonic` :268
  - album :323, artist :345 and playlist :371 all funnel into `playAllSongsFromSubsonic`
  - `playPreview` :109 is an online preview with no Subsonic id
- `Song` is freezed and has `fromJson`/`toJson` (`models/subsonic/song.dart:14-36`).

**Android: everything else**
- Polling template: `providers/queue.dart`. A keepAlive notifier reschedules a one-shot `Timer` after each tick; the interval is an overridable provider (:10-16); it has `pause()`/`resume()`.
- Backend HTTP: `BackendService` (`services/backend_service.dart`) on `dioClientProvider` (`api/client.dart`), using the bearer interceptor.
- Settings sections: `screens/settings/settings_screen.dart:55-83`. Tile widgets: `screens/settings/settings_tiles.dart`. Routes: `router.dart` (`Routes` class :38-75, full-screen pushes next to `/player`).
- `AudioService.init` has `androidStopForegroundOnPause: true` (`main.dart:41`).
- No QR packages are installed (`pubspec.yaml`).

## 4. Assumptions (please review before JM1)

- A. **Library songs only.** Online YTM results (`playPreview`) and shuffle-all can't be sent to the host. Those actions stay local and show a snackbar saying "not available while controlling <host>".
- B. **Payload carries full `Song` JSON**, not just the id. The guest already has the `Song` objects. The host deserializes them and calls `songItem` with its own Navidrome creds, which gives it the correct local-file or stream URL. This avoids adding `getSong.view` and N extra round trips. The host only trusts `id` for the stream URL; the other fields are display metadata.
- C. **One active session per host.** Starting a new session ends the old one. Any number of guests can join.
- D. **Authz** = a valid heerr token with `read` scope + knowledge of an active, unexpired code. There's no participant table. The code is 6 chars from an unambiguous alphabet (no 0/O/1/I), and the TTL is 12h. This is acceptable because the backend is reachable only over the tailnet.
- E. **Host poll is 1s, guest state poll is 2s.** Both are overridable providers.
- F. **Commands run strictly in order, one at a time**, each awaited, so the `_isLoadingSource` guard can't drop them.
- G. **Stale commands are discarded.** On a cold start, or when the host (re)starts polling, the cursor starts at the session's current max command id, so old commands don't replay.
- H. **Pairing is code-only.** No QR, because QR needs 2 new deps (`qr_flutter`, `mobile_scanner`). That's a backlog item.
- I. **(Unverified, gated by JM7)** the Dart `Timer` keeps firing while the app is in the background, as long as the audio_service foreground service is up. With `androidStopForegroundOnPause: true`, a paused host may stop polling, so a guest's "play" never arrives. The candidate fix is to keep the foreground service while a jam session is active.

## 5. Design

### 5.1 Data model (migration `0015_jam`)

```
jam_session
  id            uuid pk default gen_random_uuid()
  host_user_id  uuid not null fk users(id) on delete restrict
  code          text not null            -- unique among active rows (partial unique index where ended_at is null)
  state         jsonb null               -- latest host snapshot (see 5.3)
  state_at      timestamptz null
  created_at    timestamptz not null default now()
  expires_at    timestamptz not null     -- created_at + 12h
  ended_at      timestamptz null
  index (host_user_id) where ended_at is null

jam_command
  id            bigserial pk             -- monotonic cursor
  session_id    uuid not null fk jam_session(id) on delete cascade
  sender_user_id uuid not null fk users(id) on delete restrict
  kind          text not null check (kind in ('play_songs','enqueue','play','pause','next','prev','seek'))
  payload       jsonb not null default '{}'
  created_at    timestamptz not null default now()
  index (session_id, id)
```

`ponytail:` there's no cleanup job, so ended sessions and their commands stay in the table forever. Add a prune of `ended_at < now() - 7d` to the startup `lifespan` (`backend/app/main.py:18-32`) once the rows are actually noticeable.

### 5.2 API (all under `/api/v1/jam`, all `require_scope("read")`)

| Method | Path | Caller | Body | Returns | Errors |
|---|---|---|---|---|---|
| POST | `/jam` | host | — | `{id, code, expires_at}` | ends any prior active session of the caller |
| DELETE | `/jam/{id}` | host | — | 204 | 403 not host, 404 unknown |
| POST | `/jam/join` | guest | `{code}` | `{id, host_username, expires_at}` | 404 unknown/ended/expired, 409 joining own session |
| POST | `/jam/{id}/commands` | guest or host | `{kind, payload}` | `{id}` 201 | 404 inactive, 422 bad kind/payload |
| POST | `/jam/{id}/sync` | host | `{state, after}` | `{commands:[{id,kind,payload,sender}], ended:false}` | 403 not host, 404 unknown |
| GET | `/jam/{id}/state` | guest | — | `{state, state_at, host_username, ended}` | 404 unknown |

- `after = null` means: return no commands, plus `cursor = max(id)`. This is how assumption G is implemented. The response always includes `cursor`.
- `sync` on an ended or expired session returns `ended: true`, and the host stops polling.
- `GET /state` returns `ended: true` after the host stops, and the guest app shows "Session ended".

**Command payloads:**
- `play_songs`: `{songs:[Song], start_index:int}`
- `enqueue`: `{songs:[Song]}`
- `seek`: `{position_ms:int}`
- every other kind: `{}`

The backend validates the shape: `songs` must be a list of 1–500 objects that each have a string `id`. It does not validate the rest of each `Song`.

### 5.3 Host state snapshot (JSON written by `sync`)

```
{ "playing": bool, "position_ms": int, "updated_at_ms": int,
  "current": Song|null, "queue": [Song] (capped 50 from current index), "queue_index": int }
```

The guest extrapolates the playback position on its own: `position_ms + (now - updated_at_ms)` while `playing` is true.

### 5.4 Android: host side

- **`providers/jam_host.dart`:** a keepAlive notifier holding the state `{sessionId, code, commandsReceived, error}`. Loop, using the `queue.dart` template:
  1. Build the snapshot from the latest `PlayerSnapshot` and `handler.queue.value`, mapping each item through `songFromMediaItem`.
  2. Call `sync(state, after)`.
  3. Run each returned command in order, awaiting each one.
  4. Advance the cursor.
  5. Reschedule after 1s.
  - On error: keep polling, as `queue.dart` does.
  - On `ended: true`: clear the state.
- **`player/jam_executor.dart`:** a pure function `runJamCommand(ProviderReader read, HeerrAudioHandler h, JamCommand cmd)`, modelled on `playBrowseId`:
  - `play_songs` → `Song.fromJson` → `songItem` → `h.playAll(items, startIndex)`
  - `enqueue` → when the queue is empty, `playAll` (matching `addSongsToQueue`); otherwise `addQueueItems`
  - `play`/`pause`/`next`/`prev`/`seek` → the matching handler methods
  - An unknown kind is ignored.
- **Lifetime:** the session is started and stopped from the Jam screen. It is held in memory only. If the app process dies, the session is gone on the device, and the backend TTL ends it.

### 5.5 Android: guest side

- **`providers/jam_remote.dart`:** a keepAlive notifier holding `{sessionId, hostUsername}` plus a state poll every 2s, with `pause()`/`resume()` driven by app lifecycle.
- **`player/playback_actions.dart`:** this is the routing point. Add a single guard at the top of each wrapper:
  - Covered: `playSongFromSubsonic`, `addSongsToQueue`, `playAllSongsFromSubsonic`, which album/artist/playlist already go through.
  - When joined, the wrapper sends a command instead of calling the handler, and shows the snackbar "Sent to <host>".
  - `playPreview` and `shuffleAllSongsFromSubsonic` show the "not available while controlling" snackbar instead (assumption A).
- **Transport buttons:** the Jam screen (guest mode) has its own controls that send `play`/`pause`/`next`/`prev`/`seek`. The local mini-player and Now Playing screen still control the guest's own phone. A banner makes it obvious which phone you're controlling.
- **Banner:** a "Controlling <host> · Leave" strip shown above the mini-player while joined. Tapping it opens the Jam screen.

### 5.6 UI

- Settings: a new section header "Remote control" with one tile, "Jam session", that pushes `Routes.jam` (`/jam`).
- `screens/jam_screen.dart` has three states:
  - **Idle:** a "Start session (this phone plays)" button, and a "Join session" code field with a Join button.
  - **Hosting:** the big code in large monospace, "Guests can type this in heerr → Settings → Jam session", the number of commands received, and a Stop button.
  - **Joined:** the host's now-playing (art, title, artist, a progress bar from the extrapolated position), transport buttons, the next ~10 queue items, and Leave.
- Browsing and search screens are unchanged. Their play and queue taps get routed by 5.5.

## 6. Out of scope

- QR pairing (backlog).
- Sending online YTM results or downloads to the host.
- Guest reorder/remove of queue items, or editing the host's queue beyond play/enqueue.
- Android Auto UI changes: the car keeps showing whatever the host's handler is playing, which already works.
- Push or real-time transport (forbidden).
- Cross-instance jams (a guest on a different heerr server).

## 7. Tasks

### [x] JM0. Docs: ADRs + roadmap entry (no code)
- `backend/docs/DECISIONLOG.md` and `android/docs/DECISIONLOG.md`, one ADR each (2026-11-05): backend relay over phone-to-phone; REST polling at a 1s host cadence instead of push; code-only pairing; Song JSON in the payload instead of `getSong`.
- `backend/docs/ROADMAP.md` and `android/docs/ROADMAP.md`: add "Phase JM — Jam / remote control (v5.6.0)" with the JM1–JM9 headings and a pointer to `/PLAN.md`.
- Gate: user reviews the assumptions in §4.
- Commit: `docs: JM0 — jam remote-control ADRs + roadmap`

### [x] JM1. Backend: migration + models
- New `backend/alembic/versions/0015_jam.py` (`down_revision="0014"`), schema as in §5.1, with a working downgrade.
- New `backend/app/models/jam.py` (`JamSession`, `JamCommand`), exported from `backend/app/models/__init__.py`.
- Tests: `backend/tests/test_migration_0015.py` (upgrade/downgrade and constraints: bad `kind` rejected, partial unique `code`, cascade delete). Extend `backend/tests/test_models_match_schema.py` if it enumerates models.
- Gate: `poetry run pytest` green.
- Commit: `feat(backend): JM1 — jam_session / jam_command schema`

### [x] JM2. Backend: session lifecycle endpoints
- New `backend/app/schemas/jam.py` and `backend/app/api/v1/jam.py`. Wire it in `router.py`.
- `POST /jam`, `DELETE /jam/{id}`, `POST /jam/join`. Code generation uses `secrets.choice` over the unambiguous alphabet, retrying on a unique-index collision.
- Tests in `backend/tests/test_jam.py`:
  - create returns a code
  - a second create ends the first
  - join with the right code works; wrong, ended or expired codes → 404
  - joining your own session → 409
  - a non-host DELETE → 403
- Commit: `feat(backend): JM2 — jam session create/join/end`

### [x] JM3. Backend: commands + sync + state
- `POST /jam/{id}/commands`, `POST /jam/{id}/sync`, `GET /jam/{id}/state`, following §5.2 (payload validation, the `after=null` cursor bootstrap, the `ended` flag).
- Tests:
  - a guest command shows up in the host's `sync` with `after`, and `after=cursor` returns nothing
  - `after=null` returns only the cursor
  - a non-host `sync` → 403
  - a state written by `sync` is readable by the guest
  - commands on an ended session → 404
  - bad kind/payload → 422
- Gate: a manual curl round trip with two tokens, documented in `backend/README.md` (create → join → command → sync).
- Commit: `feat(backend): JM3 — jam command relay + host state`

### [x] JM4. Android: models + BackendService methods
- New `android/app/lib/models/jam.dart` (freezed): `JamSession`, `JamJoin`, `JamCommand`, `JamSyncResponse`, `JamState`.
- `services/backend_service.dart`: add `jamCreate`, `jamEnd`, `jamJoin`, `jamSend`, `jamSync`, `jamState`, all through `apiCall`.
- Run codegen: `cd android/app && dart run build_runner build --delete-conflicting-outputs`.
- Tests: model JSON round-trip; service methods against the existing dio-mock pattern in `android/app/test/services/`.
- Commit: `feat(flutter): JM4 — jam API client`

### [x] JM5. Android: host executor + poller
- New `player/jam_executor.dart` (`runJamCommand`), following §5.4.
- New `providers/jam_host.dart`: `start()`, `stop()`, the 1s loop, the cursor bootstrap, and in-order execution. Interval provider `jamHostPollInterval`.
- Tests:
  - executor: use the mocktail handler from `android/app/test/player/heerr_audio_handler_modes_test.dart`. Each kind calls the right handler method; `enqueue` on an empty queue calls `playAll`.
  - poller: with `fake_async`, commands run in order and one at a time; the cursor advances; `ended` stops polling; an error keeps polling.
- Commit: `feat(flutter): JM5 — jam host command executor`

### [x] JM6. Android: Jam screen (idle + hosting) + Settings entry
- New `screens/jam_screen.dart` (idle and hosting states). Add `Routes.jam` and a `GoRoute` in `router.dart`. Add the "Remote control" section in `screens/settings/settings_screen.dart`.
- Widget tests: idle shows Start and Join; Start shows the code; Stop goes back to idle.
- Commit: `feat(flutter): JM6 — jam host screen`

### [ ] JM7. Spike: background polling on a real device (no feature code unless needed)
- Host on the phone with the screen off, then playing → paused for 5 minutes. Watch `adb logcat` for the sync requests (backend access log as well).
- If polling stops while paused: when a jam session is active, keep the foreground service alive (switch `androidStopForegroundOnPause` behaviour, or call `AudioService` to keep it). Record the result in the android DECISIONLOG.
- Gate: a command sent during a 5-minute pause executes within about 2s.
- Commit (only if code changed): `fix(flutter): JM7 — keep jam host polling while paused`

### [x] JM8. Android: guest mode (join, routing, remote controls, banner)
- New `providers/jam_remote.dart`: join/leave plus the 2s state poll with lifecycle pause/resume.
- Guards in `player/playback_actions.dart`: `playSongFromSubsonic`, `addSongsToQueue` and `playAllSongsFromSubsonic` route to `jamSend`; `playPreview` and `shuffleAllSongsFromSubsonic` show the not-available snackbar.
- The joined state of `jam_screen.dart`: now-playing, extrapolated progress, transport, queue preview, Leave, and the "Session ended" handling.
- A "Controlling <host>" banner above the mini-player in the shell scaffold (`router.dart` shell route).
- Tests:
  - routing: when joined, the wrappers call `jamSend` and never touch the handler; when not joined, behaviour is unchanged
  - remote poller: `ended` leaves the session
  - widget test for the joined screen
- Commit: `feat(flutter): JM8 — jam guest remote`

### [ ] JM9. End-to-end smoke + docs + version 5.6.0
- Two real phones (two Navidrome users, guest via a Tailscale node share), host on the DHU:
  - play now, enqueue, pause/play, next/prev, seek
  - host Stop → the guest sees "Session ended"
  - the host's Android Auto now-playing updates
- Docs:
  - `backend/docs/CONTEXT.md` and `android/docs/CONTEXT.md`: jam facts.
  - `android/README.md`: guest setup — create the Navidrome user; Tailscale admin console → Machines → the server → Share; the guest accepts and installs heerr; logs in.
  - `backend/README.md`: the jam endpoints.
  - CHANGELOGs for both apps.
- Version bump to `5.6.0` in all 5 places (root `CLAUDE.md` §3).
- Run `graphify update .`.
- Commit: `chore: bump version to 5.6.0 (jam remote control)`

## 8. Risks

- **The paused host stops polling** (assumption I). JM7 gates this before guest work starts.
- **Latency:** 0–1s of poll delay plus a Tailscale round trip over mobile data. Inference: about 1–2s end to end in the car.
- **Data/battery on the host:** 3,600 small POSTs an hour while a session is active. Polling runs only while a session is active.
- **Song JSON drift:** a guest on an older app version could send fields the host can't parse. `Song.fromJson` must stay tolerant (verify that its unknown-key handling is the default in JM5).
