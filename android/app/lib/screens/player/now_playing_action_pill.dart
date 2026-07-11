part of 'now_playing_screen.dart';

/// Glass action pill (NOWPLAYING.md NP7): Queue / Lyrics / Timer / Add to
/// playlist. Consolidates what used to be split across the NP2 header kebab
/// (add-to-playlist, sleep timer) and the plain bottom-actions row (queue) —
/// single source for these actions now that they have real estate of their
/// own. The mockup's fifth "Equalizer" slot is dropped: the app has no
/// in-app equalizer feature (NOWPLAYING.md §2.2), and a decorative no-op
/// button isn't worth adding.
///
/// The Timer slot swaps to the existing [_SleepCountdownChip] (unchanged
/// widget, key, and tap behavior) once a timer is armed, rather than
/// duplicating that formatting logic.
class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.onQueueTap,
    required this.onLyricsTap,
    required this.onTimerTap,
    required this.onAddToPlaylistTap,
    required this.sleepRemaining,
  });

  final VoidCallback onQueueTap;
  final VoidCallback onLyricsTap;
  final VoidCallback onTimerTap;
  final VoidCallback onAddToPlaylistTap;
  final Duration? sleepRemaining;

  @override
  Widget build(BuildContext context) {
    final Duration? remaining = sleepRemaining;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: <Widget>[
              Expanded(
                child: _PillSlot(
                  key: const Key('now-playing-queue-button'),
                  icon: Icons.queue_music_rounded,
                  label: 'Queue',
                  onTap: onQueueTap,
                ),
              ),
              const _PillDivider(),
              Expanded(
                child: _PillSlot(
                  key: const Key('now-playing-pill-lyrics'),
                  icon: Icons.lyrics_outlined,
                  label: 'Lyrics',
                  onTap: onLyricsTap,
                ),
              ),
              const _PillDivider(),
              Expanded(
                child: remaining != null
                    ? _SleepCountdownChip(remaining: remaining)
                    : _PillSlot(
                        key: const Key('now-playing-pill-timer'),
                        icon: Icons.bedtime_outlined,
                        label: 'Timer',
                        onTap: onTimerTap,
                      ),
              ),
              const _PillDivider(),
              Expanded(
                child: _PillSlot(
                  key: const Key('now-playing-add-to-playlist'),
                  icon: Icons.playlist_add,
                  label: 'Add to playlist',
                  onTap: onAddToPlaylistTap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillDivider extends StatelessWidget {
  const _PillDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: Colors.white.withValues(alpha: 0.12),
    );
  }
}

class _PillSlot extends StatelessWidget {
  const _PillSlot({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
