import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_error.dart';
import '../../models/seed_track.dart';
import '../../models/subsonic/lyrics.dart';
import '../../models/subsonic/song.dart';
import '../../player/heerr_audio_handler.dart';
import '../../player/player_provider.dart';
import '../../player/sleep_timer.dart';
import '../../player/song_to_media_item.dart';
import '../../providers/library/favourites.dart';
import '../../providers/library/lyrics.dart';
import '../../providers/library/playlist_mutations.dart';
import '../../providers/queue.dart';
import '../../utils/palette.dart';
import '../../widgets/add_to_playlist_sheet.dart';
import '../../widgets/error_snackbar.dart';
import '../../widgets/preview_badge.dart';

// A17: per-section private widgets live in sibling part files to keep this
// screen file readable. They share this library's imports + privacy.
part 'now_playing_lyrics.dart';
part 'now_playing_transport.dart';
part 'now_playing_sleep_timer.dart';

/// Injection point for tests — swap `dominantColorFor` with a deterministic
/// fake (e.g. `(_) async => Colors.purple`) so widget tests don't hit the
/// network and don't depend on `package:palette_generator`'s decode path.
typedef PaletteExtractor = Future<Color?> Function(Uri? artUri);

@visibleForTesting
PaletteExtractor paletteExtractorOverride = dominantColorFor;

/// Full-screen Now Playing surface. Cover art on top, title/artist, scrubber
/// bound to the live position, transport controls, and the queue list at the
/// bottom.
///
/// State sources:
///   * [playerSnapshotProvider] — current `MediaItem` + `PlaybackState` (the
///     `playing` flag, the projected position, the duration via item).
///   * [playerQueueProvider] — queue list for the bottom section.
///
/// Position ticker: PlaybackState only emits on state changes (play, pause,
/// seek, buffer). To keep the scrubber smooth between events we rebuild every
/// 250ms via a private `Stream.periodic` while playing. The position is read
/// from the snapshot's `state.position` getter, which already extrapolates
/// from `updatePosition + elapsed * speed` (see PlaybackState in audio_service).
class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  Timer? _ticker;
  Duration? _scrubOverride;

  // Cover-art-derived tint colour. Recomputed when the current MediaItem's
  // artUri changes. Null while loading or when extraction fails — the body
  // falls back to the default surface in that case.
  Uri? _tintArtUri;
  Color? _tintColor;

  // P2: lyrics view toggle. Persisted as widget state — survives screen
  // rebuilds but resets on Now Playing pop / push (intentional; lyrics is
  // a per-session view choice, not a global preference).
  bool _showLyrics = false;

  // Cached queue notifier so dispose() doesn't have to read it through `ref`
  // (Riverpod invalidates the ref before State.dispose runs — caching here
  // means resume() can fire even during teardown).
  Queue? _queueNotifier;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
    // K1 lifecycle: pause the /queue poller while Now Playing is foreground.
    // The queue + reactive-promotion logic stays paused; the user can't see
    // it from here. Resumed in dispose().
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final Queue q = ref.read(queueProvider.notifier);
        _queueNotifier = q;
        q.pause();
      } catch (_) {
        // Provider may not be initialised yet (rare); ignore.
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    // Use the cached notifier so we don't have to touch `ref` — Riverpod
    // invalidates it before this dispose runs.
    try {
      _queueNotifier?.resume();
    } catch (_) {
      // Notifier may already be disposed; ignore.
    }
    super.dispose();
  }

  void _openSleepTimerSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => const _SleepTimerSheet(),
    );
  }

  /// Opens [AddToPlaylistSheet] for the track that is currently playing.
  /// The Subsonic song id lives in the MediaItem's `subsonicId` extra (see
  /// [songToMediaItem]); tracks without one (non-Subsonic playback) can't be
  /// added to a server-side playlist, so we surface a snackbar instead.
  void _openAddToPlaylist(BuildContext context) {
    final MediaItem? item = ref.read(playerSnapshotProvider).valueOrNull?.item;
    final Song? song = item == null ? null : songFromMediaItem(item);
    if (song == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Can't add this track to a playlist")),
      );
      return;
    }
    AddToPlaylistSheet.show(
      context: context,
      songIds: <String>[song.id],
      findSimilarSeed: seedForSong(song),
    );
  }

  void _maybeRefreshTint(Uri? artUri) {
    if (artUri == _tintArtUri) return;
    _tintArtUri = artUri;
    final Uri? captured = artUri;
    paletteExtractorOverride(captured).then((Color? c) {
      if (!mounted) return;
      // Stale-response guard: another item may have started while we were
      // extracting; only apply this colour if the current artUri still
      // matches the one we kicked off the extraction for.
      if (_tintArtUri != captured) return;
      setState(() => _tintColor = c);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<PlayerSnapshot> snap =
        ref.watch(playerSnapshotProvider);

    final Duration? sleepRemaining = ref.watch(sleepTimerNotifierProvider);

    final MediaItem? currentItem = snap.valueOrNull?.item;
    final Song? currentSong =
        currentItem != null && !isPreviewMediaItem(currentItem)
            ? songFromMediaItem(currentItem)
            : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Now playing'),
        backgroundColor: _tintColor?.withValues(alpha: 0.6),
        actions: <Widget>[
          if (sleepRemaining != null)
            _SleepCountdownChip(remaining: sleepRemaining),
          if (currentSong != null) _FavouriteButton(song: currentSong),
          IconButton(
            key: const Key('now-playing-lyrics-toggle'),
            tooltip: _showLyrics ? 'Show cover art' : 'Show lyrics',
            icon: Icon(
              _showLyrics ? Icons.image_outlined : Icons.lyrics_outlined,
            ),
            onPressed: () => setState(() => _showLyrics = !_showLyrics),
          ),
          PopupMenuButton<String>(
            key: const Key('now-playing-overflow'),
            tooltip: 'More',
            icon: const Icon(Icons.more_vert),
            onSelected: (String v) {
              if (v == 'sleep') {
                _openSleepTimerSheet(context);
              } else if (v == 'add_to_playlist') {
                _openAddToPlaylist(context);
              }
            },
            itemBuilder: (BuildContext _) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                key: Key('now-playing-add-to-playlist'),
                value: 'add_to_playlist',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.playlist_add),
                  title: Text('Add to playlist'),
                ),
              ),
              PopupMenuItem<String>(
                value: 'sleep',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.bedtime_outlined),
                  title: Text('Sleep timer'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: snap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('Player error: $e')),
        data: (PlayerSnapshot s) {
          final MediaItem? item = s.item;
          if (item == null) {
            _maybeRefreshTint(null);
            return const Center(child: Text('Nothing is playing.'));
          }
          _maybeRefreshTint(item.artUri);
          return _TintedBackground(
            color: _tintColor,
            child: _Body(
              snapshot: s,
              showLyrics: _showLyrics,
              scrubOverride: _scrubOverride,
              onSeekStart: (Duration d) => setState(() => _scrubOverride = d),
              onSeekUpdate: (Duration d) => setState(() => _scrubOverride = d),
              onSeekEnd: (Duration d) {
                ref.read(audioHandlerProvider).seek(d);
                setState(() => _scrubOverride = null);
              },
            ),
          );
        },
      ),
    );
  }
}

