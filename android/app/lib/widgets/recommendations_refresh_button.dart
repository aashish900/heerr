import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/recommendations.dart';

/// Refresh affordance for the recommendations feed (#38).
///
/// Idle: a bare white [IconButton] like every other AppBar/header icon.
/// While [recommendationsProvider] is loading: swaps to a tonal disc
/// ([IconButton.filledTonal]) with the icon spinning — the tint *is* the
/// busy indicator, appearing on tap and fading back once the new picks
/// land. Taps during the fetch are no-ops (the busy variant's handler does
/// nothing), so the button is never `onPressed: null` and never grey-flashes
/// through the M3 disabled style.
class RecommendationsRefreshButton extends ConsumerStatefulWidget {
  const RecommendationsRefreshButton({
    super.key,
    this.tooltip = 'New recommendations',
    this.onBeforeRefresh,
  });

  final String tooltip;

  /// Invoked just before the refresh fires — e.g. Home's Discover fallback
  /// also invalidates the random-songs provider.
  final VoidCallback? onBeforeRefresh;

  @override
  ConsumerState<RecommendationsRefreshButton> createState() =>
      _RecommendationsRefreshButtonState();
}

class _RecommendationsRefreshButtonState
    extends ConsumerState<RecommendationsRefreshButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _fire() {
    if (ref.read(recommendationsProvider).isLoading) return; // race guard
    widget.onBeforeRefresh?.call();
    ref.read(recommendationsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final bool busy = ref.watch(
      recommendationsProvider.select((AsyncValue<Object?> s) => s.isLoading),
    );
    if (busy) {
      if (!_spin.isAnimating) _spin.repeat();
    } else if (_spin.isAnimating) {
      // Finish the current turn instead of snapping back to 0.
      _spin.forward(from: _spin.value);
    }

    final Widget icon =
        RotationTransition(turns: _spin, child: const Icon(Icons.refresh));

    if (busy) {
      return IconButton.filledTonal(
        key: const Key('recs-refresh-busy'),
        icon: icon,
        tooltip: widget.tooltip,
        // Deliberate no-op: keeps the tonal tint (a null onPressed would
        // grey the disc via the disabled style) while swallowing re-taps.
        onPressed: () {},
      );
    }
    return IconButton(
      icon: icon,
      tooltip: widget.tooltip,
      onPressed: _fire,
    );
  }
}
