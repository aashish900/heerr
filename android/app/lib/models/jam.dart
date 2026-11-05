import 'package:freezed_annotation/freezed_annotation.dart';

part 'jam.freezed.dart';
part 'jam.g.dart';

// Phase JM (jam / remote control) wire models.
// Backend contract: `backend/app/schemas/jam.py`.

/// `POST /jam` response: the host's new session.
@freezed
class JamSession with _$JamSession {
  const factory JamSession({
    required String id,
    required String code,
    required DateTime expiresAt,
  }) = _JamSession;

  factory JamSession.fromJson(Map<String, dynamic> json) =>
      _$JamSessionFromJson(json);
}

/// `POST /jam/join` response: the session a guest joined.
@freezed
class JamJoin with _$JamJoin {
  const factory JamJoin({
    required String id,
    required String hostUsername,
    required DateTime expiresAt,
  }) = _JamJoin;

  factory JamJoin.fromJson(Map<String, dynamic> json) =>
      _$JamJoinFromJson(json);
}

/// One guest command as the host receives it from `POST /jam/{id}/sync`.
/// [payload] shapes: `play_songs {songs, start_index}`, `enqueue {songs}`,
/// `seek {position_ms}`, else `{}`. `songs` are [Song] JSON maps.
@freezed
class JamCommand with _$JamCommand {
  const factory JamCommand({
    required int id,
    required String kind,
    @Default(<String, dynamic>{}) Map<String, dynamic> payload,
    @Default('') String sender,
  }) = _JamCommand;

  factory JamCommand.fromJson(Map<String, dynamic> json) =>
      _$JamCommandFromJson(json);
}

@freezed
class JamSyncResponse with _$JamSyncResponse {
  const factory JamSyncResponse({
    @Default(<JamCommand>[]) List<JamCommand> commands,
    required int cursor,
    required bool ended,
  }) = _JamSyncResponse;

  factory JamSyncResponse.fromJson(Map<String, dynamic> json) =>
      _$JamSyncResponseFromJson(json);
}

/// `GET /jam/{id}/state`: the host's latest snapshot (shape built by the
/// host poller; see `/PLAN.md` §5.3).
@freezed
class JamState with _$JamState {
  const factory JamState({
    Map<String, dynamic>? state,
    DateTime? stateAt,
    required String hostUsername,
    required bool ended,
  }) = _JamState;

  factory JamState.fromJson(Map<String, dynamic> json) =>
      _$JamStateFromJson(json);
}
