import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/models/enums.dart';
import 'package:heerr/models/job_view.dart';

// PC4 (#53): regression coverage for the ContentType widening — before this,
// GET /queue or /status/{id} would throw ResponseValidationError-equivalent
// (json_serializable CheckedFromJsonException) on any episode job, since
// ContentType had no 'episode' JsonValue. Mirrors the backend-side
// JobView.source_type Literal fix from P5.
void main() {
  test('JobView.fromJson round-trips a source_type == "episode" job', () {
    final Map<String, dynamic> json = <String, dynamic>{
      'job_id': 'j1',
      'source_url': 'https://ex.com/e1.mp3',
      'source_type': 'episode',
      'state': 'queued',
      'display_name': 'Episode One',
      'created_at': '2026-07-20T00:00:00Z',
    };

    final JobView job = JobView.fromJson(json);

    expect(job.sourceType, ContentType.episode);
    expect(job.toJson()['source_type'], 'episode');
  });
}
