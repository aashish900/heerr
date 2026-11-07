import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/mix.dart';
import '../models/recommended_track.dart';
import '../models/seed_track.dart';
import '../services/backend_service.dart';
import 'recommendations.dart';

part 'mixes.g.dart';

/// Songs requested per mix — the backend's cap (`MixRequest.limit le=50`).
const int _kMixLimit = 50;

/// The vibes the backend offers (`GET /recommend/mixes`, Phase MX). Static
/// server-side, so kept alive for the session.
@Riverpod(keepAlive: true)
Future<List<MixVibe>> mixVibes(MixVibesRef ref) async {
  final BackendService backend = await ref.watch(backendServiceProvider.future);
  return backend.mixVibes();
}

/// One vibe's mix (`POST /recommend/mixes/{id}`), keyed by vibe id.
///
/// Sends the **whole** seed collection — unlike For You's sample of 8, a mix
/// is scored against the full taste profile — then drops songs already in the
/// library (same `search3` hydration as For You). Kept alive so reopening a
/// mix is instant; the backend caches the YTM side for 24h too.
@Riverpod(keepAlive: true)
class MixNotifier extends _$MixNotifier {
  /// Bumped by [regenerate]; the backend rotates which mood playlists it uses.
  int _variant = 0;

  @override
  Future<MixResponse> build(String id) async {
    final List<SeedTrack> seeds = await ref.watch(seedCollectionProvider.future);
    final BackendService backend =
        await ref.watch(backendServiceProvider.future);
    final MixResponse mix = await backend.mix(
      id,
      seeds: seeds,
      limit: _kMixLimit,
      variant: _variant,
    );
    final List<RecommendedTrack> hydrated =
        await hydrateLibraryMatches(ref, mix.results);
    return mix.copyWith(
      results: hydrated.where((RecommendedTrack t) => !t.inLibrary).toList(),
    );
  }

  /// A fresh take on the same vibe.
  Future<void> regenerate() async {
    _variant++;
    ref.invalidateSelf();
    await future;
  }
}
