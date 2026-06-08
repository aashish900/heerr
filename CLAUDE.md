# CLAUDE.md — heerr (Music Request App)

Strict rules for Claude in this project. Follow exactly.

---

## 1. Mandatory Logs & Session Discipline

### Files
- **CONTEXT.md** — project brief (architecture, constraints, env). Source of truth for *what and why*.
- **DECISIONLOG.md** — ADR of design **decisions** (trade-offs / choices with alternatives considered).
- **CHANGELOG.md** — append-only record of **changes** (code/file edits Claude makes).

Decision vs change: a decision is *"we chose X over Y because Z"*; a change is *"edited file F to do G"*. The same action can produce both entries.

### Session bootstrap
At the start of every session, before answering non-trivial questions or proposing changes, read in order: `CONTEXT.md` → `DECISIONLOG.md` → `CHANGELOG.md`. Trivial one-liners (clarifications, definitions) may skip. Only read source code when these three are insufficient.

### Entry format
- DECISIONLOG: `## YYYY-MM-DD — <title>` then 1–3 lines: context, decision, why. Append newest at the bottom.
- CHANGELOG: `## YYYY-MM-DD — <one-line summary>` then bullets: files touched + what changed. Append-only. Never edit or delete prior entries.
- Timestamps: use the date the harness injects into the system prompt. If unavailable, run `date` and cite it.

### Logging cadence
Flush entries **at the end of each task** (not end of session). A "task" = one user-approved unit of work. If a task spans many edits, batch them into one CHANGELOG entry on completion.

### Staleness rule
Code is the source of truth. If DECISIONLOG or CONTEXT.md contradicts current code, the log is stale — update it in the same turn you discover the drift, and note the correction in CHANGELOG.

### CONTEXT.md vs DECISIONLOG.md
- Update **CONTEXT.md** when standing facts change (architecture, env, constraints).
- Append to **DECISIONLOG.md** when a *new* decision is made (even if it also updates CONTEXT.md).

---

## 2. Project Hard Rules (derived from CONTEXT.md — do not re-litigate)

### Architecture
- Flutter is a **thin client**. No download logic, no spotDL, no Spotify SDK on the device.
- Backend is FastAPI in Docker, joins existing arr-stack at `~/docker/arr-stack/docker-compose.yml` (subnet `172.39.0.0/24`).
- Backend writes downloads to `/data/media/music` (Navidrome watches it, ~1 min scan).
- Connectivity is **Tailscale only**. Never propose public exposure, reverse proxies, or port-forwards.
- **Reproducibility via compose.** All infra setup (DB init, file ownership, schema bootstrap) must live in `docker-compose.yml` / init containers. No manual host-side steps to bring up the stack.

### Spotify
- Use **client-credentials flow only** (server-side id + secret). Never propose user-OAuth / `--user-auth` / redirect URIs.
- Feature scope: track / album / playlist search + user's own playlists. **No top-tracks** (endpoint removed).
- **Never hardcode or commit the Spotify secret.** Load from `.env` / env var in the backend container. Flag any diff that violates this.

### Scope discipline
- **Backend first, Flutter second.** Don't propose Flutter work until the backend endpoint it depends on exists and is curl-testable.
- **No Redis / Celery / RabbitMQ to start.** Use FastAPI `BackgroundTasks` for the worker; persist jobs in **Postgres** (shared arr-stack instance — see DECISIONLOG 2026-06-08). Suggest a real queue only with evidence the current setup is outgrown.
- **iOS is out of scope.** Don't suggest iOS-aware code, Cupertino widgets where Material works, or Xcode/CocoaPods steps.
- spotDL runs server-side only — phone-side spotDL has been ruled out (iOS broken, Termux broken on `libpthread.so.0` / tls-client). Don't revisit.

### Development workflow
- **TDD by default (Python backend).** Write the failing test, then the implementation. No production logic merges without a test that exercises it first. Scope: FastAPI app code (endpoints, services, models, CLI). Out of scope: `docker-compose.yml`, Dockerfiles, Alembic migrations, Flutter UI — these have their own verification gates (`docker compose up` clean, `alembic upgrade head` clean, manual smoke).
- **Green before, green after.** Run the test suite before starting a task and confirm it's passing. Run it again before declaring done. If tests were red before you started, fix or quarantine them first — don't pile changes onto a broken baseline.

### Frontend hand-holding
- User has DevOps/data-eng background, **zero mobile-app experience**. On Flutter/Dart/Android tooling: explain step-by-step, name every file path, show full commands. On backend/Docker/Python: be terse — user is fluent.

### Sources
- Cite docs / file paths / log lines for non-trivial claims. Distinguish cited facts from inferences. State assumptions before acting on them.
