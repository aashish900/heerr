import 'package:flutter/material.dart';

import '../theme.dart';

/// Full-width pill button filled with the heerr magenta→purple→violet
/// [heerrGradient] — the app's primary CTA per the redesign reference
/// (e.g. the Profile screen's Save). Black bold label on the bright
/// gradient for contrast, mirroring [ColorScheme.onPrimary].
///
/// A drop-in visual replacement for a [FilledButton]: same `onPressed` /
/// `child` contract, disabled state when `onPressed` is null.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.gradient = heerrGradient,
    this.height = 48,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Gradient gradient;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: enabled ? gradient : null,
        color: enabled ? null : const Color(0xFF2E2E2E),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: SizedBox(
        height: height,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(height / 2),
            onTap: onPressed,
            child: Center(
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  color: enabled ? Colors.black : const Color(0xFF808080),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
