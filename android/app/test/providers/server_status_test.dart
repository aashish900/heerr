import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/api/api_error.dart';
import 'package:heerr/providers/server_status.dart';
import 'package:heerr/services/backend_service.dart';

import '../support/cred_test_support.dart';

// DL2 (Downloads "Sync Center" hero, D1): serverStatusNotifierProvider's
// one-shot `_probe()` behaviour for the three states the hero card renders
// (unconfigured / online / unreachable). The periodic re-poll is plain
// `Timer.periodic` — not covered here, same testing boundary offline_sync
// uses for its own timer.

class _StubHealthyBackend extends BackendService {
  _StubHealthyBackend() : super(Dio());
  @override
  Future<bool> health() async => true;
}

class _StubUnhealthyBackend extends BackendService {
  _StubUnhealthyBackend() : super(Dio());
  @override
  Future<bool> health() async => false;
}

class _StubUnreachableBackend extends BackendService {
  _StubUnreachableBackend() : super(Dio());
  @override
  Future<bool> health() => Future<bool>.error(const NetworkError());
}

void main() {
  test('no active profile → offline with "No server configured"', () async {
    final ProviderContainer c = ProviderContainer(
      overrides: <Override>[
        backendServiceProvider.overrideWith(
          (_) async => _StubHealthyBackend(),
        ),
      ],
    );
    addTearDown(c.dispose);

    final ServerStatus status =
        await c.read(serverStatusNotifierProvider.future);

    expect(status.online, isFalse);
    expect(status.errorMessage, 'No server configured');
  });

  test('configured profile + healthy backend → online', () async {
    final ProviderContainer c = ProviderContainer(
      overrides: <Override>[
        activeProfileOverride(),
        backendServiceProvider.overrideWith(
          (_) async => _StubHealthyBackend(),
        ),
      ],
    );
    addTearDown(c.dispose);

    final ServerStatus status =
        await c.read(serverStatusNotifierProvider.future);

    expect(status.online, isTrue);
    expect(status.errorMessage, isNull);
  });

  test('configured profile + unhealthy backend → offline with message',
      () async {
    final ProviderContainer c = ProviderContainer(
      overrides: <Override>[
        activeProfileOverride(),
        backendServiceProvider.overrideWith(
          (_) async => _StubUnhealthyBackend(),
        ),
      ],
    );
    addTearDown(c.dispose);

    final ServerStatus status =
        await c.read(serverStatusNotifierProvider.future);

    expect(status.online, isFalse);
    expect(status.errorMessage, 'Backend reported unhealthy');
  });

  test('configured profile + unreachable backend → offline via ApiError',
      () async {
    final ProviderContainer c = ProviderContainer(
      overrides: <Override>[
        activeProfileOverride(),
        backendServiceProvider.overrideWith(
          (_) async => _StubUnreachableBackend(),
        ),
      ],
    );
    addTearDown(c.dispose);

    final ServerStatus status =
        await c.read(serverStatusNotifierProvider.future);

    expect(status.online, isFalse);
    expect(status.errorMessage, 'cannot reach backend — check tailscale');
  });
}
