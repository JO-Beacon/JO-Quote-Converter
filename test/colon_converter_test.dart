import 'package:flutter_test/flutter_test.dart';
import 'package:jo_symbol_converter/colon_converter.dart';

void main() {
  group('ColonConverter', () {
    test('converts half-width colons to full-width colons', () {
      expect(ColonConverter.convert('key: value'), 'key： value');
    });

    test('does not alter existing full-width colons', () {
      expect(ColonConverter.convert('作者：JO'), '作者：JO');
    });

    test('keeps URL scheme separators', () {
      expect(
        ColonConverter.convert('https://example.com/a:b'),
        'https://example.com/a：b',
      );
    });

    test('keeps times, ratios, and drive paths', () {
      expect(ColonConverter.convert('12:30'), '12:30');
      expect(ColonConverter.convert('16:9'), '16:9');
      expect(ColonConverter.convert(r'C:\Users\me'), r'C:\Users\me');
      expect(ColonConverter.convert('C:/Users/me'), 'C:/Users/me');
    });

    test('converts those cases when heuristics are disabled', () {
      expect(ColonConverter.convert('12:30', useHeuristics: false), '12：30');
      expect(
        ColonConverter.convert('https://example.com', useHeuristics: false),
        'https：//example.com',
      );
    });

    test('protects fenced Markdown code by default', () {
      const input = 'a:b\n```\nx:y\n```\nc:d';
      const expected = 'a：b\n```\nx:y\n```\nc：d';
      expect(ColonConverter.convert(input), expected);
    });

    test('protects inline Markdown code while converting surrounding text', () {
      expect(ColonConverter.convert('a:b `c:d` e:f'), 'a：b `c:d` e：f');
    });

    test('converts Markdown code when exclusion is disabled', () {
      expect(
        ColonConverter.convert('`c:d`', excludeMarkdownCode: false),
        '`c：d`',
      );
    });

    test('Markdown exclusion is independent from heuristics', () {
      const input = '12:30 `12:30`';
      expect(
        ColonConverter.convert(input, useHeuristics: false),
        '12：30 `12:30`',
      );
      expect(
        ColonConverter.convert(
          input,
          excludeMarkdownCode: false,
          useHeuristics: false,
        ),
        '12：30 `12：30`',
      );
      expect(
        ColonConverter.convert(input, excludeMarkdownCode: false),
        '12:30 `12:30`',
      );
    });

    test('keeps line endings and empty input intact', () {
      expect(ColonConverter.convert('alpha\r\nbeta'), 'alpha\r\nbeta');
      expect(ColonConverter.convert(''), '');
    });
  });
}
