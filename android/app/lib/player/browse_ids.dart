/// Stable ids for the Android Auto browse tree.
///
/// `MediaItem.id` for queued songs is the playback URL (with auth params),
/// so the car-facing tree needs its own ids. Encoded form:
///
///   `root` | `<tab>` | `<album|artist|playlist>:<id>` | `[<parent>/]song:<id>`
///
/// A song carries its parent container so `playFromMediaId` can queue the
/// whole album/playlist starting at that song. Entity ids are
/// percent-encoded, so any Subsonic id round-trips.
enum BrowseKind {
  root,
  recents,
  favourites,
  playlists,
  albums,
  artists,
  downloaded,
  album,
  artist,
  playlist,
  song;

  bool get hasId => index >= BrowseKind.album.index;
}

class BrowseId {
  /// Must equal `AudioService.browsableRootId`.
  static const root = BrowseId(BrowseKind.root);

  final BrowseKind kind;
  final String? id;

  /// Containing browse node; only set on songs.
  final BrowseId? parent;

  const BrowseId(this.kind, [this.id, this.parent]);

  String get _segment =>
      kind.hasId ? '${kind.name}:${Uri.encodeComponent(id!)}' : kind.name;

  String get encoded =>
      parent == null ? _segment : '${parent!._segment}/$_segment';

  /// Returns null for anything [encoded] could not have produced.
  static BrowseId? tryParse(String s) {
    final parts = s.split('/');
    if (parts.length > 2) return null;
    final self = _parseSegment(parts.last);
    if (self == null) return null;
    if (parts.length == 1) return self;
    final parent = _parseSegment(parts.first);
    if (self.kind != BrowseKind.song ||
        parent == null ||
        parent.kind == BrowseKind.root ||
        parent.kind == BrowseKind.song) {
      return null;
    }
    return BrowseId(self.kind, self.id, parent);
  }

  static BrowseId? _parseSegment(String s) {
    final i = s.indexOf(':');
    final name = i < 0 ? s : s.substring(0, i);
    final kind = BrowseKind.values.asNameMap()[name];
    if (kind == null) return null;
    if (!kind.hasId) return i < 0 ? BrowseId(kind) : null;
    if (i < 0 || i == s.length - 1) return null;
    try {
      return BrowseId(kind, Uri.decodeComponent(s.substring(i + 1)));
    } on ArgumentError {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is BrowseId &&
      other.kind == kind &&
      other.id == id &&
      other.parent == parent;

  @override
  int get hashCode => Object.hash(kind, id, parent);

  @override
  String toString() => 'BrowseId($encoded)';
}
