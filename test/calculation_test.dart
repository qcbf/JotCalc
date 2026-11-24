import 'package:flutter_test/flutter_test.dart';
import 'package:jotcalc/calculation.dart';

void main() {
  test('uses operator precedence and exact decimal arithmetic', () {
    expect(evaluateExpression('2+3×4−5÷2'), '11.5');
    expect(evaluateExpression('0.1 + 0.2'), '0.3');
    expect(evaluateExpression('5×−.2'), '−1');
    expect(evaluateExpression('1÷3×3'), '1');
    expect(evaluateExpression('2 / 3'), '0.666666666667');
    expect(evaluateExpression('.0000000000001×2'), '0.0000000000002');
  });

  test(
    'treats additive percentages as changes relative to the left operand',
    () {
      expect(evaluateExpression('200−10%'), '180');
      expect(evaluateExpression('200+10%+10%'), '242');
      expect(evaluateExpression('200×10%'), '20');
      expect(evaluateExpression('200+100×10%'), '210');
    },
  );

  test('reports incomplete, invalid and zero division separately', () {
    expect(
      () => evaluateExpression('12+.'),
      throwsIssue(CalculationIssue.incomplete),
    );
    expect(
      () => evaluateExpression('12 3'),
      throwsIssue(CalculationIssue.invalid),
    );
    expect(
      () => evaluateExpression('1.2.3'),
      throwsIssue(CalculationIssue.invalid),
    );
    expect(
      () => evaluateExpression('3÷−0'),
      throwsIssue(CalculationIssue.divisionByZero),
    );
  });

  test('advanced arithmetic preserves exact decimals and percentages', () {
    expect(_advanced('2*(3+(4-1))'), '12');
    expect(_advanced('-(2 + 3)'), '−5');
    expect(_advanced('(1/3)*3'), '1');
    expect(_advanced('ABS(-pow(0.2, 3))'), '0.008');
    expect(_advanced('pow(2, -3)'), '0.125');
    expect(_advanced('200+(10%)'), '220');
    expect(_advanced('200+(10+5)%'), '230');
    expect(_advanced('200+100*(10%)'), '210');
    expect(_advanced('200+10%+10%'), '242');
  });

  test('advanced operators use integer arithmetic and precedence', () {
    expect(_advanced('3 + 5 mod 3 * 2'), '7');
    expect(_advanced('-7 MOD 3'), '2');
    expect(_advanced('5 ^ 3'), '6');
    expect(_advanced('1 | 2 ^ 3 & 2'), '1');
    expect(_advanced('2 << 1 + 2'), '16');
    expect(_advanced('32 >> 1 >> 2'), '4');
    expect(_advanced('~0'), '−1');
    expect(_advanced('9007199254740993 ^ 1'), '9007199254740992');
  });

  test('advanced grammar reports incomplete and invalid expressions', () {
    for (final expression in ['(2 + 3', '12 mo', '5 <', 'pow(2,', 'ab']) {
      expect(
        () => _advanced(expression),
        throwsIssue(CalculationIssue.incomplete),
      );
    }
    for (final expression in [
      '2(3)',
      'pow(2)',
      'abs(1, 2)',
      '1.5 ^ 3',
      'pow(2, 0.5)',
      '1 << -1',
    ]) {
      expect(
        () => _advanced(expression),
        throwsIssue(CalculationIssue.invalid),
      );
    }
    for (final expression in ['5 mod 0', 'pow(0, -1)']) {
      expect(
        () => _advanced(expression),
        throwsIssue(CalculationIssue.divisionByZero),
      );
    }
  });

  test('advanced operations bound the cost of live evaluation', () {
    final opening = List.filled(65, '(').join();
    final closing = List.filled(65, ')').join();
    for (final expression in [
      'pow(10, 1000000)',
      '1 << 1000000',
      '${opening}1$closing',
    ]) {
      expect(
        () => _advanced(expression),
        throwsIssue(CalculationIssue.outOfRange),
      );
    }
  });

  test('basic evaluation rejects advanced syntax', () {
    for (final expression in ['2*(3+4)', '5 mod 3', '5 ^ 3', 'abs(-3)']) {
      expect(
        () => evaluateExpression(expression),
        throwsIssue(CalculationIssue.invalid),
      );
    }
  });
}

String _advanced(String expression) =>
    evaluateExpression(expression, allowAdvanced: true);

Matcher throwsIssue(CalculationIssue issue) => throwsA(
  isA<CalculationException>().having((error) => error.issue, 'issue', issue),
);
