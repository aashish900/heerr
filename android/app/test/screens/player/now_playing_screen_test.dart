import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:heerr/api/subsonic_client.dart';
import 'package:heerr/models/job_view.dart';
import 'package:heerr/models/podcast_channel.dart';
import 'package:heerr/models/queue_response.dart';
import 'package:heerr/offline/offline_paths.dart';
import 'package:heerr/player/heerr_audio_handler.dart';
import 'package:heerr/services/backend_service.dart';
import 'package:heerr/services/lyrics_service.dart';
import 'package:heerr/player/player_provider.dart';
import 'package:heerr/providers/queue.dart';
import 'package:heerr/screens/player/now_playing_screen.dart';
import 'package:heerr/utils/palette.dart';
import 'package:heerr/widgets/waveform_seek_bar.dart';

// Static counters so the (transient) provider instance can report into the
// test without us having to fish it back out via ProviderContainer.
int _pauseCalls = 0;
int _resumeCalls = 0;

class _StubQueue extends Queue {
  @override
  Future<QueueResponse> build() async {
    return const QueueResponse(active: <JobView>[], recent: <JobView>[]);
  }

  @override
  void pause() {
    _pauseCalls++;
  }

  @override
  Future<void> resume() async {
    _resumeCalls++;
  }
}

// Noop HTTP adapter so the always-visible lyrics section gets a fast empty
// response rather than hitting the network or blocking on real settings.
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

MediaItem _item({
  String id = 'http://stream/1',
  String title = 'Track A',
  String artist = 'Artist A',
  Duration duration = const Duration(minutes: 3, seconds: 30),
}) {
  return MediaItem(
    id: id,
    title: title,
    artist: artist,
    duration: duration,
  );
}

/// PR2 (#53): an episode `MediaItem`, distinguished from [_item] by the
/// `episodeId`/`channelId` extras `episode_to_media_item.dart` stamps on
/// every episode it builds.
MediaItem _episodeItem({
  String id = 'http://backend/podcasts/episodes/e1/audio',
  String title = 'Episode 1',
  Duration duration = const Duration(minutes: 10),
  String episodeId = 'e1',
  String channelId = 'c1',
}) {
  return MediaItem(
    id: id,
    title: title,
    duration: duration,
    extras: <String, dynamic>{'episodeId': episodeId, 'channelId': channelId},
  );
}

/// PR2 (#53): stub `BackendService` so `_PodcastShowLink`'s
/// `podcastSubscriptionsProvider` watch resolves without a real network call.
class _StubBackend extends BackendService {
  _StubBackend({this.channel}) : super(Dio());

  final PodcastChannel? channel;

  @override
  Future<List<PodcastChannel>> podcastSubscriptions() async =>
      channel == null ? const <PodcastChannel>[] : <PodcastChannel>[channel!];
}

/// #35: queue-mutation tests need a real handler behind the rows' swipe /
/// drag / tap gestures. Everything is stubbed via mocktail.
class _StubHandler extends Mock implements HeerrAudioHandler {}

