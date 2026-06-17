# smoke-test.md — Phase S v3.0.0-rc1 on-device smoke

Temporary checklist for the S11 multi-user smoke on the Pixel 7 against the
home Navidrome + heerr backend. **Delete this file after the smoke passes
and `v3.0.0` is tagged.**

---

## 0. Prerequisites

- Pixel 7 wireless-adb paired (`adb devices` shows it).
- Home server up: heerr backend at `3.0.0-rc1`, Navidrome reachable on the
  tailnet.
- Two real Navidrome accounts: `alice`, `bob`. If they don't exist, create
  them in the Navidrome web UI before starting.
- Backend reachable at `http://<tailscale-host>:8000/api/v1` from the
  Pixel's tailnet.
- Music library has at least 5 albums; alice has played at least one track
  in the past so `homeRecentProvider` has something to render.

## 1. Build + install the RC1 APK

```sh
cd /Users/E1621/Documents/Personal/Android/heerr/android/app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze                 # must be clean (one isInDebugMode info is OK)
flutter test                    # 579+ must pass
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Confirm the install:

```sh
adb shell pm list packages | grep heerr
# package:com.aashish.heerr
```

Wipe any prior install state so the migration / first-launch path runs
fresh:

```sh
adb shell pm clear com.aashish.heerr
```

Open the app on the device.

---

## 2. S11 — 7-step multi-user smoke

Tick each box on-device. Capture a screenshot of any unexpected behaviour
under `android/docs/_smoke_screenshots/` (gitignored).

### Step 1 — Fresh install → /login → alice logs in → Home loads alice's library

- [ ] App boots directly into `/login` (router redirect because no active
  profile).
- [ ] Three fields visible: heerr base URL, Navidrome username, Navidrome
  password. Eye toggle on password works.
- [ ] Submitting empty form shows validation messages.
- [ ] Enter:
  - heerr base URL: `http://<tailscale-host>:8000/api/v1`
  - username: `alice`
  - password: alice's Navidrome password
- [ ] Tap Sign in → no error snackbar → navigates to `/` (Home).
- [ ] Home renders greeting + "Jump back in" + "Most played" + "Picked for
  you" / "Discover" with alice's data.

### Step 2 — alice downloads a track → appears in alice's /queue

- [ ] Library tab → search for a song known to be on YouTube Music but
  not in the library (e.g. a B-side).
- [ ] Tap the YT result → "queued" snackbar.
- [ ] AppBar queue icon on Home → /queue shows the new job in `queued` or
  `running` state.
- [ ] Wait for the job to transition to `done`.

### Step 3 — Settings → Profiles → add bob

- [ ] Settings tab → Profiles section at the top of the list.
- [ ] alice row shows the green-highlighted selected indicator.
- [ ] "Add profile" row → tap → `/login` opens with a back arrow.
- [ ] Enter bob's creds (same heerr base URL, bob's Navidrome username +
  password) → Sign in.
- [ ] Settings → Profiles now lists both alice + bob. bob is now active
  (the screen that landed after login was Home, not Settings — re-open
  Settings to confirm the active marker moved).

### Step 4 — switch active → bob logs in → Home loads bob's library + bob's /queue is empty of alice's downloads

- [ ] If bob is not already active, tap the alice row → overflow menu →
  Switch to this profile → confirm dialog → bob → alice swap.
  (After the explicit add at Step 3, bob is already active; tap alice
  then switch back to bob to exercise the dialog path.)
- [ ] Home reloads — sections show bob's library / recents (likely sparse
  if bob is a fresh user).
- [ ] AppBar queue icon → /queue is empty (alice's job is hidden — backend
  J8 per-user filter, confirmed client-side by the bearer-token swap).

### Step 5 — toggle WiFi off → bob's offline is empty (correct — bob marked nothing)

- [ ] Settings → Offline section → confirm "Sync entire library" is OFF
  for bob.
- [ ] Library tab while still online: browse a few of bob's albums so
  cover art + metadata hit the L5 cache.
- [ ] Quick settings panel → toggle WiFi off (Tailscale also goes down).
- [ ] Library tab still navigates (cached). Tap a song → should fail with
  the "cannot reach backend — check Tailscale" snackbar because nothing
  is marked offline for bob.
- [ ] Toggle WiFi back on.

### Step 6 — switch back to alice → alice's offline + Now Playing intact

- [ ] Settings → Profiles → tap bob's row → … wait, bob is the active
  one. So tap alice's row → Switch dialog → Switch.
- [ ] Home re-renders as alice.
- [ ] If alice had any Offline-marked album from a prior smoke, library
  still shows the download icon and the song plays from the local
  `file://` URI when WiFi is off.
- [ ] Now Playing screen restores from the last-played position alice
  had before the switch (P1 persistence is per-server-key so it should
  survive switching away and back).

### Step 7 — remove bob → redirect to login when bob was active

- [ ] Switch active back to bob first (Settings → tap bob → Switch).
- [ ] Settings → Profiles → bob row → overflow menu → Remove → confirm
  dialog → Remove.
- [ ] App redirects to `/login` (because bob was the active profile and
  removal cleared the pointer).
- [ ] Settings is unreachable until login because the redirect intercepts
  every navigation outside `/login`.
- [ ] Log back in as alice → Home loads alice's library again, no
  residual bob state visible.

---

## 3. Sanity checks (any time during the smoke)

- [ ] `adb logcat | grep flutter` — no unhandled exceptions, no
  `flutter_secure_storage` permission errors.
- [ ] `adb shell run-as com.aashish.heerr ls files/offline/` — should
  show two `<serverKey>` subdirectories (one per profile) if both have
  cached anything; the two keys must be different 16-hex strings.
- [ ] Backend logs: each `/queue`, `/status`, `/download` call shows the
  correct `token.owner_label` (alice or bob) matching the active
  profile.

---

## 4. Promote to v3.0.0

When all 7 steps pass:

```sh
cd /Users/E1621/Documents/Personal/Android/heerr
git tag -d v3.0.0-rc1
git tag v3.0.0
# bump pubspec.yaml: version: 3.0.0-rc1 → 3.0.0
# CHANGELOG: append "## 2026-MM-DD — v3.0.0 on-device smoke verified"
# commit + delete this file
rm android/docs/smoke-test.md
git add android/app/pubspec.yaml android/docs/CHANGELOG.md android/docs/smoke-test.md
git commit -m "chore(flutter): v3.0.0 multi-user smoke verified"
```
