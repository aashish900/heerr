/// Backend endpoint paths. Joined onto the user-supplied `backendBaseUrl`
/// (which already includes `/api/v1`), so paths here are bare.
class Endpoints {
  const Endpoints._();

  static const String health = '/health';
  static const String search = '/search';
  static const String download = '/download';
  static const String queue = '/queue';

  static String status(String jobId) => '/status/$jobId';
}
