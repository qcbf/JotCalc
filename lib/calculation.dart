import 'dart:math' as math;

enum CalculationIssue { incomplete, invalid, divisionByZero, outOfRange }

class CalculationException implements Exception {
  const CalculationException(this.issue);

  final CalculationIssue issue;
}

final _advancedSyntax = RegExp(r'[A-Za-z(),&|^~<>]');

bool hasAdvancedSyntax(String expression) =>
    _advancedSyntax.hasMatch(expression);

String normalizeExpression(String expression) =>
    expression.replaceAll('-', '−').replaceAll('*', '×').replaceAll('/', '÷');

String evaluateExpression(String expression, {bool allowAdvanced = false}) {
  final normalized = normalizeExpression(expression);
  final parser = allowAdvanced && hasAdvancedSyntax(normalized)
      ? _AdvancedExpressionParser(normalized)
      : _ExpressionParser(normalized);
  return parser.parse().toDisplayString();
}

typedef _Operand = ({_Fraction value, bool isPercentage});

_Fraction _addOrSubtract(_Fraction left, String operator, _Operand operand) {
  // An additive percentage is relative to the accumulated left operand.
  final right = operand.isPercentage ? left * operand.value : operand.value;
  return operator == '+' ? left + right : left - right;
}

class _ExpressionParser {
  _ExpressionParser(this.expression);

  static final _decimal = RegExp(r'(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)');
  static final _whitespace = RegExp(r'\s*');

  final String expression;
  int _offset = 0;

  _Fraction parse() {
    var value = _product().value;
    while (true) {
      final operator = _takeOperator('+−');
      if (operator == null) break;

      value = _addOrSubtract(value, operator, _product());
    }
    return _finish(value);
  }

  _Fraction _finish(_Fraction value) {
    if (_offset != expression.length) {
      throw const CalculationException(CalculationIssue.invalid);
    }
    return value;
  }

  _Operand _product() {
    var operand = _number();
    while (true) {
      final operator = _takeOperator('×÷');
      if (operator == null) return operand;

      final right = _number().value;
      final value = operator == '×'
          ? operand.value * right
          : operand.value / right;
      operand = (value: value, isPercentage: false);
    }
  }

  _Operand _number() {
    final sign = _takeOperator('+−');
    _skipWhitespace();
    final match = _decimal.matchAsPrefix(expression, _offset);
    if (match == null) {
      final remainder = expression.substring(_offset).trim();
      throw CalculationException(
        remainder.isEmpty || remainder == '.'
            ? CalculationIssue.incomplete
            : CalculationIssue.invalid,
      );
    }

    final decimal = match.group(0)!;
    final point = decimal.indexOf('.');
    final places = point < 0 ? 0 : decimal.length - point - 1;
    final digits = BigInt.parse(
      point < 0 ? decimal : decimal.replaceFirst('.', ''),
    );
    _offset = match.end;
    final isPercentage = _takeOperator('%') != null;
    final decimalPlaces = places + (isPercentage ? 2 : 0);
    return (
      value: _Fraction(
        sign == '−' ? -digits : digits,
        decimalPlaces == 0 ? BigInt.one : _Fraction.ten.pow(decimalPlaces),
      ),
      isPercentage: isPercentage,
    );
  }

  String? _takeOperator(String operators) {
    _skipWhitespace();
    if (_offset == expression.length) return null;
    final candidate = expression[_offset];
    if (!operators.contains(candidate)) return null;
    _offset++;
    return candidate;
  }

  void _skipWhitespace() {
    _offset = _whitespace.matchAsPrefix(expression, _offset)!.end;
  }
}

class _AdvancedExpressionParser extends _ExpressionParser {
  _AdvancedExpressionParser(super.expression);

