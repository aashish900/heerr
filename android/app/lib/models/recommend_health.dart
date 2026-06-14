import 'package:freezed_annotation/freezed_annotation.dart';

part 'recommend_health.freezed.dart';
part 'recommend_health.g.dart';

/// `GET /api/v1/recommend/health` response. Mirrors the backend
/// `RecommendHealthResponse` schema 1-for-1.
///
/// - [engine]: configured primary engine name (e.g. `lastfm`, `ytmusic`,
///   `lastfm,ytmusic` when a fallback chain is in use).
/// - [status]: `"ok"` when the primary probes healthy, `"degraded"`
///   otherwise. The Settings indicator colours off this.
/// - [fallbackActive]: true iff the primary is down AND some downstream
///   engine in the chain reports OK — UX uses this to distinguish "still
///   serving recommendations from the fallback" from "all engines down".
@freezed
class RecommendHealth with _$RecommendHealth {
  const factory RecommendHealth({
    required String engine,
    required String status,
    @JsonKey(name: 'fallback_active') required bool fallbackActive,
  }) = _RecommendHealth;

  factory RecommendHealth.fromJson(Map<String, dynamic> json) =>
      _$RecommendHealthFromJson(json);
}
