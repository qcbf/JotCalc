import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'app_localization.dart';
import 'calculation.dart';
import 'calculator_store.dart';
import 'calculator_widgets.dart';
import 'settings_page.dart';

typedef _DisplayState = ({
  String? result,
  CalculationIssue? error,
  bool confirmed,
});

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({
    super.key,
    required this.initialSnapshot,
    required this.onSave,
    required this.onSettingsChanged,
  });

  final CalculatorSnapshot initialSnapshot;
  final Future<void> Function(CalculatorSnapshot) onSave;
  final ValueChanged<CalculatorSettings> onSettingsChanged;

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
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _display = ValueNotifier<_DisplayState>((
    result: null,
    error: null,
    confirmed: false,
  ));

  late final bool _allowAdvancedInput = switch (defaultTargetPlatform) {
    TargetPlatform.windows => true,
    TargetPlatform.macOS || TargetPlatform.linux => kIsWeb,
    _ => false,
  };
  late final AppLifecycleListener _lifecycle;
  late CalculatorSettings _settings;
  late final List<HistoryEntry> _history;
  String _evaluatedExpression = '';
  ({String value, HistoryEntry? entry})? _copyFeedback;
  Timer? _copyFeedbackTimer;
  ({PhysicalKeyboardKey key, Timer timer})? _enterHold;
  CalculationIssue? _draftIssue;
  bool _recordedCurrentResult = false;
  bool _skipDeleteConfirmation = false;
  bool _resizedHistory = false;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSnapshot.settings;
    _history = List.of(widget.initialSnapshot.history);
    _editor.addListener(_evaluateDraft);
    _lifecycle = AppLifecycleListener(onInactive: _cancelEnterHold);
    FocusManager.instance.addLateKeyEventHandler(_onUnhandledKey);
  }

  @override
  void dispose() {
    FocusManager.instance.removeLateKeyEventHandler(_onUnhandledKey);
    _lifecycle.dispose();
    _cancelEnterHold();
    _copyFeedbackTimer?.cancel();
    _editor.dispose();
    _editorFocus.dispose();
    _historyScroll.dispose();
    _display.dispose();
    super.dispose();
  }

  void _evaluateDraft() {
    final expression = _editor.text;
    if (expression == _evaluatedExpression) return;
    _cancelEnterHold();
    _evaluatedExpression = expression;
    _recordedCurrentResult = false;

    String? result;
    _draftIssue = null;
    try {
      if (expression.isNotEmpty) {
        result = evaluateExpression(
          expression,
          allowAdvanced: _allowAdvancedInput,
        );
      }
    } on CalculationException catch (error) {
      _draftIssue = error.issue;
    }

    _display.value = (result: result, error: null, confirmed: false);
  }

  void _editExpression() {
    final display = _display.value;
    if (!display.confirmed) return;
    _cancelEnterHold();
    _recordedCurrentResult = false;
    _display.value = (result: display.result, error: null, confirmed: false);
  }

  void _replaceExpression(String expression, [int? offset]) {
    _editor.value = TextEditingValue(
      text: expression,
      selection: TextSelection.collapsed(offset: offset ?? expression.length),
    );
  }

  bool get _calculatorIsActive {
    final scaffold = _scaffoldKey.currentState;
    return ModalRoute.isCurrentOf(context) == true &&
        scaffold != null &&
        !(scaffold.hasDrawer && scaffold.isDrawerOpen);
  }

  KeyEventResult _onHardwareKey(FocusNode scope, KeyEvent event) =>
      _handleHardwareKey(
        event,
        canConfirm: scope.hasPrimaryFocus || _editorFocus.hasFocus,
      );

  // Closing a Web drawer can leave focus outside the calculator's scope.
  KeyEventResult _onUnhandledKey(KeyEvent event) =>
      _handleHardwareKey(event, canConfirm: true);

  KeyEventResult _handleHardwareKey(
    KeyEvent event, {
    required bool canConfirm,
  }) {
    if (event is KeyUpEvent) {
      if (_enterHold?.key == event.physicalKey) _cancelEnterHold();
      return KeyEventResult.ignored;
    }
    if (event.synthesized || !_calculatorIsActive) {
      return KeyEventResult.ignored;
    }

    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed) {
      _cancelEnterHold();
      return KeyEventResult.ignored;
    }

    final isEnter =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (isEnter && canConfirm) {
      if (event is KeyDownEvent) _pressEnter(event.physicalKey);
      return KeyEventResult.handled;
    }

    final key = switch (event.logicalKey) {
      LogicalKeyboardKey.delete => 'C',
      LogicalKeyboardKey.backspace => '⌫',
      _ => switch (event.character) {
        '-' => '−',
        '*' => '×',
        '/' => '÷',
        final String character
            when character.length == 1 &&
                '0123456789+−×÷.%'.contains(character) =>
          character,
        final String character
            when _allowAdvancedInput &&
                character.length == 1 &&
                (character == ' ' || hasAdvancedSyntax(character)) =>
          character.toLowerCase(),
        _ => null,
      },
    };
    if (key == null) return KeyEventResult.ignored;

    _onKey(key);
    return KeyEventResult.handled;
  }

  void _pressEnter(PhysicalKeyboardKey key) {
    _cancelEnterHold();
    _confirm();
    if (!_settings.saveHistoryOnLongPress ||
        _display.value.result == null ||
        _recordedCurrentResult) {
      return;
    }
    _enterHold = (
      key: key,
      timer: Timer(kLongPressTimeout, () {
        _enterHold = null;
        if (_calculatorIsActive &&
            HardwareKeyboard.instance.isPhysicalKeyPressed(key)) {
          _confirm(addToHistory: true);
        }
      }),
    );
  }

  void _cancelEnterHold() {
    _enterHold?.timer.cancel();
    _enterHold = null;
  }

  void _onKey(String key) {
    if (key == '=') {
      _confirm();
      return;
    }

    if (key == 'C') {
      _editExpression();
      _replaceExpression('');
      _editorFocus.requestFocus();
      return;
    }

    final display = _display.value;
    if (display.confirmed) {
      _editExpression();
      if (key == '⌫') {
        _editor.selection = TextSelection.collapsed(
          offset: _editor.text.length,
        );
      } else {
        final continueFromResult =
            _binaryOperators.contains(key) ||
            key == '%' ||
            (_allowAdvancedInput && '^&|<>m '.contains(key));
        _replaceExpression(continueFromResult ? display.result! : '');
      }
    }

    _editorFocus.requestFocus();
    final draft = _editor.text;
    final advancedDraft = _allowAdvancedInput && hasAdvancedSyntax(draft);
    final selection = _editor.selection;
    var start = selection.isValid ? selection.start : draft.length;
    final end = selection.isValid ? selection.end : draft.length;
    var insertion = key;

    if (key == '⌫') {
      if (start == end) {
        while (!advancedDraft && start > 0 && draft[start - 1] == ' ') {
          start--;
        }
        if (start > 0) start--;
      }
      insertion = '';
    } else if (!advancedDraft && start == end && end == draft.length) {
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
    final value = _display.value.result;
    if (value == null) {
      if (_editor.text.trim().isNotEmpty) {
        _display.value = (
          result: null,
          error: _draftIssue ?? CalculationIssue.invalid,
          confirmed: false,
        );
      }
      return;
    }

    _display.value = (result: value, error: null, confirmed: true);
    final record =
        !_recordedCurrentResult &&
        (addToHistory || !_settings.saveHistoryOnLongPress);
    _editorFocus.unfocus();
    if (record) {
      setState(() {
        _history.add(HistoryEntry(expression: _editor.text, result: value));
        _recordedCurrentResult = true;
      });
      if (_historyScroll.hasClients) _historyScroll.jumpTo(0);
      if (_settings.persistHistory) _save();
    }
  }

  void _recall(HistoryEntry entry) {
    _cancelEnterHold();
    _evaluatedExpression = entry.expression;
    _replaceExpression(entry.expression);
    _draftIssue = null;
    _recordedCurrentResult = true;
    _display.value = (result: entry.result, error: null, confirmed: true);
    _editorFocus.requestFocus();
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

    if (_history.remove(entry)) {
      setState(() {});
      if (_settings.persistHistory) _save();
    }
  }

  Future<void> _clearHistory() async {
    final strings = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(strings.clearHistoryConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.clearHistory),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    setState(() {
      _history.clear();
      _recordedCurrentResult = false;
    });
    if (_settings.persistHistory) await _save();
  }

  Future<void> _copyHistoryResult(HistoryEntry entry) =>
      _copyValue(entry.result, historyEntry: entry);

  Future<void> _copyValue(String value, {HistoryEntry? historyEntry}) async {
    try {
      await Clipboard.setData(ClipboardData(text: value.replaceAll('−', '-')));
    } on PlatformException catch (error) {
      debugPrint('Could not copy the calculation result: $error');
      if (mounted) _notify(AppStrings.of(context).copyFailed);
      return;
    }
    if (!mounted) return;
    setState(() => _copyFeedback = (value: value, entry: historyEntry));
    _copyFeedbackTimer?.cancel();
    _copyFeedbackTimer = Timer(const Duration(seconds: 1), () {
      setState(() => _copyFeedback = null);
    });
  }

  void _openSettings() {
    _editorFocus.unfocus();
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          initialSettings: _settings,
          allowAdvancedInput: _allowAdvancedInput,
          onChanged: (settings) {
            setState(() => _settings = settings);
            widget.onSettingsChanged(settings);
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

  Widget _historyPane(Widget header, {bool inDrawer = false}) => HistoryPane(
    header: header,
    entries: _history,
    copiedEntry: _copyFeedback?.entry,
    controller: _historyScroll,
    onCopy: _copyHistoryResult,
    onRecall: inDrawer
        ? (entry) {
            _scaffoldKey.currentState?.closeDrawer();
            _recall(entry);
          }
        : _recall,
    onDelete: _deleteEntry,
    showDivider: !inDrawer,
  );

  Widget _buildDisplay({
    required double largeFontSize,
    required double smallFontSize,
  }) {
    return RepaintBoundary(
      child: ValueListenableBuilder<_DisplayState>(
        valueListenable: _display,
        builder: (context, display, _) {
          final strings = AppStrings.of(context);
          final error = switch (display.error) {
            CalculationIssue.incomplete => strings.incompleteExpression,
            CalculationIssue.divisionByZero => strings.divisionByZero,
            CalculationIssue.outOfRange => strings.calculationOutOfRange,
            CalculationIssue.invalid => strings.invalidExpression,
            null => null,
          };
          final result = display.result;
          return Stack(
            fit: StackFit.expand,
            children: [
              CalculationDisplay(
                controller: _editor,
                focusNode: _editorFocus,
                onEdit: _editExpression,
                isResult: display.confirmed,
                allowAdvancedInput: _allowAdvancedInput,
                largeFontSize: largeFontSize,
                smallFontSize: smallFontSize,
                result: result,
                error: error,
                onCopy: result == null ? null : () => _copyValue(result),
              ),
              if (result != null &&
                  _copyFeedback == (value: result, entry: null))
                Positioned(
                  top: 5,
                  left: 8,
                  child: IgnorePointer(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        strings.copied,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colors = Theme.of(context).colorScheme;
    final clearHistoryButton = IconButton(
      tooltip: strings.clearHistory,
      onPressed: _history.isEmpty ? null : _clearHistory,
      color: colors.onSurfaceVariant,
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.delete_outline),
    );
    return ColoredBox(
      color: colors.surface,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, bounds) {
            final width = bounds.maxWidth;
            final height = bounds.maxHeight;
            final landscape = width > height;
            final compact = width < 360 || height < 360;
            final padding = compact ? 6.0 : 8.0;
            final gap = compact ? 3.0 : 6.0;
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
              key: _scaffoldKey,
              drawerEnableOpenDragGesture: false,
              onDrawerChanged: (isOpen) {
                if (isOpen) _cancelEnterHold();
              },
              drawer: drawerHistory
                  ? Drawer(
                      backgroundColor: colors.surfaceContainerLow,
                      child: _historyPane(
                        ListTile(
                          title: Text(strings.history),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              clearHistoryButton,
                              IconButton(
                                tooltip: strings.closeHistory,
                                onPressed: () =>
                                    _scaffoldKey.currentState?.closeDrawer(),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                        inDrawer: true,
                      ),
                    )
                  : null,
              body: FocusScope(
                autofocus: true,
                onFocusChange: (hasFocus) {
                  if (!hasFocus) _cancelEnterHold();
                },
                onKeyEvent: _onHardwareKey,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (inlineHistory)
                      SizedBox(
                        width: historyWidth,
                        child: _historyPane(
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: SettingsButton(onPressed: _openSettings),
                              ),
                              Flexible(child: clearHistoryButton),
                              Flexible(
                                child: HistoryResizeHandle(
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
                              ),
                            ],
                          ),
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
                                  IconButton(
                                    tooltip: strings.history,
                                    onPressed: () =>
                                        _scaffoldKey.currentState?.openDrawer(),
                                    icon: Icon(
                                      Icons.history_rounded,
                                      color: colors.onSurfaceVariant,
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
                                  final panelGap = compact ? 4.0 : 6.0;
                                  final keypadHeight = math.max(
                                    0.0,
                                    math.min(
                                      preferredKeypadHeight,
                                      desk.maxHeight - panelMin - panelGap,
                                    ),
                                  );
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    spacing: panelGap,
                                    children: [
                                      Expanded(
                                        child: _buildDisplay(
                                          largeFontSize: compact
                                              ? 28
                                              : (landscape ? 34 : 40),
                                          smallFontSize: compact
                                              ? 13
                                              : (landscape ? 14 : 16),
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
