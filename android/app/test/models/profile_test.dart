import 'package:flutter_test/flutter_test.dart';
import 'package:heerr/models/profile.dart';

void main() {
  group('Profile', () {
    final Profile sample = Profile(
      id: '11111111-2222-3333-4444-555555555555',
      displayName: 'alice',
      heerrBaseUrl: 'http://100.64.0.1:8000',
      heerrBearerToken: 'tok-abc-123',
      navidromeBaseUrl: 'http://100.64.0.1:4533',
      navidromeUsername: 'alice',
      navidromePassword: 'hunter2',
      createdAt: DateTime.utc(2026, 6, 17, 10, 0, 0),
      lastUsedAt: DateTime.utc(2026, 6, 17, 12, 30, 0),
    );

    test('round-trips fromJson(toJson()) == self', () {
      final Map<String, dynamic> json = sample.toJson();
      final Profile parsed = Profile.fromJson(json);
      expect(parsed, sample);
    });

    test('copyWith replaces only the named field', () {
      final Profile renamed = sample.copyWith(displayName: 'alice-laptop');
      expect(renamed.displayName, 'alice-laptop');
      expect(renamed.id, sample.id);
      expect(renamed.heerrBearerToken, sample.heerrBearerToken);
      expect(renamed.navidromeUsername, sample.navidromeUsername);
      expect(renamed.createdAt, sample.createdAt);
      expect(renamed.lastUsedAt, sample.lastUsedAt);
    });

    test('copyWith updates lastUsedAt independently', () {
      final DateTime later = DateTime.utc(2026, 6, 18, 9, 0, 0);
      final Profile bumped = sample.copyWith(lastUsedAt: later);
      expect(bumped.lastUsedAt, later);
      expect(bumped.createdAt, sample.createdAt);
      // Equality is value-based; everything else unchanged.
      expect(bumped.copyWith(lastUsedAt: sample.lastUsedAt), sample);
    });

    test('value equality — two Profiles with identical fields are equal', () {
      final Profile twin = Profile(
        id: sample.id,
        displayName: sample.displayName,
        heerrBaseUrl: sample.heerrBaseUrl,
        heerrBearerToken: sample.heerrBearerToken,
        navidromeBaseUrl: sample.navidromeBaseUrl,
        navidromeUsername: sample.navidromeUsername,
        navidromePassword: sample.navidromePassword,
        createdAt: sample.createdAt,
        lastUsedAt: sample.lastUsedAt,
      );
      expect(twin, sample);
      expect(twin.hashCode, sample.hashCode);
    });
  });
}
