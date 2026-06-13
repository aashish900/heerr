import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Single-field "name a new playlist" dialog. Pure UI shell — the caller
/// (`_PlaylistsTab` in `library_screen.dart`) is responsible for invoking
/// `playlistMutationsProvider.notifier.createPlaylist(...)` once the user
/// confirms, so the dialog has no Riverpod side effects.
///
/// `await CreatePlaylistDialog.show(context)` resolves to:
///   - the trimmed name (non-empty `String`) when the user confirms,
///   - `null` when the user cancels / dismisses.
class CreatePlaylistDialog extends ConsumerStatefulWidget {
  const CreatePlaylistDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (_) => const CreatePlaylistDialog(),
    );
  }

  @override
  ConsumerState<CreatePlaylistDialog> createState() =>
      _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends ConsumerState<CreatePlaylistDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _trimmed => _controller.text.trim();

  void _submit() {
    if (_trimmed.isEmpty) return;
    Navigator.of(context).pop(_trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New playlist'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Playlist name',
          hintText: 'e.g. Morning Coffee',
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _trimmed.isEmpty ? null : _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }
}

/// Result envelope returned by [RenamePlaylistDialog.show]. `name` is
/// always trimmed and non-empty; `makePublic` is the toggle state at the
/// moment of confirm. Callers fan out to
/// `playlistMutationsProvider.notifier.renamePlaylist(...)`.
typedef RenamePlaylistResult = ({String name, bool makePublic});

/// Edit-existing-playlist dialog: name pre-filled with [initialName],
/// "Make public" checkbox seeded from [initialPublic]. Same purity rule
/// as [CreatePlaylistDialog] — no side effects; caller drives the
/// mutation.
///
/// Resolves to a [RenamePlaylistResult] on confirm, `null` on cancel.
class RenamePlaylistDialog extends ConsumerStatefulWidget {
  const RenamePlaylistDialog({
    required this.initialName,
    required this.initialPublic,
    super.key,
  });

  final String initialName;
  final bool initialPublic;

  static Future<RenamePlaylistResult?> show(
    BuildContext context, {
    required String initialName,
    required bool initialPublic,
  }) {
    return showDialog<RenamePlaylistResult>(
      context: context,
      builder: (_) => RenamePlaylistDialog(
        initialName: initialName,
        initialPublic: initialPublic,
      ),
    );
  }

  @override
  ConsumerState<RenamePlaylistDialog> createState() =>
      _RenamePlaylistDialogState();
}

class _RenamePlaylistDialogState extends ConsumerState<RenamePlaylistDialog> {
  late final TextEditingController _controller;
  late bool _makePublic;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _makePublic = widget.initialPublic;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _trimmed => _controller.text.trim();

  void _submit() {
    if (_trimmed.isEmpty) return;
    Navigator.of(context).pop(
      (name: _trimmed, makePublic: _makePublic),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename playlist'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Playlist name',
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Make playlist public'),
            value: _makePublic,
            onChanged: (bool? v) => setState(() => _makePublic = v ?? false),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _trimmed.isEmpty ? null : _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
