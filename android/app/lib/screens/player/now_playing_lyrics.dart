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
  });

  final String? songId;
  final String artist;
  final String title;

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
