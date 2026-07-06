import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Returns the picked image bytes, or null when the user cancelled.
typedef SongCoverImagePick = Future<Uint8List?> Function();

/// Gallery-pick seam for the song-metadata edit screen (#44). A provider so
/// widget tests substitute a stub instead of launching the platform photo
/// picker.
///
/// Downscales at pick time (1024 px box, quality 85) — covers deserve more
/// resolution than the 512 px avatar, but the box + the backend's 5 MB cap
/// keep the upload bounded.
final Provider<SongCoverImagePick> songCoverImagePickerProvider =
    Provider<SongCoverImagePick>((Ref ref) => _pickCoverImage);

Future<Uint8List?> _pickCoverImage() async {
  final XFile? picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 85,
  );
  if (picked == null) return null;
  return picked.readAsBytes();
}
