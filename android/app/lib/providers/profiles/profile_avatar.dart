import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/profile.dart';
import 'active_profile.dart';

part 'profile_avatar.g.dart';

/// Hard ceiling on a stored avatar (#37). The picker already downscales to
/// 512 px / quality 85 (typically well under 200 KB); this is the backstop
/// for callers that bypass the picker.
const int kMaxAvatarBytes = 2 * 1024 * 1024;

/// Thrown by [ProfileAvatar.setAvatar] when the image exceeds
/// [kMaxAvatarBytes]. The screen maps it to a readable snackbar.
class AvatarTooLargeError implements Exception {
  const AvatarTooLargeError(this.sizeBytes);
  final int sizeBytes;

  @override
  String toString() =>
      'AvatarTooLargeError: $sizeBytes bytes (max $kMaxAvatarBytes)';
}

/// Directory holding avatar files — `<appDocs>/avatars/`. A provider seam
/// so tests substitute a temp dir.
@Riverpod(keepAlive: true)
Future<Directory> avatarsDir(AvatarsDirRef ref) async {
  final Directory docs = await getApplicationDocumentsDirectory();
  return Directory('${docs.path}/avatars');
}

/// The active profile's avatar file, or null when none is set (#37).
///
/// Files are named `<profileId>_<millis>.jpg` — a fresh path per change so
/// Flutter's path-keyed [FileImage] cache never serves a stale picture.
/// Old files for the same profile are swept on every write/remove. Keyed
/// per profile id, so switching profiles swaps avatars automatically
/// (watching [activeProfileProvider] rebuilds the lookup).
@Riverpod(keepAlive: true)
class ProfileAvatar extends _$ProfileAvatar {
  @override
  Future<File?> build() async {
    final Profile? active = ref.watch(activeProfileProvider);
    if (active == null) return null;
    final Directory dir = await ref.watch(avatarsDirProvider.future);
    if (!dir.existsSync()) return null;
    final List<File> mine = _filesFor(dir, active.id);
    if (mine.isEmpty) return null;
    // Timestamp suffix sorts lexicographically for equal-length millis;
    // the newest write wins.
    mine.sort((File a, File b) => b.path.compareTo(a.path));
    return mine.first;
  }

  /// Persist [bytes] as the active profile's avatar. Atomic (tmp + rename,
  /// same pattern as the offline manifest) and sweeps the previous file.
  /// Throws [AvatarTooLargeError] over [kMaxAvatarBytes]. No-op without an
  /// active profile.
  Future<void> setAvatar(Uint8List bytes) async {
    if (bytes.length > kMaxAvatarBytes) {
      throw AvatarTooLargeError(bytes.length);
    }
    final Profile? active = ref.read(activeProfileProvider);
    if (active == null) return;
    final Directory dir = await ref.read(avatarsDirProvider.future);
    dir.createSync(recursive: true);

    final List<File> old = _filesFor(dir, active.id);
    // Microseconds: two rapid changes must not collide on the same path,
    // or the old-file sweep below would delete the fresh write.
    final String path =
        '${dir.path}/${active.id}_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final File tmp = File('$path.tmp');
    tmp.writeAsBytesSync(bytes, flush: true);
    tmp.renameSync(path);
    for (final File f in old) {
      if (f.path == path) continue;
      try {
        f.deleteSync();
      } on FileSystemException {
        // Best-effort sweep; a leftover is re-swept on the next write.
      }
    }
    state = AsyncData<File?>(File(path));
  }

  /// Delete the active profile's avatar (if any).
  Future<void> removeAvatar() async {
    final Profile? active = ref.read(activeProfileProvider);
    if (active == null) return;
    final Directory dir = await ref.read(avatarsDirProvider.future);
    if (dir.existsSync()) {
      for (final File f in _filesFor(dir, active.id)) {
        try {
          f.deleteSync();
        } on FileSystemException {
          // Best-effort.
        }
      }
    }
    state = const AsyncData<File?>(null);
  }
}

List<File> _filesFor(Directory dir, String profileId) {
  return dir
      .listSync()
      .whereType<File>()
      .where((File f) {
        final String name = f.uri.pathSegments.last;
        return name.startsWith('${profileId}_') && !name.endsWith('.tmp');
      })
      .toList();
}
