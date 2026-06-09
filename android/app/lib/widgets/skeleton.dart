import 'package:flutter/material.dart';

/// A low-contrast rectangular placeholder used to compose skeleton screens
/// while a fetch is in flight. Picks `surfaceContainerHighest` from the
/// active scheme so the box reads as "structure, no content" on the dark
/// M3 background — clearly different from both data and error states.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    required this.width,
    required this.height,
    this.borderRadius = 4,
    super.key,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// One skeleton row that mimics the search-result / queue-job tile shape:
/// 56×56 leading cover + 2 text lines.
class SkeletonTile extends StatelessWidget {
  const SkeletonTile({super.key});

  @override
  Widget build(BuildContext context) {
    return const ListTile(
      leading: SkeletonBox(width: 56, height: 56),
      title: SkeletonBox(width: 180, height: 12),
      subtitle: Padding(
        padding: EdgeInsets.only(top: 6),
        child: SkeletonBox(width: 120, height: 10),
      ),
    );
  }
}

/// A scrollable list of [SkeletonTile]s. Used as the loading state for both
/// the search results list and the queue list.
class SkeletonList extends StatelessWidget {
  const SkeletonList({this.count = 5, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: count,
      itemBuilder: (BuildContext _, int _) => const SkeletonTile(),
    );
  }
}