  static final _binaryOperator = RegExp(
    r'[+−×÷&|^]|<<|>>|mod(?![A-Za-z])',
    caseSensitive: false,
  );
  static final _partialOperator = RegExp(
    r'(?:m|mo|<|>)\s*$',
    caseSensitive: false,
  );
  static final _identifier = RegExp(r'[A-Za-z]+');
  static const _precedence = {
    '|': 1,
    '^': 2,
    '&': 3,
    '<<': 4,
    '>>': 4,
    '+': 5,
    '−': 5,
    '×': 6,
    '÷': 6,
    'mod': 6,
  };

  // Keep the work of nesting, powers, and shifts bounded during live input.
  static const _maximumNesting = 64;
  static const _maximumBits = 16384;
  static final _hundred = _Fraction._(BigInt.from(100), BigInt.one);

  @override
  _Fraction parse() => _finish(_expression(0).value);

  _Operand _expression(int nesting, [int minimumPrecedence = 1]) {
    var left = _operand(nesting);
    while (true) {
      _skipWhitespace();
      final match = _binaryOperator.matchAsPrefix(expression, _offset);
      if (match == null) {
        if (_partialOperator.matchAsPrefix(expression, _offset) != null) {
          throw const CalculationException(CalculationIssue.incomplete);
        }
        return left;
      }

      final operator = match[0]!.toLowerCase();
      final precedence = _precedence[operator]!;
      if (precedence < minimumPrecedence) return left;

      _offset = match.end;
      final right = _expression(nesting, precedence + 1);
      left = (
        value: _applyBinary(operator, left.value, right),
        isPercentage: false,
      );
    }
  }

  _Operand _operand(int nesting) {
    if (nesting >= _maximumNesting) {
      throw const CalculationException(CalculationIssue.outOfRange);
    }

    final prefix = _takeOperator('+−~');
    if (prefix != null) {
      final operand = _operand(nesting + 1);
      return switch (prefix) {
        '−' => (value: -operand.value, isPercentage: operand.isPercentage),
        '~' => (
          value: _Fraction._(~operand.value.integer, BigInt.one),
          isPercentage: false,
        ),
        _ => operand,
      };
    }

    final _Operand operand;
    if (_takeOperator('(') != null) {
      operand = _expression(nesting + 1);
      _expect(')');
    } else {
      final name = _identifier.matchAsPrefix(expression, _offset);
      if (name == null) return _number();
      _offset = name.end;
      operand = (
        value: _call(name[0]!.toLowerCase(), nesting + 1),
        isPercentage: false,
      );
    }

    return _takeOperator('%') == null
        ? operand
        : (value: operand.value / _hundred, isPercentage: true);
  }

  _Fraction _call(String name, int nesting) {
    if (name != 'abs' && name != 'pow') {
      _skipWhitespace();
      throw CalculationException(
        _offset == expression.length &&
                ('abs'.startsWith(name) || 'pow'.startsWith(name))
            ? CalculationIssue.incomplete
            : CalculationIssue.invalid,
      );
    }
    _expect('(');
    final argument = _expression(nesting).value;
    if (name == 'abs') {
      _expect(')');
      return argument.numerator.isNegative ? -argument : argument;
    }
    _expect(',');
    final exponent = _expression(nesting).value;
    _expect(')');
    return _power(argument, exponent.integer);
  }

  void _expect(String symbol) {
    if (_takeOperator(symbol) == null) {
      throw CalculationException(
        _offset == expression.length
            ? CalculationIssue.incomplete
            : CalculationIssue.invalid,
      );
    }
  }

  _Fraction _applyBinary(String operator, _Fraction left, _Operand right) =>
      switch (operator) {
        '+' || '−' => _addOrSubtract(left, operator, right),
        '×' => left * right.value,
        '÷' => left / right.value,
        _ => _Fraction._(
          _integerOperation(operator, left.integer, right.value.integer),
          BigInt.one,
        ),
      };

  BigInt _integerOperation(String operator, BigInt left, BigInt right) =>
      switch (operator) {
        'mod' when right == BigInt.zero => throw const CalculationException(
          CalculationIssue.divisionByZero,
        ),
        'mod' => left % right,
        '&' => left & right,
        '|' => left | right,
        '^' => left ^ right,
        '<<' =>
          left <<
              _shiftCount(right, math.max(0, _maximumBits - left.bitLength)),
        '>>' => left >> _shiftCount(right, _maximumBits),
        _ => throw StateError('Unknown operator $operator'),
      };

