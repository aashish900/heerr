import 'package:flutter/material.dart';

import 'library_cover_art.dart';

/// Horizontal section: bold header + horizontal-scroll row of
/// square cover-art cards. Used for "Jump back in", "Most played", and any
/// other Album/Playlist horizontal section on the Home screen.
class HomeSection extends StatelessWidget {
  const HomeSection({
    required this.title,
    required this.items,
    super.key,
  });

  final String title;
  final List<HomeSectionItem> items;

  static const double _kCardSize = 140;
  static const double _kCardSpacing = 12;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(title, style: tt.titleLarge),
          ),
          SizedBox(
            height: _kCardSize + 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: _kCardSpacing),
              itemBuilder: (BuildContext context, int i) {
                return _HomeSectionCard(
                  item: items[i],
                  size: _kCardSize,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One row in [HomeSection]. Caller supplies cover-art id + title + tap
/// handler; an optional subtitle (e.g. artist name) is rendered below.
class HomeSectionItem {
  const HomeSectionItem({
    required this.title,
    required this.coverArtId,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String? coverArtId;
  final VoidCallback onTap;
}

class _HomeSectionCard extends StatelessWidget {
  const _HomeSectionCard({required this.item, required this.size});

  final HomeSectionItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final TextTheme tt = Theme.of(context).textTheme;
    final ColorScheme cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: item.onTap,
      child: SizedBox(
        width: size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LibraryCoverArt(
                coverArtId: item.coverArtId,
                size: size,
                borderRadius: 0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (item.subtitle != null)
              Text(
                item.subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}
