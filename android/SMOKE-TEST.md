# SMOKE-TEST.md — v3.1.2 (A6 refactor + R8 media-notification fix)

**Tag:** `v3.1.2-rc2`
**Build:** `flutter build apk --release` → install via `adb install`
**Device:** Pixel 7, Android 16 (API 36), wireless adb
**Backend:** home-server heerr `3.1.x`, Navidrome reachable via Tailscale
**Tester:** _______________  **Date:** _______________
**Result:** PASS / FAIL

---

## ⚠️ MUST smoke a RELEASE build, not `flutter run`

This smoke **must** run against the `--release` APK (R8 minification on), **not** a
`flutter run` debug build. R8 is disabled in debug, so an entire class of
release-only regressions (stripped/obfuscated plugin classes) is invisible in
debug. The rc1→rc2 media-notification bug below was exactly this — it never
reproduced in debug. Do not sign off on a debug build.

---

## What changed in v3.1.2

**A6 internal refactor** — no user-visible behaviour changes:
- `SettingsValue` / `Settings` provider deleted.
- Per-server creds now flow through `serverCredsProvider` (synchronous re-slice of `activeProfileProvider`).
- Offline prefs now owned solely by `OfflineSettings`, reading `PrefsStorage` directly.
- Risk: any callsite that reads creds or offline prefs could silently regress.

**R8 media-notification fix (rc2)** — release-only regression introduced at commit
`403c5ff` (when R8 minification was first enabled to fix the WorkManager boot crash):
- The proguard keep rules covered only `androidx.work` / `androidx.room`, so R8
  stripped/obfuscated `audio_service`'s internal MediaSession + notification
  helper classes. The foreground service still started (playback worked) but the
  media notification + lock-screen controls silently stopped rendering.
- Fixed by adding `-keep class com.ryanheise.audioservice.**` and
  `-keep class com.ryanheise.just_audio.**` to `proguard-rules.pro`.
- **Section 6.8–6.10 below is the regression gate for this fix.**

This smoke therefore doubles as a regression check for the **entire offline +
credential surface** AND the **release-build media notification / lock-screen player**.

---

## Pre-flight

| # | Step | Expected | Pass? |
|---|---|---|---|
| P1 | `flutter analyze` from `android/app/` | Zero issues | |
| P2 | `flutter test` from `android/app/` | All tests green (no skips) | |
| P3 | `flutter build apk --release` | Exit 0, APK in `build/app/outputs/flutter-apk/` | |
| P4 | `adb install -r build/app/outputs/flutter-apk/app-release.apk` | `Success` | |
| P5 | Launch app cold on device | Dark M3 shell loads, no crash, bottom nav visible | |

---

## Section 1 — Fresh install defaults

Test that a brand-new install (no prior data) initialises correctly.

> **Setup:** Uninstall any prior version first (`adb uninstall com.aashish.heerr`), then install the APK.

| # | Step | Expected | Pass? |
|---|---|---|---|
| 1.1 | Launch app | Lands on `/login` (no profile present) | |
| 1.2 | Observe Settings icon / bottom nav | Library, Search, Queue, Downloads tabs visible but behind auth gate | |
| 1.3 | Open Settings → Profiles section | Empty — no profiles listed | |
| 1.4 | Open Settings → Offline section | Offline toggle OFF (default), all other offline prefs at defaults (`wifiOnly=true`, `chargingOnly=false`, `pollInterval=15`, `syncAll=false`) | |
| 1.5 | Tap "Add profile" | Form appears with URL / username / password fields | |
| 1.6 | Enter valid Navidrome URL + credentials → Save | Profile appears in list; app navigates away from `/login` | |
| 1.7 | Observe Library screen | Loads artist/album grid (may take a moment to populate) | |

---

## Section 2 — Profile management (A1 / S band regression)

| # | Step | Expected | Pass? |
|---|---|---|---|
| 2.1 | Settings → Profiles → Add a second profile (different Navidrome URL or user) | Both profiles appear in the list | |
| 2.2 | Switch to profile 2 | App reloads library for profile 2; active indicator moves | |
| 2.3 | Switch back to profile 1 | Library reloads for profile 1 | |
| 2.4 | While on profile 1: open Downloads screen → observe download paths | Paths are keyed to profile 1 (serverKey = sha256(url+"\|"+user)[0..16]) | |
| 2.5 | Switch to profile 2 → open Downloads | Download paths re-keyed to profile 2 — profile 1 content not visible | |
| 2.6 | Switch back to profile 1 → Downloads | Profile 1 content visible again | |
| 2.7 | Settings → Profiles → Remove profile 2 | Profile 2 gone from list; active profile unchanged (profile 1) | |
| 2.8 | Settings → "Test connection" for profile 1 | Shows "Connected" or similar success indicator | |

---

## Section 3 — A6 regression: creds isolation

These checks verify that `serverCredsProvider` re-slices correctly and that offline prefs are independent of profile switches.

