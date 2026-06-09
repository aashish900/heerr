# CHANGELOG.md — heerr Android client

Per-task change log. Newest at the bottom. Append-only; never edit prior entries.

---

## 2026-06-09 — Android client planning round

- New: `android/CLAUDE.md` — Android-app-specific Claude rules (bootstrap order, locked stack, TDD scope, "don't"s, user-background reminder).
- New: `android/README.md` — operational entry point for the Android app. Stub at this point — points at `docs/` and notes that the scaffold itself lands at milestone A1.
- New: `android/docs/CONTEXT.md` — Android client project brief (backend endpoints consumed, stack, dev env, target device, MVP screens, polling cadence, error UX, out-of-scope list).
- New: `android/docs/PLAN.md` — frozen v1 contract (stack table, project layout, API contract, configuration, routing, state management, theme, polling cadence, error UX, tests, out-of-scope list, definition-of-done).
- New: `android/docs/ROADMAP.md` — 13-milestone build sequence (A1–G1) mirroring the backend's A1–H1 cadence. Halt-and-confirm at each boundary.
- New: `android/docs/DECISIONLOG.md` — 5 seed ADRs locking the stack, theme, polling-not-WebSocket, in-app Settings (not `--dart-define`), and the `android/app/` project layout.
- New: `android/docs/CHANGELOG.md` — this file.
- Rationale: same convention as backend — get the contract locked in writing before any Dart code. Reading the ROADMAP gives the next task; reading PLAN.md tells you what's already decided so you don't re-litigate.
- **Note:** the `android/app/` directory does not exist yet. `flutter create android/app` is the first action of milestone A1.

## 2026-06-09 — Rename: `flutter/` → `android/`

