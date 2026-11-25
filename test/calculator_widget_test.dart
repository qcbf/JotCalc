import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart'
    show
        kDoubleTapMinTime,
        kLongPressTimeout,
        PointerDeviceKind,
        PointerScrollEvent;
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jotcalc/calculator_store.dart';
import 'package:jotcalc/calculator_widgets.dart';
import 'package:jotcalc/main.dart';
import 'package:jotcalc/programmer_calculation.dart';
import 'package:jotcalc/programmer_panel.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

Finder _key(String key) => find.byKey(ValueKey('key-$key'));
Finder _programmerKey(String key) =>
    find.byKey(ValueKey('programmer-key-$key'));
Finder _radix(String radix) => find.byKey(ValueKey('programmer-radix-$radix'));
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

List<String> _captureClipboard() {
  final copies = <String>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') {
      copies.add((call.arguments as Map)['text'] as String);
    }
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return copies;
}

void main() {
  testWidgets(
    'chooses a mode directly in settings and restores it from storage',
    (tester) async {
      final saves = <CalculatorSnapshot>[];
      await _start(
        tester,
        saves,
        snapshot: CalculatorSnapshot.fromJson({
          'settings': {
            'persistHistory': false,
            'portraitHistoryFraction': 0.25,
          },
        }),
        size: const Size(320, 440),
      );
      expect(find.byType(CalculatorKeypad), findsOneWidget);

      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('计算模式')).dy,
        lessThan(tester.getTopLeft(find.text('语言')).dy),
      );
      expect(find.text('标准模式'), findsOneWidget);
      await tester.tap(find.text('程序员模式'));
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsNothing);
      expect(find.byType(ProgrammerPanel), findsOneWidget);
      final radixRow = tester.getTopLeft(_radix('dec')).dy;
      for (final radix in ProgrammerRadix.values) {
        final button = _radix(radix.name);
        expect(button.hitTestable(), findsOneWidget);
        expect(tester.getTopLeft(button).dy, radixRow);
      }
      expect(
        tester.getBottomLeft(_programmerKey('=')).dy,
        lessThanOrEqualTo(440),
      );
      tester.view.physicalSize = const Size(381, 452);
      await tester.pumpAndSettle();
      expect(find.byType(HistoryPane), findsOneWidget);
      await tester.tap(find.byTooltip('位编辑'));
      await tester.pumpAndSettle();
      final display = tester.getRect(find.byType(CalculationDisplay));
      final grid = tester.getRect(find.byType(Table));
      final lowBit = find.byKey(const ValueKey('programmer-bit-0'));
      final bit60 = tester.getRect(
        find.byKey(const ValueKey('programmer-bit-60')),
      );
      final index60 = tester.getRect(find.text('60'));
      expect(display.contains(tester.getCenter(_radix('hex'))), isTrue);
      expect(grid.left, closeTo(display.left, 0.5));
      expect(grid.right, closeTo(display.right, 0.5));
      expect(index60.center.dy, closeTo(bit60.center.dy, 0.5));
      expect(index60.left, greaterThan(bit60.right));
      expect(lowBit.hitTestable(), findsOneWidget);
      expect(tester.getBottomLeft(lowBit).dy, lessThanOrEqualTo(452));
      expect(saves.single.settings.mode, CalculatorMode.programmer);
      expect(saves.single.toJson().containsKey('history'), isFalse);

      final restored = CalculatorSnapshot.fromJson(
        jsonDecode(jsonEncode(saves.single.toJson())) as Map<String, dynamic>,
      );
      await _start(tester, saves, snapshot: restored);
      expect(find.byType(ProgrammerPanel), findsOneWidget);
      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('标准模式'));
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsNothing);
      expect(find.byType(CalculatorKeypad), findsOneWidget);
      expect(saves.last.settings.mode, CalculatorMode.standard);
    },
  );

  testWidgets('Windows Alt shortcuts switch from focused input and settings', (
    tester,
  ) async {
    final saves = <CalculatorSnapshot>[];
    await _start(tester, saves);
    await _press(tester, ['4', '+', '2']);

    Future<void> switchWithAlt(LogicalKeyboardKey key) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
    }

    await switchWithAlt(LogicalKeyboardKey.digit2);
    expect(find.byType(ProgrammerPanel), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit5, character: '5');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_display(tester).result, '5');
    expect(saves.last.history.single.programmerFormat, defaultProgrammerFormat);

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await switchWithAlt(LogicalKeyboardKey.digit1);
    expect(find.byType(BackButton), findsNothing);
    expect(find.byType(CalculatorKeypad), findsOneWidget);
    expect(_display(tester).controller.text, '4+2');
    expect(saves.last.settings.mode, CalculatorMode.standard);
    expect(_historyText('5'), findsNothing);

    await switchWithAlt(LogicalKeyboardKey.digit2);
    expect(_display(tester).result, '5');
    expect(_historyText('DEC · QWORD'), findsOneWidget);
  }, variant: const TargetPlatformVariant({TargetPlatform.windows}));

  testWidgets(
    'programmer keypad, radix, bits and history share the word size',
    (tester) async {
      final saves = <CalculatorSnapshot>[];
      await _start(
        tester,
        saves,
        size: const Size(960, 640),
        snapshot: const CalculatorSnapshot(
          settings: CalculatorSettings(mode: CalculatorMode.programmer),
        ),
      );

      Future<void> tap(Finder finder) async {
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      expect(
        tester.widget<CalculatorKeyButton>(_programmerKey('F')).onTap,
        isNull,
      );
      await tap(_radix('hex'));
      await tap(find.byTooltip('字长'));
      await tap(find.text('BYTE'));
      for (final symbol in ['7', 'F', '+', '1', '=']) {
        await tap(_programmerKey(symbol));
      }
      expect(_display(tester).result, '80');
      for (final radix in ProgrammerRadix.values) {
        final descendants = find.descendant(
          of: _radix(radix.name),
          matching: find.byType(Text),
        );
        expect(tester.widget<Text>(descendants).data, radix.label);
      }
      await tap(_radix('dec'));
      expect(_display(tester).controller.text, '127+1');
      expect(_display(tester).result, '−128');
      await tap(_radix('oct'));
      expect(_display(tester).controller.text, '177+1');
      expect(_display(tester).result, '200');
      await tap(_radix('bin'));
      expect(_display(tester).controller.text, '1111111+1');
      expect(_display(tester).result, '10000000');
      await tap(_radix('hex'));
      final restored = CalculatorSnapshot.fromJson(
        jsonDecode(jsonEncode(saves.single.toJson())) as Map<String, dynamic>,
      );
      expect(restored.history.single.programmerFormat, (
        radix: ProgrammerRadix.hex,
        wordSize: ProgrammerWordSize.byte,
      ));

      await tap(find.text('位编辑'));
      await tap(find.byKey(const ValueKey('programmer-bit-0')));
      expect(_display(tester).result, '81');
      await tap(find.byKey(const ValueKey('programmer-bit-7')));
      expect(_display(tester).result, '1');
      await tap(_radix('bin'));
      await tap(find.text('键盘'));
      expect(
        tester.widget<CalculatorKeyButton>(_programmerKey('2')).onTap,
        isNull,
      );

      await tester.tap(_historyText('80'));
      await tester.pump(kDoubleTapMinTime);
      await tester.tap(_historyText('80'));
      await tester.pumpAndSettle();
      expect(_display(tester).controller.text, '7F+1');
      expect(_display(tester).result, '80');
      expect(find.text('BYTE'), findsOneWidget);
    },
  );

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

  testWidgets('scrolls a long expression without covering it', (tester) async {
    const caption = '121';
    final controller = TextEditingController(
      text: '${List.filled(120, '1+').join()}1',
    );
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 236,
              height: 110,
              child: CalculationDisplay(
                controller: controller,
                focusNode: focusNode,
                onEdit: () {},
                isResult: false,
                largeFontSize: 28,
                smallFontSize: 13,
                result: caption,
              ),
            ),
          ),
        ),
      ),
    );

    final scrollbar = find.byType(Scrollbar);
    final scrollbarBounds = tester.getRect(scrollbar);
    final painter = tester
        .widgetList<CustomPaint>(
          find.descendant(of: scrollbar, matching: find.byType(CustomPaint)),
        )
        .map((widget) => widget.foregroundPainter)
        .whereType<ScrollbarPainter>()
        .single;
    final editable = tester
        .state<EditableTextState>(find.byType(EditableText))
        .renderEditable;
    final editableRight = editable
        .localToGlobal(Offset(editable.size.width, 0))
        .dx;
    expect(
      scrollbarBounds.right - editableRight,
      greaterThanOrEqualTo(painter.thickness + 2 * painter.crossAxisMargin),
    );
    expect(
      tester.getRect(find.text(caption)).right,
      closeTo(editableRight, 0.01),
    );

    final position = tester.widget<Scrollbar>(scrollbar).controller!.position;
    expect(position.maxScrollExtent, greaterThan(0));
    final initialOffset = position.pixels;
    await tester.sendEventToBinding(
      PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        position: editable.localToGlobal(editable.size.center(Offset.zero)),
        scrollDelta: const Offset(0, 48),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final offsetAfterWheel = position.pixels;
    expect(offsetAfterWheel, greaterThan(initialOffset));

    final thumbPoint = Offset(
      scrollbarBounds.width - painter.crossAxisMargin - painter.thickness / 2,
      scrollbarBounds.height / 3,
    );
    expect(
      painter.hitTestOnlyThumbInteractive(thumbPoint, PointerDeviceKind.mouse),
      isTrue,
    );
    await tester.dragFrom(
      scrollbarBounds.topLeft + thumbPoint,
      const Offset(0, 20),
      kind: PointerDeviceKind.mouse,
    );
    expect(position.pixels, greaterThan(offsetAfterWheel));
  });

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
    await type(LogicalKeyboardKey.delete);
    expect(_display(tester).controller.text, isEmpty);
    expect(_display(tester).result, isNull);
    expect(saves, hasLength(2));
  });

  testWidgets(
    'desktop advanced keyboard input calculates, continues, and accepts pasted expressions',
    (tester) async {
      final saves = <CalculatorSnapshot>[];
      await _start(tester, saves);

      for (final (key, character) in [
        (LogicalKeyboardKey.keyP, 'p'),
        (LogicalKeyboardKey.keyO, 'o'),
        (LogicalKeyboardKey.keyW, 'w'),
        (LogicalKeyboardKey.digit9, '('),
        (LogicalKeyboardKey.digit2, '2'),
        (LogicalKeyboardKey.comma, ','),
        (LogicalKeyboardKey.space, ' '),
        (LogicalKeyboardKey.digit3, '3'),
        (LogicalKeyboardKey.digit0, ')'),
      ]) {
        await tester.sendKeyEvent(key, character: character);
        await tester.pump();
      }
      expect(_display(tester).controller.text, 'pow(2, 3)');
      expect(_display(tester).result, '8');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(saves.single.history.single.result, '8');

      await tester.sendKeyEvent(LogicalKeyboardKey.digit6, character: '^');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3, character: '3');
      await tester.pump();
      expect(_display(tester).controller.text, '8^3');
      expect(_display(tester).result, '11');

      await tester.enterText(find.byType(TextField), 'ABS(-3) + 17 mod 5');
      await tester.pump();
      expect(_display(tester).controller.text, 'ABS(−3) + 17 mod 5');
      expect(_display(tester).result, '5');
    },
    variant: const TargetPlatformVariant(
      kIsWeb
          ? {TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux}
          : {TargetPlatform.windows},
    ),
  );

  testWidgets(
    'mobile keeps basic input for hardware keys and pasted expressions',
    (tester) async {
      await _start(tester, []);
      await _press(tester, ['2', '0', '0', '+', '1', '0', '%']);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit9, character: '(');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP, character: 'p');
      await tester.pump();
      expect(_display(tester).controller.text, '200+10%');
      expect(_display(tester).result, '220');

      await tester.enterText(find.byType(TextField), 'pow(2, 3)');
      await tester.pump();
      expect(_display(tester).controller.text, '200+10%');
      expect(_display(tester).result, '220');
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

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
      final copies = _captureClipboard();

      await _start(tester, saves);
      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('仅长按 = 或回车添加到历史'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      await _press(tester, ['1', '4', '=']);
      expect(_display(tester).isResult, isTrue);
      expect(saves.single.history, isEmpty);
      await tester.tap(
        find.descendant(
          of: find.byType(CalculationDisplay),
          matching: find.byWidgetPredicate(
            (widget) => widget is Text && widget.data == '14',
          ),
        ),
      );
      await tester.pump();
      expect(copies, ['14']);

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

  testWidgets('short Enter computes and a held Enter saves once', (
    tester,
  ) async {
    final saves = <CalculatorSnapshot>[];
    await _start(
      tester,
      saves,
      snapshot: const CalculatorSnapshot(
        settings: CalculatorSettings(saveHistoryOnLongPress: true),
      ),
    );
    await _press(tester, ['2', '+', '3']);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(kLongPressTimeout);
    expect(_display(tester).isResult, isTrue);
    expect(saves, isEmpty);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump(kLongPressTimeout - const Duration(milliseconds: 1));
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    expect(saves, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    expect(saves.single.history.single.result, '5');

    await _press(tester, ['9', '÷', '3']);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.numpadEnter);
    await tester.pump(kLongPressTimeout);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.numpadEnter);
    expect(saves.last.history.map((entry) => entry.result), ['5', '3']);

    await _press(tester, ['2']);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit9, character: '9');
    await tester.pump(kLongPressTimeout);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    expect(_display(tester).controller.text, '9');
    expect(_display(tester).isResult, isFalse);
    expect(saves, hasLength(2));
  });

  testWidgets(
    'copies history on release, recalls on a second click, and confirms deletion',
    (tester) async {
      final saves = <CalculatorSnapshot>[];
      final copies = _captureClipboard();
      const copiedEntry = HistoryEntry(
        expression: '12345678+1',
        result: '12345679',
      );
      await _start(
        tester,
        saves,
        size: const Size(316, 440),
        snapshot: const CalculatorSnapshot(
          history: [
            copiedEntry,
            HistoryEntry(expression: '2×4', result: '8'),
            HistoryEntry(expression: '3×3', result: '9'),
          ],
        ),
      );
      await _press(tester, ['1', '+']);
      final historyResult = _historyText(copiedEntry.result);
      final resultBounds = tester.getRect(historyResult);
      final click = await tester.startGesture(
        resultBounds.center,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      expect(copies, isEmpty);
      await click.up();
      await tester.pump();
      expect(copies, [copiedEntry.result]);
      expect(_display(tester).controller.text, '1+');

      final feedback = _historyText('已复制');
      expect(feedback, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(feedback).didExceedMaxLines,
        isFalse,
      );
      final feedbackBounds = tester.getRect(feedback);
      expect(feedbackBounds.left, resultBounds.left);
      expect(feedbackBounds.center.dy, closeTo(resultBounds.center.dy, 0.01));
      expect(feedbackBounds.right, lessThanOrEqualTo(resultBounds.right));
      expect(tester.getRect(historyResult), resultBounds);
      await tester.pump(const Duration(seconds: 1));
      expect(feedback, findsNothing);

      await tester.tap(_historyText('8'), kind: PointerDeviceKind.mouse);
      await tester.pump(kDoubleTapMinTime);
      expect(copies, [copiedEntry.result, '8']);
      expect(_display(tester).controller.text, '1+');
      await tester.tap(_historyText('8'), kind: PointerDeviceKind.mouse);
      await tester.pump();
      expect(copies, [copiedEntry.result, '8']);
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
      expect(saves.last.history.single, copiedEntry);

      final clearHistory = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == '清空历史记录',
      );
      await tester.tap(clearHistory);
      await tester.pumpAndSettle();
      expect(find.text('清空全部历史记录？'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(historyResult, findsOneWidget);
      expect(saves, hasLength(2));

      await tester.tap(clearHistory);
      await tester.pumpAndSettle();
      await tester.tap(find.text('清空历史记录'));
      await tester.pumpAndSettle();
      expect(_historyText('暂无记录'), findsOneWidget);
      expect(saves.last.history, isEmpty);
      expect(tester.widget<IconButton>(clearHistory).onPressed, isNull);
      expect(_display(tester).controller.text, '2×4');
      expect(_display(tester).isResult, isTrue);
    },
  );

  testWidgets('recalling from the history drawer restores keyboard input', (
    tester,
  ) async {
    final saves = <CalculatorSnapshot>[];
    await _start(
      tester,
      saves,
      size: const Size(300, 590),
      snapshot: const CalculatorSnapshot(
        history: [HistoryEntry(expression: '12+3', result: '15')],
      ),
    );
    await tester.tap(find.byTooltip('历史记录'));
    await tester.pumpAndSettle();
    await tester.tap(_historyText('15'));
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(_historyText('15'));
    await tester.pumpAndSettle();

    expect(_display(tester).isResult, isTrue);
    FocusManager.instance.rootScope.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.equal, character: '+');
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1, character: '1');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(saves.single.history.last.expression, '15+1');
    expect(_display(tester).result, '16');
  });

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
    await tester.scrollUntilVisible(find.text('Show history'), 80);
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
    await tester.scrollUntilVisible(find.text('显示历史记录'), 80);
    expect(find.text('显示历史记录'), findsOneWidget);
  });

  testWidgets('shows the app version in the About row', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'JotCalc',
      packageName: 'jotcalc',
      version: '2.3.4',
      buildNumber: '5',
      buildSignature: '',
    );
    await _start(tester, []);

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    final about = find.widgetWithText(ListTile, '关于');
    await tester.scrollUntilVisible(about, 80);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: about, matching: find.text('2.3.4')),
      findsOneWidget,
    );
  });

  testWidgets('follows system theme and saves an explicit theme preference', (
    tester,
  ) async {
    final saves = <CalculatorSnapshot>[];
    final platform = tester.binding.platformDispatcher;
    platform.platformBrightnessTestValue = Brightness.dark;
    addTearDown(platform.clearPlatformBrightnessTestValue);
    const navigationInset = FakeViewPadding(bottom: 24);
    tester.view.padding = navigationInset;
    tester.view.viewPadding = navigationInset;
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    await _start(
      tester,
      saves,
      snapshot: CalculatorSnapshot.fromJson({'settings': <String, dynamic>{}}),
    );

    void expectTheme(Brightness brightness) {
      expect(
        Theme.of(tester.element(find.byType(Scaffold).last)).brightness,
        brightness,
      );
      final overlay = SystemChrome.latestStyle!;
      expect(overlay.systemNavigationBarColor, Colors.transparent);
      expect(overlay.systemNavigationBarDividerColor, Colors.transparent);
      expect(overlay.systemNavigationBarContrastEnforced, isFalse);
      expect(
        overlay.systemNavigationBarIconBrightness,
        brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      );
    }

    expectTheme(Brightness.dark);
    expect(
      tester.getBottomLeft(_key('=')).dy,
      lessThanOrEqualTo(
        tester.view.physicalSize.height - navigationInset.bottom,
      ),
    );
    platform.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expectTheme(Brightness.light);

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    expect(find.text('跟随系统'), findsOneWidget);
    await tester.tap(find.text('主题'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    expectTheme(Brightness.dark);

    await tester.tap(find.text('快捷操作'));
    await tester.pumpAndSettle();
    expect(find.textContaining('长按回车或 ='), findsOneWidget);
    expect(find.textContaining('双击可载入计算区'), findsOneWidget);
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();

    final restored = CalculatorSnapshot.fromJson(
      jsonDecode(jsonEncode(saves.single.toJson())) as Map<String, dynamic>,
    );
    expect(restored.settings.themeMode, ThemeMode.dark);
    await _start(tester, saves, snapshot: restored);
    expectTheme(Brightness.dark);

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('主题'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('浅色'));
    await tester.pumpAndSettle();
    platform.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expectTheme(Brightness.light);
    expect(saves.last.settings.themeMode, ThemeMode.light);
  }, variant: const TargetPlatformVariant({TargetPlatform.android}));

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
