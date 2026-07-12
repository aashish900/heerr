import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

/// True when [item] is an online-search *preview* stream (Phase T) rather than a
/// library track — i.e. it was built by `searchResultToMediaItem`, which stamps
/// `extras['preview'] == true`.
bool isPreviewMediaItem(MediaItem? item) => item?.extras?['preview'] == true;

/// Small "Preview" pill shown on the mini-player and Now Playing while the
/// current track is a preview stream (not yet downloaded into the library).
/// Colours default to the theme's primary container; the mini-player passes
/// white-on-translucent so it reads against the cover-tinted bar.
class PreviewBadge extends StatelessWidget {
  const PreviewBadge({this.background, this.foreground, super.key});

  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background ?? cs.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Preview',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground ?? cs.onPrimaryContainer,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}
