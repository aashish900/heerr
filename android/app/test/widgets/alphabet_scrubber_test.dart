import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/widgets/alphabet_scrubber.dart';

void main() {
  group('letterForDy', () {
    test('top of the strip is the # bucket', () {
      expect(AlphabetScrubber.letterForDy(0, 270), '#');
    });

    test('bottom of the strip clamps to Z', () {
      expect(AlphabetScrubber.letterForDy(269.9, 270), 'Z');
      expect(AlphabetScrubber.letterForDy(500, 270), 'Z');
      expect(AlphabetScrubber.letterForDy(-10, 270), '#');
    });

    test('proportional mid-strip mapping', () {
      // 27 buckets over 270px → 10px each; dy=105 → bucket 10 → 'J'.
      expect(AlphabetScrubber.letterForDy(105, 270), 'J');
    });

    test('zero height degrades to the first bucket', () {
      expect(AlphabetScrubber.letterForDy(10, 0), '#');
    });
  });

  group('scrubTargetIndex', () {
    const List<String> names = <String>[
      '1999', // # bucket
      'Abbey Road',
      'After Hours',
      'Currents',
      'Starboy',
    ];

    test('exact bucket match returns the first entry of the bucket', () {
      expect(scrubTargetIndex(names, 'A'), 1);
      expect(scrubTargetIndex(names, 'C'), 3);
      expect(scrubTargetIndex(names, '#'), 0);
    });

    test('empty bucket falls through to the next existing one', () {
      expect(scrubTargetIndex(names, 'B'), 3); // no B → Currents
      expect(scrubTargetIndex(names, 'D'), 4); // no D..R → Starboy
    });

    test('bucket past the last entry lands at the end', () {
      expect(scrubTargetIndex(names, 'Z'), names.length - 1);
    });

    test('empty list returns null', () {
      expect(scrubTargetIndex(const <String>[], 'A'), isNull);
    });

    test('case-insensitive first letters', () {
      expect(scrubTargetIndex(const <String>['abbey', 'beta'], 'B'), 1);
    });
  });

  group('AlphabetScrubber widget', () {
    testWidgets('tap fires onLetter with the mapped bucket',
        (WidgetTester tester) async {
      final List<String> received = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 24,
            height: 270,
            child: AlphabetScrubber(onLetter: received.add),
          ),
        ),
      ));

      // Tap near the top → '#'.
      await tester.tapAt(tester
          .getTopLeft(find.byKey(const Key('alphabet-scrubber')))
          .translate(10, 2));
      expect(received, <String>['#']);

      // Drag to the bottom → ends on 'Z'.
      await tester.drag(
          find.byKey(const Key('alphabet-scrubber')), const Offset(0, 260));
      expect(received.last, 'Z');
    });

    testWidgets('renders all 27 buckets', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 24,
            height: 400,
            child: AlphabetScrubber(onLetter: (_) {}),
          ),
        ),
      ));
      expect(find.text('#'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('Z'), findsOneWidget);
    });
  });
}
