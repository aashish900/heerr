import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
import '../../theme.dart';
import '../../utils/palette.dart';
import '../../widgets/add_to_playlist_sheet.dart';
import '../../widgets/error_snackbar.dart';
import '../../widgets/glass_icon_button.dart';
import '../../widgets/gradient_icon.dart';
import '../../widgets/now_playing_background.dart';
import '../../widgets/preview_badge.dart';

part 'now_playing_lyrics.dart';
part 'now_playing_transport.dart';
part 'now_playing_sleep_timer.dart';

/// Injection point for tests — swap `dominantColorFor` with a deterministic
/// fake so widget tests don't hit the network or palette_generator decode path.
typedef PaletteExtractor = Future<Color?> Function(Uri? artUri);

@visibleForTesting
PaletteExtractor paletteExtractorOverride = dominantColorFor;

/// Full-screen Now Playing surface. Big cover art, title/artist with inline
/// favourite, scrubber, transport with rounded shuffle/loop, bottom-bar with
/// queue trigger, and always-visible lyrics that appear when the user scrolls.
///
/// Layout: [SingleChildScrollView] → [Column] so the lyrics section is
/// reachable by scrolling without a separate nested scroll view.
class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  Timer? _ticker;
  Duration? _scrubOverride;

  Uri? _tintArtUri;
  Color? _tintColor;

  Queue? _queueNotifier;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final Queue q = ref.read(queueProvider.notifier);
        _queueNotifier = q;
        q.pause();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    try {
      _queueNotifier?.resume();
    } catch (_) {}
    super.dispose();
  }

  void _openSleepTimerSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => const _SleepTimerSheet(),
    );
  }

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

  void _openQueueSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Queue',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Expanded(child: _QueueList()),
          ],
        ),
      ),
    );
  }

  void _maybeRefreshTint(Uri? artUri) {
    if (artUri == _tintArtUri) return;
    _tintArtUri = artUri;
    final Uri? captured = artUri;
    paletteExtractorOverride(captured).then((Color? c) {
      if (!mounted) return;
      if (_tintArtUri != captured) return;
      setState(() => _tintColor = c);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<PlayerSnapshot> snap = ref.watch(playerSnapshotProvider);

    return Scaffold(
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
          return NowPlayingBackground(
            artUri: item.artUri,
            tintColor: _tintColor,
            child: _Body(
              snapshot: s,
              tintColor: _tintColor,
              scrubOverride: _scrubOverride,
              onSeekStart: (Duration d) => setState(() => _scrubOverride = d),
              onSeekUpdate: (Duration d) => setState(() => _scrubOverride = d),
              onSeekEnd: (Duration d) {
                ref.read(audioHandlerProvider).seek(d);
                setState(() => _scrubOverride = null);
              },
              onQueueTap: () => _openQueueSheet(context),
              onSleepTap: () => _openSleepTimerSheet(context),
              onAddToPlaylist: () => _openAddToPlaylist(context),
            ),
          );
        },
      ),
    );
  }
}

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

class _Header extends StatelessWidget {
  const _Header({
    required this.sleepRemaining,
    required this.onSleepTap,
    required this.onAddToPlaylist,
  });

  final Duration? sleepRemaining;
  final VoidCallback onSleepTap;
  final VoidCallback onAddToPlaylist;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: <Widget>[
          GlassIconButton(
            key: const Key('now-playing-collapse'),
            icon: Icons.keyboard_arrow_down,
            tooltip: 'Collapse',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              // NOWPLAYING.md §2.1: "Playing from <context>" is deferred —
              // the player has no play-source context to show today. Static
              // label kept until that plumbing exists.
              'NOW PLAYING',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(letterSpacing: 1.5, color: Colors.white70),
            ),
          ),
          if (sleepRemaining != null) ...<Widget>[
            _SleepCountdownChip(remaining: sleepRemaining!),
            const SizedBox(width: 8),
          ],
          // NOWPLAYING.md §2.3: disabled placeholder — no output-routing
          // feature exists yet; visual parity with the mockup only.
          const GlassIconButton(
            icon: Icons.speaker_outlined,
            tooltip: 'Audio device',
            onPressed: null,
          ),
          const SizedBox(width: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.06),
              border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
            ),
            child: PopupMenuButton<String>(
              key: const Key('now-playing-overflow'),
              tooltip: 'More',
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (String v) {
                if (v == 'sleep') {
                  onSleepTap();
                } else if (v == 'add_to_playlist') {
                  onAddToPlaylist();
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
          ),
        ],
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.snapshot,
    required this.tintColor,
    required this.scrubOverride,
    required this.onSeekStart,
    required this.onSeekUpdate,
    required this.onSeekEnd,
    required this.onQueueTap,
    required this.onSleepTap,
    required this.onAddToPlaylist,
  });

  final PlayerSnapshot snapshot;
  final Color? tintColor;
  final Duration? scrubOverride;
  final ValueChanged<Duration> onSeekStart;
  final ValueChanged<Duration> onSeekUpdate;
  final ValueChanged<Duration> onSeekEnd;
  final VoidCallback onQueueTap;
  final VoidCallback onSleepTap;
  final VoidCallback onAddToPlaylist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MediaItem item = snapshot.item!;
    final Duration duration = item.duration ?? Duration.zero;
    final Duration position = scrubOverride ?? snapshot.state.position;
    final Song? currentSong =
        !isPreviewMediaItem(item) ? songFromMediaItem(item) : null;
    final Duration? sleepRemaining = ref.watch(sleepTimerNotifierProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SafeArea(
            bottom: false,
            child: _Header(
              sleepRemaining: sleepRemaining,
              onSleepTap: onSleepTap,
              onAddToPlaylist: onAddToPlaylist,
            ),
          ),
          _WideCoverArt(artUri: item.artUri),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
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
                if (currentSong != null) _FavouriteButton(song: currentSong),
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
          _BottomActionsRow(onQueueTap: onQueueTap),
          _LyricsSection(
            songId: item.extras?['subsonicId'] as String?,
            artist: item.artist ?? '',
            title: item.title,
            position: position,
            tintColor: tintColor,
          ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
        ],
      ),
    );
  }
}

class _WideCoverArt extends StatelessWidget {
  const _WideCoverArt({required this.artUri});

  final Uri? artUri;

  @override
  Widget build(BuildContext context) {
    final double size = MediaQuery.sizeOf(context).width - 48;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Widget placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.music_note, size: size * 0.3, color: cs.onSurfaceVariant),
    );
    final Uri? uri = artUri;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: uri == null
          ? placeholder
          : ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                uri.toString(),
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
              ),
            ),
    );
  }
}
