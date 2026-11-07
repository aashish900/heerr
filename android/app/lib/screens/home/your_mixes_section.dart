import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/mix.dart';
import '../../providers/mixes.dart';
import '../../router.dart' show Routes;
import '../../theme.dart';

/// Icon + cover gradient for a vibe tile (and the mix screen's header cover).
/// Gradients only use the three brand colours from `theme.dart`.
typedef VibeStyle = ({IconData icon, LinearGradient gradient});

const List<List<Color>> _kPairs = <List<Color>>[
  <Color>[heerrMagenta, heerrPurple],
  <Color>[heerrPurple, heerrViolet],
  <Color>[heerrViolet, heerrMagenta],
  <Color>[heerrMagenta, heerrViolet],
];

const Map<String, IconData> _kIcons = <String, IconData>{
  'chill': Icons.local_cafe_outlined,
  'feel-good': Icons.wb_sunny_outlined,
  'party': Icons.celebration_outlined,
  'romance': Icons.favorite_border,
  'heartbreak': Icons.heart_broken_outlined,
  'workout': Icons.fitness_center,
  'focus': Icons.center_focus_strong_outlined,
  'sleep': Icons.bedtime_outlined,
};

VibeStyle vibeStyle(String id) {
  final List<String> ids = _kIcons.keys.toList();
  final int i = ids.indexOf(id);
  final List<Color> pair = _kPairs[(i < 0 ? 0 : i) % _kPairs.length];
  return (
    icon: _kIcons[id] ?? Icons.graphic_eq,
    gradient: LinearGradient(
      colors: pair,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );
}

/// Home "Your Mixes" shelf (Phase MX), below For You: one square gradient
/// tile per backend vibe in a sideways-scrolling row; a tap opens the mix.
/// Hidden while loading, on error and when the backend lists no vibes.
class YourMixesSection extends ConsumerWidget {
  const YourMixesSection({super.key});

  static const double _kTile = 132;
  static const double _kGap = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<MixVibe> vibes =
        ref.watch(mixVibesProvider).valueOrNull ?? const <MixVibe>[];
    if (vibes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Text(
            'Your Mixes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: <Widget>[
              for (int i = 0; i < vibes.length; i++)
                Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : _kGap),
                  child: _VibeTile(vibe: vibes[i], size: _kTile),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VibeTile extends StatelessWidget {
  const _VibeTile({required this.vibe, required this.size});

  final MixVibe vibe;
  final double size;

  @override
  Widget build(BuildContext context) {
    final VibeStyle style = vibeStyle(vibe.id);
    return SizedBox(
      key: const ValueKey<String>('mix-tile'),
      width: size,
      height: size,
      child: Material(
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(gradient: style.gradient),
          child: InkWell(
            onTap: () => context.push(Routes.mix(vibe.id)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(style.icon, color: Colors.white, size: 28),
                  const Spacer(),
                  Text(
                    vibe.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
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
