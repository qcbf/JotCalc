import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jotcalc/calculator_store.dart';
import 'package:jotcalc/calculator_widgets.dart';
import 'package:jotcalc/main.dart';
import 'package:material_ui/material_ui.dart';

Finder _key(String key) => find.byKey(ValueKey('key-$key'));
Finder _historyText(String text) =>
    find.descendant(of: find.byType(HistoryPane), matching: find.text(text));

Future<void> _start(
  WidgetTester tester,
  List<CalculatorSnapshot> saves, {
  CalculatorSnapshot snapshot = const CalculatorSnapshot(),
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    JotCalcApp(
      key: UniqueKey(),
      initialSnapshot: snapshot,
      onSave: (snapshot) async => saves.add(snapshot),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _press(WidgetTester tester, List<String> keys) async {
  for (final key in keys) {
    await tester.tap(_key(key));
    await tester.pump();
  }
}

CalculationDisplay _display(WidgetTester tester) =>
    tester.widget(find.byType(CalculationDisplay));

void main() {
  testWidgets(
    'tap into a confirmed expression and edit at the touched position',
    (tester) async {
      final saves = <CalculatorSnapshot>[];
      await _start(tester, saves);
      await _press(tester, ['2', '+', '3', '4', '=']);
      expect(_display(tester).isResult, isTrue);
      expect(_display(tester).result, '36');
      expect(saves.single.history.single.expression, '2+34');

      final editable = tester
          .state<EditableTextState>(find.byType(EditableText))
          .renderEditable;
      final localCaret = editable.getLocalRectForCaret(
        const TextPosition(offset: 3),
      );
      await tester.tapAt(editable.localToGlobal(localCaret.center));
      await tester.pump();
      expect(_display(tester).isResult, isFalse);
      expect(_display(tester).controller.selection.baseOffset, 3);
      expect(
        tester.widget<TextField>(find.byType(TextField)).keyboardType,
        TextInputType.none,
      );

      await _press(tester, ['⌫', '9']);
      expect(_display(tester).controller.text, '2+94');
      expect(_display(tester).result, '96');
      _display(tester).controller.selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 4,
      );
      await _press(tester, ['5', '=']);
      expect(_display(tester).controller.text, '2+5');
      expect(saves.last.history.map((entry) => entry.result), ['36', '7']);
    },
  );

  testWidgets(
    'confirm once, continue from the result, and begin a fresh number',
    (tester) async {
      final saves = <CalculatorSnapshot>[];
      await _start(tester, saves);
      await _press(tester, ['2', '+', '3', '=', '=']);
      expect(saves.single.history.single.result, '5');
      await _press(tester, ['×', '4', '=']);
      expect(_display(tester).controller.text, '5×4');
      expect(_display(tester).result, '20');
      await _press(tester, ['9', '÷', '0', '=']);
      expect(_display(tester).controller.text, '9÷0');
      expect(find.text('不能除以零'), findsOneWidget);
      expect(saves.last.history.map((entry) => entry.result), ['5', '20']);
    },
  );

  testWidgets('hardware input uses the keypad rules and result transitions', (
    tester,
  ) async {
    final saves = <CalculatorSnapshot>[];
    await _start(tester, saves);
    expect(_display(tester).focusNode.hasFocus, isFalse);

    Future<void> type(LogicalKeyboardKey key, [String? character]) async {
      expect(await tester.sendKeyEvent(key, character: character), isTrue);
      await tester.pump();
    }

    await type(LogicalKeyboardKey.digit1, '1');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await type(LogicalKeyboardKey.equal, '+');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await type(LogicalKeyboardKey.digit2, '2');
    await type(LogicalKeyboardKey.numpadMultiply, '*');
    await type(LogicalKeyboardKey.digit3, '3');
    await type(LogicalKeyboardKey.slash, '/');
    await type(LogicalKeyboardKey.digit2, '2');
    await type(LogicalKeyboardKey.minus, '-');
    await type(LogicalKeyboardKey.digit0, '0');
    expect(_display(tester).controller.text, '1+2×3÷2−0');
    expect(_display(tester).isResult, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal, character: '=');
    await tester.pump();
    expect(_display(tester).isResult, isFalse);
    expect(saves, isEmpty);
    await type(LogicalKeyboardKey.enter);
    expect(saves.single.history.single.result, '4');

    // The browser can return focus to the editor after confirmation.
    _display(tester).focusNode.requestFocus();
    await tester.pump();
    expect(_display(tester).isResult, isTrue);

    await type(LogicalKeyboardKey.numpadAdd, '+');
    await type(LogicalKeyboardKey.numpadDecimal, '.');
    await type(LogicalKeyboardKey.numpad5, '5');
    await type(LogicalKeyboardKey.numpadEnter);
    expect(saves.last.history.last.expression, '4+0.5');
    expect(_display(tester).result, '4.5');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.numpad1, character: '1');
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.numpad1, character: '1');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.numpad1);
    await tester.pump();
    expect(_display(tester).controller.text, '11');
    await type(LogicalKeyboardKey.backspace);
    expect(_display(tester).controller.text, '1');
  });

  testWidgets(
    'hardware input replaces a selection and stays on the calculator',
    (tester) async {
      await _start(tester, []);
      await _press(tester, ['2', '+', '3', '4']);
      _display(tester).controller.selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 4,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.digit5, character: '5');
      await tester.pump();
      expect(_display(tester).controller.text, '2+5');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit9, character: '9');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(_display(tester).controller.text, '2+5');

      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.digit9, character: '9');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(_display(tester).controller.text, '2+5');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(_display(tester).isResult, isTrue);
      expect(_display(tester).result, '7');
    },
  );

  testWidgets(
    'manual history can save an already confirmed value exactly once and copy it',
    (tester) async {
      final saves = <CalculatorSnapshot>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      Object? clipboard;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') clipboard = call.arguments;
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await _start(tester, saves);
      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('仅长按 = 添加到历史'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      await _press(tester, ['1', '4', '=']);
      expect(_display(tester).isResult, isTrue);
      expect(saves.single.history, isEmpty);
      await tester.longPress(
        find.descendant(
          of: find.byType(CalculationDisplay),
          matching: find.byWidgetPredicate(
            (widget) => widget is Text && widget.data == '14',
          ),
        ),
      );
      await tester.pump();
      expect(clipboard, {'text': '14'});

      await tester.longPress(_key('='));
      await tester.pump();
      await tester.longPress(_key('='));
      await tester.pump();
      expect(saves.length, 2);
      expect(saves.last.history.single.result, '14');
      await _press(tester, ['9', '+', '2']);
      await tester.longPress(_key('='));
      await tester.pump();
      expect(_display(tester).isResult, isTrue);
      expect(saves.last.history.map((entry) => entry.result), ['14', '11']);
    },
  );

  testWidgets(
    'recalls history and applies delete confirmation for the running session',
    (tester) async {
      final saves = <CalculatorSnapshot>[];
      await _start(
        tester,
        saves,
        snapshot: const CalculatorSnapshot(
          history: [
            HistoryEntry(expression: '2+5', result: '7'),
            HistoryEntry(expression: '2×4', result: '8'),
            HistoryEntry(expression: '3×3', result: '9'),
          ],
        ),
      );
      await _press(tester, ['1', '+']);
      await tester.tap(_historyText('8'));
      await tester.pump();
      expect(_display(tester).controller.text, '2×4');
      expect(_display(tester).isResult, isTrue);
      expect(saves, isEmpty);

      await tester.longPress(_historyText('9'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('本次运行不再提示'));
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(_historyText('9'), findsOneWidget);

      await tester.longPress(_historyText('9'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      await tester.tap(find.text('本次运行不再提示'));
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.longPress(_historyText('8'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(saves.last.history.single.result, '7');
    },
  );

  testWidgets('hides the sidebar independently of history persistence', (
    tester,
  ) async {
    final saves = <CalculatorSnapshot>[];
    await _start(tester, saves);
    await _press(tester, ['1', '+', '2', '=']);

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('显示历史记录'));
    await tester.tap(find.text('持久化历史'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryPane), findsNothing);
    expect(saves.last.toJson().containsKey('history'), isFalse);
    expect(saves.last.history.single.result, '3');
    await _press(tester, ['7', '=']);

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('显示历史记录'));
    await tester.tap(find.text('持久化历史'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    final restored = CalculatorSnapshot.fromJson(
      jsonDecode(jsonEncode(saves.last.toJson())) as Map<String, dynamic>,
    );
    expect(restored.history.map((entry) => entry.result), ['3', '7']);
    expect(_historyText('3'), findsOneWidget);
  });

  testWidgets('switches languages immediately and restores the saved choice', (
    tester,
  ) async {
    final saves = <CalculatorSnapshot>[];
    final legacySnapshot = CalculatorSnapshot.fromJson({
      'settings': {'portraitHistoryFraction': 0.3},
      'history': [
        {'expression': '8×2', 'result': '16'},
      ],
    });
    await _start(
      tester,
      saves,
      snapshot: legacySnapshot,
      size: const Size(320, 440),
    );
    await _press(tester, ['9', '÷', '0', '=']);
    expect(find.text('不能除以零'), findsOneWidget);

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('语言'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Show history'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(_display(tester).controller.text, '9÷0');
    expect(find.text('Cannot divide by zero'), findsOneWidget);

    await tester.longPress(_historyText('16'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this history entry?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    final restored = CalculatorSnapshot.fromJson(
      jsonDecode(jsonEncode(saves.single.toJson())) as Map<String, dynamic>,
    );
    expect(restored.settings.portraitHistoryFraction, 0.3);
    expect(restored.history.single.result, '16');

    await _start(tester, saves, snapshot: restored);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('English'), findsOneWidget);
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('简体中文'));
    await tester.pumpAndSettle();
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('显示历史记录'), findsOneWidget);
  });

  testWidgets(
    'drag persists the portrait ratio and the narrow keypad remains usable',
    (tester) async {
      final saves = <CalculatorSnapshot>[];
      await _start(tester, saves);
      final pane = find.byType(HistoryPane);
      final initialWidth = tester.getSize(pane).width;
      await tester.drag(find.byType(HistoryResizeHandle), const Offset(32, 0));
      await tester.pumpAndSettle();
      final savedWidth = tester.getSize(pane).width;
      expect(savedWidth, greaterThan(initialWidth));
      final saved = saves.single;
      expect(
        saved.settings.portraitHistoryFraction,
        closeTo(savedWidth / 390, 0.001),
      );
      expect(saved.settings.landscapeHistoryFraction, 0.25);

      tester.view.physicalSize = const Size(320, 440);
      await tester.pumpAndSettle();
      expect(tester.getSize(_key('1')).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(_key('1')).height, greaterThanOrEqualTo(44));
      await _press(tester, ['7', '=']);
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      expect(tester.getSize(pane).width, closeTo(211, 0.01));
      expect(_display(tester).result, '7');
      expect(tester.takeException(), isNull);

      await _start(tester, saves, snapshot: saved);
      expect(tester.getSize(pane).width, closeTo(savedWidth, 0.01));
    },
  );
}
