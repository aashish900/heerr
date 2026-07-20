import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/subsonic/song.dart';
import 'package:heerr/player/now_playing_persistence.dart';
import 'package:heerr/player/now_playing_snapshot.dart';
import 'package:heerr/player/now_playing_store.dart';

void main() {
  late Directory tmp;
  late NowPlayingStore store;
  late StreamController<void> trigger;
  late NowPlayingPersistence persistence;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('heerr_npp_');
    store = NowPlayingStore(File('${tmp.path}/now_playing.json'));
    trigger = StreamController<void>.broadcast();
    persistence = NowPlayingPersistence(
      store: store,
      debounce: const Duration(milliseconds: 20),
    );
  });

  tearDown(() async {
    await persistence.dispose();
    await trigger.close();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  NowPlayingSnapshot makeSnapshot({
    String title = 'A',
    int positionMs = 1000,
    int updatedAt = 1_700_000_000_000,
  }) =>
      NowPlayingSnapshot(
        songs: <Song>[Song(id: 'so-1', title: title)],
        currentIndex: 0,
        positionMs: positionMs,
        updatedAt: updatedAt,
      );

  test('debounced save fires once for a burst of trigger events', () async {
    int builds = 0;
    persistence.start(
      trigger: trigger.stream,
      build: () {
        builds++;
        return makeSnapshot(positionMs: builds * 100);
      },
    );

    trigger.add(null);
    trigger.add(null);
    trigger.add(null);

    // Wait past the 20ms debounce.
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(builds, 1, reason: 'three events collapse into one debounced save');
    final NowPlayingSnapshot? saved = await store.load();
    expect(saved, isNotNull);
    expect(saved!.positionMs, 100);
  });

  test('flush bypasses debounce and writes immediately', () async {
    int builds = 0;
    persistence.start(
      trigger: trigger.stream,
      build: () {
        builds++;
        return makeSnapshot(positionMs: 42);
      },
    );

    await persistence.flush();

    expect(builds, 1);
    final NowPlayingSnapshot? saved = await store.load();
    expect(saved, isNotNull);
    expect(saved!.positionMs, 42);
  });

  test('flush cancels a pending debounced save', () async {
    int builds = 0;
    persistence.start(
      trigger: trigger.stream,
      build: () {
        builds++;
        return makeSnapshot(positionMs: builds);
      },
    );

    trigger.add(null);
    // Let the listener schedule the debounced timer (microtask delivery).
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(builds, 0, reason: 'still within the 20ms debounce window');

    // Immediately flush — the scheduled timer should be cancelled and
    // flush itself does one build.
    await persistence.flush();
    expect(builds, 1);

    // Wait long enough that the *originally scheduled* debounce would
    // otherwise have fired. It must not — flush cancelled it.
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(builds, 1, reason: 'flush cancelled the scheduled save');
  });

  test('dispose cancels pending saves and stops listening', () async {
    int builds = 0;
    persistence.start(
      trigger: trigger.stream,
      build: () {
        builds++;
        return makeSnapshot();
      },
    );
    trigger.add(null);
    await persistence.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    // Further trigger events must be ignored.
    trigger.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(builds, 0);
  });

  test(
      'dispose() waits for a write already in flight from the debounce '
      'firing before returning', () async {
    // Regression test for a CI flake: the debounce timer fires and starts
    // NowPlayingStore.save() (write .tmp → rename), but dispose() used to
    // return immediately without waiting for that write. A caller that
    // tears down resources the write depends on right after dispose()
    // (this suite's tearDown deletes `tmp`) could then race the in-flight
    // rename and throw PathNotFoundException. Uses a gated fake store so
    // the race is deterministic rather than timing-dependent.
    final Completer<void> gate = Completer<void>();
    bool writeCompleted = false;
    final _GatedStore gatedStore = _GatedStore(
      store.file,
      gate.future,
      onDone: () => writeCompleted = true,
    );
    final NowPlayingPersistence gatedPersistence = NowPlayingPersistence(
      store: gatedStore,
      debounce: const Duration(milliseconds: 5),
    );
    gatedPersistence.start(trigger: trigger.stream, build: makeSnapshot);
    trigger.add(null);
    // Let the debounce timer fire so the (gated) write actually starts.
    await Future<void>.delayed(const Duration(milliseconds: 20));

    bool disposed = false;
    final Future<void> disposeFuture =
        gatedPersistence.dispose().then((_) => disposed = true);

    // The write is still gated shut — dispose() must still be waiting.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(disposed, isFalse,
        reason: 'dispose() returned before the in-flight write finished');
    expect(writeCompleted, isFalse);

    gate.complete();
    await disposeFuture;
    expect(disposed, isTrue);
    expect(writeCompleted, isTrue);
  });

  test('builder throws → save skipped, no file written, no crash', () async {
    persistence.start(
      trigger: trigger.stream,
      build: () => throw StateError('boom'),
    );
    await persistence.flush();
    expect(await store.load(), isNull);
  });

  test('save failure is swallowed (best-effort)', () async {
    // Path under a file (not a directory) — `parent.create(recursive: true)`
    // can't create a directory under an existing file, so save throws and
    // the persistence layer must swallow.
    final File blocker = File('${tmp.path}/blocker');
    await blocker.writeAsString('not a directory');
    final NowPlayingStore badStore =
        NowPlayingStore(File('${blocker.path}/inside/file.json'));
    final NowPlayingPersistence badPersistence = NowPlayingPersistence(
      store: badStore,
      debounce: const Duration(milliseconds: 5),
    );
    badPersistence.start(
      trigger: trigger.stream,
      build: () => makeSnapshot(),
    );
    // Must not throw.
    await badPersistence.flush();
    await badPersistence.dispose();
  });

  test('start replaces previous subscription + builder', () async {
    int firstBuilds = 0;
    int secondBuilds = 0;
    persistence.start(
      trigger: trigger.stream,
      build: () {
        firstBuilds++;
        return makeSnapshot(positionMs: 1);
      },
    );
    final StreamController<void> trigger2 =
        StreamController<void>.broadcast();
    persistence.start(
      trigger: trigger2.stream,
      build: () {
        secondBuilds++;
        return makeSnapshot(positionMs: 2);
      },
    );

    // Emit on the *old* trigger — should be ignored.
    trigger.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(firstBuilds, 0);
    expect(secondBuilds, 0);

    // Emit on the new trigger — should fire.
    trigger2.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(secondBuilds, 1);

    await trigger2.close();
  });
}

/// A [NowPlayingStore] whose `save()` blocks on [_gate] before delegating
/// to the real implementation — lets a test deterministically hold a write
/// "in flight" instead of racing real timers/IO.
class _GatedStore extends NowPlayingStore {
  _GatedStore(super.file, this._gate, {required void Function() onDone})
      // ignore: prefer_initializing_formals
      : _onDone = onDone;

  final Future<void> _gate;
  final void Function() _onDone;

  @override
  Future<void> save(NowPlayingSnapshot snapshot) async {
    await _gate;
    await super.save(snapshot);
    _onDone();
  }
}
