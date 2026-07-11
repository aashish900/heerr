part of 'now_playing_screen.dart';

/// Lyrics peek sheet docked below the transport controls (NOWPLAYING.md
/// NP8): a glass card (translucent fill + hairline border) over the
/// [NowPlayingBackground] rather than a solid palette-tint fill — the tint
/// now lives only in the active-line accent colour. Shows a preview window
/// of the lyrics; tapping the card (or the expand affordance) opens the
/// full-screen [_ExpandedLyricsSheet].
class _LyricsSection extends StatelessWidget {
  const _LyricsSection({
    required this.songId,
    required this.artist,
    required this.title,
    required this.position,
    required this.tintColor,
  });

  final String? songId;
  final String artist;
  final String title;
  final Duration position;
  final Color? tintColor;

  @override
  Widget build(BuildContext context) {
    final Color accent =
        tintColor != null ? brandBlend(tintColor!) : heerrMagenta;
    const Color fg = Colors.white;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('now-playing-lyrics-card'),
            onTap: () => _ExpandedLyricsSheet.show(context, tintColor),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'LYRICS',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: fg,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Container(width: 24, height: 2, color: accent),
                          ],
                        ),
                      ),
                      IconButton(
                        key: const Key('now-playing-lyrics-expand'),
                        tooltip: 'Expand lyrics',
                        icon: const Icon(Icons.open_in_full,
                            size: 18, color: fg),
                        onPressed: () =>
                            _ExpandedLyricsSheet.show(context, tintColor),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 8),
                    child: _LyricsContent(
                      songId: songId,
                      artist: artist,
                      title: title,
                      position: position,
                      expanded: false,
                      foreground: fg,
                      accentColor: accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
///  - Provider data with timed lines → preview window ([expanded] false) or
///    the big auto-scrolling [_SyncedLyrics] ([expanded] true).
///  - Provider data plain text → capped preview or full selectable block.
class _LyricsContent extends ConsumerWidget {
  const _LyricsContent({
    required this.songId,
    required this.artist,
    required this.title,
    required this.position,
    required this.expanded,
    required this.foreground,
    required this.accentColor,
  });

  final String? songId;
  final String artist;
  final String title;
  final Duration position;
  final bool expanded;
  final Color foreground;

  /// Active-line highlight — blended from the palette tint when one exists,
  /// [heerrMagenta] otherwise (NOWPLAYING.md NP8 §2 — the tint now lives in
  /// this accent, not the card's background fill).
  final Color accentColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if ((songId == null || songId!.isEmpty) && artist.isEmpty && title.isEmpty) {
      return _emptyState();
    }
    final AsyncValue<Lyrics?> async =
        ref.watch(lyricsForProvider(songId ?? '', artist, title));
    return async.when(
      loading: () => Center(
        key: const Key('now-playing-lyrics-loading'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: CircularProgressIndicator(color: foreground),
        ),
      ),
      error: (Object e, _) => Center(
        key: const Key('now-playing-lyrics-error'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            e is ApiError ? e.message : 'Lyrics error: $e',
            textAlign: TextAlign.center,
            style: TextStyle(color: foreground),
          ),
        ),
      ),
      data: (Lyrics? lyrics) {
        final String? value = lyrics?.value;
        if (value == null || value.trim().isEmpty) {
          return _emptyState();
        }
        final List<LyricsLine>? lines = lyrics?.lines;
        if (lines != null && lines.isNotEmpty) {
          return expanded
              ? _SyncedLyrics(
                  lines: lines,
                  position: position,
                  foreground: foreground,
                  accentColor: accentColor,
                )
              : _SyncedLyricsPreview(
                  lines: lines,
                  position: position,
                  foreground: foreground,
                  accentColor: accentColor,
                );
        }
        if (expanded) {
          return SelectableText(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
          );
        }
        return Text(
          value,
          key: const Key('now-playing-lyrics-scroll'),
          maxLines: 8,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
        );
      },
    );
  }

  Widget _emptyState() {
    return Center(
      key: const Key('now-playing-lyrics-empty'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No lyrics for this track',
          style: TextStyle(color: foreground.withValues(alpha: 0.7)),
        ),
      ),
    );
  }
}

/// Fixed window of synced lines shown inside the lyrics card: the line before
/// the active one plus the next few. No scrolling — the window slides as
/// playback advances.
class _SyncedLyricsPreview extends StatelessWidget {
  const _SyncedLyricsPreview({
    required this.lines,
    required this.position,
    required this.foreground,
    required this.accentColor,
  });

  static const int _windowSize = 5;

  final List<LyricsLine> lines;
  final Duration position;
  final Color foreground;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final int current = activeLyricsIndex(lines, position);
    final int start = (current - 1)
        .clamp(0, (lines.length - _windowSize).clamp(0, lines.length));
    final int end = (start + _windowSize).clamp(0, lines.length);
    final TextStyle? base = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        );
    return Column(
      key: const Key('now-playing-lyrics-synced'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = start; i < end; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: i == current
                ? ShaderMask(
                    shaderCallback: (Rect bounds) => LinearGradient(
                      colors: <Color>[accentColor, Colors.white],
                    ).createShader(bounds),
                    child: Text(
                      lines[i].value,
                      style: base?.copyWith(color: Colors.white),
                    ),
                  )
                : Text(
                    lines[i].value,
                    style: base?.copyWith(
                      color: foreground.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
      ],
    );
  }
}

