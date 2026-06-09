# heerr — Android client

Native Android app: search Spotify, dispatch downloads to the home-server backend, watch the queue. Talks REST over Tailscale to the FastAPI service in [`../backend/`](../backend/).

> **Status (2026-06-09):** planning complete. Flutter project itself does not exist yet — `android/app/` is created at milestone A1. Until then this README is forward-looking; commands marked **(post-A1)** won't work yet.

---

## Table of contents

- [What it does](#what-it-does)
- [Stack](#stack)
- [Prerequisites](#prerequisites)
- [Project layout](#project-layout)
- [Quick start — once A1 lands](#quick-start--once-a1-lands)
- [Configuring the app](#configuring-the-app)
- [Development commands](#development-commands)
- [Building a release APK](#building-a-release-apk)
- [Further reading](#further-reading)

---

## What it does

1. Settings screen: paste backend URL (`http://<tailscale-host>:8000/api/v1`) + bearer token (minted by the backend CLI). "Test connection" hits `/health`.
2. Search screen: type / album / playlist search via the backend's `/search`.
3. Tap a result → backend dispatches the download (`/download`) → Navidrome auto-indexes the file on the home server within ~1 min.
4. Queue + job-detail screens poll `/queue` and `/status/{id}` to show what's in flight.

What it explicitly does **not** do (see `docs/PLAN.md` §11): Spotify SDK / OAuth on device, push notifications, biometric unlock, light theme, iOS port, admin endpoints, internationalisation.

---

## Stack

Locked v1 — full rationale in `docs/DECISIONLOG.md`:

| Concern | Choice |
|---|---|
| State management | `flutter_riverpod` + codegen |
| HTTP | `dio` with auth-injecting interceptor |
| JSON | `freezed` + `json_serializable` + `build_runner` |
| Token storage | `flutter_secure_storage` |
| Navigation | `go_router` |
| Theme | Material 3, dark, seed `#1DB954` |

---

## Prerequisites

| Tool | Version | Notes |
|---|---|---|
| Flutter SDK | 3.44.0 stable | `flutter --version`. User has it at `~/develop/flutter`. |
| Dart | 3.12.0 | Bundled with Flutter 3.44.0. |
| Android SDK | 36.1.0 | Via Android Studio; cmdline-tools + licenses accepted. |
| `adb` | from platform-tools | On PATH at `~/Library/Android/sdk/platform-tools`. |
| Test device | Pixel 7, Android 16 (API 36) | Connected over wireless adb (`adb pair` → `adb connect`). |

Already set up + smoke-tested per root `CONTEXT.md`. The Flutter starter app builds and runs on the Pixel — confirmed before the planning round.

---

## Project layout

```
android/
├── README.md              ← you are here
├── CLAUDE.md              ← Claude rules
├── docs/
│   ├── CONTEXT.md         project brief
│   ├── PLAN.md            frozen v1 contract
│   ├── ROADMAP.md         milestone sequence
│   ├── DECISIONLOG.md     ADRs
│   └── CHANGELOG.md       per-task history
└── app/                   ← `flutter create` lives here (created at A1)
    ├── pubspec.yaml
    ├── analysis_options.yaml
    ├── android/
    ├── lib/
    │   ├── main.dart
    │   ├── theme.dart
    │   ├── router.dart
    │   ├── api/, models/, providers/, screens/, widgets/
    └── test/
```

See `docs/PLAN.md` §2 for the full annotated `lib/` tree.

---

## Quick start — once A1 lands

**(post-A1 — won't work until milestone A1 ships):**

```bash
# from repo root
cd android/app
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs   # generates freezed + json + riverpod
flutter run -d <device-id>                                        # `flutter devices` to list
```

Open the Settings screen on first launch, paste the backend URL + token, hit "Test connection" → expect "ok".

---

## Configuring the app

Two values, entered once on the Settings screen, persisted to `flutter_secure_storage`:

| Field | Example | Notes |
|---|---|---|
| Backend base URL | `http://100.106.120.121:8000/api/v1` | Tailscale IP or MagicDNS name + `:8000` + `/api/v1`. Trailing slash trimmed automatically. |
| Bearer token | `rXq…` (raw output of `create-token`) | Minted on the backend: `python -m app.cli create-token --owner=phone --scopes=read,download`. |

No `.env` files. No `--dart-define`. Settings → Save persists; the dio client provider invalidates and rebuilds with the new values.

---

## Development commands

**(post-A1):**

```bash
cd android/app

flutter analyze                                # lint
flutter test                                   # unit + widget tests
flutter pub run build_runner watch \
  --delete-conflicting-outputs                 # codegen on edit
flutter run -d <device-id>                     # hot-reload dev loop
```

The CI workflow on `main` runs `flutter analyze` + `flutter test` for every PR touching `android/**` (added at a Flutter-CI milestone post-G1; planning-round scope only).

---

## Building a release APK

**(post-F1):**

```bash
cd android/app
flutter build apk --release                    # → build/app/outputs/flutter-apk/app-release.apk
adb install build/app/outputs/flutter-apk/app-release.apk
```

Signing keystore + `key.properties` are gitignored. Generation steps are in F1's commit message.

---

## Further reading

- `CLAUDE.md` — Android-client Claude rules.
- `docs/CONTEXT.md` — env, target device, what the app does NOT do, user background.
- `docs/PLAN.md` — locked v1 contract (stack, layout, API, routing, theme, polling, errors, tests, scope).
- `docs/ROADMAP.md` — A1 → G1 milestones.
- `docs/DECISIONLOG.md` — ADRs (Riverpod choice, polling-not-WebSocket, etc.).
- `docs/CHANGELOG.md` — per-task history.
- `../backend/README.md` — the API the app consumes.
- `/CLAUDE.md` — project-wide rules (Tailscale-only, never commit secrets, etc.).
