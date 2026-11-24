import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'app_localization.dart';
import 'calculation.dart';
import 'calculator_store.dart';

const _tabularFigures = [FontFeature.tabularFigures()];

class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: AppStrings.of(context).settings,
    onPressed: onPressed,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
    padding: EdgeInsets.zero,
    icon: const Icon(Icons.more_horiz),
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
    final colors = Theme.of(context).colorScheme;
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
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                Icons.drag_indicator_rounded,
                color: colors.onSurfaceVariant,
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
    required this.onCopy,
    required this.onRecall,
    required this.onDelete,
    this.copiedEntry,
    this.showDivider = false,
  });

  final Widget header;
  final List<HistoryEntry> entries;
  final ScrollController controller;
  final ValueChanged<HistoryEntry> onCopy;
  final ValueChanged<HistoryEntry> onRecall;
  final ValueChanged<HistoryEntry> onDelete;
  final HistoryEntry? copiedEntry;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
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
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
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
                            copied: entry == copiedEntry,
                            onCopy: () => onCopy(entry),
                            onRecall: () => onRecall(entry),
                            onDelete: () => onDelete(entry),
                          );
                        },
                      ),
              ),
            ],
          ),
          if (showDivider)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              width: 1,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _PaperRule(Axis.vertical, colors.outline),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatefulWidget {
  const _HistoryRow({
    super.key,
    required this.entry,
    required this.copied,
    required this.onCopy,
    required this.onRecall,
    required this.onDelete,
  });

  final HistoryEntry entry;
  final bool copied;
  final VoidCallback onCopy;
  final VoidCallback onRecall;
  final VoidCallback onDelete;

  @override
  State<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_HistoryRow> {
  Timer? _doubleTapTimer;

  void _handleTap() {
    final doubleTapTimer = _doubleTapTimer;
    if (doubleTapTimer != null) {
      doubleTapTimer.cancel();
      _doubleTapTimer = null;
      widget.onRecall();
      return;
    }

    // Flutter Web can deliver a double-click as two separate semantic taps.
    _doubleTapTimer = Timer(kDoubleTapTimeout, () => _doubleTapTimer = null);
    widget.onCopy();
  }

  @override
  void dispose() {
    _doubleTapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colors = Theme.of(context).colorScheme;
    final entry = widget.entry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 1,
          child: CustomPaint(
            painter: _PaperRule(
              Axis.horizontal,
              colors.outline.withValues(alpha: 0.6),
            ),
          ),
        ),
        Semantics(
          onTapHint: strings.copyResult,
          onLongPressHint: strings.delete,
          customSemanticsActions: {
            CustomSemanticsAction(label: strings.recallCalculation):
                widget.onRecall,
          },
          child: InkWell(
            onTap: _handleTap,
            onLongPress: widget.onDelete,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (entry.programmerFormat case final format?)
                    Text(
                      '${format.radix.label} · ${format.wordSize.label}',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  Text(
                    entry.expression,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 11,
                      fontFeatures: _tabularFigures,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Stack(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          entry.result,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFeatures: _tabularFigures,
                          ),
                        ),
                      ),
                      if (widget.copied)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Flexible(
                                  child: ColoredBox(
                                    color: colors.surfaceContainerLow,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Semantics(
                                        liveRegion: true,
                                        child: Text(
                                          strings.copied,
                                          style: TextStyle(
                                            color: colors.primary,
                                            fontSize: 11,
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
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PaperRule extends CustomPainter {
  const _PaperRule(this.axis, this.color);

  final Axis axis;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final vertical = axis == Axis.vertical;
    final length = vertical ? size.height : size.width;
    final mark = vertical ? 4.0 : 1.25;
    final paint = Paint()
      ..color = color
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
      oldDelegate.axis != axis || oldDelegate.color != color;
}

class _ExpressionScrollBehavior extends MaterialScrollBehavior {
  const _ExpressionScrollBehavior();

  // Include the desktop scrollbar's track margins in the gutter.
  static const gutterWidth = 12.0;

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => super.buildScrollbar(
    context,
    Padding(
      padding: const EdgeInsets.only(right: gutterWidth),
      child: child,
    ),
    details,
  );
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
    this.allowAdvancedInput = false,
    this.inputFormatter,
    this.result,
    this.error,
    this.onCopy,
    this.copied = false,
    this.footer,
  });

  static final _expressionFormatter = _formatter(RegExp(r'^[0-9.+−×÷% ]*$'));
  static final _advancedExpressionFormatter = _formatter(
    RegExp(r'^[0-9A-Za-z.+−×÷%(),&|^~<> ]*$'),
  );

  static TextInputFormatter _formatter(RegExp allowedCharacters) =>
      TextInputFormatter.withFunction((previous, next) {
        final text = normalizeExpression(next.text);
        return allowedCharacters.hasMatch(text)
            ? next.copyWith(text: text)
            : previous;
      });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onEdit;
  final bool isResult;
  final bool allowAdvancedInput;
  final double largeFontSize;
  final double smallFontSize;
  final TextInputFormatter? inputFormatter;
  final String? result;
  final String? error;
  final VoidCallback? onCopy;
  final bool copied;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colors = Theme.of(context).colorScheme;
    final expressionStyle = TextStyle(
      color: isResult ? colors.onSurfaceVariant : colors.onSurface,
      fontSize: isResult ? smallFontSize : largeFontSize,
      fontWeight: isResult ? FontWeight.w400 : FontWeight.w600,
      fontFeatures: _tabularFigures,
      letterSpacing: 0.45,
      height: 1.12,
    );
    final caption = error ?? result;
    final copy = error == null ? onCopy : null;
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(8, 5, 2, 5),
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.bottomRight,
                child: Semantics(
                  label: strings.expression,
                  child: ScrollConfiguration(
                    behavior: const _ExpressionScrollBehavior(),
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onTap: onEdit,
                      showCursor: !isResult,
                      keyboardType: TextInputType.none,
                      inputFormatters: [
                        inputFormatter ??
                            (allowAdvancedInput
                                ? _advancedExpressionFormatter
                                : _expressionFormatter),
                      ],
                      autocorrect: false,
                      enableSuggestions: false,
                      maxLines: null,
                      textAlign: TextAlign.right,
                      scrollPadding: EdgeInsets.zero,
                      cursorColor: colors.primary,
                      style: expressionStyle,
                      decoration: InputDecoration.collapsed(
                        hintText: '0',
                        hintStyle: expressionStyle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (caption != null)
              Padding(
                padding: const EdgeInsets.only(
                  top: 2,
                  right: _ExpressionScrollBehavior.gutterWidth,
                ),
                child: Semantics(
                  label: error == null
                      ? (isResult ? strings.result : strings.previewResult)
                      : strings.calculationError,
                  liveRegion: isResult || error != null,
                  button: copy != null,
                  onTapHint: copy == null ? null : strings.copyResult,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: copy,
                    child: MouseRegion(
                      cursor: copy == null
                          ? MouseCursor.defer
                          : SystemMouseCursors.click,
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
                                      ? colors.error
                                      : (isResult
                                            ? colors.onSurface
                                            : colors.onSurfaceVariant),
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
              ),
          ],
        ),
      ),
    );
    final borderRadius = BorderRadius.circular(12);
    final display = DecoratedBox(
      position: footer == null
          ? DecorationPosition.background
          : DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(
          color: error == null ? colors.outlineVariant : colors.error,
        ),
        borderRadius: borderRadius,
      ),
      child: footer == null
          ? body
          : ClipRRect(
              borderRadius: borderRadius,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: body),
                  footer!,
                ],
              ),
            ),
    );
    if (!copied) return display;
    return Stack(
      fit: StackFit.expand,
      children: [
        display,
        Positioned(
          top: 5,
          left: 8,
          child: IgnorePointer(
            child: Semantics(
              liveRegion: true,
              child: Text(
                strings.copied,
                style: TextStyle(color: colors.primary, fontSize: 12),
              ),
            ),
          ),
        ),
      ],
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
                  child: CalculatorKeyButton(
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

enum CalculatorKeyRole { digit, operator, edit, equals }

class CalculatorKeyButton extends StatelessWidget {
  const CalculatorKeyButton({
    super.key,
    required this.symbol,
    required this.onTap,
    this.onLongPress,
    this.role,
    this.semanticLabel,
  });

  final String symbol;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final CalculatorKeyRole? role;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colors = Theme.of(context).colorScheme;
    final kind =
        role ??
        switch (symbol) {
          'C' || '⌫' => CalculatorKeyRole.edit,
          '%' || '÷' || '×' || '−' || '+' => CalculatorKeyRole.operator,
          '=' => CalculatorKeyRole.equals,
          _ => CalculatorKeyRole.digit,
        };
    final (background, foreground) = switch (kind) {
      CalculatorKeyRole.edit => (
        colors.errorContainer,
        colors.onErrorContainer,
      ),
      CalculatorKeyRole.operator => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
      CalculatorKeyRole.equals => (colors.primary, colors.onPrimary),
      CalculatorKeyRole.digit => (
        colors.surfaceContainerHighest,
        colors.onSurface,
      ),
    };
    final label =
        semanticLabel ??
        switch (symbol) {
          'C' when kind == CalculatorKeyRole.edit => strings.clear,
          '⌫' => strings.backspace,
          '%' => strings.percent,
          '=' => strings.equals,
          _ => symbol,
        };
    final enabled = onTap != null;

    return Semantics(
      label: label,
      button: true,
      enabled: enabled,
      onTap: onTap,
      onLongPress: onLongPress,
      hint: onLongPress == null ? null : strings.holdToSave,
      excludeSemantics: true,
      child: Material(
        color: enabled
            ? background
            : colors.surfaceContainerHighest.withValues(alpha: 0.70),
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
                          color: enabled
                              ? foreground
                              : foreground.withValues(alpha: 0.32),
                          fontSize: switch (symbol) {
                            'C' when kind == CalculatorKeyRole.edit => 18,
                            'AC' ||
                            'AND' ||
                            'OR' ||
                            'XOR' ||
                            'NOT' ||
                            'MOD' => 16,
                            '00' || '%' => 20,
                            '=' => 24,
                            _ => 22,
                          },
                          fontWeight:
                              kind == CalculatorKeyRole.equals ||
                                  (kind == CalculatorKeyRole.edit &&
                                      symbol != '⌫')
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
