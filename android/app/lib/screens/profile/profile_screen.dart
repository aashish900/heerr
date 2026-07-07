import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/backend_profile.dart';
import '../../models/profile.dart';
import '../../models/profile_meta.dart';
import '../../providers/profiles/active_profile.dart';
import '../../providers/profiles/profile_avatar.dart';
import '../../providers/profiles/profile_image_picker.dart';
import '../../providers/profiles/profile_meta.dart';
import '../../providers/profiles/profile_registry.dart';
import '../../router.dart';
import '../../utils/word_limit.dart';

enum _ProfileMenuAction { editServerDetails }

/// Bio word cap (#37).
const int kBioMaxWords = 100;

/// Profile page (#37): avatar (add / change / remove), Name, Nickname, and
/// a 100-word Bio. Every field is optional — blank Name falls back to the
/// Navidrome username, blank Nickname/Bio persist as null.
///
/// Name edits `Profile.displayName` on the registry (it was already the
/// handle shown in Settings' profiles list); Nickname + Bio live in
/// [ProfileMetaNotifier] (plain prefs, per profile id); the picture lives
/// on disk via [ProfileAvatar].
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _nickname = TextEditingController();
  final TextEditingController _bio = TextEditingController();
  bool _metaSeeded = false;
  int _bioWords = 0;

  @override
  void initState() {
    super.initState();
    final Profile? active = ref.read(activeProfileProvider);
    if (active != null) _name.text = active.displayName;
  }

  @override
  void dispose() {
    _name.dispose();
    _nickname.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _seedMeta(ProfileMeta meta) {
    if (_metaSeeded) return;
    _metaSeeded = true;
    _nickname.text = meta.nickname ?? '';
    _bio.text = meta.bio ?? '';
    _bioWords = countWords(_bio.text);
  }

  Future<void> _pickPhoto() async {
    final Uint8List? bytes =
        await ref.read(profileImagePickerProvider).call();
    if (bytes == null || !mounted) return; // cancelled
    try {
      await ref.read(profileAvatarProvider.notifier).setAvatar(bytes);
      unawaited(pushProfileToBackend(ref));
    } on AvatarTooLargeError {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Image too large — max 2 MB'),
      ));
    }
  }

  void _showPhotoSheet(bool hasAvatar) {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                key: const Key('profile-pic-pick'),
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(hasAvatar ? 'Change photo' : 'Choose photo'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickPhoto();
                },
              ),
              if (hasAvatar)
                ListTile(
                  key: const Key('profile-pic-remove'),
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Remove photo'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    ref
                        .read(profileAvatarProvider.notifier)
                        .removeAvatar()
                        .then((_) => pushProfileToBackend(ref));
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    final Profile? active = ref.read(activeProfileProvider);
    if (active == null) return;
    final String name = _name.text.trim();
    // Blank Name is allowed — fall back to the Navidrome username so the
    // Settings profiles list never shows an empty row.
    await ref.read(profileRegistryProvider.notifier).updateDisplayName(
          active.id,
          name.isEmpty ? active.navidromeUsername : name,
        );
    await ref
        .read(profileMetaNotifierProvider.notifier)
        .save(nickname: _nickname.text, bio: _bio.text);
    unawaited(pushProfileToBackend(ref));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Profile saved'),
    ));
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final File? avatar = ref.watch(profileAvatarProvider).valueOrNull;
    final AsyncValue<ProfileMeta> metaAsync =
        ref.watch(profileMetaNotifierProvider);
    final ProfileMeta? meta = metaAsync.valueOrNull;
    if (meta != null) _seedMeta(meta);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: <Widget>[
          PopupMenuButton<_ProfileMenuAction>(
            onSelected: (_ProfileMenuAction action) {
              switch (action) {
                case _ProfileMenuAction.editServerDetails:
                  context.push(Routes.editServerDetails);
              }
            },
            itemBuilder: (BuildContext context) =>
                <PopupMenuEntry<_ProfileMenuAction>>[
              const PopupMenuItem<_ProfileMenuAction>(
                value: _ProfileMenuAction.editServerDetails,
                child: Text('Edit server details'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Center(
            child: InkWell(
              key: const Key('profile-avatar'),
              customBorder: const CircleBorder(),
              onTap: () => _showPhotoSheet(avatar != null),
              child: CircleAvatar(
                radius: 56,
                foregroundImage: avatar != null ? FileImage(avatar) : null,
                child: avatar == null
                    ? const Icon(Icons.person_outline, size: 56)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              key: const Key('profile-pic-edit'),
              onPressed: () => _showPhotoSheet(avatar != null),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(avatar == null ? 'Add photo' : 'Edit photo'),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('profile-name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              helperText: 'Optional — shown in the profiles list',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('profile-nickname'),
            controller: _nickname,
            decoration: const InputDecoration(
              labelText: 'Nickname',
              helperText: 'Optional — used in the Home greeting',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('profile-bio'),
            controller: _bio,
            minLines: 4,
            maxLines: 8,
            inputFormatters: <TextInputFormatter>[
              WordLimitTextInputFormatter(kBioMaxWords),
            ],
            onChanged: (String text) =>
                setState(() => _bioWords = countWords(text)),
            decoration: InputDecoration(
              labelText: 'Bio',
              helperText: 'Optional — $_bioWords/$kBioMaxWords words',
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('profile-save'),
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
