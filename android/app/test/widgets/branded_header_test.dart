import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/profile_meta.dart';
import 'package:heerr/providers/profiles/profile_meta.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/widgets/branded_header.dart';

class _NoopStorage implements SecureStorage {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

class _StubMeta extends ProfileMetaNotifier {
  _StubMeta(this._nickname);
  final String? _nickname;

  @override
  Future<ProfileMeta> build() async => ProfileMeta(nickname: _nickname);
}

Widget _wrap({required bool compactGreeting, String? nickname}) {
  return ProviderScope(
    overrides: <Override>[
      secureStorageProvider.overrideWithValue(_NoopStorage()),
      profileMetaNotifierProvider.overrideWith(() => _StubMeta(nickname)),
    ],
    child: MaterialApp(
      home: Scaffold(
        appBar: BrandedAppBar(
          compactGreeting: compactGreeting,
          actions: const <Widget>[Icon(Icons.science)],
        ),
      ),
    ),
  );
}

void main() {
  group('BrandedAppBar', () {
    testWidgets('default title is the full logo (wordmark, no greeting)',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(compactGreeting: false, nickname: 'Al'));
      await tester.pumpAndSettle();
      expect(find.text('heerr'), findsOneWidget);
      expect(find.textContaining('Good '), findsNothing);
    });

    testWidgets('compact greeting shows two lines with the nickname',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(compactGreeting: true, nickname: 'Al'));
      await tester.pumpAndSettle();
      // Line 1 ends with a comma; line 2 is nickname + wave.
      expect(find.textContaining(RegExp(r'^Good .*,$')), findsOneWidget);
      expect(find.text('Al \u{1F44B}'), findsOneWidget);
      // No wordmark in compact mode.
      expect(find.text('heerr'), findsNothing);
    });

    testWidgets('compact greeting without nickname is a single line, no wave',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(compactGreeting: true, nickname: null));
      await tester.pumpAndSettle();
      expect(find.textContaining(RegExp(r'^Good [a-z]+$')), findsOneWidget);
      expect(find.textContaining('\u{1F44B}'), findsNothing);
    });

    testWidgets('renders extra actions plus queue shortcut and avatar',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(compactGreeting: false, nickname: null));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.science), findsOneWidget);
      expect(find.byIcon(Icons.queue_music_outlined), findsOneWidget);
      expect(find.byKey(const Key('home-profile-avatar')), findsOneWidget);
    });
  });
}
