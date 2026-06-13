import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/widgets/playlist_dialogs.dart';

/// Mount the [Dialog] under test via a `Builder` so we have a concrete
/// `BuildContext` ancestor that owns the `Navigator` — same pattern as
/// the other dialog widget tests in the repo. We pump it inside a
/// `ProviderScope` so the `ConsumerStatefulWidget`s find a Riverpod
/// container at the root.
Future<T?> _showVia<T>(
  WidgetTester tester,
  Future<T?> Function(BuildContext) opener,
) async {
  T? result;
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await opener(context);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  group('CreatePlaylistDialog', () {
    testWidgets('empty name disables the Create button',
        (WidgetTester tester) async {
      await _showVia<String>(
        tester,
        (BuildContext c) => CreatePlaylistDialog.show(c),
      );

      final Finder createBtn = find.widgetWithText(FilledButton, 'Create');
      expect(createBtn, findsOneWidget);
      expect(tester.widget<FilledButton>(createBtn).onPressed, isNull);
    });

    testWidgets('whitespace-only name keeps Create disabled',
        (WidgetTester tester) async {
      await _showVia<String>(
        tester,
        (BuildContext c) => CreatePlaylistDialog.show(c),
      );
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();

      final FilledButton btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Create'),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('non-empty name enables Create + submit returns trimmed value',
        (WidgetTester tester) async {
      String? captured;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (BuildContext context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      captured = await CreatePlaylistDialog.show(context);
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '  Morning Coffee  ');
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(captured, 'Morning Coffee');
    });

    testWidgets('Cancel resolves to null', (WidgetTester tester) async {
      bool resolved = false;
      String? captured;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (BuildContext context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      captured = await CreatePlaylistDialog.show(context);
                      resolved = true;
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(resolved, isTrue);
      expect(captured, isNull);
    });
  });

  group('RenamePlaylistDialog', () {
    testWidgets('seeds the name field with initialName', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (BuildContext context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => RenamePlaylistDialog.show(
                      context,
                      initialName: 'Morning Coffee',
                      initialPublic: false,
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Morning Coffee'), findsOneWidget);
    });

    testWidgets(
      'initialPublic: true seeds the checkbox ticked; submit returns it',
      (WidgetTester tester) async {
        RenamePlaylistResult? captured;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Builder(
                builder: (BuildContext context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        captured = await RenamePlaylistDialog.show(
                          context,
                          initialName: 'X',
                          initialPublic: true,
                        );
                      },
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // CheckboxListTile renders a Checkbox internally.
        final CheckboxListTile tile = tester.widget<CheckboxListTile>(
          find.byType(CheckboxListTile),
        );
        expect(tile.value, isTrue);

        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();

        expect(captured, isNotNull);
        expect(captured!.name, 'X');
        expect(captured!.makePublic, isTrue);
      },
    );

    testWidgets(
      'empty name disables Save',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Builder(
                builder: (BuildContext context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => RenamePlaylistDialog.show(
                        context,
                        initialName: '',
                        initialPublic: false,
                      ),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        final FilledButton btn = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Save'),
        );
        expect(btn.onPressed, isNull);
      },
    );

    testWidgets('toggling the checkbox flips makePublic', (
      WidgetTester tester,
    ) async {
      RenamePlaylistResult? captured;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (BuildContext context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      captured = await RenamePlaylistDialog.show(
                        context,
                        initialName: 'X',
                        initialPublic: false,
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.makePublic, isTrue);
    });

    testWidgets('Cancel resolves to null', (WidgetTester tester) async {
      RenamePlaylistResult? captured;
      bool resolved = false;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (BuildContext context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      captured = await RenamePlaylistDialog.show(
                        context,
                        initialName: 'X',
                        initialPublic: false,
                      );
                      resolved = true;
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(resolved, isTrue);
      expect(captured, isNull);
    });
  });
}
