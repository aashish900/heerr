// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'now_playing_widget_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$nowPlayingWidgetHash() => r'679922f0dfce1a5ce881ad13aa169befbba126a0';

/// #20: keep-alive side-effect provider that mirrors the live player state
/// onto the home-screen widget. Watched by `HeerrApp` purely for the
/// subscription — same pattern as `nowPlayingPersistenceProvider`.
///
/// Listens to the fused [playerSnapshotProvider] and pushes each emission
/// through [NowPlayingWidgetUpdater]. Updates only happen while the app
/// process is alive; when the app is killed the widget keeps showing the
/// last-pushed state until the user reopens the app.
///
/// Copied from [nowPlayingWidget].
@ProviderFor(nowPlayingWidget)
final nowPlayingWidgetProvider = Provider<NowPlayingWidgetUpdater>.internal(
  nowPlayingWidget,
  name: r'nowPlayingWidgetProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$nowPlayingWidgetHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NowPlayingWidgetRef = ProviderRef<NowPlayingWidgetUpdater>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
