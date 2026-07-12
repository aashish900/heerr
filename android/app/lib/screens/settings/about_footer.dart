import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/app_version.dart';
import 'settings_tiles.dart';

const String _kGithubUrl = 'https://github.com/aashish900/heerr';

/// About-heerr footer (SETTINGSSCREEN.md SE7) — app version (existing
/// `appVersionProvider`, key `settings-app-version` preserved from the old
/// `_AppVersionTile`), open-source licenses (Flutter's built-in
/// `showLicensePage`), a GitHub link, and a closing tagline. No Privacy
/// Policy / Terms rows — no such documents exist (D1: don't ship dead
/// links).
class AboutFooter extends ConsumerWidget {
  const AboutFooter({this.onGithubTap, super.key});

  /// Overridable for widget tests — production default opens [_kGithubUrl]
  /// via `url_launcher`, which needs a platform channel tests don't have.
  final VoidCallback? onGithubTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? version = ref.watch(appVersionProvider).valueOrNull;
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SettingsSectionHeader('About'),
        SettingsGroupCard(
          children: <Widget>[
            if (version != null)
              SettingsTile(
                key: const Key('settings-app-version'),
                icon: Icons.info_outline,
                title: 'App version',
                subtitle: version,
              ),
            SettingsTile(
              icon: Icons.description_outlined,
              title: 'Open source licenses',
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'heerr',
                applicationVersion: version,
              ),
            ),
            SettingsTile(
              icon: Icons.code,
              title: 'GitHub',
              onTap: onGithubTap ?? _launchGithub,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'Made for self-hosted music lovers',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _launchGithub() async {
    final Uri uri = Uri.parse(_kGithubUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
