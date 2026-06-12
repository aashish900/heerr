/// Template for `dev_defaults.dart` — copy this file to
/// `lib/dev_defaults.dart` (already gitignored) and fill in your own
/// values. The values populate the "Add server" form's text fields on a
/// fresh install so you don't retype the same URLs on every reinstall.
///
/// Nothing in this file should ever land in committed code besides the
/// `null` placeholders below — your real values live only in the
/// gitignored copy.
class DevDefaults {
  /// Pre-fills the "Server name" field. Null → field stays blank.
  static const String? serverName = null;

  /// Pre-fills "Backend URL". Null → blank.
  static const String? backendBaseUrl = null;

  /// Pre-fills "Navidrome URL". Null → blank.
  static const String? navidromeBaseUrl = null;

  /// Pre-fills "Navidrome username". Null → blank.
  static const String? navidromeUsername = null;
}
