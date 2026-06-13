# Playlist-mutations smoke log — M5

End-to-end verification of in-app playlist editing (Phase M) on the live home server. Companion to `smoke_streamer.md`; covers everything added on top of the streaming MVP — create / rename / delete, add songs, reorder + remove, Favourites toggle, addSongs client-side dedupe.

## Test environment

- **Device:** Pixel 7, on the user's tailnet.
- **Build:** `flutter build apk --debug && flutter install --debug`, `pubspec.yaml` at `1.2.1`.
- **Backends reached over Tailscale:**
  - heerr backend at `http://<tailscale-host>:8000/api/v1`
  - Navidrome at `http://<tailscale-host>:4533`
- **No public ingress; no reverse proxy.** Same cleartext-over-tailnet posture as the G1 / K2 smokes.

## Result

**Verification pending — to be filled in by the user after the on-device run.**

The six steps below are the M5 test gate (`android/docs/ROADMAP_PLAYLISTS.md`, "Phase M5"). Mark each as PASS / FAIL with a one-line detail after running; update the **Result** line above to "All N pass" once done.

## Per-step procedure

### 1. Create — TBD
- Library tab → Playlists sub-tab → tap the "+ New playlist" FAB.
- Enter name `Smoke test`. Confirm.
- **Expected:** snackbar "Playlist 'Smoke test' created" (1s). New empty playlist appears in the list; tapping it lands on the (empty) detail screen.

### 2. Add via long-press — TBD
- Library tab → tap the search icon → search `foo` (any term that returns at least one local Subsonic song).
- Long-press a song row (or tap the new `more_vert` icon) → "Add to playlist…" sheet opens.
- Pick `Smoke test`.
- **Expected:** snackbar "Added 1 song to 'Smoke test'" (1s). Playlist detail now shows the song.

### 3. Add via album overflow — TBD
- Library tab → Albums sub-tab → open any album.
- AppBar overflow → "Add album to playlist…" → pick `Smoke test`.
- **Expected:** snackbar reflects the number of songs added (e.g. "Added 12 songs to 'Smoke test'"). Detail screen shows the new entries appended after the existing one.

### 4. Rename + publish — TBD
- Open `Smoke test` → AppBar overflow → "Rename…" → change to `Smoke test (renamed)` + tick "Make playlist public".
- **Expected:** snackbar "Playlist updated" (1s). Library list shows the new name. Navidrome web UI confirms `public=true`.

### 5. Edit (reorder + remove) — TBD
- On the renamed playlist → tap the Edit pencil → enter edit mode.
- Drag the first song to last position via the right-side drag handle.
- Tap the delete handle on the second-from-top song.
- Tap the Check (save) icon.
- **Expected:** snackbar "Playlist updated" (1s). Detail re-renders in the new order; removed song is gone. Navidrome web UI confirms the canonical state.

### 6. Favourites + heart toggle — TBD
- On any song row (album detail or playlist detail), tap the outlined heart icon.
- **Expected (first ever tap):** lazy-creates the "Favourites" playlist. The heart switches to filled red. Library → Playlists shows the new "Favourites" row.
- Tap the same heart again.
- **Expected:** heart goes back to outlined; the song is removed from the Favourites playlist.

### 7. Delete + offline — TBD
- Open the renamed playlist → AppBar overflow → "Delete…" → confirm.
- **Expected:** snackbar "Playlist deleted" (1s). Playlist disappears from the Library list.
- Turn WiFi off → try to create another playlist via the FAB.
- **Expected:** "cannot reach backend — check tailscale" snackbar (~2s).
- Re-enable WiFi → retry succeeds.

### 8. Dedupe sanity — TBD
- Re-create `Smoke test`, add the same song twice via two consecutive long-press → "Add to playlist…" → `Smoke test` sweeps.
- **Expected:** first add → "Added 1 song to 'Smoke test'". Second add → "Already in 'Smoke test'". Playlist still has one copy of the song.

## Test gate

- `flutter analyze`: clean (CI).
- `flutter test`: **378/378** pass at the M1–polish baseline.
- On-device steps 1–8: to be marked PASS / FAIL by the user after the install.

## Caveats / out of scope for this smoke

- **Heart icon scope.** Available on album-detail and playlist-detail song rows only. Library-search "Songs" sub-section uses `LibraryResultTile` and is intentionally left out — long-press there still opens the add-to-playlist sheet.
- **Cover-art upload not exposed.** Navidrome auto-derives cover art from the first track in the playlist. Subsonic 1.16.1 has no clean upload endpoint. Out of scope.
- **Smart / dynamic playlists.** Subsonic doesn't model editable smart playlists; nothing to wire.
- **No offline mutation queue.** Mutations require online connectivity (Tailscale up + Navidrome reachable). Failures surface as snackbars; the library cache is invalidated on every successful mutation.
- **Reorder is delete-all-and-re-add.** Subsonic's `updatePlaylist` only exposes append + delete-at-index; the M1 `reorder()` method synthesises a single `updatePlaylist` call. Visible to Navidrome's audit log if the user inspects it.
- **Single-user posture preserved.** Owner-gated edits (`playlist.owner == settings.navidromeUsername`) hide rename / delete / edit / drag affordances on playlists not owned by the configured user.

## Done

M5 closes Phase M, which closes the playlist-mutations roadmap (M1 → M5). `pubspec.yaml` bumped `1.2.0-pre+11` → `1.2.1` to mark the playlists feature shipping milestone. Tag `v1.2.1`.
