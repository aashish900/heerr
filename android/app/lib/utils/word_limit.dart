import 'package:flutter/services.dart';

/// Whitespace-separated word count. Empty / whitespace-only text is 0.
int countWords(String text) {
  final String trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  return trimmed.split(RegExp(r'\s+')).length;
}

/// Rejects edits that would push the field past [maxWords] (#37 — the Bio
/// field's 100-word cap). Deletions and edits at/under the limit pass
/// through untouched; an over-limit edit keeps the previous value.
class WordLimitTextInputFormatter extends TextInputFormatter {
  WordLimitTextInputFormatter(this.maxWords);

  final int maxWords;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (countWords(newValue.text) <= maxWords) return newValue;
    return oldValue;
  }
}
