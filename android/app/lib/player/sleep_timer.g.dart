// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sleep_timer.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sleepTimerNotifierHash() =>
    r'63bce14b60461c966cdcf8014937df8b15e8dba1';

/// Riverpod-facing notifier. P3. Owns one [SleepTimerController] whose
/// `onExpire` callback resolves [audioHandlerProvider] and calls
/// `pause()`. Survives app background (keep-alive); does not survive
/// cold start (intentional — sleep timers are session-scoped).
///
/// Copied from [SleepTimerNotifier].
@ProviderFor(SleepTimerNotifier)
final sleepTimerNotifierProvider =
    NotifierProvider<SleepTimerNotifier, Duration?>.internal(
      SleepTimerNotifier.new,
      name: r'sleepTimerNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$sleepTimerNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SleepTimerNotifier = Notifier<Duration?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
