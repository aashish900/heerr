# heerr

**Seerr, but for music.** Search YouTube Music from your phone, dispatch downloads to your home server, watch the queue as tracks land in Navidrome.

[![backend CI](https://github.com/aashish900/heerr/actions/workflows/backend-ci.yml/badge.svg)](https://github.com/aashish900/heerr/actions/workflows/backend-ci.yml)
[![Docker publish](https://github.com/aashish900/heerr/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/aashish900/heerr/actions/workflows/docker-publish.yml)
[![Android APK](https://github.com/aashish900/heerr/actions/workflows/android-publish.yml/badge.svg)](https://github.com/aashish900/heerr/actions/workflows/android-publish.yml)
[![latest release](https://img.shields.io/github/v/release/aashish900/heerr)](https://github.com/aashish900/heerr/releases/latest)

---

## How it works

```
Phone (Android app)
  │  search query / download request (Bearer token over HTTPS)
  ▼  (Tailscale only — no public ingress)
FastAPI backend  ──── YouTube Music (ytmusicapi, no credentials)
  │  spotDL subprocess (yt-dlp under the hood)
  ▼
/data/media/music/...
  │  auto-indexed within ~1 min
  ▼
Navidrome (streaming)
```

The phone is a **thin client** — no download logic, no Spotify SDK, no credentials on device. It only speaks REST to the backend. The backend does everything: search, download, dedupe, state tracking.

---

## Repository layout

```
heerr/
├── backend/                  FastAPI service (Python 3.13 + Poetry)
│   ├── README.md             ← operational entry point (install, run, curl)
│   ├── Dockerfile
│   ├── app/
│   │   ├── api/v1/           endpoints: /health /search /download /status /queue /admin
│   │   ├── models/           SQLAlchemy ORM (tokens, jobs, downloads)
│   │   ├── services/         ytmusic.py · jobs.py · spotdl_runner.py · workers.py
│   │   └── cli.py            token management (create / list / revoke)
│   ├── alembic/              migrations (0001 schema v1, 0002 display_name)
│   ├── tests/                pytest suite (testcontainers-postgres)
│   └── docs/                 CONTEXT · PLAN · ROADMAP · DECISIONLOG · CHANGELOG
│
├── android/                  Flutter client (Android-only)
│   ├── README.md             ← operational entry point (build, sign, install)
│   ├── app/
│   │   ├── lib/
│   │   │   ├── main.dart
│   │   │   ├── theme.dart    heerr-green (#1DB954) on Material 3 dark
│   │   │   ├── router.dart   go_router: /search /queue /settings /settings/servers
│   │   │   ├── api/          dio client + bearer interceptor + ApiError mapping
│   │   │   ├── models/       freezed + json_serializable
│   │   │   ├── providers/    Riverpod: settings · download · queue · search · job_status
│   │   │   └── screens/      search · queue · job_detail · settings · servers
│   │   └── test/             Flutter widget + unit tests
│   └── docs/                 CONTEXT · PLAN · ROADMAP · DECISIONLOG · CHANGELOG
│
├── docker-compose.snippet.yml   merge into your arr-stack compose file
├── .env.example                 env template — copy to .env and populate
├── CLAUDE.md                    project-wide rules for Claude Code sessions
└── .github/workflows/
    ├── backend-ci.yml           ruff + mypy + pytest on every PR / push to main
    ├── docker-publish.yml       build + trivy scan + push to Docker Hub on v* tags
    └── android-publish.yml      build signed APK + publish GitHub Release on v* tags
```

---

## Quick start

### 1. Deploy the backend

```bash
# Configure environment
cp .env.example .env
# edit .env — fill in POSTGRES_PASSWORD, DATABASE_URL, MUSIC_OUTPUT_DIR

# Merge docker-compose.snippet.yml into your arr-stack compose file, then:
docker compose up -d heerr-postgres-init heerr-postgres
docker compose up -d heerr-migrate          # one-shot: alembic upgrade head
docker compose up -d heerr-backend

# Verify
curl http://localhost:8000/api/v1/health    # → {"status":"ok"}
```

Full env-var reference, curl examples, CLI usage: [`backend/README.md`](backend/README.md).

### 2. Mint a bearer token

```bash
docker compose exec heerr-backend \
  python -m app.cli create-token --owner=phone --scopes=read,download
# prints the raw token ONCE — copy it; the DB stores only sha256(raw).
```

### 3. Install the Android app

Download the latest signed APK from [**Releases**](https://github.com/aashish900/heerr/releases/latest) and sideload:

```bash
adb install heerr-v*.apk
```

On first launch: **Settings → Servers → +** → enter a name, backend URL (`http://<tailscale-host>:8000/api/v1`), bearer token → **Save** → tap **Test connection** → expect "ok".

Building from source + keystore generation: [`android/README.md`](android/README.md).

---

## API contract (v1)

All under `/api/v1`. JSON in/out. `Authorization: Bearer <raw-token>` on every endpoint except `/health`.

| Method | Path | Scope | Purpose |
|---|---|---|---|
| `GET` | `/health` | none | Liveness — used by compose healthcheck + app's "Test connection" |
| `POST` | `/search` | `read` | YouTube Music song/album/playlist search with dedupe hints |
| `POST` | `/download` | `download` | Idempotent dispatch — returns `deduped=true` for active or on-disk URIs |
| `GET` | `/status/{job_id}` | `read` | Single-job state for the job-detail screen |
| `GET` | `/queue` | `read` | Active jobs + recent 20 finished — queue screen polls every 3s |
| `POST` | `/admin/tokens` | admin flag | CLI-equivalent token mint |
| `POST` | `/admin/jobs/{id}/retry` | admin flag | Re-queue a `failed` job; bumps `attempt_count` |

Frozen contract with full request/response shapes and error envelope: [`backend/docs/PLAN.md`](backend/docs/PLAN.md).

---

## CI / CD

| Trigger | Workflow | What it does |
|---|---|---|
| PR → `main` (backend files) | [`backend-ci.yml`](.github/workflows/backend-ci.yml) | ruff lint + format check, mypy, pytest (testcontainers-postgres) |
| Push to `main` (backend files) | [`backend-ci.yml`](.github/workflows/backend-ci.yml) | same — keeps the main badge green |
| Push tag `v*` | [`docker-publish.yml`](.github/workflows/docker-publish.yml) | build amd64 image, Trivy CVE scan, push multi-arch (amd64+arm64) to Docker Hub |
| Push tag `v*` | [`android-publish.yml`](.github/workflows/android-publish.yml) | `flutter build apk --release` (signed), create GitHub Release, attach APK |

**Cutting a release** — tag on `main`, push:

```bash
git tag -a v0.2.0 -m "v0.2.0 — <summary>"
git push origin v0.2.0
```

This fires both publish workflows in parallel. The Docker image is tagged `0.2.0`, `0.2`, `latest`, and `sha-<short>`. The APK is attached to a GitHub Release as `heerr-v0.2.0.apk`.

Docker Hub: [`aashish010/heerr-backend`](https://hub.docker.com/r/aashish010/heerr-backend).

### Required GitHub secrets

| Workflow | Secret | Purpose |
|---|---|---|
| `docker-publish.yml` | `DOCKERHUB_USERNAME` | Docker Hub login |
| `docker-publish.yml` | `DOCKERHUB_TOKEN` | Docker Hub access token (Read & Write) |
| `android-publish.yml` | `ANDROID_KEYSTORE_BASE64` | `base64 -i android/app/android/keystore.jks \| tr -d '\n'` |
| `android-publish.yml` | `ANDROID_KEY_ALIAS` | keystore alias (e.g. `heerr`) |
| `android-publish.yml` | `ANDROID_KEY_PASSWORD` | key password |
| `android-publish.yml` | `ANDROID_STORE_PASSWORD` | keystore password |

---

## Stack at a glance

| Layer | Technology |
|---|---|
| Backend language | Python 3.13 + FastAPI + SQLAlchemy 2 (async) |
| Database | PostgreSQL 17 (`pgvector/pgvector:pg17`) |
| Migrations | Alembic |
| Download engine | spotDL 4.5.0 — invoked as a subprocess, isolated venv |
| Search | YouTube Music via ytmusicapi (no API key) |
| Worker | FastAPI `BackgroundTasks` (no Redis/Celery — single-user scale) |
| Auth | Per-user opaque bearer tokens with scopes (`read`, `download`) — sha256 hashed at rest |
| Android app | Flutter 3.44.0 / Dart 3.12.0 |
| State management | Riverpod (riverpod_generator) |
| HTTP | dio + bearer interceptor + typed `ApiError` |
| JSON models | freezed + json_serializable |
| Secure storage | flutter_secure_storage (Android EncryptedSharedPreferences) |
| Navigation | go_router |
| Theme | Material 3 dark, seed `#1DB954` |
| Connectivity | Tailscale only — no public ingress |

Rationale for every choice lives in the per-app `docs/DECISIONLOG.md`.

---

## Hard constraints (do not re-litigate)

- **No public ingress.** App-to-backend traffic runs over Tailscale only.
- **No secrets in the repo.** DB passwords, bearer tokens — all `.env` / GitHub Secrets / `flutter_secure_storage`.
- **iOS is out of scope.** No Xcode, no Cupertino, no CocoaPods.
- **spotDL runs server-side only** — phone-side spotDL is broken (iOS unsupported; Android/Termux dies on `libpthread.so.0`).

Full project-wide rules: [`CLAUDE.md`](CLAUDE.md).

---

## Further reading

| Document | Contents |
|---|---|
| [`backend/README.md`](backend/README.md) | Install, run, curl examples, env-var reference, CLI |
| [`backend/docs/CONTEXT.md`](backend/docs/CONTEXT.md) | Server environment, architecture decisions, hard constraints |
| [`backend/docs/PLAN.md`](backend/docs/PLAN.md) | Frozen API contract — endpoint shapes, scopes, error envelope |
| [`backend/docs/ROADMAP.md`](backend/docs/ROADMAP.md) | A1–H1 milestones and current status |
| [`backend/docs/DECISIONLOG.md`](backend/docs/DECISIONLOG.md) | All backend ADRs |
| [`backend/docs/CHANGELOG.md`](backend/docs/CHANGELOG.md) | Per-task change log |
| [`android/README.md`](android/README.md) | Flutter dev commands, release build + signing, sideload instructions |
| [`android/docs/CONTEXT.md`](android/docs/CONTEXT.md) | App architecture, screen contract, polling cadences, error UX |
| [`android/docs/PLAN.md`](android/docs/PLAN.md) | Frozen UI contract — screens, widgets, routing, test scope |
| [`android/docs/ROADMAP.md`](android/docs/ROADMAP.md) | A1–G1 milestones and current status |
| [`android/docs/DECISIONLOG.md`](android/docs/DECISIONLOG.md) | All Android ADRs (Riverpod, polling-not-WebSocket, secure storage, etc.) |
| [`android/docs/CHANGELOG.md`](android/docs/CHANGELOG.md) | Per-task change log |
| [`CLAUDE.md`](CLAUDE.md) | Project-wide rules for Claude Code sessions |
| [`.env.example`](.env.example) | Environment variable template |
| [`docker-compose.snippet.yml`](docker-compose.snippet.yml) | Services to merge into your arr-stack |
