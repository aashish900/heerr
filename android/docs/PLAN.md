# PLAN — Widget polish (4 fixes) + Library tab gradient indicator

Status: implemented (all 5 fixes); pending on-device manual smoke. Date: 2026-07-10.

## Context

The 4x1 hero widget and library tabs don't match the concept art (`~/Documents/Personal/Android/ChatGPT Image Jul 10, 2026, 12_54_40 PM.png`; tab reference `~/Documents/Personal/Android/Screenshot 2026-07-10 at 8.18.30 PM.png`). Five mismatches:

1. **Album art** has a hard right border; reference fades it into the black widget body.
2. **Progress bar** is display-only; user wants seek. RemoteViews forbid drag gestures — **user approved tap-to-seek zones** (10 zones, ~10% granularity) as the substitute.
3. **Idle heerr logo** (`widget_logo_gradient.xml`) doesn't match the reference mark (magenta left upright + violet right upright, ~7 magenta waveform bars + connector dashes between).
4. **Playing waveform** (`widget_wave_1..8.xml`) is 21 centered sine bars; reference is ~36 thin baseline-aligned bars in clusters with dots, magenta→violet gradient.
5. **Tab indicator** is a plain magenta underline; reference is a thicker gradient bar under the label with a thin line extending beyond it.

Flutter project root: `android/app/` (all `flutter` commands from there). Native code: `android/app/android/app/src/main/`.

**Facts from exploration:**
- `HeroWidgetProvider.kt` — `buildArtBitmap()` decodes `np_art_path`, center-crops, rounds left corners. Constants `ART_WIDTH_DP=96`, `CORNER_DP=26`. Buttons broadcast `ACTION_MEDIA_BUTTON` to `com.ryanheise.audioservice.MediaButtonReceiver`.
- audio_service 0.18.18: `AudioService` is a `MediaBrowserServiceCompat`; its session fields are package-private → a receiver must connect via `MediaBrowserCompat` to get the session token.
- `lib/theme.dart:104-109` — `TabBarThemeData` with plain `indicatorColor: heerrMagenta`. Reusables: `heerrGradient` / `heerrMagenta #F533C8` / `heerrPurple #A93CF2` / `heerrViolet #6F4BF5` (`lib/theme.dart:1-12`).
- No native test infra; Dart tests exist (`test/screens/library/library_screen_test.dart` `_wrap` helper, `test/widget/now_playing_widget_updater_test.dart`).

## Green-before

```
cd android/app && flutter test && flutter analyze
```
Both must pass before any edit.

## Fix 5 — Gradient tab indicator (Dart, TDD first)

**New:** `lib/widgets/gradient_tab_indicator.dart` — `GradientTabIndicator extends Decoration` (const-constructible; defaults `gradient: heerrGradient`, `thickness: 3`). Its `BoxPainter` draws:
- a rounded 3dp gradient bar across the label rect,
- a thin 1dp gradient line extending ~16dp beyond each side of the bar (same shader, lower alpha). If TabBar clips the overdraw, fall back to `dividerColor: Color(0xFF2E2E2E), dividerHeight: 1` for the extension.

**Edit:** `lib/theme.dart` — replace `indicatorColor` with `indicator: GradientTabIndicator()`, `indicatorSize: TabBarIndicatorSize.label`. Stays `const` (verified: const defaults). `library_screen.dart` unchanged — plain `const TabBar` inherits the theme.

**Tests (write first, red → green):**
- New `test/widgets/gradient_tab_indicator_test.dart`: (a) `heerrDarkTheme().tabBarTheme.indicator is GradientTabIndicator`; (b) pump a 3-tab `TabBar` with the theme, tap tab 2, `pumpAndSettle`, no exceptions (exercises the painter through animation).
- `test/screens/library/library_screen_test.dart`: one test asserting the `TabBar`'s effective `tabBarTheme.indicator` is `GradientTabIndicator` (pass `theme: heerrDarkTheme()` in that test's `MaterialApp` if `_wrap` doesn't).

## Fix 1 — Album-art fade (Kotlin + XML)

`HeroWidgetProvider.kt` `buildArtBitmap()`: after drawing the cropped bitmap, draw a `LinearGradient` (WHITE→TRANSPARENT) rect with `PorterDuff.Mode.DST_IN` over the right 35% (`FADE_FRACTION = 0.35f` companion const). Bitmap is already ARGB_8888.

Layout compensation in `hero_widget.xml`: `widget_art` width 96dp → 112dp; content column `paddingStart` 12dp → 0dp (the fade tail becomes the gap). Update `ART_WIDTH_DP` to 112 and the KDoc size math (~224x212 px @2x ≈ 0.19 MB, under Binder limit).