  int _shiftCount(BigInt count, int maximum) {
    if (count.isNegative) {
      throw const CalculationException(CalculationIssue.invalid);
    }
    if (count > BigInt.from(maximum)) {
      throw const CalculationException(CalculationIssue.outOfRange);
    }
    return count.toInt();
  }

  _Fraction _power(_Fraction base, BigInt exponent) {
    final baseBits = math.max(
      base.numerator.abs().bitLength,
      base.denominator.bitLength,
    );
    final magnitude = exponent.abs();
    if (magnitude > BigInt.from(_maximumBits ~/ baseBits)) {
      throw const CalculationException(CalculationIssue.outOfRange);
    }
    final power = magnitude.toInt();
    final numerator = base.numerator.pow(power);
    final denominator = base.denominator.pow(power);
    return exponent.isNegative
        ? _Fraction(denominator, numerator)
        : _Fraction._(numerator, denominator);
  }
}

class _Fraction {
  factory _Fraction(BigInt numerator, BigInt denominator) {
    if (denominator == BigInt.one) {
      return _Fraction._(numerator, denominator);
    }
    if (denominator == BigInt.zero) {
      throw const CalculationException(CalculationIssue.divisionByZero);
    }
    final common = numerator.gcd(denominator);
    final divisor = denominator.isNegative ? -common : common;
    return _Fraction._(numerator ~/ divisor, denominator ~/ divisor);
  }

  const _Fraction._(this.numerator, this.denominator);

  static final ten = BigInt.from(10);
  static final _five = BigInt.from(5);
  static final _trailingZeroes = RegExp(r'0+$');

  final BigInt numerator;
  final BigInt denominator;

  BigInt get integer {
    if (denominator != BigInt.one) {
      throw const CalculationException(CalculationIssue.invalid);
    }
    return numerator;
  }

  _Fraction operator -() => _Fraction._(-numerator, denominator);

  _Fraction operator +(_Fraction other) => denominator == other.denominator
      ? _Fraction(numerator + other.numerator, denominator)
      : _Fraction(
          numerator * other.denominator + other.numerator * denominator,
          denominator * other.denominator,
        );

  _Fraction operator -(_Fraction other) => denominator == other.denominator
      ? _Fraction(numerator - other.numerator, denominator)
      : _Fraction(
          numerator * other.denominator - other.numerator * denominator,
          denominator * other.denominator,
        );

  _Fraction operator *(_Fraction other) =>
      _Fraction(numerator * other.numerator, denominator * other.denominator);

  _Fraction operator /(_Fraction other) =>
      _Fraction(numerator * other.denominator, denominator * other.numerator);

  String toDisplayString() {
    final sign = numerator.isNegative ? '−' : '';
    final absolute = numerator.abs();
    if (denominator == BigInt.one) return '$sign$absolute';

    final places =
        _terminatingPlaces() ??
        math.max(
          12,
          denominator.toString().length - absolute.toString().length + 11,
        );
    final scaled = absolute * ten.pow(places);
    final rounded = (scaled + (denominator >> 1)) ~/ denominator;
    final digits = rounded.toString().padLeft(places + 1, '0');
    final point = digits.length - places;
    final whole = digits.substring(0, point);
    final fraction = digits.substring(point).replaceFirst(_trailingZeroes, '');
    return fraction.isEmpty ? '$sign$whole' : '$sign$whole.$fraction';
  }

  int? _terminatingPlaces() {
    var remainder = denominator;
    var twos = 0;
    var fives = 0;
    while (remainder.isEven) {
      remainder >>= 1;
      twos++;
    }
    while (remainder % _five == BigInt.zero) {
      remainder ~/= _five;
      fives++;
    }
    return remainder == BigInt.one ? math.max(twos, fives) : null;
  }
}
