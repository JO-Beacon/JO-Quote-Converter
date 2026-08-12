import 'package:flutter_test/flutter_test.dart';
import 'package:jo_quote_converter/quote_converter.dart';

void main() {
  group('QuoteConverter', () {
    test('converts paired double quotes', () {
      expect(QuoteConverter.convert('He said, "Hello."'), 'He said, “Hello.”');
    });

    test('converts nested single quotes', () {
      expect(
        QuoteConverter.convert('He said, "She said \'hello\'."'),
        'He said, “She said ‘hello’.”',
      );
    });

    test('preserves apostrophes in contractions and possessives', () {
      expect(
        QuoteConverter.convert("Don't change John's book or students' work."),
        "Don't change John's book or students' work.",
      );
    });

    test('preserves measurements and abbreviated years', () {
      expect(
        QuoteConverter.convert("He is 5' 10\" and remembers '90s music."),
        "He is 5' 10\" and remembers '90s music.",
      );
    });

    test('mechanical mode alternates each quote type independently', () {
      expect(
        QuoteConverter.convert('"abc\'don\'t tell\'"', useHeuristics: false),
        '“abc‘don’t tell‘”',
      );
      expect(
        QuoteConverter.convert("'one' and 'two'", useHeuristics: false),
        '‘one’ and ‘two’',
      );
    });

    test('does not alter existing Chinese quotes', () {
      expect(QuoteConverter.convert('他说：“你好。”'), '他说：“你好。”');
    });

    test('protects fenced Markdown code by default', () {
      const input = '正文 "内容"\n```dart\nprint("code");\n```\n结尾 "文字"';
      const expected = '正文 “内容”\n```dart\nprint("code");\n```\n结尾 “文字”';
      expect(QuoteConverter.convert(input), expected);
    });

    test('protects tilde fenced Markdown code', () {
      const input = '~~~json\n{"name": "value"}\n~~~\n"done"';
      const expected = '~~~json\n{"name": "value"}\n~~~\n“done”';
      expect(QuoteConverter.convert(input), expected);
    });

    test('protects inline Markdown code while keeping quote state', () {
      const input = '"Use `print("hello")` here."';
      const expected = '“Use `print("hello")` here.”';
      expect(QuoteConverter.convert(input), expected);
    });

    test('converts Markdown code when exclusion is disabled', () {
      const input = '```dart\nprint("hello");\n```';
      const expected = '```dart\nprint(“hello”);\n```';
      expect(
        QuoteConverter.convert(input, excludeMarkdownCode: false),
        expected,
      );
    });

    test('Markdown exclusion is independent from mechanical pairing', () {
      const input = "'outside' `code 'x'` 'again'";
      expect(
        QuoteConverter.convert(input, useHeuristics: false),
        "‘outside’ `code 'x'` ‘again’",
      );
      expect(
        QuoteConverter.convert(
          input,
          excludeMarkdownCode: false,
          useHeuristics: false,
        ),
        '‘outside’ `code ‘x’` ‘again’',
      );
    });

    test('keeps line endings and unmatched text intact', () {
      expect(QuoteConverter.convert('alpha\r\nbeta'), 'alpha\r\nbeta');
      expect(QuoteConverter.convert(''), '');
    });
  });
}
