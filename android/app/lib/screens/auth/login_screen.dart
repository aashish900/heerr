import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_error.dart';
import '../../api/auth_login.dart';
import '../../models/profile.dart';
import '../../providers/profiles/profile_registry.dart';
import '../../router.dart';
import '../../widgets/error_snackbar.dart';

/// First-launch / add-profile screen. Collects {heerr base URL,
/// Navidrome username, Navidrome password}, calls [authLogin] (S4), and
/// on success persists the resulting [Profile] into the
/// [profileRegistryProvider] and marks it active. Navigates to `/` on
/// success.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _baseUrlCtrl = TextEditingController();
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _submitting = false;
  bool _obscure = true;

  @override
  void dispose() {
    _baseUrlCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final AuthLoginResponse res = await authLogin(
        baseUrl: _baseUrlCtrl.text.trim(),
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      final DateTime now = DateTime.now().toUtc();
      final Profile profile = Profile(
        id: _newId(),
        displayName: res.navidromeUsername,
        heerrBaseUrl: _baseUrlCtrl.text.trim(),
        heerrBearerToken: res.token,
        navidromeBaseUrl: res.navidromeUrl,
        navidromeUsername: res.navidromeUsername,
        navidromePassword: _passwordCtrl.text,
        createdAt: now,
        lastUsedAt: now,
      );
      await ref.read(profileRegistryProvider.notifier).addProfile(profile);
      await ref.read(profileRegistryProvider.notifier).setActive(profile.id);
      if (!mounted) return;
      context.go(Routes.home);
    } on ApiError catch (e) {
      if (!mounted) return;
      showApiError(context, e, action: 'sign in');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Sign in to your heerr backend with your Navidrome '
                  'credentials. The backend forwards the check to '
                  'Navidrome and mints a token on success.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _baseUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'heerr base URL',
                    hintText: 'http://100.x.y.z:8000/api/v1',
                  ),
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  enabled: !_submitting,
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
                  enabled: !_submitting,
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
                  enabled: !_submitting,
                  validator: (String? v) =>
                      (v ?? '').isEmpty ? 'Enter the password' : null,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _newId() {
  final Random rng = Random.secure();
  final List<int> bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0F) | 0x40;
  bytes[8] = (bytes[8] & 0x3F) | 0x80;
  String hex(int b) => b.toRadixString(16).padLeft(2, '0');
  final String h = bytes.map(hex).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
      '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}
