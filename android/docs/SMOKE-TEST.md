# SMOKE-TEST.md — heerr Android client

Manual on-device verification. Scoped to the **A1/A4/A5 credential + offline-prefs
band** (commit `33aa334`, DECISIONLOG/CHANGELOG 2026-06-19). The automated gate
(`flutter analyze` clean, `flutter test` = 567 pass) covers logic; this doc covers
the things only a real device + real upgrade can prove: the silent migration of an
existing install and the absence of the deleted Servers surface.

Run from `android/app`. Target device per `docs/CONTEXT.md`: Pixel 7, Android 16,
wireless adb.

---

## 0. What this band changed (so you know what you're checking)

- **A1** — the active Profile is the *only* credential store. The legacy
  single-set secure-storage keys, the `server_profiles` blob, the `ServerProfiles`
  notifier, and the **entire "Servers" screen + Settings tile** are gone. Creds are
  managed only via Settings → Profiles (added at `/login`).
- **A5** — the five offline-download prefs moved out of EncryptedSharedPreferences
  into plain `shared_preferences`, with a one-shot migration on first launch.
- **A4** — `Settings.build` no longer does 10 sequential keystore reads (no
  user-visible behaviour, but the Settings screen should feel no slower).

Highest-risk path = **upgrade of an existing install** (steps 1–2). If you only run
one section, run that.

---

## 1. Pre-req: capture a "before" state on the OLD build

> Skip if you have no prior install — jump to §3 (fresh install). This section
> proves the silent upgrade, so do it on a device that already runs **v3.0.0**
> (the build before this band) with a logged-in profile.

1. On the existing `v3.0.0` build, confirm you are logged in and the library loads
   (Home shows albums).
2. Settings → Offline downloads: set a **non-default** combination so the migration
   is observable — e.g. toggle **WiFi only OFF** and **Sync interval = 60**. Note
   the exact values you set.
3. Mark one album for offline (album detail → download icon) and let it finish, so
   there's an offline manifest on disk to confirm it survives the upgrade.
4. Leave the app. Do **not** clear app data.

---

## 2. Upgrade smoke (install the new build over the old one)

Build + install over the top (no uninstall — that's the whole point):

```
cd android/app
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Launch the app and verify:

| # | Check | Expected |
|---|-------|----------|
| 2.1 | App opens straight to **Home** (not `/login`). | The legacy single-set creds were migrated to a Profile by `migrateLegacyCreds` on a prior version, so the active profile persists. No re-login. |
| 2.2 | Library/Home load real data. | The dio + Subsonic clients resolve creds from the active Profile (A1). |
| 2.3 | Settings → Offline downloads shows the **exact** values from §1.2 (WiFi only OFF, interval 60). | `migrateOfflinePrefs` copied the offline keys secure→prefs on first launch; values preserved, not reset to defaults. |
| 2.4 | The album marked in §1.3 still plays **with WiFi off** (airplane mode + WiFi off, or pull the tailnet). | Offline manifest + files survived the upgrade (serverKey unchanged — it derives from the active profile's `navidromeBaseUrl`+`username`, same as before). |
| 2.5 | Toggle an offline pref (e.g. WiFi only ON), force-stop the app, reopen. | The new value persists — offline prefs now round-trip through `shared_preferences`. |

> Migration is idempotent: relaunching again is a no-op. If 2.3 shows defaults
> instead of your §1.2 values, the offline-prefs migration regressed.

---

## 3. Servers surface is gone (A1)

| # | Check | Expected |
|---|-------|----------|
| 3.1 | Settings screen: scroll the whole list. | Sections are **Profiles**, **Offline downloads**, **Recommendations**. There is **no "Servers"** tile. |
| 3.2 | There is no way to reach a "Servers" / "Add server" form anywhere outside the Profiles section. | The `ServersScreen` and `/settings/servers` route were deleted. Credentials are only added via Profiles → Add profile (`/login`). |

---

## 4. Profile credential flow (A1)

| # | Check | Expected |
|---|-------|----------|
| 4.1 | Settings → Profiles → **Add profile** → the **Sign in** screen opens. | `/login` is the only credential-entry surface. |
| 4.2 | On a dev build, the **heerr base URL** and **Navidrome username** fields are pre-filled; **password** is blank. | `DevDefaults` wired into the login screen (URL + username only; never the secret). On a non-dev clone (`dev_defaults.example.dart` → all null) the fields are blank — that's correct too. |
| 4.3 | Sign in with valid creds → lands on Home with that profile's library. | Login mints the token via `POST /auth/login`, writes a Profile, sets it active; clients rebuild against it. |
| 4.4 | With ≥2 profiles, switch the active profile (tap a non-active one → confirm). | App re-routes to Home; library, queue, and offline state are the *new* profile's (per-profile `serverKey`). |
| 4.5 | Remove the **active** profile. | Redirects to `/login` (no active profile). |

---

## 5. Auth-error redirect (A1)

| # | Check | Expected |
|---|-------|----------|
| 5.1 | Force a Navidrome auth failure: Settings → Profiles → (re-add / edit a profile with a **wrong Navidrome password**), then browse the Library so a Subsonic call fires. | A snackbar appears **and** the app navigates to `/login` (not to a Servers screen — that's gone). `NavidromeAuthError → /login`. |
| 5.2 | Force a heerr 401 (revoked/expired bearer token) by browsing a heerr-backed surface (Queue/Search). | Snackbar + redirect to Settings (unchanged `UnauthorizedError` behaviour). |

---

## 6. Fresh-install sanity (no prior data)

> Only if you can spare a clean device / `adb uninstall com.aashish.heerr` first.

| # | Check | Expected |
|---|-------|----------|
| 6.1 | First launch on a clean install. | Boots to `/login` (no active profile). |
| 6.2 | Sign in → Home loads. | Standard Phase-S first-run. |
| 6.3 | Offline downloads section shows **defaults** (master OFF, WiFi only ON, interval 15). | No prefs to migrate; defaults applied in `Settings.build`. |

---

## Pass criteria

- §2 (upgrade) all green — **the critical one**: silent re-login + offline prefs +
  offline files all survive the upgrade.
- §3 — no Servers tile/route anywhere.
- §4/§5 — profile add/switch/remove + auth-error redirects behave as described.

If any §2 row fails, do **not** ship — it means an existing user loses creds or
offline settings on upgrade. Capture `adb logcat | grep -i heerr` and file before
tagging.