/// Index of the last line whose start time is at or before [position],
/// or -1 when playback hasn't reached the first line yet.
int activeLyricsIndex(List<LyricsLine> lines, Duration position) {
  final int ms = position.inMilliseconds;
  int idx = -1;
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].start <= ms) {
      idx = i;
    } else {
      break;
    }
  }
  return idx;
}

/// #26: synced lyrics for the expanded sheet. Big bold lines — sung and
/// active lines at full contrast, upcoming lines dimmed. Scrolls the active
/// line into view via [Scrollable.ensureVisible], which bubbles up to the
/// sheet's [SingleChildScrollView].
class _SyncedLyrics extends StatefulWidget {
  const _SyncedLyrics({
    required this.lines,
    required this.position,
    required this.foreground,
    required this.accentColor,
  });

  final List<LyricsLine> lines;
  final Duration position;
  final Color foreground;
  final Color accentColor;

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

  @override
  void didUpdateWidget(covariant _SyncedLyrics old) {
    super.didUpdateWidget(old);
    final int idx = activeLyricsIndex(widget.lines, widget.position);
    if (idx < 0 || idx == _lastScrolledIndex) return;
    _lastScrolledIndex = idx;
    final BuildContext? lineContext = _lineKeys[idx].currentContext;
    if (lineContext == null) return;
    Scrollable.ensureVisible(
      lineContext,
      alignment: 0.35,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final int current = activeLyricsIndex(widget.lines, widget.position);
    final TextStyle? base = Theme.of(context).textTheme.headlineSmall;
    return Column(
      key: const Key('now-playing-lyrics-synced-expanded'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < widget.lines.length; i++)
          Padding(
            key: _lineKeys[i],
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: i == current
                ? ShaderMask(
                    shaderCallback: (Rect bounds) => LinearGradient(
                      colors: <Color>[widget.accentColor, Colors.white],
                    ).createShader(bounds),
                    child: Text(
                      widget.lines[i].value,
                      style: base?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  )
                : Text(
                    widget.lines[i].value,
                    style: base?.copyWith(
                      color: i < current
                          ? widget.foreground
                          : widget.foreground.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
          ),
      ],
    );
  }
}

/// Full-screen lyrics view (drag-up / "pulled up" state): drag-down /
/// chevron to dismiss, album-art thumbnail in the top-left corner, big bold
/// auto-scrolling lyrics. Watches [playerSnapshotProvider] itself so it stays
/// current across track changes, with its own 250 ms ticker for position.
class _ExpandedLyricsSheet extends ConsumerStatefulWidget {
  const _ExpandedLyricsSheet({required this.tintColor});

  final Color? tintColor;

  static void show(BuildContext context, Color? tintColor) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExpandedLyricsSheet(tintColor: tintColor),
    );
  }

  @override
  ConsumerState<_ExpandedLyricsSheet> createState() =>
      _ExpandedLyricsSheetState();
}

class _ExpandedLyricsSheetState extends ConsumerState<_ExpandedLyricsSheet> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color bg = Color.lerp(
      widget.tintColor ?? cs.surfaceContainerHigh,
      Colors.black,
      0.6,
    )!;
    final Color accent = widget.tintColor != null
        ? brandBlend(widget.tintColor!)
        : heerrMagenta;
    final PlayerSnapshot? snap =
        ref.watch(playerSnapshotProvider).valueOrNull;
    final MediaItem? item = snap?.item;

    return Container(
      key: const Key('now-playing-lyrics-sheet'),
      height: MediaQuery.sizeOf(context).height,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
      ),
      child: SafeArea(
        child: item == null
            ? const Center(child: Text('Nothing is playing.'))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                    child: Row(
                      children: <Widget>[
                        IconButton(
                          key: const Key('lyrics-sheet-collapse'),
                          tooltip: 'Collapse',
                          icon: const Icon(Icons.keyboard_arrow_down),
                          color: Colors.white,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: Column(
                            children: <Widget>[
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(color: Colors.white),
                              ),
                              if (item.artist != null)
                                Text(
                                  item.artist!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.white70),
                                ),
                            ],
                          ),
                        ),
                        // Balances the leading IconButton so the title stays
                        // centred.
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
                      child: _CornerArt(artUri: item.artUri),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                      child: _LyricsContent(
                        songId: item.extras?['subsonicId'] as String?,
                        artist: item.artist ?? '',
                        title: item.title,
                        position: snap!.state.position,
                        expanded: true,
                        foreground: Colors.white,
                        accentColor: accent,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Small album-art thumbnail pinned to the top-left corner of the expanded
/// lyrics sheet.
class _CornerArt extends StatelessWidget {
  const _CornerArt({required this.artUri});

  static const double _size = 88;

  final Uri? artUri;

  @override
  Widget build(BuildContext context) {
    final Widget placeholder = Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.music_note, color: Colors.white54),
    );
    final Uri? uri = artUri;
    return KeyedSubtree(
      key: const Key('lyrics-sheet-art'),
      child: uri == null
          ? placeholder
          : ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                uri.toString(),
                width: _size,
                height: _size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
              ),
            ),
    );
  }
}
