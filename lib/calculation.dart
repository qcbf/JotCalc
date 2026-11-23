import 'dart:math' as math;

enum CalculationIssue { incomplete, invalid, divisionByZero }

class CalculationException implements Exception {
  const CalculationException(this.issue);

  final CalculationIssue issue;
}

String evaluateExpression(String expression) {
  final normalized = expression
      .replaceAll('-', '−')
      .replaceAll('*', '×')
      .replaceAll('/', '÷');
  return _ExpressionParser(normalized).parse().toDisplayString();
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

      final operand = _product();
      // An additive percentage is relative to the accumulated left operand.
      final right = operand.isPercentage
          ? value * operand.value
          : operand.value;
      value = operator == '+' ? value + right : value - right;
    }
    if (_offset != expression.length) {
      throw const CalculationException(CalculationIssue.invalid);
    }
    return value;
  }

  ({_Fraction value, bool isPercentage}) _product() {
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

  ({_Fraction value, bool isPercentage}) _number() {
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
    final digits = BigInt.parse(decimal.replaceFirst('.', ''));
    _offset = match.end;
    final isPercentage = _takeOperator('%') != null;
    return (
      value: _Fraction(
        sign == '−' ? -digits : digits,
        _Fraction.ten.pow(places + (isPercentage ? 2 : 0)),
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

class _Fraction {
  factory _Fraction(BigInt numerator, BigInt denominator) {
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

  _Fraction operator +(_Fraction other) => _Fraction(
    numerator * other.denominator + other.numerator * denominator,
    denominator * other.denominator,
  );

  _Fraction operator -(_Fraction other) => _Fraction(
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
