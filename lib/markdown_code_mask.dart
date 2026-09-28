/// Marks the characters that belong to Markdown fenced code blocks or inline
/// code, so converters can leave them untouched.
class MarkdownCodeMask {
  const MarkdownCodeMask._();

  static List<bool> build(String input) {
    final mask = List<bool>.filled(input.length, false);
    _markFencedCode(input, mask);
    _markInlineCode(input, mask);
    return mask;
  }

  static void _markFencedCode(String input, List<bool> mask) {
    String? fenceCharacter;
    var fenceLength = 0;
    var lineStart = 0;

    while (lineStart < input.length) {
      final newline = input.indexOf('\n', lineStart);
      final lineEnd = newline == -1 ? input.length : newline + 1;
      final contentEnd = newline == -1 ? input.length : newline;
      final line = input
          .substring(lineStart, contentEnd)
          .replaceFirst(RegExp(r'\r$'), '');
      final opening = RegExp(r'^[ \t]{0,3}(`{3,}|~{3,})').firstMatch(line);

      if (fenceCharacter == null && opening != null) {
        final run = opening.group(1)!;
        fenceCharacter = run[0];
        fenceLength = run.length;
        _mark(mask, lineStart, lineEnd);
      } else if (fenceCharacter != null) {
        _mark(mask, lineStart, lineEnd);
        final closing = RegExp(
          '^[ \\t]{0,3}${RegExp.escape(fenceCharacter)}{$fenceLength,}[ \\t]*\\r?\$',
        ).hasMatch(input.substring(lineStart, contentEnd));
        if (closing) {
          fenceCharacter = null;
          fenceLength = 0;
        }
      }

      lineStart = lineEnd;
    }
  }

  static void _markInlineCode(String input, List<bool> mask) {
    var index = 0;
    while (index < input.length) {
      if (mask[index] || input[index] != '`') {
        index++;
        continue;
      }

      final openingStart = index;
      while (index < input.length && !mask[index] && input[index] == '`') {
        index++;
      }
      final runLength = index - openingStart;
      var cursor = index;
      var closingEnd = -1;

      while (cursor < input.length && input[cursor] != '\n') {
        if (mask[cursor] || input[cursor] != '`') {
          cursor++;
          continue;
        }
        final closingStart = cursor;
        while (cursor < input.length && !mask[cursor] && input[cursor] == '`') {
          cursor++;
        }
        if (cursor - closingStart == runLength) {
          closingEnd = cursor;
          break;
        }
      }

      if (closingEnd != -1) {
        _mark(mask, openingStart, closingEnd);
        index = closingEnd;
      }
    }
  }

  static void _mark(List<bool> mask, int start, int end) {
    for (var index = start; index < end; index++) {
      mask[index] = true;
    }
  }
}
