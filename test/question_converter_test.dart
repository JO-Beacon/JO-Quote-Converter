import 'package:flutter_test/flutter_test.dart';
import 'package:jo_symbol_converter/question_converter.dart';

void main() {
  group('QuestionConverter', () {
    test('converts half-width question marks to full-width marks', () {
      expect(QuestionConverter.convert('Really?'), 'Really？');
      expect(QuestionConverter.convert('What? Why?'), 'What？ Why？');
    });

    test('converts repeated and operator-like question marks too', () {
      expect(QuestionConverter.convert('Really??'), 'Really？？');
      expect(QuestionConverter.convert('a ?? b'), 'a ？？ b');
      expect(QuestionConverter.convert('a?.b'), 'a？.b');
      expect(QuestionConverter.convert('a ??= b'), 'a ？？= b');
    });

    test('does not alter existing full-width question marks', () {
      expect(QuestionConverter.convert('真的吗？'), '真的吗？');
    });

    test('protects fenced Markdown code by default', () {
      const input = 'a?b\n```\nx?y\n```\nc?d';
      const expected = 'a？b\n```\nx?y\n```\nc？d';
      expect(QuestionConverter.convert(input), expected);
    });

    test('protects inline Markdown code while converting surrounding text', () {
      expect(QuestionConverter.convert('a?b `c?d` e?f'), 'a？b `c?d` e？f');
    });

    test('converts Markdown code when exclusion is disabled', () {
      expect(
        QuestionConverter.convert('`c?d`', excludeMarkdownCode: false),
        '`c？d`',
      );
    });

    test('keeps line endings and empty input intact', () {
      expect(QuestionConverter.convert('alpha\r\nbeta'), 'alpha\r\nbeta');
      expect(QuestionConverter.convert(''), '');
    });
  });
}
