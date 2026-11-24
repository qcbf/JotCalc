import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'calculation.dart';
import 'calculator_store.dart';
import 'programmer_calculation.dart';

class ProgrammerInput extends ChangeNotifier {
  ProgrammerInput() {
    editor.addListener(_onEdit);
  }

  static final _digit = RegExp(r'^[0-9A-F]$');
  static final _allowedText = RegExp(r'^[0-9A-FMO+−×÷%()&|^~<> ]*$');
  static const _binaryKeys = {
    '+',
    '−',
    '×',
    '÷',
    '%',
    '&',
    '|',
    '^',
    '<',
    '>',
    '<<',
    '>>',
    '>>>',
  };
  static final formatter = TextInputFormatter.withFunction((previous, next) {
    final text = normalizeExpression(next.text).toUpperCase();
    return text.length <= maxProgrammerExpressionLength &&
            _allowedText.hasMatch(text)
        ? next.copyWith(text: text)
        : previous;
  });

  final editor = TextEditingController();
  final focusNode = FocusNode();
  var _format = defaultProgrammerFormat;
  String _evaluatedExpression = '';
  BigInt? _result;
  CalculationIssue? _issue;
  bool _showError = false;
  bool _confirmed = false;
  bool _recorded = false;
  bool _showBits = false;

  ProgrammerFormat get format => _format;
  bool get showBits => _showBits;
  bool get confirmed => _confirmed;
  bool get canRecord => _result != null && !_recorded;
  BigInt? get value => editor.text.trim().isEmpty ? BigInt.zero : _result;
  CalculationIssue? get error => _showError ? _issue : null;
  String? get result =>
      _result == null ? null : _format.radix.format(_result!, _format.wordSize);

  void _onEdit() {
    if (editor.text == _evaluatedExpression) return;
    _evaluateDraft();
  }

  void _evaluateDraft({bool keepConfirmation = false}) {
    _evaluatedExpression = editor.text;
    _issue = null;
    _result = null;
    if (_evaluatedExpression.trim().isNotEmpty) {
      try {
        _result = evaluateProgrammerExpression(_evaluatedExpression, _format);
      } on CalculationException catch (error) {
        _issue = error.issue;
      }
    }
    if (!keepConfirmation || _result == null) {
      _confirmed = _recorded = false;
    }
    _showError = false;
    notifyListeners();
  }

  void edit() {
    if (!_confirmed) return;
    _confirmed = _recorded = false;
    notifyListeners();
  }

  bool canPress(String key) =>
      !_digit.hasMatch(key) || _format.radix.acceptsDigit(key);

  String? hardwareKey(String? character) {
    if (character == null) return null;
    final key = normalizeExpression(character).toUpperCase();
    return key.length == 1 && _allowedText.hasMatch(key) ? key : null;
  }

  void press(String key) {
    if (key == 'AC') {
      _replace('');
      focusNode.requestFocus();
      return;
    }
    if (!canPress(key) && !_completesMod(key)) return;

    if (_confirmed) {
      final previousResult = result!;
      edit();
      if (key == '⌫') {
        editor.selection = TextSelection.collapsed(offset: editor.text.length);
      } else {
        _replace(_binaryKeys.contains(key) || key == 'M' ? previousResult : '');
      }
    }

    focusNode.requestFocus();
    final expression = editor.text;
    final selection = editor.selection;
    var start = selection.isValid ? selection.start : expression.length;
    final end = selection.isValid ? selection.end : expression.length;
    if (key == '⌫' && start == end && start > 0) start--;
    final insertion = key == '⌫' ? '' : key;
    final next = expression.replaceRange(start, end, insertion);
    if (next.length <= maxProgrammerExpressionLength) {
      _replace(next, offset: start + insertion.length);
    }
  }

  bool _completesMod(String key) {
    final offset = editor.selection.isValid
        ? editor.selection.start
        : editor.text.length;
    return key == 'D' && editor.text.substring(0, offset).endsWith('MO');
  }

  void applyUnary(String operator) {
    final operand = _confirmed ? result! : editor.text.trim();
    if (operand.isEmpty) {
      press(operator == '−' ? '−' : '~0');
    } else if (_result == null) {
      press(operator);
    } else {
      final expression = '$operator($operand)';
      if (expression.length <= maxProgrammerExpressionLength) {
        _replace(expression);
        focusNode.requestFocus();
      }
    }
  }

  void selectRadix(ProgrammerRadix radix) {
    if (radix == _format.radix) return;
    final expression = convertProgrammerRadix(editor.text, _format, radix);
    _format = (radix: radix, wordSize: _format.wordSize);
    _replace(expression, evaluate: false);
    _evaluateDraft(keepConfirmation: true);
  }

  void selectWordSize(ProgrammerWordSize wordSize) {
    if (wordSize == _format.wordSize) return;
    _format = (radix: _format.radix, wordSize: wordSize);
    _evaluateDraft();
  }

  void setShowBits(bool showBits) {
    if (_showBits == showBits) return;
    _showBits = showBits;
    notifyListeners();
  }

  void toggleBit(int index) {
    final current = value;
    if (current == null) return;
    _replace(
      _format.radix.format(current ^ (BigInt.one << index), _format.wordSize),
    );
  }

  HistoryEntry? confirm({required bool record}) {
    final renderedResult = result;
    if (renderedResult == null) {
      if (_issue != null && !_showError) {
        _showError = true;
        notifyListeners();
      }
      return null;
    }

    _confirmed = true;
    focusNode.unfocus();
    final save = record && !_recorded;
    if (save) _recorded = true;
    notifyListeners();
    return save
        ? HistoryEntry(
            expression: editor.text,
            result: renderedResult,
            programmerFormat: _format,
          )
        : null;
  }

  void recall(HistoryEntry entry) {
    _format = entry.programmerFormat!;
    _replace(entry.expression, evaluate: false);
    _confirmed = _recorded = true;
    _evaluateDraft(keepConfirmation: true);
    focusNode.requestFocus();
  }

  void resetRecorded() => _recorded = false;

  void _replace(String text, {int? offset, bool evaluate = true}) {
    if (!evaluate) _evaluatedExpression = text;
    editor.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset ?? text.length),
    );
  }

  @override
  void dispose() {
    editor.dispose();
    focusNode.dispose();
    super.dispose();
  }
}
