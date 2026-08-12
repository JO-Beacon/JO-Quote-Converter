/// Converts straight English quotation marks to Chinese curly quotation marks.
class QuoteConverter {
  const QuoteConverter._();

  static String convert(
    String input, {
    bool excludeMarkdownCode = true,
    bool useHeuristics = true,
  }) {
    if (input.isEmpty) return input;

    final protected = excludeMarkdownCode
        ? _MarkdownCodeMask.build(input)
        : List<bool>.filled(input.length, false);
    final output = StringBuffer();
    var doubleQuoteOpen = false;
    var singleQuoteOpen = false;

    for (var index = 0; index < input.length; index++) {
      final character = input[index];
      if (protected[index] || (character != '"' && character != "'")) {
        output.write(character);
        continue;
      }

      if (!useHeuristics) {
        if (character == "'") {
          output.write(singleQuoteOpen ? '’' : '‘');
          singleQuoteOpen = !singleQuoteOpen;
        } else {
          output.write(doubleQuoteOpen ? '”' : '“');
          doubleQuoteOpen = !doubleQuoteOpen;
        }
        continue;
      }

      final previous = _previousUnprotectedCharacter(input, protected, index);
      final next = _nextUnprotectedCharacter(input, protected, index);

      if (character == "'") {
        if (_isApostrophe(previous, next, singleQuoteOpen)) {
          output.write(character);
          continue;
        }
        final opens = _opensQuote(previous, next, singleQuoteOpen);
        output.write(opens ? '‘' : '’');
        singleQuoteOpen = opens;
      } else {
        if (_isInchMark(previous, next, doubleQuoteOpen)) {
          output.write(character);
          continue;
        }
        final opens = _opensQuote(previous, next, doubleQuoteOpen);
        output.write(opens ? '“' : '”');
        doubleQuoteOpen = opens;
      }
    }

    return output.toString();
  }

  static bool _isApostrophe(String? previous, String? next, bool quoteOpen) {
    if (_isWordCharacter(previous) && _isWordCharacter(next)) return true;
    if (quoteOpen) return false;

    // Keep decade abbreviations ('90s), measurements (5'), and possessives
    // without a matching opening quote (students').
    if (_isDigit(next) && _isOpeningBoundary(previous)) return true;
    if (_isDigit(previous) && (next == null || _isWhitespace(next))) {
      return true;
    }
    if (_isAsciiLetter(previous) && (next == null || _isWhitespace(next))) {
      return true;
    }
    return false;
  }

  static bool _isInchMark(String? previous, String? next, bool quoteOpen) {
    return !quoteOpen &&
        _isDigit(previous) &&
        (next == null || _isWhitespace(next) || _isClosingPunctuation(next));
  }

  static bool _opensQuote(String? previous, String? next, bool quoteOpen) {
    final canOpen =
        _isOpeningBoundary(previous) &&
        next != null &&
        !_isWhitespace(next) &&
        !_isClosingPunctuation(next);
    final canClose =
        previous != null &&
        !_isWhitespace(previous) &&
        (next == null || _isWhitespace(next) || _isClosingPunctuation(next));

    if (quoteOpen) {
      if (canClose || !canOpen) return false;
      return false;
    }
    if (canOpen) return true;
    if (canClose) return false;
    return true;
  }

  static String? _previousUnprotectedCharacter(
    String input,
    List<bool> protected,
    int index,
  ) {
    for (var cursor = index - 1; cursor >= 0; cursor--) {
      if (!protected[cursor]) return input[cursor];
    }
    return null;
  }

  static String? _nextUnprotectedCharacter(
    String input,
    List<bool> protected,
    int index,
  ) {
    for (var cursor = index + 1; cursor < input.length; cursor++) {
      if (!protected[cursor]) return input[cursor];
    }
    return null;
  }

  static bool _isOpeningBoundary(String? character) {
    if (character == null || _isWhitespace(character)) return true;
    return '([{<（［｛【《〈「『，。！？：；、—–-'.contains(character);
  }

  static bool _isClosingPunctuation(String character) {
    return '.,!?;:)]}>，。！？；：、）］｝】》〉」』…'.contains(character);
  }

  static bool _isWhitespace(String? character) {
    return character != null && RegExp(r'\s').hasMatch(character);
  }

  static bool _isWordCharacter(String? character) {
    return character != null && RegExp(r'[A-Za-z0-9_]').hasMatch(character);
  }

  static bool _isAsciiLetter(String? character) {
    return character != null && RegExp(r'[A-Za-z]').hasMatch(character);
  }

  static bool _isDigit(String? character) {
    return character != null && RegExp(r'[0-9]').hasMatch(character);
  }
}

class _MarkdownCodeMask {
  const _MarkdownCodeMask._();

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
