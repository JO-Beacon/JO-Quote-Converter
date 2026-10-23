import 'package:flutter_test/flutter_test.dart';
import 'package:jo_symbol_converter/semicolon_converter.dart';

void main() {
  group('SemicolonConverter', () {
    test('converts half-width semicolons to full-width semicolons', () {
      expect(SemicolonConverter.convert('a;b'), 'a；b');
      expect(SemicolonConverter.convert('First; second;'), 'First； second；');
    });

    test('does not alter existing full-width semicolons', () {
      expect(SemicolonConverter.convert('第一；第二'), '第一；第二');
    });

    test('protects fenced Markdown code by default', () {
      const input = 'a;b\n```\nx;y\n```\nc;d';
      const expected = 'a；b\n```\nx;y\n```\nc；d';
      expect(SemicolonConverter.convert(input), expected);
    });

    test('protects inline Markdown code while converting surrounding text', () {
      expect(SemicolonConverter.convert('a;b `c;d` e;f'), 'a；b `c;d` e；f');
    });

    test('converts Markdown code when exclusion is disabled', () {
      expect(
        SemicolonConverter.convert('`c;d`', excludeMarkdownCode: false),
        '`c；d`',
      );
    });

    test('keeps line endings and empty input intact', () {
      expect(SemicolonConverter.convert('alpha\r\nbeta'), 'alpha\r\nbeta');
      expect(SemicolonConverter.convert(''), '');
    });
  });
}
