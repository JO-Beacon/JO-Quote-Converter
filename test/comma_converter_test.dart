import 'package:flutter_test/flutter_test.dart';
import 'package:jo_symbol_converter/comma_converter.dart';

void main() {
  group('CommaConverter', () {
    test('converts half-width commas to full-width commas', () {
      expect(CommaConverter.convert('one, two, three'), 'one， two， three');
    });

    test('does not alter existing full-width commas', () {
      expect(CommaConverter.convert('第一，第二'), '第一，第二');
    });

    test('keeps digit group separators when heuristics are enabled', () {
      expect(CommaConverter.convert('1,000'), '1,000');
      expect(CommaConverter.convert('12,345,678'), '12,345,678');
      expect(CommaConverter.convert('Total: 1,234 yuan'), 'Total: 1,234 yuan');
    });

    test('does not treat non-thousands commas as separators', () {
      expect(CommaConverter.convert('1,23'), '1，23');
      expect(CommaConverter.convert('1234,5678'), '1234，5678');
    });

    test('converts digit separators when heuristics are disabled', () {
      expect(CommaConverter.convert('1,000', useHeuristics: false), '1，000');
    });

    test('protects fenced Markdown code by default', () {
      const input = '正文,文字\n```\n1,2,3\n```\n结尾,文字';
      const expected = '正文，文字\n```\n1,2,3\n```\n结尾，文字';
      expect(CommaConverter.convert(input), expected);
    });

    test('protects inline Markdown code while converting surrounding text', () {
      expect(CommaConverter.convert('a,b `c,d` e,f'), 'a，b `c,d` e，f');
    });

    test('converts Markdown code when exclusion is disabled', () {
      expect(
        CommaConverter.convert('`c,d`', excludeMarkdownCode: false),
        '`c，d`',
      );
    });

    test('Markdown exclusion is independent from heuristics', () {
      const input = '1,000 `1,000` 1,000';
      expect(
        CommaConverter.convert(input, useHeuristics: false),
        '1，000 `1,000` 1，000',
      );
      expect(
        CommaConverter.convert(
          input,
          excludeMarkdownCode: false,
          useHeuristics: false,
        ),
        '1，000 `1，000` 1，000',
      );
      expect(
        CommaConverter.convert(input, excludeMarkdownCode: false),
        '1,000 `1,000` 1,000',
      );
    });

    test('keeps line endings and empty input intact', () {
      expect(CommaConverter.convert('alpha\r\nbeta'), 'alpha\r\nbeta');
      expect(CommaConverter.convert(''), '');
    });
  });
}
