import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../api/api_error.dart';
import '../../models/seed_track.dart';
import '../../models/subsonic/lyrics.dart';
import '../../models/subsonic/song.dart';
import '../../offline/offline_manifest.dart';
import '../../offline/offline_marker.dart';
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
import '../../widgets/animated_tint.dart';
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

/// NP3 — hero-art "float" breathing animation. A module-scope flag rather
/// than a widget parameter (same shape as [paletteExtractorOverride]) so the
/// whole screen tree doesn't need to plumb an `animate` argument down to
/// `_HeroArt`. Tests must set this `false` in `setUp` — a repeating
/// [AnimationController] never satisfies `pumpAndSettle`.
@visibleForTesting
bool heroArtFloatEnabled = true;

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
          _HeroArt(
            artUri: item.artUri,
            tintColor: tintColor,
            song: currentSong,
          ),
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

/// Hero artwork (NOWPLAYING.md NP3): 28dp radius, hairline border, a soft
/// glow blended from the palette [tintColor] (never recolours the artwork
/// itself — only the surrounding glow, matching the Home hero / MiniPlayer
/// adaptive-theming rule), a slow floating breathe, and a floating on-art
/// download-state button for [song] (hidden for preview items, where
/// [song] is null).
class _HeroArt extends StatefulWidget {
  const _HeroArt({
    required this.artUri,
    required this.tintColor,
    required this.song,
  });

  final Uri? artUri;
  final Color? tintColor;
  final Song? song;

  @override
  State<_HeroArt> createState() => _HeroArtState();
}

class _HeroArtState extends State<_HeroArt> with SingleTickerProviderStateMixin {
  late final AnimationController _floatCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  @override
  void initState() {
    super.initState();
    if (heroArtFloatEnabled) _floatCtrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double size = MediaQuery.sizeOf(context).width - 48;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Uri? uri = widget.artUri;
    final Color? tint = widget.tintColor;

    final Widget placeholderIcon = Center(
      child: Icon(Icons.music_note, size: size * 0.3, color: cs.onSurfaceVariant),
    );
    final Widget content = uri == null
        ? placeholderIcon
        : Image.network(
            uri.toString(),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) => placeholderIcon,
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: AnimatedBuilder(
        animation: _floatCtrl,
        builder: (BuildContext context, Widget? child) => Transform.translate(
          offset: Offset(
            0,
            heroArtFloatEnabled ? (_floatCtrl.value * 6 - 3) : 0,
          ),
          child: child,
        ),
        child: AnimatedTint(
          tint: tint ?? cs.surfaceContainerHighest,
          builder: (BuildContext context, Color glow) => Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: uri == null ? cs.surfaceContainerHighest : null,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.24),
                  ),
                  boxShadow: tint == null
                      ? const <BoxShadow>[]
                      : <BoxShadow>[
                          BoxShadow(
                            color: brandBlend(tint).withValues(alpha: 0.45),
                            blurRadius: 24,
                            spreadRadius: -4,
                          ),
                          BoxShadow(
                            color: brandBlend(tint).withValues(alpha: 0.2),
                            blurRadius: 60,
                            spreadRadius: 4,
                          ),
                        ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: content,
                ),
              ),
              if (widget.song != null)
                Positioned(
                  top: 12,
                  right: 12,
                  child: _HeroArtDownloadButton(song: widget.song!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// On-art floating download-state affordance (NOWPLAYING.md §2.4). The app
/// has no single-song download mutation — offline downloads are driven by
/// marking whole albums/playlists/artists (`OfflineMarker`). This button
/// reflects the song's existing per-song manifest state (mirrors the
/// read-only glyphs in `album_detail_screen.dart` /
/// `playlist_detail_screen.dart`) and, when already downloaded, offers the
/// one per-song mutation that *does* exist: `deleteSongLocally`. When not
/// yet downloaded, tapping explains how to make it available rather than
/// silently no-op-ing.
class _HeroArtDownloadButton extends ConsumerWidget {
  const _HeroArtDownloadButton({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OfflineManifest? manifest =
        ref.watch(offlineManifestProvider).valueOrNull;
    final OfflineSongEntry? entry = manifest?.songs[song.id];

    switch (entry?.state) {
      case null:
        return GlassIconButton(
          key: const Key('now-playing-hero-download'),
          icon: Icons.download_outlined,
          tooltip:
              'Download the album or playlist this song belongs to, to '
              'make it available offline',
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Download this song's album or playlist to make it "
                'available offline.',
              ),
            ),
          ),
        );
      case OfflineSongState.downloading:
        return const Padding(
          padding: EdgeInsets.all(8),
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
        );
      case OfflineSongState.queued:
        return const GlassIconButton(
          icon: Icons.schedule,
          tooltip: 'Queued for download',
          onPressed: null,
        );
      case OfflineSongState.failed:
        return GlassIconButton(
          key: const Key('now-playing-hero-download'),
          icon: Icons.error_outline,
          tooltip: entry?.lastError ?? 'Download failed',
          iconColor: Colors.redAccent,
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(entry?.lastError ?? 'Download failed')),
          ),
        );
      case OfflineSongState.ready:
        return GlassIconButton(
          key: const Key('now-playing-hero-download'),
          icon: Icons.download_done,
          tooltip: 'Downloaded — tap to remove',
          iconColor: heerrMagenta,
          onPressed: () async {
            await ref
                .read(offlineMarkerProvider.notifier)
                .deleteSongLocally(song.id);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Removed from downloads')),
            );
          },
        );
    }
  }
}
