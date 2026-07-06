import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_error.dart';
import '../../models/subsonic/song.dart';
import '../../providers/library/library_edit.dart';
import '../../providers/library/song_cover_image_picker.dart';
import '../../widgets/error_snackbar.dart';
import '../../widgets/library_cover_art.dart';

/// Y2 (#44): full-screen editor for one song's tags + cover art. Reached from
/// the "Edit metadata…" tile in the add-to-playlist long-press sheet; pushed
/// on the root navigator (no go_router route — there's no deep-link need).
///
/// Only *changed* fields are sent on Save. A field left equal to its original
/// value — or cleared to empty — is omitted (the backend rejects blank tags,
/// and v1 has no "delete a tag" affordance). Save is disabled until something
/// changes. Cover uploads route through the [libraryEditProvider] notifier,
/// which evicts the cached cover so the new art shows after the next scan.
class EditSongMetadataScreen extends ConsumerStatefulWidget {
  const EditSongMetadataScreen({required this.song, super.key});

  final Song song;

  @override
  ConsumerState<EditSongMetadataScreen> createState() =>
      _EditSongMetadataScreenState();
}

class _EditSongMetadataScreenState
    extends ConsumerState<EditSongMetadataScreen> {
  late final TextEditingController _title;
  late final TextEditingController _album;
  late final TextEditingController _artist;

  Uint8List? _pickedCover;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.song.title);
    _album = TextEditingController(text: widget.song.album ?? '');
    _artist = TextEditingController(text: widget.song.artist ?? '');
    for (final TextEditingController c in <TextEditingController>[
      _title,
      _album,
      _artist,
    ]) {
      c.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _album.dispose();
    _artist.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  /// A field's new value if it changed to a non-empty string, else null.
  String? _changed(TextEditingController c, String? original) {
    final String next = c.text.trim();
    if (next.isEmpty || next == (original ?? '').trim()) return null;
    return next;
  }

  bool get _hasChanges =>
      _pickedCover != null ||
      _changed(_title, widget.song.title) != null ||
      _changed(_album, widget.song.album) != null ||
      _changed(_artist, widget.song.artist) != null;

  Future<void> _pickCover() async {
    final Uint8List? bytes = await ref.read(songCoverImagePickerProvider)();
    if (bytes != null && mounted) setState(() => _pickedCover = bytes);
  }

  Future<void> _save() async {
    final String? title = _changed(_title, widget.song.title);
    final String? album = _changed(_album, widget.song.album);
    final String? artist = _changed(_artist, widget.song.artist);
    setState(() => _saving = true);
    try {
      await ref.read(libraryEditProvider.notifier).editSong(
            widget.song,
            title: title,
            album: album,
            artist: artist,
            coverBytes: _pickedCover,
          );
      if (!mounted) return;
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          duration: kSnackBarDuration,
          content: Text(
            'Updated "${title ?? widget.song.title}" — library reflects '
            'changes after the next Navidrome scan',
          ),
        ),
      );
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canSave = _hasChanges && !_saving;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit metadata'),
        actions: <Widget>[
          TextButton(
            key: const Key('edit-song-save'),
            onPressed: canSave ? _save : null,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Center(
            child: Column(
              children: <Widget>[
                _CoverPreview(
                  picked: _pickedCover,
                  coverArtId: widget.song.coverArt,
                ),
                TextButton.icon(
                  key: const Key('edit-song-cover-picker'),
                  onPressed: _saving ? null : _pickCover,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Change cover'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('edit-song-title'),
            controller: _title,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('edit-song-artist'),
            controller: _artist,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Artist(s)',
              helperText: 'Separate multiple with commas',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('edit-song-album'),
            controller: _album,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Album',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverPreview extends StatelessWidget {
  const _CoverPreview({required this.picked, required this.coverArtId});

  final Uint8List? picked;
  final String? coverArtId;

  @override
  Widget build(BuildContext context) {
    const double size = 180;
    final Uint8List? bytes = picked;
    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (BuildContext c, _, _) => _brokenImage(c, size),
        ),
      );
    }
    return LibraryCoverArt(
      coverArtId: coverArtId,
      size: size,
      borderRadius: 8,
    );
  }

  Widget _brokenImage(BuildContext context, double size) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      color: cs.surfaceContainerHighest,
      child: Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant),
    );
  }
}
