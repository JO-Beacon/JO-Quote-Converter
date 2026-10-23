import 'markdown_code_mask.dart';

/// Converts half-width English colons to the Chinese full-width colon.
class ColonConverter {
  const ColonConverter._();

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
      if (protected[index] || character != ':') {
        output.write(character);
        continue;
      }

      if (useHeuristics && _shouldKeepColon(input, protected, index)) {
        output.write(character);
        continue;
      }

      output.write('：');
    }

    return output.toString();
  }

  /// Keeps ASCII colons that are likely part of a URL scheme (`http://`),
  /// a time or ratio (`12:30`, `16:9`), or a Windows drive path (`C:\`).
  static bool _shouldKeepColon(String input, List<bool> protected, int index) {
    final previousIndex = _previousUnprotectedIndex(input, protected, index);
    final nextIndex = _nextUnprotectedIndex(input, protected, index);
    if (nextIndex == null) return false;

    final previous = previousIndex == null ? null : input[previousIndex];
    final next = input[nextIndex];

    if (next == '/') {
      final secondIndex = _nextUnprotectedIndex(input, protected, nextIndex);
      if (secondIndex != null && input[secondIndex] == '/') return true;
    }
    if (_isDigit(previous) && _isDigit(next)) return true;
    if (_isAsciiLetter(previous) && (next == '\\' || next == '/')) return true;

    return false;
  }

  static int? _previousUnprotectedIndex(
    String input,
    List<bool> protected,
    int index,
  ) {
    for (var cursor = index - 1; cursor >= 0; cursor--) {
      if (!protected[cursor]) return cursor;
    }
    return null;
  }

  static int? _nextUnprotectedIndex(
    String input,
    List<bool> protected,
    int index,
  ) {
    for (var cursor = index + 1; cursor < input.length; cursor++) {
      if (!protected[cursor]) return cursor;
    }
    return null;
  }

  static bool _isDigit(String? character) {
    return character != null && RegExp(r'[0-9]').hasMatch(character);
  }

  static bool _isAsciiLetter(String? character) {
    return character != null && RegExp(r'[A-Za-z]').hasMatch(character);
  }
}
