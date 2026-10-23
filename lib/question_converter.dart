import 'markdown_code_mask.dart';

/// Converts half-width English question marks to the Chinese full-width
/// question mark.
///
/// Unlike the other converters this one has no heuristic exceptions: a
/// sequence such as `??` is common in ordinary text, so every half-width
/// question mark is converted (unless it is inside Markdown code).
class QuestionConverter {
  const QuestionConverter._();

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
      if (protected[index] || character != '?') {
        output.write(character);
        continue;
      }
      output.write('？');
    }

    return output.toString();
  }
}
