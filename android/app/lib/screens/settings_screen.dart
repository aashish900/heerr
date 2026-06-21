import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recommend_health.dart';
import '../offline/offline_manifest.dart';
import '../offline/offline_paths.dart';
import '../offline/offline_settings.dart';
import '../offline/offline_size_estimator.dart';
import '../offline/offline_sync.dart';
import '../providers/recommendations.dart';
import '../providers/server_creds.dart';
import '../theme.dart';
import '../widgets/error_snackbar.dart';
import 'settings/profiles_section.dart';

// A17: the recommendations-health + offline-downloads sections live in sibling
// part files to keep this screen file readable (shared imports + privacy).
part 'settings_recommendations.dart';
part 'settings_offline.dart';

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
      appBar: AppBar(title: const Text('Settings')),
      // A1: the legacy "Servers" tile + screen are gone. Profiles are the
      // single credential surface — added via /login (Phase S) and managed
      // in ProfilesSection.
      body: ListView(
        children: const <Widget>[
          // #17: each section is collapsible to keep the screen uncluttered.
          // Profiles (the primary credential surface) stays open by default;
          // the heavier Offline + Recommendations sections start collapsed.
          _CollapsibleSection(
            icon: Icons.people_outline,
            title: 'Profiles',
            initiallyExpanded: true,
            child: ProfilesSection(),
          ),
          _CollapsibleSection(
            icon: Icons.download_for_offline_outlined,
            title: 'Offline downloads',
            child: _OfflineSection(),
          ),
          _CollapsibleSection(
            icon: Icons.recommend_outlined,
            title: 'Recommendations',
            child: _RecommendationsSection(),
          ),
        ],
      ),
    );
  }
}

/// #17: a collapsible settings section. Wraps [child] in an [ExpansionTile]
/// with a leading [icon] + bold [title]. Keyed `settings-section-<title>` so
/// widget tests can target the header. Collapsed by default unless
/// [initiallyExpanded].
class _CollapsibleSection extends StatelessWidget {
  const _CollapsibleSection({
    required this.icon,
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: Key('settings-section-$title'),
      leading: Icon(icon),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      initiallyExpanded: initiallyExpanded,
      shape: const Border(),
      collapsedShape: const Border(),
      childrenPadding: EdgeInsets.zero,
      children: <Widget>[child],
    );
  }
}
