import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile_meta.freezed.dart';
part 'profile_meta.g.dart';

/// Optional display metadata for the profile page (#37) — nickname + bio.
///
/// Deliberately *not* part of [Profile]: these aren't credentials, so they
/// live in plain `shared_preferences` (per the A5 rule that the keystore is
/// for secrets only), keyed per profile id. The person's Name edits
/// `Profile.displayName` on the registry instead — it was already the
/// display handle shown in Settings.
///
/// Every field is nullable; blank input persists as null.
@freezed
class ProfileMeta with _$ProfileMeta {
  const factory ProfileMeta({
    String? nickname,
    String? bio,
  }) = _ProfileMeta;

  factory ProfileMeta.fromJson(Map<String, dynamic> json) =>
      _$ProfileMetaFromJson(json);
}