| # | Step | Expected | Pass? |
|---|---|---|---|
| 3.1 | Settings → Offline → Enable offline | Toggle switches ON | |
| 3.2 | Switch profiles (2.2 above) | Offline toggle remains ON (offline prefs are per-device, not per-profile) | |
| 3.3 | Settings → Offline → toggle WiFi-only | Saves immediately; verify by killing + relaunching app; toggle still in new state | |
| 3.4 | Settings → Offline → Change poll interval to 30 min | Saved; relaunch app → poll interval shows 30 min | |
| 3.5 | Settings → Offline → Enable "sync all" | Saved; relaunch → "sync all" still checked | |
| 3.6 | Switch profiles → Settings → Offline | All offline prefs unchanged (switching profile must not reset prefs) | |
| 3.7 | Settings → Offline → toggle WiFi-only OFF then back ON while on different profile | Each toggle takes effect immediately; no crash | |
| 3.8 | Settings → Downloads → Clear all downloads | Clears downloaded content for **current profile only**; other profile content unaffected | |

---

## Section 4 — Offline settings persistence (OfflineSettings owner check)

| # | Step | Expected | Pass? |
|---|---|---|---|
| 4.1 | Force-stop the app (`adb shell am force-stop com.aashish.heerr`) | — | |
| 4.2 | Relaunch | Offline prefs exactly as set in Section 3 — no reset to defaults | |
| 4.3 | Toggle charging-only ON | Saved | |
| 4.4 | Reboot device | — | |
| 4.5 | Relaunch app | Profile still active; offline prefs (including charging-only) survive reboot | |

---

## Section 5 — Library browsing

| # | Step | Expected | Pass? |
|---|---|---|---|
| 5.1 | Library → Artists tab | Artist list loads, cover art loads for ≥1 artist | |
| 5.2 | Tap an artist | Artist detail: albums listed | |
| 5.3 | Tap an album | Song list with track numbers and durations | |
| 5.4 | Library → Albums tab | Album grid loads | |
| 5.5 | Library → Playlists tab | Playlist list loads | |
| 5.6 | Tap a playlist | Songs listed; if owned by active profile's username, "Edit" option visible | |
| 5.7 | Library → Songs tab | Flat song list loads | |
| 5.8 | Library → Favourites | Starred tracks listed (if any); star/unstar a track → list updates | |
| 5.9 | Cover art | Album art appears in artist detail, album detail, song rows (no broken-image placeholders) | |

---

## Section 6 — Playback

> **6.8–6.10 are the R8 regression gate (rc2).** On a release build, these are
> the exact controls that were missing in rc1. Confirm they render BEFORE
> signing off — a debug build will always pass these and hide the regression.

| # | Step | Expected | Pass? |
|---|---|---|---|
| 6.1 | Tap any song in Library → Songs | Begins playing; mini-player appears at bottom | |
| 6.2 | Tap mini-player | Now Playing screen opens; track title, album art, controls visible | |
| 6.3 | Tap pause | Playback stops | |
| 6.4 | Tap play | Playback resumes from same position | |
| 6.5 | Skip next | Next track starts | |
| 6.6 | Skip previous (within 3s of start) | Goes to previous track | |
| 6.7 | Seek bar | Drag to ~50% → playback jumps to that position | |
| 6.8 | Lock screen | Lock-screen controls visible; play/pause/skip work from lock screen | |
| 6.9 | Notification (pull-down shade) | Media notification shows track + play/pause/skip controls (R8 gate) | |
| 6.10 | Play an album (tap first song → queue fills) | Gapless transition between tracks — no gap or silence between them | |
| 6.11 | Switch profiles mid-playback | Playback stops or gracefully clears (creds changed — old stream URL invalid) | |

---

## Section 7 — Search and download dispatch

| # | Step | Expected | Pass? |
|---|---|---|---|
| 7.1 | Search tab → type a query → Submit | Results list appears (tracks or albums depending on toggle) | |
| 7.2 | Toggle Track / Album / Playlist | Results update for the selected type | |
| 7.3 | Tap a result → Download | Confirmation or immediate dispatch; job appears in Queue | |
| 7.4 | Search with no backend reachable (disable Tailscale) | Snackbar "can't reach backend — check Tailscale" | |
| 7.5 | Re-enable Tailscale → retry search | Works normally | |

---

## Section 8 — Queue and job detail

| # | Step | Expected | Pass? |
|---|---|---|---|
| 8.1 | Queue tab after dispatching a download | Job visible with status `queued` or `running` | |
| 8.2 | Observe queue polling | Status updates without any manual refresh (every 3 s) | |
| 8.3 | Tap a job | Job detail screen opens; status, started_at, output_path visible | |
| 8.4 | Job detail auto-refresh | Status refreshes every 2 s while `queued` / `running`; stops once `done` / `failed` | |
| 8.5 | Completed job | Shows `done`, output_path populated | |
| 8.6 | Failed job | Shows `failed` + error message | |

---

## Section 9 — Offline download subsystem

