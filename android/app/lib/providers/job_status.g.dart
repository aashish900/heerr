// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_status.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$jobStatusPollIntervalHash() =>
    r'e72ae02beb1d8aeeb88731f94046f7fd31465385';

/// Polling interval for `GET /status/{id}`. Default 2s per PLAN.md §8;
/// exposed as a provider so tests override to short durations.
///
/// Copied from [jobStatusPollInterval].
@ProviderFor(jobStatusPollInterval)
final jobStatusPollIntervalProvider = Provider<Duration>.internal(
  jobStatusPollInterval,
  name: r'jobStatusPollIntervalProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$jobStatusPollIntervalHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef JobStatusPollIntervalRef = ProviderRef<Duration>;
String _$jobStatusHash() => r'54022e83d35e82bd9bd12a5aecf2d3b87ffffb7c';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$JobStatus extends BuildlessAutoDisposeAsyncNotifier<JobView> {
  late final String jobId;

  FutureOr<JobView> build(String jobId);
}

/// Polls `GET /status/{jobId}` every 2s **while the job state is
/// non-terminal**, stops once `state ∈ {done, failed}`. Auto-disposes when
/// the last listener detaches (the screen) so navigating away cancels the
/// in-flight poll cycle.
///
/// Family argument is the `jobId` (UUID string). Two open job-detail
/// screens for different jobs would each get their own provider instance.
///
/// Copied from [JobStatus].
@ProviderFor(JobStatus)
const jobStatusProvider = JobStatusFamily();

/// Polls `GET /status/{jobId}` every 2s **while the job state is
/// non-terminal**, stops once `state ∈ {done, failed}`. Auto-disposes when
/// the last listener detaches (the screen) so navigating away cancels the
/// in-flight poll cycle.
///
/// Family argument is the `jobId` (UUID string). Two open job-detail
/// screens for different jobs would each get their own provider instance.
///
/// Copied from [JobStatus].
class JobStatusFamily extends Family<AsyncValue<JobView>> {
  /// Polls `GET /status/{jobId}` every 2s **while the job state is
  /// non-terminal**, stops once `state ∈ {done, failed}`. Auto-disposes when
  /// the last listener detaches (the screen) so navigating away cancels the
  /// in-flight poll cycle.
  ///
  /// Family argument is the `jobId` (UUID string). Two open job-detail
  /// screens for different jobs would each get their own provider instance.
  ///
  /// Copied from [JobStatus].
  const JobStatusFamily();

  /// Polls `GET /status/{jobId}` every 2s **while the job state is
  /// non-terminal**, stops once `state ∈ {done, failed}`. Auto-disposes when
  /// the last listener detaches (the screen) so navigating away cancels the
  /// in-flight poll cycle.
  ///
  /// Family argument is the `jobId` (UUID string). Two open job-detail
  /// screens for different jobs would each get their own provider instance.
  ///
  /// Copied from [JobStatus].
  JobStatusProvider call(String jobId) {
    return JobStatusProvider(jobId);
  }

  @override
  JobStatusProvider getProviderOverride(covariant JobStatusProvider provider) {
    return call(provider.jobId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'jobStatusProvider';
}

/// Polls `GET /status/{jobId}` every 2s **while the job state is
/// non-terminal**, stops once `state ∈ {done, failed}`. Auto-disposes when
/// the last listener detaches (the screen) so navigating away cancels the
/// in-flight poll cycle.
///
/// Family argument is the `jobId` (UUID string). Two open job-detail
/// screens for different jobs would each get their own provider instance.
///
/// Copied from [JobStatus].
class JobStatusProvider
    extends AutoDisposeAsyncNotifierProviderImpl<JobStatus, JobView> {
  /// Polls `GET /status/{jobId}` every 2s **while the job state is
  /// non-terminal**, stops once `state ∈ {done, failed}`. Auto-disposes when
  /// the last listener detaches (the screen) so navigating away cancels the
  /// in-flight poll cycle.
  ///
  /// Family argument is the `jobId` (UUID string). Two open job-detail
  /// screens for different jobs would each get their own provider instance.
  ///
  /// Copied from [JobStatus].
  JobStatusProvider(String jobId)
    : this._internal(
        () => JobStatus()..jobId = jobId,
        from: jobStatusProvider,
        name: r'jobStatusProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$jobStatusHash,
        dependencies: JobStatusFamily._dependencies,
        allTransitiveDependencies: JobStatusFamily._allTransitiveDependencies,
        jobId: jobId,
      );

  JobStatusProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.jobId,
  }) : super.internal();

  final String jobId;

  @override
  FutureOr<JobView> runNotifierBuild(covariant JobStatus notifier) {
    return notifier.build(jobId);
  }

  @override
  Override overrideWith(JobStatus Function() create) {
    return ProviderOverride(
      origin: this,
      override: JobStatusProvider._internal(
        () => create()..jobId = jobId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        jobId: jobId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<JobStatus, JobView> createElement() {
    return _JobStatusProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is JobStatusProvider && other.jobId == jobId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, jobId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin JobStatusRef on AutoDisposeAsyncNotifierProviderRef<JobView> {
  /// The parameter `jobId` of this provider.
  String get jobId;
}

class _JobStatusProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<JobStatus, JobView>
    with JobStatusRef {
  _JobStatusProviderElement(super.provider);

  @override
  String get jobId => (origin as JobStatusProvider).jobId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
