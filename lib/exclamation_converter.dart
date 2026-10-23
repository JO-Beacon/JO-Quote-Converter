import 'markdown_code_mask.dart';

/// Converts half-width English exclamation marks to the Chinese full-width
/// exclamation mark.
class ExclamationConverter {
  const ExclamationConverter._();

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
      if (protected[index] || character != '!') {
        output.write(character);
        continue;
      }

      if (useHeuristics && _isOperator(input, protected, index)) {
        output.write(character);
        continue;
      }

      output.write('！');
    }

    return output.toString();
  }

  /// Keeps ASCII exclamation marks that start an operator such as `!=` or
  /// `!==`.
  static bool _isOperator(String input, List<bool> protected, int index) {
    for (var cursor = index + 1; cursor < input.length; cursor++) {
      if (protected[cursor]) continue;
      return input[cursor] == '=';
    }
    return false;
  }
}
