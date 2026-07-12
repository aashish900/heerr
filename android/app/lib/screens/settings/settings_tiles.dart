import 'package:flutter/material.dart';

import '../../theme.dart';

/// Small uppercase-ish label rendered above a [SettingsGroupCard]
/// (SETTINGSSCREEN.md SE2 — "Downloads & Storage", "Server & Sync", ...).
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// Floating rounded card grouping related [SettingsTile]-family rows, with a
/// thin divider between rows (none trailing/leading). Same visual language
/// as the Downloads hero card: `surfaceContainerHigh` fill, soft outline, no
/// heavy borders (SETTINGSSCREEN.md §5).
class SettingsGroupCard extends StatelessWidget {
  const SettingsGroupCard({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        clipBehavior: Clip.antiAlias,
        // Plain `ListTile`s nested inside `children` (ProfilesSection,
        // _RecommendationsSection) paint their ink/selection on the nearest
        // Material ancestor. Without this explicit transparent Material,
        // Flutter's debug assertion flags the DecoratedBox above as hiding
        // that ink — give them a Material surface between the decoration
        // and the tiles.
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int i = 0; i < children.length; i++) ...<Widget>[
                if (i > 0) const Divider(height: 1, indent: 20, endIndent: 20),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Derives the `settings-tile-<slug>` test key from a row title: lowercase,
/// non-alphanumerics collapsed to single dashes, no leading/trailing dash.
Key settingsTileKey(String title) {
  final String slug = title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return Key('settings-tile-$slug');
}

/// Base row for the settings tile system: leading icon, title, optional
/// subtitle, optional accent-colored value, and a chevron when [onTap] is
/// set and no custom [trailing] is supplied. Min height 56dp (>=48dp
/// accessibility target).
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
    this.trailing,
    this.iconColor,
    this.titleColor,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// Overrides for destructive rows (e.g. "Clear all downloads"). Default to
  /// the theme's magenta accent when unset.
  final Color? iconColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Widget? effectiveTrailing = trailing ??
        (onTap != null
            ? Icon(Icons.chevron_right, color: cs.onSurfaceVariant)
            : null);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: settingsTileKey(title),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: <Widget>[
                Icon(icon, color: iconColor ?? heerrMagenta),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: titleColor,
                            ),
                      ),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (value != null) ...<Widget>[
                  const SizedBox(width: 8),
                  Text(
                    value!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: heerrMagenta,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
                if (effectiveTrailing != null) ...<Widget>[
                  const SizedBox(width: 4),
                  effectiveTrailing,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// [SettingsTile] anatomy with a trailing [Switch] instead of a chevron.
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: Switch(value: value, onChanged: onChanged),
      onTap: () => onChanged(!value),
    );
  }
}

/// [SettingsTile] anatomy with a trailing [DropdownButton] instead of a
/// chevron.
class SettingsDropdownTile<T> extends StatelessWidget {
  const SettingsDropdownTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
    this.subtitle,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final T value;
  final List<T> items;
  final String Function(T) labelBuilder;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: DropdownButton<T>(
        value: value,
        underline: const SizedBox.shrink(),
        onChanged: (T? v) {
          if (v != null) onChanged(v);
        },
        items: <DropdownMenuItem<T>>[
          for (final T item in items)
            DropdownMenuItem<T>(value: item, child: Text(labelBuilder(item))),
        ],
      ),
    );
  }
}
