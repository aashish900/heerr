import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/profile.dart';
import 'package:heerr/providers/profiles/active_profile.dart';
import 'package:heerr/providers/profiles/profile_avatar.dart';

Profile _profile(String id) => Profile(
      id: id,
      displayName: 'user-$id',
      heerrBaseUrl: 'http://h',
      heerrBearerToken: 't',
      navidromeBaseUrl: 'http://n',
      navidromeUsername: 'u-$id',
      navidromePassword: 'p',
      createdAt: DateTime.utc(2026),
      lastUsedAt: DateTime.utc(2026),
    );

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('avatar_test');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  ProviderContainer container({Profile? active}) {
    final ProviderContainer c = ProviderContainer(overrides: <Override>[
      avatarsDirProvider.overrideWith((_) async => tmp),
      activeProfileProvider.overrideWithValue(active),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('no active profile → null; setAvatar is a no-op', () async {
    final ProviderContainer c = container();
    expect(await c.read(profileAvatarProvider.future), isNull);
    await c
        .read(profileAvatarProvider.notifier)
        .setAvatar(Uint8List.fromList(<int>[1, 2, 3]));
    expect(tmp.listSync(), isEmpty);
  });

  test('setAvatar writes a file and build finds it again', () async {
    final ProviderContainer c = container(active: _profile('a'));
    await c
        .read(profileAvatarProvider.notifier)
        .setAvatar(Uint8List.fromList(<int>[9, 9, 9]));

    final File? file = await c.read(profileAvatarProvider.future);
    expect(file, isNotNull);
    expect(file!.existsSync(), isTrue);
    expect(file.readAsBytesSync(), <int>[9, 9, 9]);

    // Fresh container (cold start) re-discovers the same avatar from disk.
    final ProviderContainer c2 = container(active: _profile('a'));
    final File? again = await c2.read(profileAvatarProvider.future);
    expect(again, isNotNull);
    expect(again!.readAsBytesSync(), <int>[9, 9, 9]);
  });

  test('changing the avatar removes the previous file (fresh path)', () async {
    final ProviderContainer c = container(active: _profile('a'));
    final ProfileAvatar notifier = c.read(profileAvatarProvider.notifier);

    await notifier.setAvatar(Uint8List.fromList(<int>[1]));
    final File? first = await c.read(profileAvatarProvider.future);
    await notifier.setAvatar(Uint8List.fromList(<int>[2]));
    final File? second = await c.read(profileAvatarProvider.future);

    expect(second!.path, isNot(first!.path),
        reason: 'a new path defeats FileImage caching');
    expect(first.existsSync(), isFalse, reason: 'old file cleaned up');
    expect(
      tmp.listSync().whereType<File>(),
      hasLength(1),
    );
  });

  test('removeAvatar deletes the file and state goes null', () async {
    final ProviderContainer c = container(active: _profile('a'));
    final ProfileAvatar notifier = c.read(profileAvatarProvider.notifier);
    await notifier.setAvatar(Uint8List.fromList(<int>[1]));

    await notifier.removeAvatar();

    expect(await c.read(profileAvatarProvider.future), isNull);
    expect(
      tmp.listSync().whereType<File>(),
      isEmpty,
    );
  });

  test('rejects images over kMaxAvatarBytes', () async {
    final ProviderContainer c = container(active: _profile('a'));
    await expectLater(
      c
          .read(profileAvatarProvider.notifier)
          .setAvatar(Uint8List(kMaxAvatarBytes + 1)),
      throwsA(isA<AvatarTooLargeError>()),
    );
    expect(tmp.listSync().whereType<File>(), isEmpty);
  });

  test('avatars are keyed per profile id', () async {
    final ProviderContainer cA = container(active: _profile('a'));
    await cA
        .read(profileAvatarProvider.notifier)
        .setAvatar(Uint8List.fromList(<int>[1]));

    final ProviderContainer cB = container(active: _profile('b'));
    expect(await cB.read(profileAvatarProvider.future), isNull);

    // Removing b's (absent) avatar must not touch a's file.
    await cB.read(profileAvatarProvider.notifier).removeAvatar();
    final ProviderContainer cA2 = container(active: _profile('a'));
    expect(await cA2.read(profileAvatarProvider.future), isNotNull);
  });
}
