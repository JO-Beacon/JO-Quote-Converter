import 'markdown_code_mask.dart';

/// Converts half-width English commas to the Chinese full-width comma.
class CommaConverter {
  const CommaConverter._();

  static String convert(
    String input, {
    bool excludeMarkdownCode = true,
    bool useHeuristics = true,
  }) {
    if (input.isEmpty) return input;

    final protected = excludeMarkdownCode
        ? MarkdownCodeMask.build(input)
        : List<bool>.filled(input.length, false);
    final output = StringBuffer();

    for (var index = 0; index < input.length; index++) {
      final character = input[index];
      if (protected[index] || character != ',') {
        output.write(character);
        continue;
      }

      if (useHeuristics && _isThousandsSeparator(input, protected, index)) {
        output.write(character);
        continue;
      }

      output.write('，');
    }

    return output.toString();
  }

  /// Keeps ASCII commas that look like digit group separators, such as
  /// `1,000` or `12,345,678`.
  static bool _isThousandsSeparator(
    String input,
    List<bool> protected,
    int index,
  ) {
    var left = index - 1;
    while (left >= 0 && protected[left]) {
      left--;
    }
    if (!_isDigit(left >= 0 ? input[left] : null)) return false;

    // The leading group must contain one to three digits.
    var leadingDigits = 0;
    var cursor = left;
    while (cursor >= 0 && !protected[cursor] && _isDigit(input[cursor])) {
      leadingDigits++;
      cursor--;
    }
    if (leadingDigits > 3) return false;

    var right = index + 1;
    while (right < input.length && protected[right]) {
      right++;
    }

    // The trailing group must contain exactly three digits.
    var trailingDigits = 0;
    while (right < input.length &&
        !protected[right] &&
        _isDigit(input[right])) {
      trailingDigits++;
      right++;
    }
    if (trailingDigits != 3) return false;

    // A fourth digit after the group means this is not a thousands separator.
    while (right < input.length && protected[right]) {
      right++;
    }
    return right >= input.length || !_isDigit(input[right]);
  }

  static bool _isDigit(String? character) {
    return character != null && RegExp(r'[0-9]').hasMatch(character);
  }
}
