import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/storage_breakdown.dart';
import '../../theme.dart';

/// Downloads "Sync Center" storage card (DL7, DOWNLOADSSCREEN.md §5) —
/// actual on-disk usage as one stacked bar (Music/Artwork/Lyrics/Cache),
/// each segment a `heerrGradient`-family tint, with a legend below.
class StorageCard extends ConsumerWidget {
  const StorageCard({super.key});

  static const List<Color> _segmentColors = <Color>[
    heerrMagenta,
    heerrPurple,
    heerrViolet,
    Colors.white38,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final StorageBreakdown? b = ref.watch(storageBreakdownProvider).valueOrNull;
    if (b == null) return const SizedBox.shrink();

    final List<(String, int)> categories = <(String, int)>[
      ('Music', b.music),
      ('Artwork', b.artwork),
      ('Lyrics', b.lyrics),
      ('Cache', b.cache),
    ];
    final int total = categories.fold(0, (int sum, (String, int) c) => sum + c.$2);
    if (total == 0) return const SizedBox.shrink();

    final ColorScheme cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Storage',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  _humanBytes(total),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: <Widget>[
                    for (int i = 0; i < categories.length; i++)
                      if (categories[i].$2 > 0)
                        Expanded(
                          flex: categories[i].$2,
                          child: ColoredBox(color: _segmentColors[i]),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            for (int i = 0; i < categories.length; i++)
              if (categories[i].$2 > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _segmentColors[i],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(categories[i].$1)),
                      Text(
                        '${_humanBytes(categories[i].$2)} • ${(categories[i].$2 / total * 100).round()}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

String _humanBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
