import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_error.dart';
import '../api/client.dart';
import '../api/endpoints.dart';
import '../providers/settings.dart';
import '../widgets/error_snackbar.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  bool _populated = false;
  bool _testing = false;

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  // Strip trailing slashes from the URL so callers don't end up with paths
  // like "...//health" (per `docs/PLAN.md` §4).
  String _normalizeUrl(String raw) => raw.trim().replaceAll(RegExp(r'/+$'), '');

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

  String? _validateToken(String? value) {
    if ((value ?? '').trim().isEmpty) return 'required';
    return null;
  }

  // Persist current field values without showing user-facing feedback.
  // Used by both buttons: _save() then displays a snackbar; _testConnection()
  // skips the snackbar and runs the request.
  Future<bool> _persist() async {
    if (!(_formKey.currentState?.validate() ?? false)) return false;
    final String url = _normalizeUrl(_urlController.text);
    final String token = _tokenController.text.trim();
    _urlController.text = url; // reflect normalisation in the field
    await ref.read(settingsProvider.notifier).save(
          backendBaseUrl: url,
          bearerToken: token,
        );
    return true;
  }

  Future<void> _save() async {
    if (!await _persist()) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved')),
    );
  }

  Future<void> _testConnection() async {
    setState(() => _testing = true);
    try {
      if (!await _persist()) return;
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
      // The user is already on /settings — suppress the auto-redirect that
      // showApiError() would trigger for 401 (it'd be a no-op anyway, but
      // calling it shouldn't surprise readers). For all other ApiErrors,
      // show the standard mapped snackbar.
      showApiError(context, e);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  // First time the AsyncValue settles, pre-fill the fields. Subsequent
  // provider invalidations (e.g. after Save) intentionally don't overwrite
  // what the user is typing.
  void _maybePopulateFields(SettingsValue v) {
    if (_populated) return;
    _urlController.text = v.backendBaseUrl ?? '';
    _tokenController.text = v.bearerToken ?? '';
    _populated = true;
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<SettingsValue> settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object err, _) => Center(child: Text('Storage error: $err')),
        data: (SettingsValue v) {
          _maybePopulateFields(v);
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
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
                    helperText:
                        'Output of: python -m app.cli create-token --owner=phone …',
                    border: OutlineInputBorder(),
                  ),
                  autocorrect: false,
                  obscureText: true,
                  validator: _validateToken,
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
                      child: FilledButton.tonal(
                        onPressed: _testing ? null : _testConnection,
                        child: _testing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Test connection'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
