import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/subsonic_client.dart';
import '../providers/settings.dart';

/// Renders a Subsonic `coverArt` image. Composes the auth-tokenised
/// `/rest/getCoverArt.view?...` URL from the current settings and hands it
/// to `Image.network`. Falls back to a neutral music-note placeholder when:
///   * no coverArtId is provided (e.g. an album with no embedded art),
///   * navidromeBaseUrl / navidromeUsername / navidromePassword is null
///     (the user hasn't configured Navidrome yet),
///   * the network fetch errors out (errorBuilder).
class LibraryCoverArt extends ConsumerWidget {
  const LibraryCoverArt({
    required this.coverArtId,
    this.size = 56,
    this.borderRadius = 4,
    super.key,
  });

  final String? coverArtId;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? id = coverArtId;
    if (id == null || id.isEmpty) {
      return _placeholder(context);
    }
    final SettingsValue? settings = ref.watch(settingsProvider).valueOrNull;
    final String? baseUrl = settings?.navidromeBaseUrl;
    final String? user = settings?.navidromeUsername;
    final String? pass = settings?.navidromePassword;
    if (baseUrl == null || baseUrl.isEmpty ||
        user == null || user.isEmpty ||
        pass == null || pass.isEmpty) {
      return _placeholder(context);
    }
    final String url = buildSubsonicCoverArtUrl(
      baseUrl: baseUrl,
      username: user,
      password: pass,
      coverArtId: id,
      size: size.toInt(),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (BuildContext c, _, _) => _placeholder(c),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(Icons.music_note, color: cs.onSurfaceVariant),
    );
  }
}