/// Heart icon in the Now Playing AppBar. Watches [favouriteSongIdsProvider]
/// so the filled/outlined state updates immediately after a toggle.
/// Only rendered for Subsonic tracks (preview MediaItems have no song id).
class _FavouriteButton extends ConsumerWidget {
  const _FavouriteButton({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Set<String> favIds =
        ref.watch(favouriteSongIdsProvider).valueOrNull ?? const <String>{};
    final bool isFav = favIds.contains(song.id);
    return IconButton(
      tooltip: isFav ? 'Remove from Favourites' : 'Add to Favourites',
      icon: Icon(
        isFav ? Icons.favorite : Icons.favorite_border,
        color: isFav ? Colors.redAccent : null,
      ),
      onPressed: () async {
        try {
          await ref
              .read(playlistMutationsProvider.notifier)
              .toggleFavourite(song);
        } on ApiError catch (e) {
          if (!context.mounted) return;
          showApiError(context, e);
        }
      },
    );
  }
}

/// Vertical gradient from [color] (top, at low opacity) to the default M3
/// surface (bottom). Null [color] → no gradient applied.
class _TintedBackground extends StatelessWidget {
  const _TintedBackground({required this.color, required this.child});

  final Color? color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Color? c = color;
    if (c == null) return child;
    final ColorScheme cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            c.withValues(alpha: 0.85),
            c.withValues(alpha: 0.35),
            cs.surface,
          ],
          stops: const <double>[0.0, 0.45, 0.9],
        ),
      ),
      child: child,
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.snapshot,
    required this.showLyrics,
    required this.scrubOverride,
    required this.onSeekStart,
    required this.onSeekUpdate,
    required this.onSeekEnd,
  });

  final PlayerSnapshot snapshot;
  final bool showLyrics;
  final Duration? scrubOverride;
  final ValueChanged<Duration> onSeekStart;
  final ValueChanged<Duration> onSeekUpdate;
  final ValueChanged<Duration> onSeekEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MediaItem item = snapshot.item!;
    final Duration duration = item.duration ?? Duration.zero;
    final Duration position = scrubOverride ?? snapshot.state.position;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 16),
        Center(
          child: showLyrics
              ? _LyricsPane(
                  songId: item.extras?['subsonicId'] as String?,
                  artist: item.artist ?? '',
                  title: item.title,
                )
              : _CoverArt(artUri: item.artUri),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (isPreviewMediaItem(item)) ...<Widget>[
                const PreviewBadge(),
                const SizedBox(height: 8),
              ],
              Text(
                item.title,
                style: Theme.of(context).textTheme.titleLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (item.artist != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  item.artist!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
        _Scrubber(
          position: position,
          duration: duration,
          onSeekStart: onSeekStart,
          onSeekUpdate: onSeekUpdate,
          onSeekEnd: onSeekEnd,
        ),
        _Transport(
          playing: snapshot.isPlaying,
          repeatMode: snapshot.state.repeatMode,
          shuffleMode: snapshot.state.shuffleMode,
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        const Expanded(child: _QueueList()),
      ],
    );
  }
}

class _CoverArt extends StatelessWidget {
  const _CoverArt({required this.artUri});

  final Uri? artUri;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Uri? uri = artUri;
    final Widget placeholder = Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.music_note, size: 96, color: cs.onSurfaceVariant),
    );
    if (uri == null) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        uri.toString(),
        width: 240,
        height: 240,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}

