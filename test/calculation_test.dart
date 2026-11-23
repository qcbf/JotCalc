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
}

Matcher throwsIssue(CalculationIssue issue) => throwsA(
  isA<CalculationException>().having((error) => error.issue, 'issue', issue),
);
