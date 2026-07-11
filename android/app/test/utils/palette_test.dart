import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/providers/player/art_palette.dart';
import 'package:heerr/theme.dart';
import 'package:heerr/utils/palette.dart';

void main() {
  tearDown(() {
    dominantColorForOverride = dominantColorFor;
  });

  group('brandBlend', () {
    test('lerps the extracted colour kBrandBlend toward heerrMagenta', () {
      const Color extracted = Color(0xFF7A0018);
      expect(
        brandBlend(extracted),
        Color.lerp(extracted, heerrMagenta, kBrandBlend),
      );
    });

    test('blending the brand colour itself is a no-op', () {
      // Color.lerp works in float components — compare quantized ARGB to
      // dodge ulp-level differences from the const literal.
      expect(brandBlend(heerrMagenta).toARGB32(), heerrMagenta.toARGB32());
    });
  });

  group('artPaletteProvider', () {
    test('caches per URI — one extraction per unique cover', () async {
      int calls = 0;
      dominantColorForOverride = (Uri? _) async {
        calls++;
        return const Color(0xFF112233);
      };
      final ProviderContainer c = ProviderContainer();
      addTearDown(c.dispose);

      const String uri = 'http://navi.test/cover/1';
      final Color? first = await c.read(artPaletteProvider(uri).future);
      final Color? second = await c.read(artPaletteProvider(uri).future);
      await c.read(artPaletteProvider('http://navi.test/cover/2').future);

      expect(first, const Color(0xFF112233));
      expect(second, first);
      expect(calls, 2, reason: 'one call per unique URI, cached thereafter');
    });

    test('null extraction propagates as null (caller falls back)', () async {
      dominantColorForOverride = (Uri? _) async => null;
      final ProviderContainer c = ProviderContainer();
      addTearDown(c.dispose);

      expect(
        await c.read(artPaletteProvider('http://navi.test/x').future),
        isNull,
      );
    });
  });
}
