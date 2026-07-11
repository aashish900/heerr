import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/subsonic_client.dart';
import 'package:heerr/models/job_view.dart';
import 'package:heerr/models/queue_response.dart';
import 'package:heerr/offline/offline_paths.dart';
import 'package:heerr/player/heerr_audio_handler.dart';
import 'package:heerr/services/lyrics_service.dart';
import 'package:heerr/player/player_provider.dart';
import 'package:heerr/player/sleep_timer.dart';
import 'package:heerr/providers/queue.dart';
import 'package:heerr/screens/player/now_playing_screen.dart';
import 'package:heerr/utils/palette.dart';
import 'package:heerr/widgets/waveform_seek_bar.dart';

class _StubQueue extends Queue {
  @override
  Future<QueueResponse> build() async {
    return const QueueResponse(active: <JobView>[], recent: <JobView>[]);
  }

  @override
  void pause() {}

  @override
  Future<void> resume() async {}
}

class _NoopAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"subsonic-response":{"status":"ok"}}',
      200,
      headers: <String, List<String>>{
        'content-type': <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

PlayerSnapshot _snap({MediaItem? item, bool playing = false}) {
  return PlayerSnapshot(
    item: item,
    state: PlaybackState(playing: playing),
  );
}

MediaItem _item() => const MediaItem(
      id: 'http://stream/1',
      title: 'Track A',
      artist: 'Artist A',
      duration: Duration(minutes: 3),
    );

Widget _wrap({Duration? sleepValue}) {
  return ProviderScope(
    overrides: <Override>[
      applicationDocumentsDirectoryProvider.overrideWith(
        (ApplicationDocumentsDirectoryRef ref) async =>
            Directory.systemTemp.createTempSync('heerr-sleep-timer-'),
      ),
      subsonicDioClientProvider.overrideWith(
        (Ref<AsyncValue<Dio>> ref) async {
          final Dio dio = Dio(BaseOptions(baseUrl: 'http://navi.test'));
          dio.httpClientAdapter = _NoopAdapter();
          return dio;
        },
      ),
      lyricsServiceProvider.overrideWith((LyricsServiceRef ref) async {
        final Dio subsonic = await ref.watch(subsonicDioClientProvider.future);
        final Dio lrcLib = Dio(BaseOptions(baseUrl: 'http://navi.test'));
        lrcLib.httpClientAdapter = _NoopAdapter();
        return LyricsService(subsonic, lrcLibDio: lrcLib);
      }),
      playerSnapshotProvider.overrideWith(
        (Ref<AsyncValue<PlayerSnapshot>> ref) =>
            Stream<PlayerSnapshot>.value(_snap(item: _item())),
      ),
      playerQueueProvider.overrideWith(
        (Ref<AsyncValue<List<MediaItem>>> ref) =>
            Stream<List<MediaItem>>.value(<MediaItem>[]),
      ),
      currentMediaItemProvider.overrideWith(
        (Ref<AsyncValue<MediaItem?>> ref) =>
            Stream<MediaItem?>.value(_item()),
      ),
      queueProvider.overrideWith(_StubQueue.new),
    ],
    child: MaterialApp(
      home: _SleepValueSeeder(
        seed: sleepValue,
        child: const NowPlayingScreen(),
      ),
    ),
  );
}

/// Wraps the screen so we can prime `sleepTimerNotifierProvider` to a
/// specific remaining-time value before the first frame.
class _SleepValueSeeder extends ConsumerStatefulWidget {
  const _SleepValueSeeder({required this.child, this.seed});
  final Widget child;
  final Duration? seed;

  @override
  ConsumerState<_SleepValueSeeder> createState() => _SleepValueSeederState();
}

class _SleepValueSeederState extends ConsumerState<_SleepValueSeeder> {
  @override
  void initState() {
    super.initState();
    final Duration? seed = widget.seed;
    if (seed != null) {
      // Read once to instantiate; then directly set state via the
      // notifier's public API.
      ref
          .read(sleepTimerNotifierProvider.notifier)
          .setDuration(seed);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

void main() {
  setUp(() {
    paletteExtractorOverride = (Uri? _) async => null;
    heroArtFloatEnabled = false;
    waveformSeekBarAnimateEnabled = false;
  });
  tearDown(() {
    paletteExtractorOverride = dominantColorFor;
    heroArtFloatEnabled = true;
    waveformSeekBarAnimateEnabled = true;
  });

  testWidgets('countdown chip is absent when timer is idle',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('now-playing-sleep-chip')), findsNothing);
  });

  testWidgets('countdown chip is visible and shows formatted time when active',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(sleepValue: const Duration(minutes: 15)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('now-playing-sleep-chip')), findsOneWidget);
    expect(find.text('15:00'), findsOneWidget);
  });

  testWidgets(
      'Timer pill slot opens the bottom sheet with the preset list',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('now-playing-pill-timer')));
    await tester.tap(find.byKey(const Key('now-playing-pill-timer')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sleep-timer-15')), findsOneWidget);
    expect(find.byKey(const Key('sleep-timer-30')), findsOneWidget);
    expect(find.byKey(const Key('sleep-timer-45')), findsOneWidget);
    expect(find.byKey(const Key('sleep-timer-60')), findsOneWidget);
    expect(find.byKey(const Key('sleep-timer-custom')), findsOneWidget);
    // Off tile hidden when no timer is active.
    expect(find.byKey(const Key('sleep-timer-off')), findsNothing);
  });

  testWidgets('tap "15 minutes" sets the timer and closes the sheet',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('now-playing-pill-timer')));
    await tester.tap(find.byKey(const Key('now-playing-pill-timer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sleep-timer-15')));
    await tester.pumpAndSettle();

    // Sheet closed.
    expect(find.byKey(const Key('sleep-timer-15')), findsNothing);
    // Chip now visible with the right value.
    expect(find.byKey(const Key('now-playing-sleep-chip')), findsOneWidget);
    expect(find.text('15:00'), findsOneWidget);
  });

  testWidgets('Off tile appears when active and cancels the timer',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(sleepValue: const Duration(minutes: 30)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('now-playing-sleep-chip')), findsOneWidget);

    // Timer is armed, so the pill slot itself is the chip — tap it directly.
    await tester.ensureVisible(find.byKey(const Key('now-playing-sleep-chip')));
    await tester.tap(find.byKey(const Key('now-playing-sleep-chip')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sleep-timer-off')), findsOneWidget);

    // Off tile may be below the fold in the small test viewport — scroll
    // it into view before tapping.
    await tester.ensureVisible(find.byKey(const Key('sleep-timer-off')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sleep-timer-off')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('now-playing-sleep-chip')), findsNothing);
  });
}