- The directory holding the mobile-client docs (and, later, the `flutter create` scaffold at `app/`) is renamed from `flutter/` to `android/`. The convention `<app>/` from the root `/CLAUDE.md` still applies — `<app>` here is `android`.
- Rationale: `flutter` named the framework, not the role. The pair `backend/` + `flutter/` was inconsistent (backend isn't called `fastapi/`). `android/` names the deployment platform — Flutter is still the framework used to build the app, but iOS is explicitly out of scope (per `/CLAUDE.md` §3), so the dir name reflects the only target the user ships to.
- Trade-off: the inner `flutter create` scaffold (landing at A1) will create its own `android/` subdir for the Android build manifest + Gradle config — so paths like `android/app/android/AndroidManifest.xml` will exist. Annoying-but-harmless path repetition; accepted at rename time after the preview was shown.
- Path refs updated throughout `android/CLAUDE.md`, `android/README.md`, `android/docs/{CONTEXT,PLAN,ROADMAP,DECISIONLOG,CHANGELOG}.md`, root `/CLAUDE.md`, and two stale forward-references in `backend/docs/CHANGELOG.md` (per CLAUDE.md staleness rule).
- Project-noun refs ("the Flutter app", "Flutter client", file titles) updated to "Android client" / "Android app" / similar. Framework refs (Flutter SDK, Flutter 3.44.0, `flutter create`, `flutter analyze`, `flutter_secure_storage`, "the Flutter team") left intact — Flutter is still the framework even though the dir is named for the platform.
- Root `/CLAUDE.md`: app inventory + the "Backend first, Flutter second" rule reworded to "Backend first, Android client second" with a clarifying parenthetical noting the framework/platform split.
- Nothing else moved; no Dart code yet — this is purely a docs rename.

## 2026-06-09 — A1: Flutter scaffold + pinned deps + lint

- Ran `flutter create --project-name=heerr --org=com.aashish --platforms=android --no-pub android/app` → creates a single-platform (Android-only) Flutter scaffold at `android/app/`. No `ios/`, `web/`, `linux/`, `macos/`, `windows/` dirs generated.
- Application id / namespace: `com.aashish.heerr` (`android/app/android/app/build.gradle.kts` lines 8 + 19).
- **Replaced `pubspec.yaml`** with the locked-stack pin set:
  - Runtime: `flutter_riverpod ^2.6`, `riverpod_annotation ^2.6`, `dio ^5.7`, `freezed_annotation ^2.4`, `json_annotation ^4.9`, `flutter_secure_storage ^9.2`, `go_router ^14.6`.
  - Dev (codegen + lint + test): `build_runner ^2.4`, `freezed ^2.5`, `json_serializable ^6.8`, `riverpod_generator ^2.6`, `flutter_lints ^6.0`, `mocktail ^1.0.4`.
  - Removed `cupertino_icons` (iOS-only, out of scope per `/CLAUDE.md` §3).
  - Version line: `0.1.0+1`.
- **Replaced `analysis_options.yaml`** with strict-mode + extras: `strict-casts`, `strict-inference`, `strict-raw-types`; exclude `**/*.g.dart` + `**/*.freezed.dart` (codegen output); enforce `prefer_const_*`, `prefer_final_locals`, `require_trailing_commas`, `avoid_print`, `unawaited_futures`, `cancel_subscriptions`, `close_sinks`. `invalid_annotation_target` set to ignore (freezed false-positive that doesn't apply at lint time).
- **Replaced `lib/main.dart`** with a bare `HeerrApp` (StatelessWidget) — `ProviderScope` root, M3 dark theme via `ColorScheme.fromSeed(0xFF1DB954, dark)`, centred "heerr" text on the dark surface. No router yet — that lands at A2.
- **Replaced `test/widget_test.dart`** with a smoke test that pumps `HeerrApp` and asserts (a) "heerr" text rendered and (b) `Theme.of(context).brightness == Brightness.dark`. Default counter-app test removed (no longer applicable).
- **`.gitignore`** appended four lines for Android signing artefacts (`android/key.properties`, `android/keystore.jks`, `android/app/key.properties`, `**/*.jks`) — F1 will generate these locally; they must never be committed.
- Removed IDE noise the scaffold produced: `android/app/.idea/` and `android/app/heerr.iml` (covered by the default `.gitignore` but cleaner to delete from the working tree).
- Verification: `cd android/app && flutter pub get` → 112 deps resolved (36 packages have newer majors blocked by our caret pins — Dependabot will surface those). `flutter analyze` → "No issues found! (ran in 0.2s)". `flutter test` → 1/1 passed.
- **Manual verification deferred** to when the user is near the Pixel: `cd android/app && flutter run -d <pixel-device-id>` should show "heerr" centred on a dark green-tinted surface. (`flutter devices` lists connected devices.)

## 2026-06-09 — A2: theme + go_router + bottom-nav shell

- New: `android/app/lib/theme.dart` — single `heerrDarkTheme()` builder. M3 dark theme via `ColorScheme.fromSeed(0xFF1DB954, brightness: dark)`. Seed colour defined as a private const so it isn't hardcoded in every consumer.
- New: `android/app/lib/router.dart`:
  - `Routes` class with `search`/`queue`/`settings` constants + a `job(id)` builder. Keeps URL shape DRY between the router, link callers, and tests.
  - `buildHeerrRouter()` returns the configured `GoRouter`. Pulled out of `main.dart` so widget tests reuse the exact production config (no parallel test-only router).
  - `ShellRoute` wraps the three child routes with `_ShellScaffold`, which holds the M3 `NavigationBar` (Search · Queue · Settings). Tab tap calls `context.go(...)`. Selected index derived from the matched location.
- New stub screens (all `StatelessWidget` returning a `Scaffold` with an AppBar + centred body label, populated later):
  - `android/app/lib/screens/search_screen.dart` (filled at C2).
  - `android/app/lib/screens/queue_screen.dart` (filled at D2).
  - `android/app/lib/screens/settings_screen.dart` (filled at B3).
- Updated `android/app/lib/main.dart`: switched from `MaterialApp` + inline `Scaffold` to `MaterialApp.router(routerConfig: ...)`. `ProviderScope` wraps `HeerrApp`.
- Removed `android/app/test/widget_test.dart` (the A1 smoke test asserted the now-removed `heerr` centred text on the root) and replaced with new `android/app/test/router_test.dart` — five tests:
  1. boots on `/` (Search) by default;
  2. tapping the Queue tab renders the Queue screen;
  3. tapping the Settings tab renders the Settings screen;
  4. round-trip Settings → Search returns to Search;
  5. theme: M3 + dark brightness.
- Test helper `_activeTitle(tester)` reads the AppBar title widget directly (instead of `find.text(...)`) — each stub renders the same label twice (in the AppBar and the body), so a text-based finder would be ambiguous.
- `analysis_options.yaml`: removed `avoid_returning_null_for_future` (removed from Dart 3.3+, surfaced as a `removed_lint` warning during the first `flutter analyze` of this milestone).
- Verification: `flutter analyze` → no issues; `flutter test` → 5/5 passed.
