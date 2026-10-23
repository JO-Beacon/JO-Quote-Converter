import 'colon_converter.dart';
import 'comma_converter.dart';
import 'converter_tool.dart';
import 'exclamation_converter.dart';
import 'question_converter.dart';
import 'quote_converter.dart';
import 'semicolon_converter.dart';

/// Dispatches text to the converter selected in the workspace sidebar.
class TextConverter {
  const TextConverter._();

  static String convert(
    ConverterTool tool,
    String input, {
    bool excludeMarkdownCode = true,
    bool useHeuristics = true,
  }) {
    return switch (tool) {
      ConverterTool.quote => QuoteConverter.convert(
        input,
        excludeMarkdownCode: excludeMarkdownCode,
        useHeuristics: useHeuristics,
      ),
      ConverterTool.comma => CommaConverter.convert(
        input,
        excludeMarkdownCode: excludeMarkdownCode,
        useHeuristics: useHeuristics,
      ),
      ConverterTool.colon => ColonConverter.convert(
        input,
        excludeMarkdownCode: excludeMarkdownCode,
        useHeuristics: useHeuristics,
      ),
      ConverterTool.exclamation => ExclamationConverter.convert(
        input,
        excludeMarkdownCode: excludeMarkdownCode,
        useHeuristics: useHeuristics,
      ),
      ConverterTool.question => QuestionConverter.convert(
        input,
        excludeMarkdownCode: excludeMarkdownCode,
        useHeuristics: useHeuristics,
      ),
      ConverterTool.semicolon => SemicolonConverter.convert(
        input,
        excludeMarkdownCode: excludeMarkdownCode,
        useHeuristics: useHeuristics,
      ),
    };
  }
}
