// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'queue.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$queuePollIntervalHash() => r'd8caeaf80cdf2c1245f96042f2cd084ca84d0d28';

/// Polling interval for `GET /queue`. Exposed as a provider so tests can
/// override it (typically to a short real duration when paired with
/// `fake_async`).
///
/// Copied from [queuePollInterval].
@ProviderFor(queuePollInterval)
final queuePollIntervalProvider = Provider<Duration>.internal(
  queuePollInterval,
  name: r'queuePollIntervalProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$queuePollIntervalHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef QueuePollIntervalRef = ProviderRef<Duration>;
String _$queueHash() => r'2944b1801a44682d612c1bfa8ab5d9a3b00f5e16';

/// Polls `GET /queue` on a schedule (PLAN.md §8 — 3s default, pauses on app
/// background). Implemented as an `AsyncNotifier` rather than a
/// `StreamProvider` because the UI needs to **imperatively** pause/resume on
/// lifecycle changes — Streams don't expose that control to consumers.
///
/// `keepAlive: true` so the in-progress poll cycle survives screen rebuilds
/// (e.g. quickly switching tabs and back).
///
/// Copied from [Queue].
@ProviderFor(Queue)
final queueProvider = AsyncNotifierProvider<Queue, QueueResponse>.internal(
  Queue.new,
  name: r'queueProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$queueHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$Queue = AsyncNotifier<QueueResponse>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
