import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:heerr/providers/library/library_search_query.dart';

void main() {
  test('initial state is empty', () {
    final ProviderContainer c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(librarySearchQueryProvider), '');
  });

  test('set updates the value', () {
    final ProviderContainer c = ProviderContainer();
    addTearDown(c.dispose);

    c.read(librarySearchQueryProvider.notifier).set('tame impala');
    expect(c.read(librarySearchQueryProvider), 'tame impala');
  });

  test('clear resets to empty', () {
    final ProviderContainer c = ProviderContainer();
    addTearDown(c.dispose);

    c.read(librarySearchQueryProvider.notifier).set('whatever');
    c.read(librarySearchQueryProvider.notifier).clear();
    expect(c.read(librarySearchQueryProvider), '');
  });
}
