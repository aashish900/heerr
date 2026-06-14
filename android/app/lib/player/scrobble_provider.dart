import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api/subsonic_client.dart';
import '../api/subsonic_endpoints.dart';
import 'player_provider.dart';
import 'scrobble_controller.dart';

part 'scrobble_provider.g.dart';

/// Boots a [ScrobbleController] wired to the running [HeerrAudioHandler] +
/// the Subsonic dio client. Keep-alive so it survives screen rebuilds and
/// tracks every play across the session.
///
/// Read once at the root of the widget tree (see `HeerrApp.build`) to
/// trigger the subscription chain. The provider exposes nothing the UI
/// needs — its work is purely the side-effecting controller it owns. The
/// `Future<void>` shape lets the keep-alive scope clean up the controller
/// via `ref.onDispose`.
@Riverpod(keepAlive: true)
Future<void> scrobble(ScrobbleRef ref) async {
  final Dio dio = await ref.watch(subsonicDioClientProvider.future);
  final handler = ref.watch(audioHandlerProvider);

  final ScrobbleController controller = ScrobbleController(
    mediaItemStream: handler.mediaItem.stream,
    positionStream: handler.player.positionStream,
    scrobble: (String id, {required bool submission}) async {
      await dio.get<dynamic>(
        SubsonicEndpoints.scrobble,
        queryParameters: <String, dynamic>{
          'id': id,
          'submission': submission.toString(),
        },
      );
    },
  );
  controller.start();
  ref.onDispose(() {
    // Fire-and-forget dispose; the controller's cancels are awaitable but
    // Riverpod's onDispose is sync. The stream cancels complete quickly.
    controller.dispose();
  });
}
