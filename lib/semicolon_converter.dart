import 'markdown_code_mask.dart';

/// Converts half-width English semicolons to the Chinese full-width semicolon.
///
/// The semicolon has no common ambiguous use in ordinary text, so every
/// half-width semicolon is converted (unless it is inside Markdown code).
class SemicolonConverter {
  const SemicolonConverter._();

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
      if (protected[index] || character != ';') {
        output.write(character);
        continue;
      }
      output.write('；');
    }

    return output.toString();
  }
}
