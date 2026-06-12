// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_manifest.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$OfflineManifestImpl _$$OfflineManifestImplFromJson(
  Map<String, dynamic> json,
) => _$OfflineManifestImpl(
  markedAlbums:
      (json['marked_albums'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toSet() ??
      const <String>{},
  markedPlaylists:
      (json['marked_playlists'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toSet() ??
      const <String>{},
  songs:
      (json['songs'] as Map<String, dynamic>?)?.map(
        (k, e) =>
            MapEntry(k, OfflineSongEntry.fromJson(e as Map<String, dynamic>)),
      ) ??
      const <String, OfflineSongEntry>{},
  estimatedTotalBytes: (json['estimated_total_bytes'] as num?)?.toInt(),
  estimatedAt: json['estimated_at'] == null
      ? null
      : DateTime.parse(json['estimated_at'] as String),
);

Map<String, dynamic> _$$OfflineManifestImplToJson(
  _$OfflineManifestImpl instance,
) => <String, dynamic>{
  'marked_albums': instance.markedAlbums.toList(),
  'marked_playlists': instance.markedPlaylists.toList(),
  'songs': instance.songs.map((k, e) => MapEntry(k, e.toJson())),
  if (instance.estimatedTotalBytes case final value?)
    'estimated_total_bytes': value,
  if (instance.estimatedAt?.toIso8601String() case final value?)
    'estimated_at': value,
};

_$OfflineSongEntryImpl _$$OfflineSongEntryImplFromJson(
  Map<String, dynamic> json,
) => _$OfflineSongEntryImpl(
  state: $enumDecode(_$OfflineSongStateEnumMap, json['state']),
  localPath: json['local_path'] as String?,
  size: (json['size'] as num?)?.toInt(),
  suffix: json['suffix'] as String?,
  downloadedAt: json['downloaded_at'] == null
      ? null
      : DateTime.parse(json['downloaded_at'] as String),
  lastError: json['last_error'] as String?,
);

Map<String, dynamic> _$$OfflineSongEntryImplToJson(
  _$OfflineSongEntryImpl instance,
) => <String, dynamic>{
  'state': _$OfflineSongStateEnumMap[instance.state]!,
  if (instance.localPath case final value?) 'local_path': value,
  if (instance.size case final value?) 'size': value,
  if (instance.suffix case final value?) 'suffix': value,
  if (instance.downloadedAt?.toIso8601String() case final value?)
    'downloaded_at': value,
  if (instance.lastError case final value?) 'last_error': value,
};

const _$OfflineSongStateEnumMap = {
  OfflineSongState.queued: 'queued',
  OfflineSongState.downloading: 'downloading',
  OfflineSongState.ready: 'ready',
  OfflineSongState.failed: 'failed',
};

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$offlineManifestStoreHash() =>
    r'9f01410755160317d826df399feee266b0079d2e';

/// See also [offlineManifestStore].
@ProviderFor(offlineManifestStore)
final offlineManifestStoreProvider =
    FutureProvider<OfflineManifestStore>.internal(
      offlineManifestStore,
      name: r'offlineManifestStoreProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$offlineManifestStoreHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef OfflineManifestStoreRef = FutureProviderRef<OfflineManifestStore>;
String _$offlineManifestHash() => r'635704af1e0ab39e4b0755d7219b1019351f3d9e';

/// Current manifest for the active server profile. Watches `settingsProvider`
/// so a profile-switch reloads the manifest under the new server-key.
///
/// Copied from [offlineManifest].
@ProviderFor(offlineManifest)
final offlineManifestProvider = FutureProvider<OfflineManifest>.internal(
  offlineManifest,
  name: r'offlineManifestProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$offlineManifestHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef OfflineManifestRef = FutureProviderRef<OfflineManifest>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
