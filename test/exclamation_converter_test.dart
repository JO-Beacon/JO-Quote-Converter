import 'package:flutter_test/flutter_test.dart';
import 'package:jo_symbol_converter/exclamation_converter.dart';

void main() {
  group('ExclamationConverter', () {
    test('converts half-width exclamation marks to full-width marks', () {
      expect(ExclamationConverter.convert('Hello!'), 'Hello！');
      expect(ExclamationConverter.convert('Wow! Really!'), 'Wow！ Really！');
    });

    test('does not alter existing full-width exclamation marks', () {
      expect(ExclamationConverter.convert('太好了！'), '太好了！');
    });

    test('keeps operators when heuristics are enabled', () {
      expect(ExclamationConverter.convert('a != b'), 'a != b');
      expect(ExclamationConverter.convert('a !== b'), 'a !== b');
    });

    test('converts operators when heuristics are disabled', () {
      expect(
        ExclamationConverter.convert('a != b', useHeuristics: false),
        'a ！= b',
      );
    });

    test('protects fenced Markdown code by default', () {
      const input = 'a!b\n```\nx!y\n```\nc!d';
      const expected = 'a！b\n```\nx!y\n```\nc！d';
      expect(ExclamationConverter.convert(input), expected);
    });

    test('protects inline Markdown code while converting surrounding text', () {
      expect(ExclamationConverter.convert('a!b `c!d` e!f'), 'a！b `c!d` e！f');
    });

    test('converts Markdown code when exclusion is disabled', () {
      expect(
        ExclamationConverter.convert('`c!d`', excludeMarkdownCode: false),
        '`c！d`',
      );
    });

    test('Markdown exclusion is independent from heuristics', () {
      const input = 'a != b `a != b`';
      expect(
        ExclamationConverter.convert(input, useHeuristics: false),
        'a ！= b `a != b`',
      );
      expect(
        ExclamationConverter.convert(
          input,
          excludeMarkdownCode: false,
          useHeuristics: false,
        ),
        'a ！= b `a ！= b`',
      );
      expect(
        ExclamationConverter.convert(input, excludeMarkdownCode: false),
        'a != b `a != b`',
      );
    });

    test('keeps line endings and empty input intact', () {
      expect(ExclamationConverter.convert('alpha\r\nbeta'), 'alpha\r\nbeta');
      expect(ExclamationConverter.convert(''), '');
    });
  });
}
