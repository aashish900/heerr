import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Returns the picked image bytes, or null when the user cancelled.
typedef ProfileImagePick = Future<Uint8List?> Function();

/// Gallery-pick seam for the profile avatar (#37). A provider so widget
/// tests substitute a stub instead of launching the platform photo picker.
///
/// The production impl downscales at pick time (512 px box, quality 85) —
/// any source photo lands well under the [kMaxAvatarBytes] backstop.
final Provider<ProfileImagePick> profileImagePickerProvider =
    Provider<ProfileImagePick>((Ref ref) => _pickAvatarImage);

Future<Uint8List?> _pickAvatarImage() async {
  final XFile? picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 512,
    maxHeight: 512,
    imageQuality: 85,
  );
  if (picked == null) return null;
  return picked.readAsBytes();
}
