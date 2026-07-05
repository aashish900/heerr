part of 'now_playing_screen.dart';

/// P2: scrollable lyrics pane shown in place of the cover art when the
/// user toggles the AppBar lyrics action. Sized to match the cover-art
/// box (240×240) so the surrounding scrubber + transport + queue don't
/// jump when switching views.
///
/// Render rules:
///  - [songId] null/empty → "No lyrics for this track" empty state (no
///    network call — happens when a MediaItem has no `subsonicId` extra).
///  - Provider loading → spinner.
///  - Provider error (any [ApiError]) → readable error line.
///  - Provider data null → "No lyrics for this track" empty state.
///  - Provider data → scrollable plain text with selectable copy.
class _LyricsPane extends ConsumerWidget {
  const _LyricsPane({
    required this.songId,
    required this.artist,
    required this.title,
    required this.position,
  });

  final String? songId;
  final String artist;
  final String title;

  /// #26: live playback position from the Now Playing ticker — drives the
  /// highlighted line when the resolved lyrics carry timed `lines`.
  final Duration position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Skip network entirely when we have nothing to search with.
    if ((songId == null || songId!.isEmpty) && artist.isEmpty && title.isEmpty) {
      return const _LyricsBox(
        child: Center(
          key: Key('now-playing-lyrics-empty'),
          child: Text('No lyrics for this track'),
        ),
      );
    }
    final AsyncValue<Lyrics?> async =
        ref.watch(lyricsForProvider(songId ?? '', artist, title));
    return _LyricsBox(
      child: async.when(
        loading: () => const Center(
          key: Key('now-playing-lyrics-loading'),
          child: CircularProgressIndicator(),
        ),
        error: (Object e, _) => Center(
          key: const Key('now-playing-lyrics-error'),
          child: Text(
            e is ApiError ? e.message : 'Lyrics error: $e',
            textAlign: TextAlign.center,
          ),
        ),
        data: (Lyrics? lyrics) {
          final String? value = lyrics?.value;
          if (value == null || value.trim().isEmpty) {
            return const Center(
              key: Key('now-playing-lyrics-empty'),
              child: Text('No lyrics for this track'),
            );
          }
          // #26: timed lines → synced view following [position]; otherwise
          // the original plain scrollable text.
          final List<LyricsLine>? lines = lyrics?.lines;
          if (lines != null && lines.isNotEmpty) {
            return _SyncedLyrics(lines: lines, position: position);
          }
          return Scrollbar(
            child: SingleChildScrollView(
              key: const Key('now-playing-lyrics-scroll'),
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                value,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// #26: synced lyrics view. Highlights the last line whose `start` is at or
/// before [position] and keeps it centred via `Scrollable.ensureVisible`
/// whenever the active line changes. Tapping a line is intentionally not a
/// seek affordance in v1 — the scrubber owns seeking.
class _SyncedLyrics extends StatefulWidget {
  const _SyncedLyrics({required this.lines, required this.position});

  final List<LyricsLine> lines;
  final Duration position;

  @override
  State<_SyncedLyrics> createState() => _SyncedLyricsState();
}

class _SyncedLyricsState extends State<_SyncedLyrics> {
  late final List<GlobalKey> _lineKeys;
  int _lastScrolledIndex = -1;

  @override
  void initState() {
    super.initState();
    _lineKeys = List<GlobalKey>.generate(
      widget.lines.length,
      (_) => GlobalKey(),
    );
  }

  int _currentIndex() {
    final int ms = widget.position.inMilliseconds;
    int idx = -1;
    for (int i = 0; i < widget.lines.length; i++) {
      if (widget.lines[i].start <= ms) {
        idx = i;
      } else {
        break;
      }
    }
    return idx;
  }

  @override
  void didUpdateWidget(covariant _SyncedLyrics old) {
    super.didUpdateWidget(old);
    final int idx = _currentIndex();
    if (idx < 0 || idx == _lastScrolledIndex) return;
    _lastScrolledIndex = idx;
    final BuildContext? lineContext = _lineKeys[idx].currentContext;
    if (lineContext == null) return;
    Scrollable.ensureVisible(
      lineContext,
      alignment: 0.4, // slightly above centre, Spotify-style
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final int current = _currentIndex();
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme cs = Theme.of(context).colorScheme;
    // Non-lazy list on purpose: `ensureVisible` needs the target line's
    // context to exist, and after a seek the active line can be anywhere.
    // Lyrics documents are at most a few hundred short Text rows — cheap.
    return Scrollbar(
      child: ListView(
        key: const Key('now-playing-lyrics-synced'),
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          for (int i = 0; i < widget.lines.length; i++)
            Padding(
              key: _lineKeys[i],
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                widget.lines[i].value,
                style: (i == current ? text.bodyLarge : text.bodyMedium)
                    ?.copyWith(
                  color: i == current ? cs.primary : cs.onSurfaceVariant,
                  fontWeight: i == current ? FontWeight.w700 : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LyricsBox extends StatelessWidget {
  const _LyricsBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}