| # | Step | Expected | Pass? |
|---|---|---|---|
| 9.1 | Settings → Offline → Enable offline | Toggle ON | |
| 9.2 | Library → Songs → long-press (or mark) a song for offline | Song marked; download starts | |
| 9.3 | Downloads screen | Song appears in downloads list with progress indicator | |
| 9.4 | Song download completes | Status changes to downloaded; file present at expected path under app-private storage | |
| 9.5 | Disable Tailscale | — | |
| 9.6 | Play the downloaded song | Plays from local file — no network required | |
| 9.7 | Re-enable Tailscale | — | |
| 9.8 | Mark an album for offline | All songs in the album queued for download | |
| 9.9 | Downloads screen → long-press downloaded song → remove | Song removed from local storage; status reverts to "not downloaded" | |
| 9.10 | Settings → Offline → "Sync all" ON → trigger sync | All library tracks queued for download | |
| 9.11 | Size estimator | Downloads screen shows estimated size of pending/completed downloads | |

---

## Section 10 — Background sync (WorkManager)

| # | Step | Expected | Pass? |
|---|---|---|---|
| 10.1 | Settings → Offline → Enable offline; set poll interval to minimum | — | |
| 10.2 | Put app in background (home button) | — | |
| 10.3 | Wait for WorkManager window (~15 min, or force via `adb shell am broadcast -a androidx.work.diagnostics.REQUEST_DIAGNOSTICS`) | Background sync task fires; newly-marked songs download without opening the app | |
| 10.4 | Check device logcat (`adb logcat -s WorkManager`) | No crash; task completes or reschedules cleanly | |
| 10.5 | WiFi-only gate: disable WiFi, keep mobile data | Background sync does NOT fire | |
| 10.6 | Re-enable WiFi | Sync fires on next window | |
| 10.7 | Charging-only gate: unplug device | Background sync does NOT fire (if charging-only ON) | |
| 10.8 | Plug in device | Sync fires on next window | |

---

## Section 11 — Recommendations and home screen

| # | Step | Expected | Pass? |
|---|---|---|---|
| 11.1 | Home tab | Recommendations load (or graceful "no recommendations yet" empty state) | |
| 11.2 | Tap a recommended track | Now Playing opens | |
| 11.3 | Switch profiles | Recommendations reload for new profile | |

---

## Section 12 — Error handling

| # | Step | Expected | Pass? |
|---|---|---|---|
| 12.1 | Invalidate bearer token on backend (`python -m app.cli revoke-token ...`) | Next API call gets 401; snackbar "auth failed"; app redirects to `/login` | |
| 12.2 | On `/login`, re-enter valid token | App navigates back to Library | |
| 12.3 | Use a token without `download` scope → tap Download | Snackbar "insufficient scope" — no redirect | |
| 12.4 | Backend unreachable (stop docker-compose) | Snackbar "can't reach backend — check Tailscale" on any network action | |
| 12.5 | Backend returns 502 (ytmusicapi failure on search) | Snackbar "YouTube Music error: …" | |

---

## Section 13 — Upgrade path from v3.1.1

> **Setup:** Install v3.1.1 APK, add a profile, enable offline, pin 2–3 songs, set non-default offline prefs. Then upgrade to v3.1.2 APK (`adb install -r`).

| # | Step | Expected | Pass? |
|---|---|---|---|
| 13.1 | Install v3.1.2 over v3.1.1 | No crash on first launch | |
| 13.2 | Profile still active | Existing profile present and active; no forced re-login | |
| 13.3 | Offline prefs | Survived upgrade — same values as before (wifiOnly, pollInterval, etc.) | |
| 13.4 | Previously downloaded songs | Appear in Downloads screen as downloaded; playable offline | |
| 13.5 | Library | Loads normally | |

---

## Section 14 — Stability

| # | Step | Expected | Pass? |
|---|---|---|---|
| 14.1 | Navigate all 5 tabs in sequence 3× | No crash, no white screens | |
| 14.2 | Rapidly toggle offline prefs 10× | No crash; final state persists on relaunch | |
| 14.3 | Switch profiles 5× rapidly | No crash; correct profile active at end | |
| 14.4 | Background the app and foreground it 5× | State preserved; no reload flicker | |
| 14.5 | Leave app playing for 10 min in background | No crash, notification still showing, audio still playing | |

---

## Pass criteria

All items in Sections 1–5, 6.1–6.9, 7, 8, 9.1–9.7, 12, 13 must pass.
Sections 10, 11, 14 are best-effort on day-of-smoke; document any failures.
A single FAIL in Sections 1–5 or 12–13 blocks promotion to `v3.1.2`.

---

## On pass

1. Delete this file (replaced by a one-liner in DEBT.md smoke table).
2. Append to `android/docs/DEBT.md` smoke table:

```
| V6 | A6 SettingsValue split (v3.1.2) | ✅ YYYY-MM-DD — on-device smoke passed. Upgrade from v3.1.1: prefs survived, offline paths re-key on profile switch, background sync fires. Tagged `v3.1.2`. |
```

3. Retag: `git tag -d v3.1.2-rc1 && git tag v3.1.2 && git push origin v3.1.2`.
