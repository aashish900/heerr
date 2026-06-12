import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_error.dart';
import '../api/client.dart';
import '../api/endpoints.dart';
import '../api/subsonic_client.dart';
import '../api/subsonic_endpoints.dart';
import '../dev_defaults.dart';
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
  late final TextEditingController _navidromeUrlController;
  late final TextEditingController _navidromeUserController;
  late final TextEditingController _navidromePassController;
  bool _testingHeerr = false;
  bool _testingNavidrome = false;
  // Secret-field visibility toggles. Default = obscured; tap eye to reveal
  // so the user can verify they typed the secret correctly without re-entry.
  bool _tokenObscured = true;
  bool _navPassObscured = true;

  bool get _anyTesting => _testingHeerr || _testingNavidrome;

  @override
  void initState() {
    super.initState();
    // For an **add** flow (no `existing`), pre-fill the four non-secret
    // fields from `DevDefaults` so reinstalls don't require retyping the
    // Tailnet URLs / username. The bearer token + Navidrome password are
    // never defaulted — they're the actual secrets. `DevDefaults` lives
    // in a gitignored file (see lib/dev_defaults.example.dart for the
    // template); on a fresh clone the fields stay blank.
    final bool isAdd = widget.existing == null;
    _nameController = TextEditingController(
      text: widget.existing?.name ?? (isAdd ? DevDefaults.serverName : null) ?? '',
    );
    _urlController = TextEditingController(
      text: widget.existing?.backendBaseUrl ??
          (isAdd ? DevDefaults.backendBaseUrl : null) ??
          '',
    );
    _tokenController =
        TextEditingController(text: widget.existing?.bearerToken ?? '');
    _navidromeUrlController = TextEditingController(
      text: widget.existing?.navidromeBaseUrl ??
          (isAdd ? DevDefaults.navidromeBaseUrl : null) ??
          '',
    );
    _navidromeUserController = TextEditingController(
      text: widget.existing?.navidromeUsername ??
          (isAdd ? DevDefaults.navidromeUsername : null) ??
          '',
    );
    _navidromePassController =
        TextEditingController(text: widget.existing?.navidromePassword ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _tokenController.dispose();
    _navidromeUrlController.dispose();
    _navidromeUserController.dispose();
    _navidromePassController.dispose();
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

  /// Navidrome URL is optional but, if provided, must be a valid http(s) URL.
  String? _validateOptionalUrl(String? value) {
    final String v = (value ?? '').trim();
    if (v.isEmpty) return null;
    return _validateUrl(value);
  }

  /// Validate, normalise URLs, build a [ServerProfile]. Returns null if form
  /// validation fails so callers can early-return without showing UI noise.
  Future<ServerProfile?> _buildProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return null;
    final String url = _normalizeUrl(_urlController.text);
    _urlController.text = url;
    final String nUrlRaw = _navidromeUrlController.text.trim();
    final String? nUrl = nUrlRaw.isEmpty ? null : _normalizeUrl(nUrlRaw);
    if (nUrl != null) _navidromeUrlController.text = nUrl;
    final String nUser = _navidromeUserController.text.trim();
    final String nPass = _navidromePassController.text;
    return ServerProfile(
      name: _nameController.text.trim(),
      backendBaseUrl: url,
      bearerToken: _tokenController.text.trim(),
      navidromeBaseUrl: nUrl,
      navidromeUsername: nUser.isEmpty ? null : nUser,
      navidromePassword: nPass.isEmpty ? null : nPass,
    );
  }

  Future<void> _save() async {
    final ServerProfile? profile = await _buildProfile();
    if (profile == null) return;
    await ref.read(serverProfilesProvider.notifier).saveProfile(profile);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: kSnackBarDuration,
        content: Text('Saved "${profile.name}"'),
      ),
    );
  }

  Future<void> _testHeerr() async {
    final ServerProfile? profile = await _buildProfile();
    if (profile == null) return;
    setState(() => _testingHeerr = true);
    try {
      await ref.read(serverProfilesProvider.notifier).saveProfile(profile);
      final Dio dio = await ref.read(dioClientProvider.future);
      await apiCall<dynamic>(
        () => dio.get<dynamic>(Endpoints.health),
        (dynamic d) => d,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: kSnackBarDuration,
          content: Text('Connection OK'),
        ),
      );
    } on ApiError catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _testingHeerr = false);
    }
  }

  Future<void> _testNavidrome() async {
    final ServerProfile? profile = await _buildProfile();
    if (profile == null) return;
    if (!mounted) return;
    if (profile.navidromeBaseUrl == null ||
        profile.navidromeUsername == null ||
        profile.navidromePassword == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: kSnackBarDuration,
          content: Text('Fill in all 3 Navidrome fields first'),
        ),
      );
      return;
    }
    setState(() => _testingNavidrome = true);
    try {
      await ref.read(serverProfilesProvider.notifier).saveProfile(profile);
      final Dio dio = await ref.read(subsonicDioClientProvider.future);
      await subsonicCall<dynamic>(
        () => dio.get<dynamic>(SubsonicEndpoints.ping),
        (Map<String, dynamic> env) => env,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: kSnackBarDuration,
          content: Text('Connection OK'),
        ),
      );
    } on ApiError catch (e) {
      if (!mounted) return;
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _testingNavidrome = false);
    }
  }

  Widget _spinnerOr(bool loading, String label) {
    if (!loading) return Text(label);
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: heerrGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16, 24 + bottomInset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
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
                  helperText: 'e.g. http://100.x.y.z:8000/api/v1',
                  border: OutlineInputBorder(),
                ),
                autocorrect: false,
                keyboardType: TextInputType.url,
                validator: _validateUrl,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tokenController,
                decoration: InputDecoration(
                  labelText: 'Bearer token',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip:
                        _tokenObscured ? 'Show token' : 'Hide token',
                    icon: Icon(
                      _tokenObscured
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _tokenObscured = !_tokenObscured),
                  ),
                ),
                autocorrect: false,
                obscureText: _tokenObscured,
                validator: _required,
              ),
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Text(
                'Navidrome (optional)',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _navidromeUrlController,
                decoration: const InputDecoration(
                  labelText: 'Navidrome URL',
                  helperText: 'e.g. http://100.x.y.z:4533',
                  border: OutlineInputBorder(),
                ),
                autocorrect: false,
                keyboardType: TextInputType.url,
                validator: _validateOptionalUrl,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _navidromeUserController,
                decoration: const InputDecoration(
                  labelText: 'Navidrome username',
                  border: OutlineInputBorder(),
                ),
                autocorrect: false,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _navidromePassController,
                decoration: InputDecoration(
                  labelText: 'Navidrome password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: _navPassObscured
                        ? 'Show password'
                        : 'Hide password',
                    icon: Icon(
                      _navPassObscured
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(
                        () => _navPassObscured = !_navPassObscured),
                  ),
                ),
                autocorrect: false,
                obscureText: _navPassObscured,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _anyTesting ? null : _save,
                child: const Text('Save'),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _anyTesting ? null : _testHeerr,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white),
                        foregroundColor: Colors.white,
                      ),
                      child: _spinnerOr(_testingHeerr, 'Test heerr'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _anyTesting ? null : _testNavidrome,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white),
                        foregroundColor: Colors.white,
                      ),
                      child: _spinnerOr(_testingNavidrome, 'Test Navidrome'),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
