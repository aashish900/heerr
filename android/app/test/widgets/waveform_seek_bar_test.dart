import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/widgets/waveform_seek_bar.dart';

/// NOWPLAYING.md NP5 — waveform seek bar replacing the Material [Slider].
void main() {
  setUp(() => waveformSeekBarAnimateEnabled = false);
  tearDown(() => waveformSeekBarAnimateEnabled = true);

  Widget wrap({
    required Duration position,
    required Duration duration,
    ValueChanged<Duration>? onSeekStart,
    ValueChanged<Duration>? onSeekUpdate,
    ValueChanged<Duration>? onSeekEnd,
    bool animate = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          child: WaveformSeekBar(
            position: position,
            duration: duration,
            onSeekStart: onSeekStart ?? (_) {},
            onSeekUpdate: onSeekUpdate ?? (_) {},
            onSeekEnd: onSeekEnd ?? (_) {},
            animate: animate,
            seed: 1,
          ),
        ),
      ),
    );
  }

  testWidgets('renders elapsed and total time labels',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap(
      position: const Duration(seconds: 67),
      duration: const Duration(minutes: 3, seconds: 50),
    ));
    await tester.pumpAndSettle();
    expect(find.text('1:07'), findsOneWidget);
    expect(find.text('3:50'), findsOneWidget);
  });

  testWidgets('exposes slider semantics', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(wrap(
      position: const Duration(seconds: 30),
      duration: const Duration(seconds: 200),
    ));
    await tester.pumpAndSettle();
    final Finder semantics = find.byWidgetPredicate(
      (Widget w) => w is Semantics && w.properties.slider == true,
    );
    expect(
      tester.getSemantics(semantics),
      matchesSemantics(
        isSlider: true,
        value: '0:30',
        increasedValue: '0:40',
        decreasedValue: '0:20',
        textDirection: TextDirection.ltr,
        // GestureDetector auto-attaches these from onTapUp / the horizontal
        // drag callbacks — real, not something to suppress.
        hasTapAction: true,
        hasScrollLeftAction: true,
        hasScrollRightAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('tap seeks to the tapped fraction of the bar',
      (WidgetTester tester) async {
    Duration? started;
    Duration? ended;
    await tester.pumpWidget(wrap(
      position: Duration.zero,
      duration: const Duration(seconds: 200),
      onSeekStart: (Duration d) => started = d,
      onSeekEnd: (Duration d) => ended = d,
    ));
    await tester.pumpAndSettle();

    // Tap at the horizontal midpoint of the 300px-wide bar → ~50%.
    await tester.tapAt(tester.getCenter(find.byKey(const Key('waveform-seek-bar-track'))));
    await tester.pumpAndSettle();

    expect(started, isNotNull);
    expect(ended, isNotNull);
    expect(ended!.inSeconds, closeTo(100, 5));
  });

  testWidgets('drag reports monotonic seek-update progress then a final seek',
      (WidgetTester tester) async {
    final List<Duration> updates = <Duration>[];
    Duration? ended;
    await tester.pumpWidget(wrap(
      position: Duration.zero,
      duration: const Duration(seconds: 200),
      onSeekUpdate: updates.add,
      onSeekEnd: (Duration d) => ended = d,
    ));
    await tester.pumpAndSettle();

    final Offset start = tester.getTopLeft(find.byKey(const Key('waveform-seek-bar-track'))) +
        const Offset(10, 20);
    final TestGesture gesture = await tester.startGesture(start);
    for (int i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(updates.length, greaterThanOrEqualTo(2));
    for (int i = 1; i < updates.length; i++) {
      expect(updates[i].inMilliseconds,
          greaterThanOrEqualTo(updates[i - 1].inMilliseconds));
    }
    expect(ended, isNotNull);
  });

  testWidgets('zero duration disables gestures entirely',
      (WidgetTester tester) async {
    bool fired = false;
    await tester.pumpWidget(wrap(
      position: Duration.zero,
      duration: Duration.zero,
      onSeekStart: (_) => fired = true,
      onSeekEnd: (_) => fired = true,
    ));
    await tester.pumpAndSettle();

    await tester.tapAt(tester.getCenter(find.byKey(const Key('waveform-seek-bar-track'))));
    await tester.pumpAndSettle();
    expect(fired, isFalse);
  });

  testWidgets('animate:true bar-breathing does not block pumpAndSettle when the flag is disabled',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap(
      position: const Duration(seconds: 30),
      duration: const Duration(seconds: 200),
      animate: true,
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('waveform-seek-bar-track')), findsOneWidget);
  });
}
