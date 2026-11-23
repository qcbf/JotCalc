import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'app_localization.dart';
import 'calculator_store.dart';

abstract final class JotCalcColors {
  static const paper = Color(0xFFF3EFE4);
  static const ink = Color(0xFF1F2328);
  static const muted = Color(0xFF5B6169);
  static const accent = Color(0xFF0F6E6E);
  static const outline = Color(0xFFC9CDD3);
  static const error = Color(0xFF8F2323);
}

const _tabularFigures = [FontFeature.tabularFigures()];

class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: AppStrings.of(context).settings,
    onPressed: onPressed,
    icon: const Icon(Icons.more_horiz, color: JotCalcColors.muted),
  );
}

class HistoryResizeHandle extends StatelessWidget {
  const HistoryResizeHandle({
    super.key,
    required this.fraction,
    required this.onDrag,
    required this.onDragDone,
    required this.onWiden,
    required this.onNarrow,
  });

  final double fraction;
  final ValueChanged<double> onDrag;
  final VoidCallback onDragDone;
  final VoidCallback onWiden;
  final VoidCallback onNarrow;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Semantics(
      label: strings.historyWidth((fraction * 100).round()),
      onIncrease: onWiden,
      onDecrease: onNarrow,
      child: Tooltip(
        message: strings.resizeHistory,
        excludeFromSemantics: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeLeftRight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
            onHorizontalDragEnd: (_) => onDragDone(),
            onHorizontalDragCancel: onDragDone,
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                Icons.drag_indicator_rounded,
                color: JotCalcColors.muted,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HistoryPane extends StatelessWidget {
  const HistoryPane({
    super.key,
    required this.header,
    required this.entries,
    required this.controller,
    required this.onSelect,
    required this.onDelete,
    this.showDivider = false,
  });

  final Widget header;
  final List<HistoryEntry> entries;
  final ScrollController controller;
  final ValueChanged<HistoryEntry> onSelect;
  final ValueChanged<HistoryEntry> onDelete;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: JotCalcColors.paper,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Expanded(
                child: entries.isEmpty
                    ? Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            AppStrings.of(context).noHistory,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: JotCalcColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: controller,
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[entries.length - index - 1];
                          return _HistoryRow(
                            key: ObjectKey(entry),
                            entry: entry,
                            onTap: () => onSelect(entry),
                            onLongPress: () => onDelete(entry),
                          );
                        },
                      ),
              ),
            ],
          ),
          if (showDivider)
            const Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              width: 1,
              child: IgnorePointer(
                child: CustomPaint(painter: _PaperRule(Axis.vertical)),
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onLongPress,
  });

  final HistoryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(
          height: 1,
          child: CustomPaint(painter: _PaperRule(Axis.horizontal)),
        ),
        InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  entry.expression,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  style: const TextStyle(
                    color: JotCalcColors.muted,
                    fontSize: 11,
                    fontFeatures: _tabularFigures,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.result,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFeatures: _tabularFigures,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PaperRule extends CustomPainter {
  const _PaperRule(this.axis);

  final Axis axis;

  @override
  void paint(Canvas canvas, Size size) {
    final vertical = axis == Axis.vertical;
    final length = vertical ? size.height : size.width;
    final mark = vertical ? 4.0 : 1.25;
    final paint = Paint()
      ..color = vertical ? const Color(0xFFB9B2A0) : const Color(0xFFCFC8B5)
      ..strokeWidth = 1;
    for (var start = 0.0; start < length; start += mark + 3) {
      final end = math.min(start + mark, length);
      canvas.drawLine(
        vertical ? Offset(0.5, start) : Offset(start, 0.5),
        vertical ? Offset(0.5, end) : Offset(end, 0.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PaperRule oldDelegate) =>
      oldDelegate.axis != axis;
}

class CalculationDisplay extends StatelessWidget {
  const CalculationDisplay({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onEdit,
    required this.isResult,
    required this.largeFontSize,
    required this.smallFontSize,
    this.result,
    this.error,
    this.onCopy,
  });

  static final _allowedCharacters = RegExp(r'^[0-9.+−×÷% ]*$');
  static final _expressionFormatter = TextInputFormatter.withFunction((
    previous,
    next,
  ) {
    final text = next.text
        .replaceAll('-', '−')
        .replaceAll('*', '×')
        .replaceAll('/', '÷');
    return _allowedCharacters.hasMatch(text)
        ? next.copyWith(text: text)
        : previous;
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onEdit;
  final bool isResult;
  final double largeFontSize;
  final double smallFontSize;
  final String? result;
  final String? error;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final expressionStyle = TextStyle(
      color: isResult ? JotCalcColors.muted : JotCalcColors.ink,
      fontSize: isResult ? smallFontSize : largeFontSize,
      fontWeight: isResult ? FontWeight.w400 : FontWeight.w600,
      fontFeatures: _tabularFigures,
      letterSpacing: 0.45,
      height: 1.12,
    );
    final caption = error ?? result;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: error == null ? JotCalcColors.outline : JotCalcColors.error,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Semantics(
                    label: strings.expression,
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onTap: onEdit,
                      showCursor: !isResult,
                      keyboardType: TextInputType.none,
                      inputFormatters: [_expressionFormatter],
                      autocorrect: false,
                      enableSuggestions: false,
                      maxLines: null,
                      textAlign: TextAlign.right,
                      scrollPadding: EdgeInsets.zero,
                      cursorColor: JotCalcColors.accent,
                      style: expressionStyle,
                      decoration: InputDecoration.collapsed(
                        hintText: '0',
                        hintStyle: expressionStyle,
                      ),
                    ),
                  ),
                ),
              ),
              if (caption != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Semantics(
                    label: error == null
                        ? (isResult ? strings.result : strings.previewResult)
                        : strings.calculationError,
                    liveRegion: isResult || error != null,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onLongPress: error == null ? onCopy : null,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: constraints.maxHeight * 0.64,
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            reverse: true,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                caption,
                                maxLines: 1,
                                style: TextStyle(
                                  color: error != null
                                      ? JotCalcColors.error
                                      : (isResult
                                            ? JotCalcColors.ink
                                            : JotCalcColors.muted),
                                  fontSize: isResult
                                      ? largeFontSize
                                      : smallFontSize,
                                  fontWeight: isResult
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  fontFeatures: _tabularFigures,
                                  height: 1.12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class CalculatorKeypad extends StatelessWidget {
  const CalculatorKeypad({
    super.key,
    required this.gap,
    required this.onKey,
    this.onHoldEquals,
  });

  static const _keys = [
    ['C', '⌫', '%', '÷'],
    ['7', '8', '9', '×'],
    ['4', '5', '6', '−'],
    ['1', '2', '3', '+'],
    ['00', '0', '.', '='],
  ];

  final double gap;
  final ValueChanged<String> onKey;
  final VoidCallback? onHoldEquals;

  @override
  Widget build(BuildContext context) => Column(
    spacing: gap,
    children: [
      for (final row in _keys)
        Expanded(
          child: Row(
            spacing: gap,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final symbol in row)
                Expanded(
                  child: _KeyButton(
                    key: ValueKey('key-$symbol'),
                    symbol: symbol,
                    onTap: () => onKey(symbol),
                    onLongPress: symbol == '=' ? onHoldEquals : null,
                  ),
                ),
            ],
          ),
        ),
    ],
  );
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    super.key,
    required this.symbol,
    required this.onTap,
    this.onLongPress,
  });

  final String symbol;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final (background, foreground, label) = switch (symbol) {
      'C' => (const Color(0xFFF7E6E6), JotCalcColors.error, strings.clear),
      '⌫' => (const Color(0xFFF7E6E6), JotCalcColors.error, strings.backspace),
      '%' => (
        const Color(0xFFE1EEEE),
        const Color(0xFF0B4F4F),
        strings.percent,
      ),
      '÷' ||
      '×' ||
      '−' ||
      '+' => (const Color(0xFFE1EEEE), const Color(0xFF0B4F4F), symbol),
      '=' => (JotCalcColors.accent, Colors.white, strings.equals),
      _ => (const Color(0xFFF0F1F3), JotCalcColors.ink, symbol),
    };

    return Semantics(
      label: label,
      button: true,
      onTap: onTap,
      onLongPress: onLongPress,
      hint: onLongPress == null ? null : strings.holdToSave,
      excludeSemantics: true,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: symbol == '⌫'
                    ? Icon(
                        Icons.backspace_outlined,
                        color: foreground,
                        size: 21,
                      )
                    : Text(
                        symbol,
                        style: TextStyle(
                          color: foreground,
                          fontSize: switch (symbol) {
                            'C' => 18,
                            '00' || '%' => 20,
                            '=' => 24,
                            _ => 22,
                          },
                          fontWeight: symbol == '=' || symbol == 'C'
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontFeatures: _tabularFigures,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
