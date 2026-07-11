import 'package:flutter/widgets.dart';
import 'package:palette_generator/palette_generator.dart';

import '../theme.dart';

/// Part B adaptive-theming constants (HOMESCREEN.md §7) — single source of
/// truth for the art-driven chrome on the hero card + MiniPlayer.
///
/// Fraction to lerp an extracted cover colour toward the brand magenta.
const double kBrandBlend = 0.18;

/// Blur sigma for the hero card's stretched-art backdrop.
const double kArtBackdropBlur = 24.0;

/// Accent-colour cross-fade on track change.
const Duration kTintTransition = Duration(milliseconds: 400);

/// Blend an extracted cover colour toward the brand palette so every
/// album's accent "feels heerr" without touching the artwork itself.
Color brandBlend(Color extracted) =>
    Color.lerp(extracted, heerrMagenta, kBrandBlend)!;

/// Module-scope test seam for [dominantColorFor] consumers that go through
/// `artPaletteProvider` — swap with a deterministic fake so widget tests
/// don't hit the network / `palette_generator`. (Not `@visibleForTesting`:
/// the provider reads it in production as its default implementation.)
Future<Color?> Function(Uri? artUri) dominantColorForOverride =
    dominantColorFor;

/// Extract a tasteful tint colour from the cover art at [artUri]. Returns
/// `null` when:
///   * [artUri] is null,
///   * the network fetch fails (404, TLS, timeout),
///   * `PaletteGenerator` finds no dominant / vibrant colour worth using.
///
/// Failure is silent on purpose — Now Playing falls back to the default
/// M3 dark surface, which is correct UX rather than a broken tint.
///
/// Preference order favours an actual *hue* over a big bland area, so even
/// covers whose largest region is near-black still yield a visible tint:
///   1. `vibrantColor` (saturated, lively — best on dark M3 surfaces).
///   2. `lightVibrantColor` / `darkVibrantColor` (still saturated).
///   3. `mutedColor` (some colour beats none).
///   4. `dominantColor` (just-the-biggest-area, may be bland).
///   5. `null` (caller uses theme default).
Future<Color?> dominantColorFor(Uri? artUri) async {
  if (artUri == null) return null;
  try {
    final PaletteGenerator p = await PaletteGenerator.fromImageProvider(
      NetworkImage(artUri.toString()),
      size: const Size(80, 80),
      maximumColorCount: 12,
    );
    return p.vibrantColor?.color ??
        p.lightVibrantColor?.color ??
        p.darkVibrantColor?.color ??
        p.mutedColor?.color ??
        p.dominantColor?.color;
  } catch (_) {
    return null;
  }
}
