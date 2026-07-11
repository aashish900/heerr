import 'dart:ui' show Color;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../utils/palette.dart';

part 'art_palette.g.dart';

/// Cached dominant-colour extraction for a cover-art URI (Part B —
/// HOMESCREEN.md §7 task B1).
///
/// Family keyed by the art URI string; keep-alive so each unique cover is
/// decoded + quantised exactly once per app session (palette extraction
/// decodes the whole image — that's the expensive step). Family keying also
/// kills the stale-response race the MiniPlayer used to guard by hand: a
/// late completion for an old URI lands in that URI's own provider entry
/// and can't clobber the current track's tint.
///
/// `null` = no extractable colour (fetch failed / bland cover) — callers
/// fall back to a brand colour.
@Riverpod(keepAlive: true)
Future<Color?> artPalette(ArtPaletteRef ref, String artUri) {
  return dominantColorForOverride(Uri.tryParse(artUri));
}
