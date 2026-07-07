import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_error.dart';
import '../../api/auth_login.dart';
import '../../models/profile.dart';
import '../../providers/profiles/active_profile.dart';
import '../../providers/profiles/profile_registry.dart';
import '../../widgets/error_snackbar.dart';

class EditServerDetailsScreen extends ConsumerStatefulWidget {
  const EditServerDetailsScreen({super.key, this.profileId});

  /// Id of the profile to edit. Falls back to the active profile when null.
  final String? profileId;

  @override
  ConsumerState<EditServerDetailsScreen> createState() =>
      _EditServerDetailsScreenState();
}

class _EditServerDetailsScreenState
    extends ConsumerState<EditServerDetailsScreen> {
  late final TextEditingController _urlCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _passwordCtrl;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _obscure = true;
  bool _busy = false;

  /// Returns the profile this screen is editing — either the one identified by
  /// [EditServerDetailsScreen.profileId] or, as a fallback, the active profile.
  Profile? _targetProfile() {
    if (widget.profileId != null) {
      final ProfileRegistryState? state =
          ref.read(profileRegistryProvider).valueOrNull;
      final Profile? found = state?.profiles
          .where((Profile p) => p.id == widget.profileId)
          .firstOrNull;
      if (found != null) return found;
    }
    return ref.read(activeProfileProvider);
  }

  @override
  void initState() {
    super.initState();
    final Profile? target = _targetProfile();
    _urlCtrl = TextEditingController(text: target?.heerrBaseUrl ?? '');
    _usernameCtrl =
        TextEditingController(text: target?.navidromeUsername ?? '');
    _passwordCtrl =
        TextEditingController(text: target?.navidromePassword ?? '');
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<AuthLoginResponse?> _callLogin() async {
    if (!_formKey.currentState!.validate()) return null;
    setState(() => _busy = true);
    try {
      return await authLogin(
        baseUrl: _urlCtrl.text.trim(),
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
    } on ApiError catch (e) {
      if (!mounted) return null;
      showApiError(context, e, action: 'connect');
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _testConnection() async {
    final AuthLoginResponse? res = await _callLogin();
    if (res == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Connection successful'),
    ));
  }

  Future<void> _save() async {
    final Profile? target = _targetProfile();
    if (target == null) return;
    final AuthLoginResponse? res = await _callLogin();
    if (res == null || !mounted) return;
    await ref.read(profileRegistryProvider.notifier).updateServerDetails(
          target.id,
          heerrBaseUrl: _urlCtrl.text.trim(),
          heerrBearerToken: res.token,
          navidromeBaseUrl: res.navidromeUrl,
          navidromeUsername: res.navidromeUsername,
          navidromePassword: _passwordCtrl.text,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Server details saved'),
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit server details')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  controller: _urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'heerr base URL',
                    hintText: 'http://100.x.y.z:8000/api/v1',
                  ),
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  enabled: !_busy,
                  validator: (String? v) {
                    final String s = (v ?? '').trim();
                    if (s.isEmpty) return 'Enter the heerr base URL';
                    if (!s.startsWith('http')) {
                      return 'Must start with http:// or https://';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _usernameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Navidrome username',
                  ),
                  autocorrect: false,
                  enabled: !_busy,
                  validator: (String? v) =>
                      (v ?? '').trim().isEmpty ? 'Enter a username' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtrl,
                  decoration: InputDecoration(
                    labelText: 'Navidrome password',
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  obscureText: _obscure,
                  enabled: !_busy,
                  validator: (String? v) =>
                      (v ?? '').isEmpty ? 'Enter the password' : null,
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: _busy ? null : _testConnection,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Test connection'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
