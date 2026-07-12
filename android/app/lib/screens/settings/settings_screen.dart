import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/recommend_health.dart';
import '../../providers/app_version.dart';
import '../../offline/offline_manifest.dart';
import '../../offline/offline_paths.dart';
import '../../offline/offline_settings.dart';
import '../../offline/offline_size_estimator.dart';
import '../../providers/recommendations.dart';
import '../../providers/server_creds.dart';
import '../../theme.dart';
import '../../widgets/branded_header.dart';
import '../../widgets/error_snackbar.dart';
import 'profile_card.dart';
import 'profiles_section.dart';
import 'server_sync_card.dart';
import 'settings_tiles.dart';

// A17: the recommendations-health + offline-downloads sections live in sibling
// part files to keep this screen file readable (shared imports + privacy).
part 'settings_recommendations.dart';
part 'settings_offline.dart';

/// Settings screen — "Control Center" redesign (docs/SETTINGSSCREEN.md,
/// SE1-SE6). Shares the `BrandedAppBar` + headline/subtitle shell
/// established by Home/Library/Downloads. D2: no greeting — the default
/// (non-compact) `BrandedAppBar` renders the logo mark + wordmark only, same
/// as Home. D5: every section is a flat, always-visible `SettingsGroupCard`
/// under a `SettingsSectionHeader` — no collapsible `ExpansionTile`s.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh recommendation-engine health when the screen opens. The
    // notifier no-ops when the cached payload is < 60 s old, so rapid
    // open/close cycles don't thrash the backend.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(recommendHealthNotifierProvider.notifier).refreshIfStale();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BrandedAppBar(),
      body: CustomScrollView(
        slivers: <Widget>[
          const SliverToBoxAdapter(child: _SettingsTitle()),
          // A1: the legacy "Servers" tile + screen are gone. Profiles are the
          // single credential surface — added via /login (Phase S) and
          // managed in ProfilesSection.
          const SliverToBoxAdapter(child: ProfileCard()),
          const SliverToBoxAdapter(child: SettingsSectionHeader('Server & Sync')),
          const SliverToBoxAdapter(child: ServerSyncCard()),
          SliverList(
            delegate: SliverChildListDelegate(const <Widget>[
              SettingsSectionHeader('Profiles'),
              SettingsGroupCard(children: <Widget>[ProfilesSection()]),
              SettingsSectionHeader('Downloads & Storage'),
              _OfflineSection(),
              SettingsSectionHeader('Recommendations'),
              SettingsGroupCard(children: <Widget>[_RecommendationsSection()]),
              _AppVersionTile(),
            ]),
          ),
        ],
      ),
    );
  }
}

/// Headline + subtitle, same visual pattern as Downloads' `_DownloadsTitle`.
class _SettingsTitle extends StatelessWidget {
  const _SettingsTitle();

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Settings',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Customize heerr the way you like.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

/// #36: app-version footer at the bottom of Settings. Reads the installed
/// APK's versionName/versionCode via [appVersionProvider]; renders nothing
/// while loading and on error (a version line is nice-to-have, never worth
/// an error surface).
class _AppVersionTile extends ConsumerWidget {
  const _AppVersionTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? version = ref.watch(appVersionProvider).valueOrNull;
    if (version == null) return const SizedBox.shrink();
    return ListTile(
      key: const Key('settings-app-version'),
      leading: const Icon(Icons.info_outline, color: heerrMagenta),
      title: const Text(
        'App version',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(version),
    );
  }
}
