import 'package:flutter_test/flutter_test.dart';
import 'package:heerr/utils/word_limit.dart';

TextEditingValue _v(String text) => TextEditingValue(text: text);

void main() {
  group('countWords', () {
    test('empty and whitespace-only count as zero', () {
      expect(countWords(''), 0);
      expect(countWords('   '), 0);
      expect(countWords('\n\t '), 0);
    });

    test('counts whitespace-separated words', () {
      expect(countWords('one'), 1);
      expect(countWords('one two three'), 3);
      expect(countWords('  padded   out\nacross\tlines '), 4);
    });
  });

  group('WordLimitTextInputFormatter', () {
    final WordLimitTextInputFormatter fmt = WordLimitTextInputFormatter(3);

    test('allows edits at or under the limit', () {
      final TextEditingValue out =
          fmt.formatEditUpdate(_v('one two'), _v('one two three'));
      expect(out.text, 'one two three');
    });

    test('rejects edits that exceed the limit', () {
      final TextEditingValue out =
          fmt.formatEditUpdate(_v('one two three'), _v('one two three four'));
      expect(out.text, 'one two three');
    });

    test('always allows deletions', () {
      final TextEditingValue out =
          fmt.formatEditUpdate(_v('one two three'), _v('one two'));
      expect(out.text, 'one two');
    });
  });
}
