import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_error.dart';
import '../../models/subsonic/album.dart';
import '../../models/subsonic/artist.dart';
import '../../player/playback_actions.dart';
import '../../providers/library/library_artist.dart';
import '../../router.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/library_result_tile.dart';
import '../../widgets/skeleton.dart';

/// Artist detail. Renders the artist's album list as tap-to-open library
/// tiles. No cover/header art at I1 — artists don't always carry one and
/// the header is K1 polish.
class ArtistDetailScreen extends ConsumerWidget {
  const ArtistDetailScreen({required this.artistId, super.key});

  final String artistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Artist> async =
        ref.watch(libraryArtistProvider(artistId));

    return Scaffold(
      appBar: AppBar(
        title: Text(async.maybeWhen<String>(
          data: (Artist a) => a.name,
          orElse: () => 'Artist',
        )),
      ),
      body: async.when(
        loading: () => const SkeletonList(count: 4),
        error: (Object e, _) => Center(
          child: Text(e is ApiError ? e.message : 'Error: $e'),
        ),
        data: (Artist a) {
          if (a.album.isEmpty) {
            return const EmptyState(
              icon: Icons.album_outlined,
              title: 'No albums',
              subtitle: 'This artist has no albums in your library.',
            );
          }
          return ListView.builder(
            itemCount: a.album.length,
            itemBuilder: (BuildContext c, int i) {
              final Album album = a.album[i];
              return LibraryResultTile(
                title: album.name,
                subtitle: album.year == null ? null : '${album.year}',
                coverArtId: album.coverArt,
                trailingPlay: true,
                onPlay: () =>
                    playAlbumFromSubsonic(ref, context, album.id),
                onTap: () => context.push(Routes.libraryAlbum(album.id)),
              );
            },
          );
        },
      ),
    );
  }
}
