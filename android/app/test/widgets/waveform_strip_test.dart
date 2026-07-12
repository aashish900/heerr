import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/widgets/waveform_strip.dart';

// DL2 (Downloads "Sync Center" hero): WaveformStrip.progress turns the
// decorative strip into a sync-progress indicator without touching the
// existing decorative-only call sites (progress defaults to null).

Future<void> _pump(WidgetTester tester, WaveformStrip strip) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SizedBox(width: 200, child: strip)),
    ),
  );
}

void main() {
  testWidgets('renders with progress unset (default decorative behaviour)',
      (WidgetTester tester) async {
    await _pump(tester, const WaveformStrip());
    await tester.pump();
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('renders at progress 0.0, 0.5 and 1.0 without throwing',
      (WidgetTester tester) async {
    for (final double p in <double>[0.0, 0.5, 1.0]) {
      await _pump(tester, WaveformStrip(progress: p));
      await tester.pump();
      expect(find.byType(CustomPaint), findsWidgets);
    }
  });

  testWidgets('updating progress on an existing strip does not throw',
      (WidgetTester tester) async {
    await _pump(tester, const WaveformStrip(progress: 0.2));
    await tester.pump();
    await _pump(tester, const WaveformStrip(progress: 0.8));
    await tester.pump();
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