## Fix 2 — Tap-to-seek (Kotlin + XML + manifest + gradle)

**New:** `.../kotlin/com/aashish/heerr/WidgetSeekReceiver.kt` — `BroadcastReceiver` for `ACTION_WIDGET_SEEK` (`com.aashish.heerr.WIDGET_SEEK`) with float extra `seek_fraction`. Reads `np_duration_ms` from `HomeWidgetPreferences` (hoist `HOME_WIDGET_PREFS` to a shared top-level `internal const` in `HeroWidgetProvider.kt`), computes target ms, then `goAsync()` + `MediaBrowserCompat` connect to `com.ryanheise.audioservice.AudioService` → `MediaControllerCompat(context, token).transportControls.seekTo(targetMs)` → disconnect/finish. Early-return on `duration <= 0` or fraction out of [0,1].

**Gradle:** `android/app/android/app/build.gradle.kts` — add `implementation("androidx.media:media:1.7.0")` (already on the runtime classpath via audio_service; needed for compile visibility only — not a new Flutter plugin).

**Layout:** replace the bare `ProgressBar` row in `hero_widget.xml` with a 16dp-tall `FrameLayout`: the 4dp `ProgressBar` centered vertically, overlaid by a horizontal `LinearLayout` of 10 equal-weight empty `FrameLayout` tap zones (`widget_seek_0..9`; RemoteViews whitelists FrameLayout, not bare View).

**Provider wiring:** in the `hasTrack` branch of `onUpdate`, loop zones setting `setOnClickPendingIntent` with fraction `(i + 0.5f)/10` and **distinct requestCodes** `100 + i` (extras don't participate in `Intent.filterEquals`; base 100 avoids collision with keycode requestCodes).

**Manifest:** register `<receiver android:name=".WidgetSeekReceiver" android:exported="false" />` (explicit-component broadcast, no intent-filter).

No Dart changes — existing `np_*` contract untouched, so no Dart seek tests.

## Fix 3 — Idle logo vector

Rewrite `res/drawable/widget_logo_gradient.xml` (keep 46x40 viewport, stroked paths, round caps): left upright strokeWidth 7 solid `#F533C8`; right upright strokeWidth 7 solid `#6F4BF5`; two 2.5dp connector dashes at mid-height (left magenta, right violet); 7 magenta 2.5dp waveform bars between with varying half-heights (~5–12), centered on y=20. Exact heights tuned by eye on-device.

## Fix 4 — Waveform regeneration

**New:** `android/app/tool/gen_widget_wave.py` (committed) — emits `widget_wave_1..8.xml`, viewport 110x24 unchanged:
- 36 bars, x = 2.5 + 3.0·i, strokeWidth 2, round caps, baseline y=22, bars grow upward (`M{x},{22-h} L{x},22`; h≈0.6 renders as a dot).
- Clustered envelope: three Gaussian clusters (centers i=6, 15, 26) over a 2dp floor.
- 8-frame travelling modulation `0.55 + 0.45·sin(2π(i/6 + f/8))` — loops cleanly at the existing `flipInterval=120`.
- Per-bar color lerped through `#F533C8 → #A93CF2 → #6F4BF5`; header comment noting the generator.

Run `python3 tool/gen_widget_wave.py` from `android/app/`. Static fallback still references `widget_wave_3` — no layout change.

## Sequencing

1. Green-before (`flutter test`, `flutter analyze`).
2. Fix 5 (TDD: red tests → indicator → theme → green).
3. Fix 1, Fix 2, Fix 3, Fix 4 (native — gated by compile).
4. Verification (below), then CHANGELOG entry (+ DECISIONLOG entry for tap-to-seek-over-slider decision) per repo convention.

## Verification

- `flutter test` and `flutter analyze` from `android/app/` — green after.
- `flutter build apk --debug` — the only compile gate for Kotlin/XML changes.
- Manual smoke (user, on device): idle logo shape, art fade while playing, waveform look/animation, tap-seek at ~25/50/75%, tab indicator on Library.

## Risks

- **Seek cold-start:** MediaBrowser connect can cold-start `AudioService` if the app was killed with stale prefs; seekTo on an empty session is a no-op — worst case a brief service spin-up. The `AudioService` ComponentName string is the coupling point to audio_service 0.18.x internals.
- **Touch targets:** 16dp-tall zones are small; acceptable for a dense widget, taps will be forgiving at 10-zone granularity.
- **Indicator overdraw:** if TabBar clips the thin extension lines, fall back to the theme divider for the extension (noted in Fix 5).
- **Vector aesthetics:** logo/waveform numbers need 1–2 look-and-regenerate iterations on device; the generator script makes that cheap.
