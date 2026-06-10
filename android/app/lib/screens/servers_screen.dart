import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_error.dart';
import '../api/client.dart';
import '../api/endpoints.dart';
import '../providers/settings.dart';
import '../theme.dart';
import '../widgets/error_snackbar.dart';

class ServersScreen extends ConsumerWidget {
  const ServersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ServerProfile>> profilesAsync =
        ref.watch(serverProfilesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Servers')),
      body: profilesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('Error: $e')),
        data: (List<ServerProfile> profiles) {
          if (profiles.isEmpty) {
            return const Center(
              child: Text(
                'No servers yet.\nTap + to add one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: profiles.length,
            separatorBuilder: (BuildContext context, int i) => const Divider(height: 1),
            itemBuilder: (BuildContext context, int i) {
              final ServerProfile p = profiles[i];
              return ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: Text(p.name),
                subtitle: Text(
                  p.backendBaseUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openForm(context, ref, existing: p),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: heerrGreen,
        foregroundColor: Colors.white,
        onPressed: () => _openForm(context, ref),
        child: const _ThickPlus(),
      ),
    );
  }

  void _openForm(BuildContext context, WidgetRef ref,
      {ServerProfile? existing}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ServerForm(existing: existing),
    );
  }
}

class _ServerForm extends ConsumerStatefulWidget {
  const _ServerForm({this.existing});
  final ServerProfile? existing;

  @override
  ConsumerState<_ServerForm> createState() => _ServerFormState();
}

class _ServerFormState extends ConsumerState<_ServerForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _tokenController;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.existing?.name ?? '');
    _urlController =
        TextEditingController(text: widget.existing?.backendBaseUrl ?? '');
    _tokenController =
        TextEditingController(text: widget.existing?.bearerToken ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  String _normalizeUrl(String raw) =>
      raw.trim().replaceAll(RegExp(r'/+$'), '');

  String? _required(String? v) =>
      (v ?? '').trim().isEmpty ? 'required' : null;

  String? _validateUrl(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return 'required';
    final Uri? uri = Uri.tryParse(v);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return 'must start with http:// or https://';
    }
    if (uri.host.isEmpty) return 'missing host';
    return null;
  }

  Future<ServerProfile?> _buildProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return null;
    final String url = _normalizeUrl(_urlController.text);
    _urlController.text = url;
    return ServerProfile(
      name: _nameController.text.trim(),
      backendBaseUrl: url,
      bearerToken: _tokenController.text.trim(),
    );
  }

  Future<void> _save() async {
    final ServerProfile? profile = await _buildProfile();
    if (profile == null) return;
    await ref.read(serverProfilesProvider.notifier).saveProfile(profile);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved "${profile.name}"')),
    );
  }

  Future<void> _testConnection() async {
    final ServerProfile? profile = await _buildProfile();
    if (profile == null) return;
    setState(() => _testing = true);
    try {
      await ref.read(serverProfilesProvider.notifier).saveProfile(profile);
      final Dio dio = await ref.read(dioClientProvider.future);
      await apiCall<dynamic>(
        () => dio.get<dynamic>(Endpoints.health),
        (dynamic d) => d,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection OK')),
      );
    } on ApiError catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16, 24 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget.existing == null ? 'Add server' : 'Edit server',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Server name',
                helperText: 'e.g. Home, VPN, Office',
                border: OutlineInputBorder(),
              ),
              autocorrect: false,
              validator: _required,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Backend URL',
                helperText: 'e.g. http://100.106.120.121:8000/api/v1',
                border: OutlineInputBorder(),
              ),
              autocorrect: false,
              keyboardType: TextInputType.url,
              validator: _validateUrl,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'Bearer token',
                border: OutlineInputBorder(),
              ),
              autocorrect: false,
              obscureText: true,
              validator: _required,
            ),
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    onPressed: _testing ? null : _save,
                    child: const Text('Save'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _testing ? null : _testConnection,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white),
                      foregroundColor: Colors.white,
                    ),
                    child: _testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: heerrGreen,
                            ),
                          )
                        : const Text('Test connection'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThickPlus extends StatelessWidget {
  const _ThickPlus();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(painter: _ThickPlusPainter()),
    );
  }
}

class _ThickPlusPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), paint);
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
