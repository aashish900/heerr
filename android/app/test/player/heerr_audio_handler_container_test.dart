import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';

import 'package:heerr/player/heerr_audio_handler.dart';
import 'package:heerr/providers/library/library_albums.dart';
import 'package:heerr/providers/profiles/profile_registry.dart';
import 'package:heerr/providers/secure_storage.dart';
import 'package:heerr/providers/server_creds.dart';

import '../support/cred_test_support.dart';

class _MockAudioPlayer extends Mock implements AudioPlayer {}

class _FakeStorage implements SecureStorage {
  _FakeStorage(this.data);
  final Map<String, String> data;
  Future<void>? gate;
  Object? readError;

  @override
  Future<String?> read(String key) async {
    await gate;
    if (readError != null) throw readError!;
    return data[key];
  }

  @override
  Future<void> write(String key, String value) async => data[key] = value;

  @override
  Future<void> delete(String key) async => data.remove(key);
}

void main() {
  late HeerrAudioHandler handler;

  setUp(() {
    final player = _MockAudioPlayer();
    when(
      () => player.playbackEventStream,
    ).thenAnswer((_) => const Stream<PlaybackEvent>.empty());
    when(
      () => player.currentIndexStream,
    ).thenAnswer((_) => const Stream<int?>.empty());
    handler = HeerrAudioHandler(player: player);
  });

  ProviderContainer containerWith(_FakeStorage storage) {
    final c = ProviderContainer(
      overrides: [secureStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(c.dispose);
    return c;
  }

  _FakeStorage storageWithProfile() => _FakeStorage({
    kProfilesIndexKey: jsonEncode({
      'profiles': [testProfile(id: 'p1').toJson()],
    }),
    kActiveProfileIdKey: 'p1',
  });

  test('whenReady waits until a container is attached', () async {
    var done = false;
    final ready = handler.whenReady().then((c) {
      done = true;
      return c;
    });
    await Future<void>.delayed(Duration.zero);
    expect(done, isFalse);

    final c = containerWith(storageWithProfile());
    handler.attachContainer(c);
    expect(await ready, same(c));
  });

  test(
    'whenReady resolves only after the profile registry has loaded',
    () async {
      final storage = storageWithProfile();
      final gate = Completer<void>();
      storage.gate = gate.future;
      final c = containerWith(storage);
      handler.attachContainer(c);

      var done = false;
      final ready = handler.whenReady().then((_) => done = true);
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse, reason: 'registry still reading secure storage');

      gate.complete();
      await ready;
      expect(c.read(serverCredsProvider).navidromeUsername, 'me');
    },
  );

  test(
    'whenReady surfaces a secure-storage failure instead of hanging',
    () async {
      final storage = storageWithProfile()..readError = StateError('keystore');
      handler.attachContainer(containerWith(storage));
      await expectLater(handler.whenReady(), throwsA(isA<StateError>()));
    },
  );

  test('attaching twice keeps the first container', () async {
    final first = containerWith(storageWithProfile());
    final second = containerWith(storageWithProfile());
    handler.attachContainer(first);
    handler.attachContainer(second);
    expect(await handler.whenReady(), same(first));
  });

  group('getChildren', () {
    test('waits for the container, then serves the root tabs', () async {
      final f = handler.getChildren('root');
      handler.attachContainer(containerWith(storageWithProfile()));
      expect((await f).map((i) => i.id).first, 'recents');
    });

    test('unknown parent ids give an empty list', () async {
      handler.attachContainer(containerWith(storageWithProfile()));
      expect(await handler.getChildren('recent'), isEmpty);
      expect(await handler.getChildren('bogus'), isEmpty);
    });

    test('a failing provider gives an empty list, not an exception', () async {
      final c = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storageWithProfile()),
          libraryAlbumsProvider.overrideWith((ref) async => throw StateError('x')),
        ],
      );
      addTearDown(c.dispose);
      handler.attachContainer(c);
      expect(await handler.getChildren('albums'), isEmpty);
    });
  });
}
