# CLAUDE.md — android

Android-client Claude rules. The app is built with Flutter but deploys Android-only; the dir is named for the platform, not the framework. **Project-wide rules live in `/CLAUDE.md` at repo root** — read that first.

---

## Bootstrap (when working on the Android client)

In order:
1. `/CLAUDE.md` (project-wide rules)
2. `android/CLAUDE.md` (this file — Android client hard rules)
3. `android/docs/CONTEXT.md` (env, target device, user background)
4. `android/docs/DECISIONLOG.md` (ADRs — newest at the bottom)
5. `android/docs/CHANGELOG.md` (per-task history)

For operational lookup: `android/README.md`.
For the locked v1 contract: `android/docs/PLAN.md`.
For the build sequence: `android/docs/ROADMAP.md`.

---

## Architecture (do not re-litigate)

- **Thin client.** REST-over-HTTPS against the FastAPI backend at `http://<tailscale-host>:8000/api/v1`. No download logic on the device. No spotDL. No Spotify SDK. No Spotify OAuth.
- **Connectivity is Tailscale-only.** App reaches the backend via the host's tailnet IP / MagicDNS name. There is no public ingress; the user enters the backend URL in Settings.
- **Single-user.** No multi-user login, no Sign-In-With-X, no biometric token unlock. The bearer token is created on the backend via the CLI; the user pastes it into Settings once.
- **Android-only.** iOS is out of scope (no Xcode / Apple Developer / CocoaPods). Don't suggest Cupertino widgets, iOS-specific plugins, or iOS deployment steps. (See `/CLAUDE.md` §3.)
- **Polling, not streaming.** The backend exposes REST endpoints only — no WebSocket / SSE. The queue + job-detail screens poll on a timer (see `docs/PLAN.md` "Polling cadence").

---

## Stack (locked v1 — see `docs/DECISIONLOG.md` 2026-06-09 entries)

- **State management:** [Riverpod](https://riverpod.dev). `flutter_riverpod` + `riverpod_annotation` + `riverpod_generator`.
- **HTTP:** [dio](https://pub.dev/packages/dio) with an auth-injecting interceptor.
- **JSON:** [freezed](https://pub.dev/packages/freezed) (immutable models + `copyWith`) + `json_serializable` (codegen).
- **Token storage:** [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) — Android EncryptedSharedPreferences. Never `shared_preferences` for the bearer token.
- **Navigation:** [go_router](https://pub.dev/packages/go_router) — declarative routes.
- **Theme:** Material 3, dark mode, `ColorScheme.fromSeed(#1DB954, Brightness.dark)`. No light-mode variant in v1.

---

## Development workflow

- **TDD by default.** Widget tests for screens (`flutter_test` + `WidgetTester`). Unit tests for providers/services. Write the failing test first, then the implementation.
  - **Scope:** screens, providers, API client wrappers, model serialization.
  - **Out of scope (v1):** golden tests, integration tests on a real device, performance benchmarks. They have their own verification gates (manual smoke against the home server is the G1 milestone).
- **Green before, green after.** Run `flutter test` before starting a task and confirm it passes. Run it again before declaring done. Run `flutter analyze` (lint) at the same checkpoints.
- Commit per ROADMAP milestone with the Conventional Commits message prescribed by `docs/ROADMAP.md`.
- **No emojis in code or commits unless explicitly requested** (project-wide rule).

---

## User background (mobile-side reminder)

The user has **zero Flutter / Dart / mobile-app experience** (DevOps + data engineer by day). When explaining:
- Name every file path in full.
- Show every command with its working directory.
- Don't assume familiarity with `pubspec.yaml`, `pub get`, hot-reload, build_runner, `flutter analyze`, or Android Studio.
- Backend / Docker / Python / SQL analogies are fair game and welcome.

The user *does* know REST APIs, JSON, async, containers, and the backend in this repo end-to-end. Don't re-explain those.

---

## Hard "don't"s

- Don't add a Sign-In-With-Spotify flow on the device. Backend uses client-credentials only; the device authenticates to the **backend**, not to Spotify.
- Don't propose iOS / Cupertino / Xcode steps.
- Don't store the bearer token in `shared_preferences` or write it to a file — `flutter_secure_storage` only.
- Don't add a real-time push channel (WebSocket / Firebase Cloud Messaging). Polling is the contract.
- Don't bypass `dio`'s interceptor to set the auth header per-call — the interceptor is the single source of truth.
