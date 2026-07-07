import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile.dart';
import '../models/profile_meta.dart';
import '../providers/profiles/active_profile.dart';
import '../providers/profiles/profile_avatar.dart';
import '../providers/profiles/profile_meta.dart';
import 'api_error.dart';
import 'endpoints.dart';

/// Profile data as transported to/from the backend.
class BackendProfileData {
  const BackendProfileData({
    this.displayName,
    this.nickname,
    this.bio,
    this.avatarB64,
  });

  final String? displayName;
  final String? nickname;
  final String? bio;
  final String? avatarB64;

  factory BackendProfileData.fromJson(Map<String, dynamic> json) =>
      BackendProfileData(
        displayName: json['display_name'] as String?,
        nickname: json['nickname'] as String?,
        bio: json['bio'] as String?,
        avatarB64: json['avatar_b64'] as String?,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'display_name': displayName,
        'nickname': nickname,
        'bio': bio,
        'avatar_b64': avatarB64,
      };
}

/// PUT /profile — replaces all stored profile fields for the calling user.
///
/// Uses its own Dio (no auth interceptor dependency) with the provided
/// [bearerToken] injected directly, matching the pattern in [authLogin].
Future<BackendProfileData> putBackendProfile({
  required String baseUrl,
  required String bearerToken,
  required BackendProfileData data,
  Dio? dio,
}) async {
  final Dio client = dio ??
      Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

  try {
    final Response<dynamic> res = await client.put<dynamic>(
      Endpoints.profile,
      data: data.toJson(),
      options: Options(
        headers: <String, String>{'Authorization': 'Bearer $bearerToken'},
      ),
    );
    return BackendProfileData.fromJson(res.data as Map<String, dynamic>);
  } on DioException catch (e) {
    throw mapDioErrorToApiError(e);
  }
}

/// Assembles the current local profile state and pushes it to the backend.
///
/// Reads: active profile (credentials + displayName), ProfileMeta (nickname /
/// bio), and the avatar file. Safe to call fire-and-forget — errors are
/// swallowed so a transient network blip never blocks a local save.
Future<void> pushProfileToBackend(WidgetRef ref) async {
  final Profile? active = ref.read(activeProfileProvider);
  if (active == null) return;

  final ProfileMeta meta =
      await ref.read(profileMetaNotifierProvider.future);

  final File? avatarFile =
      await ref.read(profileAvatarProvider.future);

  String? avatarB64;
  if (avatarFile != null && avatarFile.existsSync()) {
    final Uint8List bytes = await avatarFile.readAsBytes();
    avatarB64 = base64Encode(bytes);
  }

  try {
    await putBackendProfile(
      baseUrl: active.heerrBaseUrl,
      bearerToken: active.heerrBearerToken,
      data: BackendProfileData(
        displayName: active.displayName,
        nickname: meta.nickname,
        bio: meta.bio,
        avatarB64: avatarB64,
      ),
    );
  } on ApiError {
    // Best-effort: local save already succeeded; a transient backend failure
    // is not surfaced to the user. The next successful save will resync.
  }
}
