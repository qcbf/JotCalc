import 'package:flutter_test/flutter_test.dart';
import 'package:jotcalc/calculation.dart';
import 'package:jotcalc/programmer_calculation.dart';

void main() {
  const hexQword = (
    radix: ProgrammerRadix.hex,
    wordSize: ProgrammerWordSize.qword,
  );
  const hexByte = (
    radix: ProgrammerRadix.hex,
    wordSize: ProgrammerWordSize.byte,
  );

  test('preserves the full 64-bit pattern and formats DEC as signed', () {
    final value = evaluateProgrammerExpression('8000000000000001', hexQword);
    expect(value, -BigInt.parse('9223372036854775807'));
    expect(
      ProgrammerRadix.hex.format(value, hexQword.wordSize),
      '8000000000000001',
    );
    expect(
      ProgrammerRadix.oct.format(value, hexQword.wordSize),
      '1000000000000000000001',
    );
    expect(
      ProgrammerRadix.bin.format(value, hexQword.wordSize),
      '1${'0' * 62}1',
    );
    expect(
      ProgrammerRadix.dec.format(value, hexQword.wordSize),
      '−9223372036854775807',
    );
    expect(
      evaluateProgrammerExpression('FFFFFFFFFFFFFFFF + 1', hexQword),
      BigInt.zero,
    );
  });

  test('uses fixed-width integer arithmetic and distinct right shifts', () {
    BigInt hex(String expression) =>
        evaluateProgrammerExpression(expression, hexByte);
    expect(hex('7F + 1'), BigInt.from(-128));
    expect(hex('80 >> 1'), BigInt.from(-64));
    expect(hex('80 >>> 1'), BigInt.from(64));
    expect(hex('80 >>> 8'), BigInt.zero);
    expect(hex('FF << 8'), BigInt.zero);
    expect(hex('~(A | 1) & F'), BigInt.from(4));
    expect(hex('1 | 2 ^ 3 & 4 << 1 + 1'), BigInt.from(3));
    expect(hex('−7 ÷ 3'), BigInt.from(-2));
    expect(hex('−7 mod 3'), BigInt.from(-1));
  });

  test('keeps the value and pending operators when changing radix', () {
    const decByte = (
      radix: ProgrammerRadix.dec,
      wordSize: ProgrammerWordSize.byte,
    );
    expect(convertProgrammerRadix('FF', hexByte, ProgrammerRadix.dec), '−1');
    expect(convertProgrammerRadix('−1', decByte, ProgrammerRadix.hex), 'FF');
    expect(
      convertProgrammerRadix('F mod A + (10 << ', hexByte, ProgrammerRadix.dec),
      '15 mod 10 + (16 << ',
    );
    const expression = 'FE / (−2) + A';
    final converted = convertProgrammerRadix(
      expression,
      hexByte,
      ProgrammerRadix.dec,
    );
    expect(
      evaluateProgrammerExpression(converted, decByte),
      evaluateProgrammerExpression(expression, hexByte),
    );
  });

  test('distinguishes invalid digits, incomplete input and integer errors', () {
    expect(
      () => evaluateProgrammerExpression('2', (
        radix: ProgrammerRadix.bin,
        wordSize: ProgrammerWordSize.byte,
      )),
      throwsIssue(CalculationIssue.invalid),
    );
    expect(
      () => evaluateProgrammerExpression('F <<', hexByte),
      throwsIssue(CalculationIssue.incomplete),
    );
    expect(
      () => evaluateProgrammerExpression('F mod 0', hexByte),
      throwsIssue(CalculationIssue.divisionByZero),
    );
    expect(
      () => evaluateProgrammerExpression('10000000000000000', hexQword),
      throwsIssue(CalculationIssue.outOfRange),
    );
  });
}

Matcher throwsIssue(CalculationIssue issue) => throwsA(
  isA<CalculationException>().having((error) => error.issue, 'issue', issue),
);
