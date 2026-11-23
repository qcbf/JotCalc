import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'app_localization.dart';
import 'calculation.dart';
import 'calculator_store.dart';
import 'calculator_widgets.dart';
import 'settings_page.dart';

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({
    super.key,
    required this.initialSnapshot,
    required this.onSave,
    required this.onLanguageChanged,
  });

  final CalculatorSnapshot initialSnapshot;
  final Future<void> Function(CalculatorSnapshot) onSave;
  final ValueChanged<AppLanguage> onLanguageChanged;

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  static const _minimumHistoryWidth = 96.0;
  static const _binaryOperators = '+−×÷';
  static final _trailingOperators = RegExp(r'[+−×÷]+\s*$');
  static final _trailingNumber = RegExp(r'[0-9.]+$');
  static final _numberEnd = RegExp(r'[0-9.]$');

  final _editor = TextEditingController();
  final _editorFocus = FocusNode();
  final _historyScroll = ScrollController();

  late CalculatorSettings _settings;
  late final List<HistoryEntry> _history;
  String _evaluatedExpression = '';
  String? _value;
  String? _copiedValue;
  Timer? _copyFeedbackTimer;
  CalculationIssue? _issue;
  bool _isResult = false;
  bool _showIssue = false;
  bool _recordedCurrentResult = false;
  bool _skipDeleteConfirmation = false;
  bool _resizedHistory = false;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSnapshot.settings;
    _history = List.of(widget.initialSnapshot.history);
    _editor.addListener(_evaluateDraft);
  }

  @override
  void dispose() {
    _copyFeedbackTimer?.cancel();
    _editor.dispose();
    _editorFocus.dispose();
    _historyScroll.dispose();
    super.dispose();
  }

  void _evaluateDraft() {
    final expression = _editor.text;
    if (expression == _evaluatedExpression) return;

    String? value;
    CalculationIssue? issue;
    try {
      value = evaluateExpression(expression);
    } on CalculationException catch (error) {
      issue = error.issue;
    }

    setState(() {
      _evaluatedExpression = expression;
      _value = value;
      _issue = issue;
      _showIssue = false;
      _isResult = false;
      _recordedCurrentResult = false;
    });
  }

  void _editExpression() {
    if (!_isResult) return;
    setState(() {
      _isResult = false;
      _recordedCurrentResult = false;
    });
  }

  void _replaceExpression(String expression, [int? offset]) {
    _editor.value = TextEditingValue(
      text: expression,
      selection: TextSelection.collapsed(offset: offset ?? expression.length),
    );
  }

  KeyEventResult _onHardwareKey(FocusNode scope, KeyEvent event) {
    if (event is KeyUpEvent || event.synthesized) return KeyEventResult.ignored;

    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed) {
      return KeyEventResult.ignored;
    }

    final key = switch (event.logicalKey) {
      LogicalKeyboardKey.backspace => '⌫',
      LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter
          when scope.hasPrimaryFocus || _editorFocus.hasFocus =>
        '=',
      _ => switch (event.character) {
        '-' => '−',
        '*' => '×',
        '/' => '÷',
        final String character
            when character.length == 1 &&
                '0123456789+−×÷.%'.contains(character) =>
          character,
        _ => null,
      },
    };
    if (key == null) return KeyEventResult.ignored;

    _onKey(key);
    return KeyEventResult.handled;
  }

  void _onKey(String key) {
    if (key == '=') {
      _confirm();
      return;
    }

    if (key == 'C') {
      _editExpression();
      _replaceExpression('');
      if (_showIssue) setState(() => _showIssue = false);
      _editorFocus.requestFocus();
      return;
    }

    if (_isResult) {
      final previousResult = _value!;
      _editExpression();
      if (key == '⌫') {
        _editor.selection = TextSelection.collapsed(
          offset: _editor.text.length,
        );
      } else {
        final continueFromResult = _binaryOperators.contains(key) || key == '%';
        _replaceExpression(continueFromResult ? previousResult : '');
      }
    }

    _editorFocus.requestFocus();
    final draft = _editor.text;
    final selection = _editor.selection;
    var start = selection.isValid ? selection.start : draft.length;
    final end = selection.isValid ? selection.end : draft.length;
    var insertion = key;

    if (key == '⌫') {
      if (start == end) {
        while (start > 0 && draft[start - 1] == ' ') {
          start--;
        }
        if (start > 0) start--;
      }
      insertion = '';
    } else if (start == end && end == draft.length) {
      final tail = draft.trimRight();
      if (key == '.') {
        final literal = _trailingNumber.firstMatch(tail)?.group(0);
        if (literal?.contains('.') ?? false) return;
        if (literal == null) insertion = '0.';
      } else if (key == '%') {
        if (!_numberEnd.hasMatch(tail)) return;
      } else if (_binaryOperators.contains(key)) {
        if (tail.isEmpty && key != '−') return;
        final trailing = _trailingOperators.firstMatch(draft);
        if (trailing != null) {
          final operator = trailing.group(0)!.trimRight();
          final addNegativeOperand =
              trailing.start > 0 &&
              key == '−' &&
              (operator == '×' || operator == '÷' || operator == '+');
          if (!addNegativeOperand) {
            start = trailing.start;
            if (start == 0 && key != '−') return;
          }
        }
      }
    }

    _replaceExpression(
      draft.replaceRange(start, end, insertion),
      start + insertion.length,
    );
  }

  void _confirm({bool addToHistory = false}) {
    final value = _value;
    if (value == null) {
      if (_editor.text.trim().isNotEmpty) setState(() => _showIssue = true);
      return;
    }

    final record =
        !_recordedCurrentResult &&
        (addToHistory || !_settings.saveHistoryOnLongPress);
    setState(() {
      _isResult = true;
      _showIssue = false;
      if (record) {
        _history.add(HistoryEntry(expression: _editor.text, result: value));
        _recordedCurrentResult = true;
      }
    });
    _editorFocus.unfocus();
    if (record) {
      if (_historyScroll.hasClients) _historyScroll.jumpTo(0);
      if (_settings.persistHistory) _save();
    }
  }

  void _recall(HistoryEntry entry) {
    _editorFocus.unfocus();
    setState(() {
      _evaluatedExpression = entry.expression;
      _replaceExpression(entry.expression);
      _value = entry.result;
      _issue = null;
      _showIssue = false;
      _isResult = true;
      _recordedCurrentResult = true;
    });
  }

  Future<void> _deleteEntry(HistoryEntry entry) async {
    if (!_skipDeleteConfirmation) {
      final strings = AppStrings.of(context);
      var skip = false;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            scrollable: true,
            title: Text(strings.deleteConfirmation),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.expression} = ${entry.result}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(strings.skipDeleteConfirmation),
                  value: skip,
                  onChanged: (checked) =>
                      setDialogState(() => skip = checked ?? false),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(strings.delete),
              ),
            ],
          ),
        ),
      );
      if (!mounted || confirmed != true) return;
      _skipDeleteConfirmation = skip;
    }

    setState(() => _history.remove(entry));
    if (_settings.persistHistory) _save();
  }

  Future<void> _copyValue(String value) async {
    try {
      await Clipboard.setData(ClipboardData(text: value.replaceAll('−', '-')));
    } on PlatformException catch (error) {
      debugPrint('Could not copy the calculation result: $error');
      if (mounted) _notify(AppStrings.of(context).copyFailed);
      return;
    }
    if (!mounted) return;
    setState(() => _copiedValue = value);
    _copyFeedbackTimer?.cancel();
    _copyFeedbackTimer = Timer(const Duration(seconds: 1), () {
      setState(() => _copiedValue = null);
    });
  }

  void _openSettings() {
    _editorFocus.unfocus();
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          initialSettings: _settings,
          onChanged: (settings) {
            final languageChanged = _settings.language != settings.language;
            setState(() => _settings = settings);
            if (languageChanged) widget.onLanguageChanged(settings.language);
            _save();
          },
        ),
      ),
    );
  }

  double _historyWidth(double totalWidth, double maxWidth, bool landscape) {
    final fraction = landscape
        ? _settings.landscapeHistoryFraction
        : _settings.portraitHistoryFraction;
    return (totalWidth * fraction).clamp(_minimumHistoryWidth, maxWidth);
  }

  void _resizeHistory(
    double delta,
    double totalWidth,
    double maxWidth,
    bool landscape,
  ) {
    final current = _historyWidth(totalWidth, maxWidth, landscape);
    final next = (current + delta).clamp(_minimumHistoryWidth, maxWidth);
    if (next == current) return;
    final fraction = next / totalWidth;
    setState(() {
      _settings = landscape
          ? _settings.copyWith(landscapeHistoryFraction: fraction)
          : _settings.copyWith(portraitHistoryFraction: fraction);
      _resizedHistory = true;
    });
  }

  void _finishResizing() {
    if (!_resizedHistory) return;
    _resizedHistory = false;
    _save();
  }

  Future<void> _save() async {
    try {
      await widget.onSave(
        CalculatorSnapshot(settings: _settings, history: List.of(_history)),
      );
    } catch (error) {
      debugPrint('Could not save JotCalc settings and history: $error');
      if (mounted) _notify(AppStrings.of(context).saveFailed);
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  String? _errorMessage(AppStrings strings) => !_showIssue
      ? null
      : switch (_issue) {
          CalculationIssue.incomplete => strings.incompleteExpression,
          CalculationIssue.divisionByZero => strings.divisionByZero,
          _ => strings.invalidExpression,
        };

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, bounds) {
            final width = bounds.maxWidth;
            final height = bounds.maxHeight;
            final landscape = width > height;
            final compact = width < 360 || height < 360;
            final padding = compact ? 8.0 : 12.0;
            final gap = compact ? 4.0 : 8.0;
            final maxHistoryWidth = width - (4 * 48 + 3 * gap + 2 * padding);
            final inlineHistory =
                _settings.showHistory &&
                maxHistoryWidth >= _minimumHistoryWidth;
            final drawerHistory = _settings.showHistory && !inlineHistory;
            final historyWidth = inlineHistory
                ? _historyWidth(width, maxHistoryWidth, landscape)
                : 0.0;
            final preferredKeypadHeight = landscape
                ? 272.0
                : (height < 600 ? 246.0 : 372.0);

            void resize(double delta) =>
                _resizeHistory(delta, width, maxHistoryWidth, landscape);

            return Scaffold(
              drawerEnableOpenDragGesture: false,
              drawer: drawerHistory
                  ? Drawer(
                      backgroundColor: JotCalcColors.paper,
                      child: Builder(
                        builder: (context) => HistoryPane(
                          header: ListTile(
                            title: Text(strings.history),
                            trailing: IconButton(
                              tooltip: strings.closeHistory,
                              onPressed: Scaffold.of(context).closeDrawer,
                              icon: const Icon(Icons.close),
                            ),
                          ),
                          entries: _history,
                          controller: _historyScroll,
                          onSelect: (entry) {
                            Scaffold.of(context).closeDrawer();
                            _recall(entry);
                          },
                          onDelete: _deleteEntry,
                        ),
                      ),
                    )
                  : null,
              body: FocusScope(
                autofocus: true,
                onKeyEvent: _onHardwareKey,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (inlineHistory)
                      SizedBox(
                        width: historyWidth,
                        child: HistoryPane(
                          header: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SettingsButton(onPressed: _openSettings),
                              HistoryResizeHandle(
                                fraction: historyWidth / width,
                                onDrag: resize,
                                onDragDone: _finishResizing,
                                onWiden: () {
                                  resize(16);
                                  _finishResizing();
                                },
                                onNarrow: () {
                                  resize(-16);
                                  _finishResizing();
                                },
                              ),
                            ],
                          ),
                          entries: _history,
                          controller: _historyScroll,
                          onSelect: _recall,
                          onDelete: _deleteEntry,
                          showDivider: true,
                        ),
                      ),
                    Expanded(
                      child: Column(
                        children: [
                          if (!inlineHistory)
                            Row(
                              children: [
                                SettingsButton(onPressed: _openSettings),
                                if (drawerHistory)
                                  Builder(
                                    builder: (context) => IconButton(
                                      tooltip: strings.history,
                                      onPressed: Scaffold.of(context)
                                          .openDrawer,
                                      icon: const Icon(
                                        Icons.history_rounded,
                                        color: JotCalcColors.muted,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                padding,
                                inlineHistory ? padding : 0,
                                padding,
                                padding,
                              ),
                              child: LayoutBuilder(
                                builder: (context, desk) {
                                  final panelMin = math.min(
                                    86.0,
                                    desk.maxHeight * 0.35,
                                  );
                                  final panelGap = compact ? 6.0 : 8.0;
                                  final keypadHeight = math.max(
                                    0.0,
                                    math.min(
                                      preferredKeypadHeight,
                                      desk.maxHeight - panelMin - panelGap,
                                    ),
                                  );
                                  final value = _value;
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    spacing: panelGap,
                                    children: [
                                      Expanded(
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            CalculationDisplay(
                                              controller: _editor,
                                              focusNode: _editorFocus,
                                              onEdit: _editExpression,
                                              isResult: _isResult,
                                              largeFontSize: compact
                                                  ? 28
                                                  : (landscape ? 34 : 40),
                                              smallFontSize: compact
                                                  ? 13
                                                  : (landscape ? 14 : 16),
                                              result: value,
                                              error: _errorMessage(strings),
                                              onCopy: value == null
                                                  ? null
                                                  : () => _copyValue(value),
                                            ),
                                            if (value != null &&
                                                _copiedValue == value)
                                              Positioned(
                                                top: 8,
                                                left: 12,
                                                child: IgnorePointer(
                                                  child: Semantics(
                                                    liveRegion: true,
                                                    child: Text(
                                                      strings.copied,
                                                      style: const TextStyle(
                                                        color: JotCalcColors
                                                            .accent,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        height: keypadHeight,
                                        child: CalculatorKeypad(
                                          gap: gap,
                                          onKey: _onKey,
                                          onHoldEquals:
                                              _settings.saveHistoryOnLongPress
                                              ? () =>
                                                    _confirm(addToHistory: true)
                                              : null,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