Widget _wrap({
  required PlayerSnapshot snapshot,
  List<MediaItem> queue = const <MediaItem>[],
  HeerrAudioHandler? handler,
  List<Override> extraOverrides = const <Override>[],
}) {
  return ProviderScope(
    overrides: <Override>[
      // Always-visible lyrics section: stub the full lyrics service stack so
      // no real HTTP calls are made and lyricsForProvider resolves fast.
      applicationDocumentsDirectoryProvider.overrideWith(
        (ApplicationDocumentsDirectoryRef ref) async =>
            Directory.systemTemp.createTempSync('heerr-np-screen-'),
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
      if (handler != null) audioHandlerProvider.overrideWithValue(handler),
      playerSnapshotProvider.overrideWith(
        (Ref<AsyncValue<PlayerSnapshot>> ref) =>
            Stream<PlayerSnapshot>.value(snapshot),
      ),
      playerQueueProvider.overrideWith(
        (Ref<AsyncValue<List<MediaItem>>> ref) =>
            Stream<List<MediaItem>>.value(queue),
      ),
      currentMediaItemProvider.overrideWith(
        (Ref<AsyncValue<MediaItem?>> ref) =>
            Stream<MediaItem?>.value(snapshot.item),
      ),
      queueProvider.overrideWith(_StubQueue.new),
      ...extraOverrides,
    ],
    child: const MaterialApp(home: NowPlayingScreen()),
  );
}

void main() {
  setUp(() {
    _pauseCalls = 0;
    _resumeCalls = 0;
    paletteExtractorOverride = (Uri? _) async => null; // deterministic, no I/O
    heroArtFloatEnabled = false; // repeating controller never settles
    waveformSeekBarAnimateEnabled = false;
  });

  tearDown(() {
    paletteExtractorOverride = dominantColorFor;
    heroArtFloatEnabled = true;
    waveformSeekBarAnimateEnabled = true;
  });

  testWidgets('"Nothing is playing" when snapshot has no item',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(snapshot: _snap()));
    await tester.pumpAndSettle();
    expect(find.text('Nothing is playing.'), findsOneWidget);
  });

  testWidgets('renders title, artist, duration, and play icon when paused',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      snapshot: _snap(item: _item(), playing: false),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Track A'), findsWidgets);
    expect(find.text('Artist A'), findsOneWidget);
    // duration 3:30
    expect(find.text('3:30'), findsOneWidget);
    // paused → play glyph on the centre filled-circle transport button.
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsNothing);
  });

  testWidgets('renders pause icon when playing',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      snapshot: _snap(item: _item(), playing: true),
    ));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
  });

  testWidgets('renders queue items with current track marked',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final MediaItem a = _item(id: 'http://s/1', title: 'Track A');
    final MediaItem b = _item(id: 'http://s/2', title: 'Track B');
    await tester.pumpWidget(_wrap(
      snapshot: _snap(item: a, playing: true),
      queue: <MediaItem>[a, b],
    ));
    await tester.pumpAndSettle();

    // Open the queue sheet via the bottom-bar queue button.
    await tester.ensureVisible(find.byKey(const Key('now-playing-queue-button')));
    await tester.tap(find.byKey(const Key('now-playing-queue-button')));
    await tester.pumpAndSettle();

    expect(find.text('Track A'), findsWidgets);
    expect(find.text('Track B'), findsOneWidget);
    // The current track gets the equalizer icon.
    expect(find.byIcon(Icons.equalizer), findsOneWidget);
    // NP9 — sectioned sheet: "Now Playing" (Track A) + "Next Up" (Track B).
    // Scoped to the sheet — the header (NP2) has its own static "NOW
    // PLAYING" label elsewhere on screen.
    final Finder sheet = find.byKey(const Key('now-playing-queue-sheet'));
    expect(find.descendant(of: sheet, matching: find.text('NOW PLAYING')),
        findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('NEXT UP')),
        findsOneWidget);
  });

  // NP9 — when the current track isn't first, everything before it renders
  // dimmed with no section header ("earlier" — cheaper than a third
  // "History" section per NOWPLAYING.md).
  testWidgets('items before the current track render with no section header',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final MediaItem a = _item(id: 'http://s/1', title: 'Track A');
    final MediaItem b = _item(id: 'http://s/2', title: 'Track B');
    final MediaItem c = _item(id: 'http://s/3', title: 'Track C');
    await tester.pumpWidget(_wrap(
      snapshot: _snap(item: b, playing: true),
      queue: <MediaItem>[a, b, c],
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('now-playing-queue-button')));
    await tester.tap(find.byKey(const Key('now-playing-queue-button')));
    await tester.pumpAndSettle();

    expect(find.text('Track A'), findsOneWidget);
    // Track B is current — also rendered as the big hero title, hence
    // findsWidgets rather than findsOneWidget (mirrors the pattern in
    // "renders queue items with current track marked" above).
    expect(find.text('Track B'), findsWidgets);
    expect(find.text('Track C'), findsOneWidget);
    final Finder sheet = find.byKey(const Key('now-playing-queue-sheet'));
    expect(find.descendant(of: sheet, matching: find.text('NOW PLAYING')),
        findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('NEXT UP')),
        findsOneWidget);
    // No third "History"/"Earlier" header — just the dimmed row.
    expect(find.text('EARLIER'), findsNothing);
    expect(find.text('HISTORY'), findsNothing);
    // Track A (earlier) has no drag handle; only Track C (Next Up) does.
    expect(find.byIcon(Icons.drag_handle), findsOneWidget);
  });

  group('queue edit (#35)', () {
    late _StubHandler handler;

    setUp(() {
      handler = _StubHandler();
      when(() => handler.removeQueueItemAt(any())).thenAnswer((_) async {});
      when(() => handler.moveQueueItem(any(), any()))
          .thenAnswer((_) async {});
    });

    Future<void> pumpQueue(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final MediaItem a = _item(id: 'http://s/1', title: 'Track A');
      final MediaItem b = _item(id: 'http://s/2', title: 'Track B');
      final MediaItem c = _item(id: 'http://s/3', title: 'Track C');
      await tester.pumpWidget(_wrap(
        snapshot: _snap(item: a, playing: true),
        queue: <MediaItem>[a, b, c],
        handler: handler,
      ));
      await tester.pumpAndSettle();
      // Open queue sheet before interacting with rows.
      await tester.ensureVisible(find.byKey(const Key('now-playing-queue-button')));
      await tester.tap(find.byKey(const Key('now-playing-queue-button')));
      await tester.pumpAndSettle();
    }

    // NP9 — the "Now Playing" row (Track A here) is neither draggable nor
    // dismissible; only the "Next Up" rows (Track B, Track C) get a handle.
    testWidgets('only Next Up rows render drag handles',
        (WidgetTester tester) async {
      await pumpQueue(tester);
      expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));
    });

    testWidgets('swipe-to-dismiss removes the row at its index',
        (WidgetTester tester) async {
      await pumpQueue(tester);
      await tester.drag(find.text('Track B'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      verify(() => handler.removeQueueItemAt(1)).called(1);
    });

    testWidgets(
        'dragging a Next Up handle reorders via moveQueueItem (real queue indices)',
        (WidgetTester tester) async {
      await pumpQueue(tester);
      // Track A (current) has no handle; .first is Track B's. Row height
      // ~56px; drag it down past Track C.
      await tester.timedDrag(
        find.byIcon(Icons.drag_handle).first,
        const Offset(0, 70),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();
      final List<dynamic> args = verify(
        () => handler.moveQueueItem(captureAny(), captureAny()),
      ).captured;
      // Track B is real queue index 1, Track C is real queue index 2 —
      // the local Next Up sub-list index (0) is offset by currentIndex + 1.
      expect(args[0], 1);
      expect(args[1], 2);
    });
  });

  testWidgets('empty queue → "Queue is empty"',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      snapshot: _snap(item: _item(), playing: false),
      queue: const <MediaItem>[],
    ));
    await tester.pumpAndSettle();

    // Open the queue sheet.
    await tester.ensureVisible(find.byKey(const Key('now-playing-queue-button')));
    await tester.tap(find.byKey(const Key('now-playing-queue-button')));
    await tester.pumpAndSettle();

    expect(find.text('Queue is empty.'), findsOneWidget);
  });

  testWidgets('scrubber shows elapsed/total labels for the item duration',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(
      snapshot: _snap(
        item: _item(duration: const Duration(seconds: 200)),
        playing: false,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(WaveformSeekBar), findsOneWidget);
    expect(find.text('3:20'), findsOneWidget);
  });

  testWidgets('snapshot stream loading → CircularProgressIndicator',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          playerSnapshotProvider.overrideWith(
            (Ref<AsyncValue<PlayerSnapshot>> ref) =>
                Stream<PlayerSnapshot>.fromFuture(
                    Completer<PlayerSnapshot>().future),
          ),
          queueProvider.overrideWith(_StubQueue.new),
        ],
        child: const MaterialApp(home: NowPlayingScreen()),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // K1.2 — palette tint
  testWidgets(
    'paints a gradient surface when palette extractor returns a colour',
    (WidgetTester tester) async {
      paletteExtractorOverride =
          (Uri? _) async => const Color(0xFFAB47BC); // purple-ish
      await tester.pumpWidget(_wrap(
        snapshot: _snap(
          item: _item(id: 'http://stream/x'),
          playing: false,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(DecoratedBox), findsWidgets);
    },
  );

  testWidgets('does NOT crash when palette extractor returns null',
      (WidgetTester tester) async {
    paletteExtractorOverride = (Uri? _) async => null;
    await tester.pumpWidget(_wrap(
      snapshot: _snap(item: _item(), playing: false),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Track A'), findsWidgets);
  });

  // K1.3 — lifecycle
  testWidgets('pauses queueProvider on mount and resumes on dispose',
      (WidgetTester tester) async {
    expect(_pauseCalls, 0);
    expect(_resumeCalls, 0);

    final ValueNotifier<bool> showPlayer = ValueNotifier<bool>(true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          applicationDocumentsDirectoryProvider.overrideWith(
            (ApplicationDocumentsDirectoryRef ref) async =>
                Directory.systemTemp.createTempSync('heerr-np-lifecycle-'),
          ),
          subsonicDioClientProvider.overrideWith(
            (Ref<AsyncValue<Dio>> ref) async {
              final Dio dio = Dio(BaseOptions(baseUrl: 'http://navi.test'));
              dio.httpClientAdapter = _NoopAdapter();
              return dio;
            },
          ),
          lyricsServiceProvider.overrideWith((LyricsServiceRef ref) async {
            final Dio subsonic =
                await ref.watch(subsonicDioClientProvider.future);
            final Dio lrcLib = Dio(BaseOptions(baseUrl: 'http://navi.test'));
            lrcLib.httpClientAdapter = _NoopAdapter();
            return LyricsService(subsonic, lrcLibDio: lrcLib);
          }),
          playerSnapshotProvider.overrideWith(
            (Ref<AsyncValue<PlayerSnapshot>> ref) =>
                Stream<PlayerSnapshot>.value(
                  _snap(item: _item(), playing: true),
                ),
          ),
          playerQueueProvider.overrideWith(
            (Ref<AsyncValue<List<MediaItem>>> ref) =>
                Stream<List<MediaItem>>.value(const <MediaItem>[]),
          ),
          currentMediaItemProvider.overrideWith(
            (Ref<AsyncValue<MediaItem?>> ref) =>
                Stream<MediaItem?>.value(_item()),
          ),
          queueProvider.overrideWith(_StubQueue.new),
        ],
        child: MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: showPlayer,
            builder: (BuildContext c, bool show, _) =>
                show ? const NowPlayingScreen() : const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_pauseCalls, 1);
    expect(_resumeCalls, 0);

    showPlayer.value = false;
    await tester.pumpAndSettle();
    expect(_resumeCalls, 1);
  });

  // NP2 — glass header chevron replaces BackButton; same maybePop behavior.
  testWidgets('collapse button pops the route',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          applicationDocumentsDirectoryProvider.overrideWith(
            (ApplicationDocumentsDirectoryRef ref) async =>
                Directory.systemTemp.createTempSync('heerr-np-collapse-'),
          ),
          subsonicDioClientProvider.overrideWith(
            (Ref<AsyncValue<Dio>> ref) async {
              final Dio dio = Dio(BaseOptions(baseUrl: 'http://navi.test'));
              dio.httpClientAdapter = _NoopAdapter();
              return dio;
            },
          ),
          lyricsServiceProvider.overrideWith((LyricsServiceRef ref) async {
            final Dio subsonic =
                await ref.watch(subsonicDioClientProvider.future);
            final Dio lrcLib = Dio(BaseOptions(baseUrl: 'http://navi.test'));
            lrcLib.httpClientAdapter = _NoopAdapter();
            return LyricsService(subsonic, lrcLibDio: lrcLib);
          }),
          playerSnapshotProvider.overrideWith(
            (Ref<AsyncValue<PlayerSnapshot>> ref) =>
                Stream<PlayerSnapshot>.value(
                  _snap(item: _item(), playing: false),
                ),
          ),
          playerQueueProvider.overrideWith(
            (Ref<AsyncValue<List<MediaItem>>> ref) =>
                Stream<List<MediaItem>>.value(const <MediaItem>[]),
          ),
          currentMediaItemProvider.overrideWith(
            (Ref<AsyncValue<MediaItem?>> ref) =>
                Stream<MediaItem?>.value(_item()),
          ),
          queueProvider.overrideWith(_StubQueue.new),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NowPlayingScreen(),
                    ),
                  ),
                  child: const Text('open player'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open player'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('now-playing-collapse')), findsOneWidget);

    await tester.tap(find.byKey(const Key('now-playing-collapse')));
    await tester.pumpAndSettle();
    expect(find.text('open player'), findsOneWidget);
    expect(find.byKey(const Key('now-playing-collapse')), findsNothing);
  });

  group('PR2 podcast player (#53)', () {
    List<Override> episodeOverrides({PodcastChannel? channel}) {
      return <Override>[
        backendServiceProvider.overrideWith(
          (BackendServiceRef ref) async => _StubBackend(channel: channel),
        ),
      ];
    }

    testWidgets(
        'renders the podcast layout: title, plain scrubber, skip±30s, '
        'speed pill — no waveform/lyrics/add-to-playlist',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        snapshot: _snap(item: _episodeItem(), playing: false),
        extraOverrides: episodeOverrides(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Episode 1'), findsWidgets);
      expect(find.byKey(const Key('now-playing-podcast-scrubber')),
          findsOneWidget);
      expect(find.byType(WaveformSeekBar), findsNothing);
      expect(find.byKey(const Key('now-playing-podcast-skip-back')),
          findsOneWidget);
      expect(find.byKey(const Key('now-playing-podcast-skip-forward')),
          findsOneWidget);
      expect(find.byKey(const Key('now-playing-podcast-speed')),
          findsOneWidget);
      expect(find.text('1x'), findsOneWidget);
      expect(find.byKey(const Key('now-playing-pill-lyrics')), findsNothing);
      expect(find.byKey(const Key('now-playing-add-to-playlist')),
          findsNothing);
      expect(find.byKey(const Key('now-playing-queue-button')),
          findsOneWidget);
    });

    testWidgets('shows the show name link for the episode\'s channel',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        snapshot: _snap(item: _episodeItem(), playing: false),
        extraOverrides: episodeOverrides(
          channel: const PodcastChannel(
            id: 'c1',
            feedUrl: 'https://a.com/f.xml',
            title: 'Darknet Diaries',
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Darknet Diaries'), findsOneWidget);
    });

    testWidgets('tapping skip-back/forward calls the handler',
        (WidgetTester tester) async {
      final _StubHandler handler = _StubHandler();
      when(() => handler.skipBack30()).thenAnswer((_) async {});
      when(() => handler.skipForward30()).thenAnswer((_) async {});

      await tester.pumpWidget(_wrap(
        snapshot: _snap(item: _episodeItem(), playing: false),
        handler: handler,
        extraOverrides: episodeOverrides(),
      ));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
          find.byKey(const Key('now-playing-podcast-skip-back')));
      await tester.tap(find.byKey(const Key('now-playing-podcast-skip-back')));
      await tester
          .tap(find.byKey(const Key('now-playing-podcast-skip-forward')));
      await tester.pumpAndSettle();

      verify(() => handler.skipBack30()).called(1);
      verify(() => handler.skipForward30()).called(1);
    });

    testWidgets('speed pill opens a picker; selecting a speed calls setSpeed',
        (WidgetTester tester) async {
      final _StubHandler handler = _StubHandler();
      when(() => handler.setSpeed(any())).thenAnswer((_) async {});

      await tester.pumpWidget(_wrap(
        snapshot: _snap(item: _episodeItem(), playing: false),
        handler: handler,
        extraOverrides: episodeOverrides(),
      ));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
          find.byKey(const Key('now-playing-podcast-speed')));
      await tester.tap(find.byKey(const Key('now-playing-podcast-speed')));
      await tester.pumpAndSettle();

      expect(find.text('Playback speed'), findsOneWidget);
      await tester.tap(find.byKey(const Key('now-playing-speed-1.5x')));
      await tester.pumpAndSettle();

      verify(() => handler.setSpeed(1.5)).called(1);
    });
  });
}
