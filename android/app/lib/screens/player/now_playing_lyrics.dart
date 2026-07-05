part of 'now_playing_screen.dart';

/// Always-visible lyrics section rendered below the transport controls.
/// The user reaches it by scrolling the parent [SingleChildScrollView].
/// No toggle — lyrics are always in the widget tree.
class _LyricsSection extends StatelessWidget {
  const _LyricsSection({
    required this.songId,
    required this.artist,
    required this.title,
    required this.position,
  });

  final String? songId;
  final String artist;
  final String title;
  final Duration position;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Text(
            'Lyrics',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        _LyricsContent(
          songId: songId,
          artist: artist,
          title: title,
          position: position,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Resolves the [lyricsForProvider] and renders the appropriate state widget.
///
/// Render rules:
///  - [songId] null/empty AND artist/title both empty → empty state, no call.
///  - Provider loading → spinner.
///  - Provider error → readable error line.
///  - Provider data null or empty text → empty state.
///  - Provider data with timed lines → [_SyncedLyrics].
///  - Provider data plain text → selectable scrollable block.
class _LyricsContent extends ConsumerWidget {
  const _LyricsContent({
    required this.songId,
    required this.artist,
    required this.title,
    required this.position,
  });

  final String? songId;
  final String artist;
  final String title;
  final Duration position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if ((songId == null || songId!.isEmpty) && artist.isEmpty && title.isEmpty) {
      return const Center(
        key: Key('now-playing-lyrics-empty'),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Text('No lyrics for this track'),
        ),
      );
    }
    final AsyncValue<Lyrics?> async =
        ref.watch(lyricsForProvider(songId ?? '', artist, title));
    return async.when(
      loading: () => const Center(
        key: Key('now-playing-lyrics-loading'),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (Object e, _) => Center(
        key: const Key('now-playing-lyrics-error'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Text(
            e is ApiError ? e.message : 'Lyrics error: $e',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (Lyrics? lyrics) {
        final String? value = lyrics?.value;
        if (value == null || value.trim().isEmpty) {
          return const Center(
            key: Key('now-playing-lyrics-empty'),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Text('No lyrics for this track'),
            ),
          );
        }
        final List<LyricsLine>? lines = lyrics?.lines;
        if (lines != null && lines.isNotEmpty) {
          return _SyncedLyrics(lines: lines, position: position);
        }
        return Padding(
          key: const Key('now-playing-lyrics-scroll'),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: SelectableText(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        );
      },
    );
  }
}

/// #26: synced lyrics. Highlights the active line and scrolls it into view via
/// [Scrollable.ensureVisible], which bubbles up to the parent
/// [SingleChildScrollView] (the whole Now Playing page) because this widget
/// uses a [Column], not a nested [ListView] with its own [Scrollable].
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
      alignment: 0.4,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final int current = _currentIndex();
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Column(
      key: const Key('now-playing-lyrics-synced'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < widget.lines.length; i++)
          Padding(
            key: _lineKeys[i],
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
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
    );
  }
}
