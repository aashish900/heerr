part of 'settings_screen.dart';

class _RecommendationsSection extends ConsumerStatefulWidget {
  const _RecommendationsSection();

  @override
  ConsumerState<_RecommendationsSection> createState() =>
      _RecommendationsSectionState();
}

class _RecommendationsSectionState
    extends ConsumerState<_RecommendationsSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<RecommendHealth> async =
        ref.watch(recommendHealthNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            'Recommendations',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
        async.when(
          loading: () => const ListTile(
            leading: Icon(Icons.recommend_outlined),
            title: Text('Engine health'),
            subtitle: Text('Checking…'),
          ),
          error: (Object e, _) => ListTile(
            leading: const Icon(Icons.recommend_outlined),
            title: const Text('Engine health'),
            subtitle: Text(
              'Could not reach backend — check token in Servers.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
          data: (RecommendHealth h) {
            final bool degraded = h.status != 'ok';
            return Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.recommend_outlined),
                  title: Text('Engine: ${h.engine}'),
                  subtitle: Row(
                    children: <Widget>[
                      _StatusChip(degraded: degraded),
                      if (h.fallbackActive) ...<Widget>[
                        const SizedBox(width: 8),
                        const _FallbackBadge(),
                      ],
                    ],
                  ),
                  trailing: degraded
                      ? IconButton(
                          key: const Key('settings-recommend-help'),
                          icon: Icon(
                            _expanded
                                ? Icons.expand_less
                                : Icons.help_outline,
                          ),
                          tooltip: 'Why is this degraded?',
                          onPressed: () => setState(() {
                            _expanded = !_expanded;
                          }),
                        )
                      : null,
                ),
                if (degraded && _expanded)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
                    child: Text(
                      h.fallbackActive
                          ? 'Primary engine probe failed; '
                              'recommendations are running on the fallback. '
                              'Check your API key (Last.fm / ListenBrainz) '
                              'or wait for the upstream service to recover.'
                          : 'No engine in the chain is reachable. Check '
                              'the backend logs and your credentials.',
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.degraded});

  final bool degraded;

  @override
  Widget build(BuildContext context) {
    final Color colour = degraded ? Colors.amber : heerrGreen;
    return Chip(
      key: Key(degraded ? 'engine-chip-degraded' : 'engine-chip-ok'),
      avatar: Icon(
        degraded ? Icons.warning_amber_outlined : Icons.check_circle_outline,
        color: colour,
        size: 18,
      ),
      label: Text(
        degraded ? 'Degraded' : 'OK',
        style: TextStyle(color: colour, fontWeight: FontWeight.w500),
      ),
      backgroundColor: colour.withValues(alpha: 0.12),
      side: BorderSide(color: colour.withValues(alpha: 0.4)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _FallbackBadge extends StatelessWidget {
  const _FallbackBadge();

  @override
  Widget build(BuildContext context) {
    return Chip(
      key: const Key('engine-chip-fallback-active'),
      avatar: const Icon(Icons.shuffle, size: 16),
      label: const Text('Fallback active'),
      backgroundColor:
          Theme.of(context).colorScheme.surfaceContainerHighest,
      visualDensity: VisualDensity.compact,
    );
  }
}
