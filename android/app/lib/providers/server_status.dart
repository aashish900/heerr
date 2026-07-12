import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api/api_error.dart';
import '../services/backend_service.dart';
import 'server_creds.dart';

part 'server_status.g.dart';

/// DL2 (Downloads "Sync Center" hero, D1): reachability state the hero card
/// watches. `online` reflects the backend `/health` probe only — the thin
/// client never talks to Navidrome directly, so this is "the pipeline that
/// syncs my library is alive", not a direct Navidrome ping.
typedef ServerStatus = ({
  bool online,
  String? errorMessage,
  DateTime checkedAt,
});

const Duration _kPollInterval = Duration(seconds: 30);

/// Polls `BackendService.health()` every [_kPollInterval] while this
/// provider has a listener (autoDispose — the Downloads screen is the only
/// watcher, so polling stops the moment the user navigates away). No poll at
/// all when no profile is configured yet.
@riverpod
class ServerStatusNotifier extends _$ServerStatusNotifier {
  Timer? _timer;

  @override
  Future<ServerStatus> build() async {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    _timer = Timer.periodic(_kPollInterval, (_) => _tick());
    return _probe();
  }

  void _tick() {
    _probe().then((ServerStatus s) {
      state = AsyncValue<ServerStatus>.data(s);
    });
  }

  Future<ServerStatus> _probe() async {
    final ServerCreds creds = ref.read(serverCredsProvider);
    final DateTime now = DateTime.now();
    if (creds.navidromeBaseUrl == null || creds.navidromeBaseUrl!.isEmpty) {
      return (online: false, errorMessage: 'No server configured', checkedAt: now);
    }
    try {
      final BackendService backend = await ref.read(backendServiceProvider.future);
      final bool ok = await backend.health();
      return (
        online: ok,
        errorMessage: ok ? null : 'Backend reported unhealthy',
        checkedAt: now,
      );
    } on ApiError catch (e) {
      return (online: false, errorMessage: e.message, checkedAt: now);
    }
  }
}
