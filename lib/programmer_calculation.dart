import 'calculation.dart';

enum ProgrammerRadix {
  hex(16),
  dec(10),
  oct(8),
  bin(2);

  const ProgrammerRadix(this.base);

  final int base;

  String get label => name.toUpperCase();

  bool acceptsDigit(String digit) => int.parse(digit, radix: 16) < base;

  String format(BigInt value, ProgrammerWordSize wordSize) {
    final number = this == dec
        ? value.toSigned(wordSize.bits)
        : value.toUnsigned(wordSize.bits);
    return number.toRadixString(base).toUpperCase().replaceFirst('-', '−');
  }
}

enum ProgrammerWordSize {
  qword(64),
  dword(32),
  word(16),
  byte(8);

  const ProgrammerWordSize(this.bits);

  final int bits;

  String get label => name.toUpperCase();
}

typedef ProgrammerFormat = ({
  ProgrammerRadix radix,
  ProgrammerWordSize wordSize,
});

const defaultProgrammerFormat = (
  radix: ProgrammerRadix.dec,
  wordSize: ProgrammerWordSize.qword,
);

const maxProgrammerExpressionLength = 4096;
final _digits = RegExp(r'[0-9A-F]+', caseSensitive: false);
final _singleNumber = RegExp(r'^[+−]?[0-9A-F]+$', caseSensitive: false);
final _radixTokens = RegExp(r'mod|[0-9A-F]+', caseSensitive: false);
final _leadingZeroes = RegExp(r'^0+(?=.)');

BigInt evaluateProgrammerExpression(
  String expression,
  ProgrammerFormat format,
) {
  if (expression.length > maxProgrammerExpressionLength) {
    throw const CalculationException(CalculationIssue.outOfRange);
  }
  return _ProgrammerParser(normalizeExpression(expression), format).parse();
}

String convertProgrammerRadix(
  String expression,
  ProgrammerFormat format,
  ProgrammerRadix radix,
) {
  if (_singleNumber.hasMatch(expression.trim())) {
    try {
      final value = evaluateProgrammerExpression(expression, format);
      return radix.format(value, format.wordSize);
    } on CalculationException {
      return expression;
    }
  }

  // Preserve pending operators and the magnitude of each literal in a formula.
  return expression.replaceAllMapped(_radixTokens, (match) {
    final token = match[0]!;
    if (token.toLowerCase() == 'mod') return token;
    try {
      return _parseLiteral(
        token,
        format.radix,
      ).toRadixString(radix.base).toUpperCase();
    } on CalculationException {
      return token;
    }
  });
}

BigInt _parseLiteral(String token, ProgrammerRadix radix) {
  final digits = token.replaceFirst(_leadingZeroes, '');
  if (digits.length > ProgrammerWordSize.qword.bits) {
    throw const CalculationException(CalculationIssue.outOfRange);
  }
  final value = BigInt.tryParse(digits, radix: radix.base);
  if (value == null) {
    throw const CalculationException(CalculationIssue.invalid);
  }
  if (value.bitLength > ProgrammerWordSize.qword.bits) {
    throw const CalculationException(CalculationIssue.outOfRange);
  }
  return value;
}

class _ProgrammerParser {
  _ProgrammerParser(this._source, this._format);

  static const _maxNesting = 64;
  static final _space = RegExp(r'\s*');
  static final _operator = RegExp(
    r'>>>|>>|<<|mod|[+−×÷%&^|]',
    caseSensitive: false,
  );
  static final _partialOperator = RegExp(
    r'(?:m|mo|<|>)\s*$',
    caseSensitive: false,
  );
  static const _precedence = {
    '|': 1,
    '^': 2,
    '&': 3,
    '<<': 4,
    '>>': 4,
    '>>>': 4,
    '+': 5,
    '−': 5,
    '×': 6,
    '÷': 6,
    '%': 6,
    'mod': 6,
  };

  final String _source;
  final ProgrammerFormat _format;
  int _offset = 0;

  int get _bits => _format.wordSize.bits;
  bool get _atEnd => _offset == _source.length;

  BigInt parse() {
    final value = _expression(0);
    if (!_atEnd) throw const CalculationException(CalculationIssue.invalid);
    return value;
  }

  BigInt _expression(int nesting, [int minimumPrecedence = 1]) {
    var left = _operand(nesting);
    while (true) {
      _skipSpace();
      final match = _operator.matchAsPrefix(_source, _offset);
      if (match == null) {
        if (_partialOperator.matchAsPrefix(_source, _offset) != null) {
          throw const CalculationException(CalculationIssue.incomplete);
        }
        return left;
      }
      final operator = match[0]!.toLowerCase();
      final precedence = _precedence[operator]!;
      if (precedence < minimumPrecedence) return left;
      _offset = match.end;
      final right = _expression(nesting, precedence + 1);
      left = _apply(operator, left, right).toSigned(_bits);
    }
  }

  BigInt _operand(int nesting) {
    if (nesting >= _maxNesting) {
      throw const CalculationException(CalculationIssue.outOfRange);
    }
    _skipSpace();
    if (_atEnd) throw const CalculationException(CalculationIssue.incomplete);

    switch (_source[_offset]) {
      case '+':
        _offset++;
        return _operand(nesting + 1);
      case '−':
        _offset++;
        return (-_operand(nesting + 1)).toSigned(_bits);
      case '~':
        _offset++;
        return (~_operand(nesting + 1)).toSigned(_bits);
      case '(':
        _offset++;
        final value = _expression(nesting + 1);
        if (_atEnd || _source[_offset] != ')') {
          throw CalculationException(
            _atEnd ? CalculationIssue.incomplete : CalculationIssue.invalid,
          );
        }
        _offset++;
        return value;
    }

    final literal = _digits.matchAsPrefix(_source, _offset);
    if (literal == null) {
      throw const CalculationException(CalculationIssue.invalid);
    }
    _offset = literal.end;
    return _parseLiteral(literal[0]!, _format.radix).toSigned(_bits);
  }

  BigInt _apply(String operator, BigInt left, BigInt right) {
    if ((operator == '÷' || operator == '%' || operator == 'mod') &&
        right == BigInt.zero) {
      throw const CalculationException(CalculationIssue.divisionByZero);
    }
    return switch (operator) {
      '+' => left + right,
      '−' => left - right,
      '×' => left * right,
      '÷' => left ~/ right,
      '%' || 'mod' => left.remainder(right),
      '&' => left & right,
      '|' => left | right,
      '^' => left ^ right,
      '<<' => left << _shiftCount(right),
      '>>' => left >> _shiftCount(right),
      '>>>' => left.toUnsigned(_bits) >> _shiftCount(right),
      _ => throw StateError('Unknown operator $operator'),
    };
  }

  int _shiftCount(BigInt count) {
    if (count.isNegative) {
      throw const CalculationException(CalculationIssue.invalid);
    }
    // Shifts at least as large as the word have the same fixed-width result.
    return count >= BigInt.from(_bits) ? _bits : count.toInt();
  }

  void _skipSpace() => _offset = _space.matchAsPrefix(_source, _offset)!.end;
}
