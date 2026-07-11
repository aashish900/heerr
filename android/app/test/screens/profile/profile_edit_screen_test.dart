import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/profile.dart';
import 'package:heerr/providers/prefs_storage.dart';
import 'package:heerr/providers/profiles/active_profile.dart';
import 'package:heerr/providers/profiles/profile_avatar.dart';
import 'package:heerr/providers/profiles/profile_image_picker.dart';
import 'package:heerr/providers/profiles/profile_registry.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/screens/profile/profile_edit_screen.dart';
import 'package:heerr/utils/word_limit.dart';

class _FakeKv implements SecureStorage, PrefsStorage {
  final Map<String, String> store = <String, String>{};
  @override
  Future<String?> read(String key) async => store[key];
  @override
  Future<void> write(String key, String value) async => store[key] = value;
  @override
  Future<void> delete(String key) async => store.remove(key);
}

Profile _profile() => Profile(
      id: 'p1',
      displayName: 'Alice',
      heerrBaseUrl: 'http://h',
      heerrBearerToken: 't',
      navidromeBaseUrl: 'http://n',
      navidromeUsername: 'alice-nd',
      navidromePassword: 'pw',
      createdAt: DateTime.utc(2026),
      lastUsedAt: DateTime.utc(2026),
    );

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('profile_edit'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Widget wrap(
    _FakeKv kv, {
    Uint8List? pickResult,
  }) {
    // Seed the registry index so updateDisplayName finds the profile.
    kv.store[kProfilesIndexKey] = jsonEncode(<String, Object?>{
      'profiles': <Map<String, dynamic>>[_profile().toJson()],
    });
    return ProviderScope(
      overrides: <Override>[
        secureStorageProvider.overrideWith((Ref<SecureStorage> _) => kv),
        prefsStorageProvider.overrideWithValue(kv),
        activeProfileProvider.overrideWithValue(_profile()),
        avatarsDirProvider.overrideWith((_) async => tmp),
        profileImagePickerProvider.overrideWithValue(() async => pickResult),
      ],
      child: const MaterialApp(home: ProfileEditScreen()),
    );
  }

  testWidgets('renders placeholder avatar + name prefilled + empty extras',
      (WidgetTester tester) async {
    final _FakeKv kv = _FakeKv();
    await tester.pumpWidget(wrap(kv));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.text('Add photo'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(const Key('profile-name'))).controller!.text,
      'Alice',
    );
    expect(
      tester.widget<TextField>(find.byKey(const Key('profile-nickname'))).controller!.text,
      isEmpty,
    );
    expect(
      tester.widget<TextField>(find.byKey(const Key('profile-bio'))).controller!.text,
      isEmpty,
    );
  });

  testWidgets('save persists name to registry + nickname/bio to meta',
      (WidgetTester tester) async {
    final _FakeKv kv = _FakeKv();
    await tester.pumpWidget(wrap(kv));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('profile-name')), 'Alice Cooper');
    await tester.enterText(find.byKey(const Key('profile-nickname')), 'Al');
    await tester.enterText(find.byKey(const Key('profile-bio')), 'hi there');
    await tester.scrollUntilVisible(
        find.byKey(const Key('profile-save')), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('profile-save')));
    await tester.pumpAndSettle();

    expect(find.text('Profile saved'), findsOneWidget);
    expect(kv.store[kProfilesIndexKey], contains('Alice Cooper'));
    expect(kv.store['profile_meta_p1'], contains('Al'));
    expect(kv.store['profile_meta_p1'], contains('hi there'));
  });

  testWidgets('blank name falls back to the Navidrome username on save',
      (WidgetTester tester) async {
    final _FakeKv kv = _FakeKv();
    await tester.pumpWidget(wrap(kv));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('profile-name')), '   ');
    await tester.scrollUntilVisible(
        find.byKey(const Key('profile-save')), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('profile-save')));
    await tester.pumpAndSettle();

    expect(kv.store[kProfilesIndexKey], contains('alice-nd'));
  });

  testWidgets('bio input is blocked past 100 words',
      (WidgetTester tester) async {
    final _FakeKv kv = _FakeKv();
    await tester.pumpWidget(wrap(kv));
    await tester.pumpAndSettle();

    final String hundred =
        List<String>.generate(100, (int i) => 'w$i').join(' ');
    await tester.enterText(find.byKey(const Key('profile-bio')), hundred);
    expect(
      countWords(tester
          .widget<TextField>(find.byKey(const Key('profile-bio')))
          .controller!
          .text),
      100,
    );

    await tester.enterText(
        find.byKey(const Key('profile-bio')), '$hundred onemore');
    expect(
      countWords(tester
          .widget<TextField>(find.byKey(const Key('profile-bio')))
          .controller!
          .text),
      lessThanOrEqualTo(100),
    );
  });

  testWidgets('pick photo via sheet sets the avatar',
      (WidgetTester tester) async {
    final _FakeKv kv = _FakeKv();
    await tester.pumpWidget(
        wrap(kv, pickResult: Uint8List.fromList(<int>[1, 2, 3])));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profile-avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-pic-pick')));
    await tester.pumpAndSettle();

    expect(tmp.listSync().whereType<File>(), hasLength(1));
    expect(find.text('Edit photo'), findsOneWidget);
  });

  testWidgets('remove photo via sheet deletes the avatar',
      (WidgetTester tester) async {
    final _FakeKv kv = _FakeKv();
    await tester.pumpWidget(
        wrap(kv, pickResult: Uint8List.fromList(<int>[1, 2, 3])));
    await tester.pumpAndSettle();

    // Set one first.
    await tester.tap(find.byKey(const Key('profile-avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-pic-pick')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profile-avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-pic-remove')));
    await tester.pumpAndSettle();

    expect(tmp.listSync().whereType<File>(), isEmpty);
    expect(find.text('Add photo'), findsOneWidget);
  });

  testWidgets('oversize pick shows the too-large snackbar, keeps no file',
      (WidgetTester tester) async {
    final _FakeKv kv = _FakeKv();
    await tester
        .pumpWidget(wrap(kv, pickResult: Uint8List(kMaxAvatarBytes + 1)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profile-avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-pic-pick')));
    await tester.pumpAndSettle();

    expect(find.textContaining('too large'), findsOneWidget);
    expect(tmp.listSync().whereType<File>(), isEmpty);
  });
}
