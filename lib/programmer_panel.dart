import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'app_localization.dart';
import 'calculator_widgets.dart';
import 'programmer_calculation.dart';
import 'programmer_input.dart';

class ProgrammerPanel extends StatelessWidget {
  const ProgrammerPanel({
    super.key,
    required this.input,
    required this.onEquals,
    required this.onCopy,
    this.onHoldEquals,
    this.copiedValue,
    this.leadingActions = const [],
  });

  final ProgrammerInput input;
  final VoidCallback onEquals;
  final VoidCallback? onHoldEquals;
  final ValueChanged<String> onCopy;
  final String? copiedValue;
  final List<Widget> leadingActions;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: input,
    builder: (context, _) => LayoutBuilder(
      builder: (context, bounds) {
        final strings = AppStrings.of(context);
        final wide = bounds.maxWidth >= 540;
        final compact = bounds.maxHeight < 480;
        final gap = compact ? 4.0 : 8.0;
        final toolbarHeight = compact ? 40.0 : 44.0;
        final radixHeight = compact ? 32.0 : 36.0;
        final displayAndKeypadHeight =
            bounds.maxHeight - toolbarHeight - radixHeight - 2 * gap;
        final displayHeight = math.max(
          compact ? 68.0 : (wide ? 120.0 : 100.0),
          displayAndKeypadHeight - 400,
        );
        final keypadHeight = math.max(
          6 * (compact ? 27.0 : 36.0) + 5 * gap,
          displayAndKeypadHeight - displayHeight,
        );
        final result = input.result;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: gap,
          children: [
            SizedBox(
              height: toolbarHeight,
              child: _ProgrammerToolbar(
                input: input,
                leadingActions: leadingActions,
                showTitle: leadingActions.isEmpty || bounds.maxWidth >= 345,
                showViewLabels: wide,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: gap,
                  children: [
                    SizedBox(
                      height: displayHeight + radixHeight,
                      child: CalculationDisplay(
                        controller: input.editor,
                        focusNode: input.focusNode,
                        onEdit: input.edit,
                        inputFormatter: ProgrammerInput.formatter,
                        isResult: input.confirmed,
                        largeFontSize: compact ? 28 : 38,
                        smallFontSize: compact ? 13 : 16,
                        result: result,
                        error: input.error == null
                            ? null
                            : strings.calculationIssueLabel(input.error!),
                        onCopy: result == null ? null : () => onCopy(result),
                        copied: result != null && result == copiedValue,
                        footer: SizedBox(
                          height: radixHeight,
                          child: _RadixSelector(input: input),
                        ),
                      ),
                    ),
                    if (input.showBits)
                      _BitPanel(input: input)
                    else
                      SizedBox(
                        height: keypadHeight,
                        child: _ProgrammerKeypad(
                          input: input,
                          gap: gap,
                          onEquals: onEquals,
                          onHoldEquals: onHoldEquals,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _ProgrammerToolbar extends StatelessWidget {
  const _ProgrammerToolbar({
    required this.input,
    required this.leadingActions,
    required this.showTitle,
    required this.showViewLabels,
  });

  final ProgrammerInput input;
  final List<Widget> leadingActions;
  final bool showTitle;
  final bool showViewLabels;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final wordSize = input.format.wordSize;
    return Row(
      children: [
        ...leadingActions,
        Expanded(
          child: showTitle
              ? Text(
                  strings.programmerMode,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : const SizedBox.shrink(),
        ),
        PopupMenuButton<ProgrammerWordSize>(
          tooltip: strings.wordSize,
          initialValue: wordSize,
          onSelected: input.selectWordSize,
          position: PopupMenuPosition.under,
          itemBuilder: (context) => [
            for (final size in ProgrammerWordSize.values)
              PopupMenuItem(
                value: size,
                child: Row(
                  spacing: 14,
                  children: [
                    Expanded(child: Text(size.label)),
                    Text(
                      strings.wordSizeBits(size.bits),
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
          ],
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 3,
                children: [
                  Text(wordSize.label, style: theme.textTheme.labelMedium),
                  const Icon(Icons.expand_more_rounded, size: 16),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _viewButton(
                  context,
                  strings.programmerKeypad,
                  Icons.dialpad_rounded,
                  false,
                ),
                _viewButton(
                  context,
                  strings.bitPanel,
                  Icons.grid_on_rounded,
                  true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _viewButton(
    BuildContext context,
    String label,
    IconData icon,
    bool showBits,
  ) {
    final colors = Theme.of(context).colorScheme;
    final selected = showBits == input.showBits;
    void select() => input.setShowBits(showBits);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
    );
    final background = selected ? colors.secondaryContainer : null;
    final foreground = selected
        ? colors.onSecondaryContainer
        : colors.onSurfaceVariant;
    return showViewLabels
        ? Semantics(
            selected: selected,
            child: TextButton.icon(
              onPressed: select,
              icon: Icon(icon, size: 18),
              label: Text(label),
              style: TextButton.styleFrom(
                backgroundColor: background,
                foregroundColor: foreground,
                shape: shape,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          )
        : IconButton(
            tooltip: label,
            onPressed: select,
            isSelected: selected,
            style: IconButton.styleFrom(
              backgroundColor: background,
              foregroundColor: foreground,
              shape: shape,
              minimumSize: const Size.square(32),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: Icon(icon, size: 19),
          );
  }
}

class _RadixSelector extends StatelessWidget {
  const _RadixSelector({required this.input});

  final ProgrammerInput input;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: AppStrings.of(context).numberBase,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(height: 1, thickness: 1, color: colors.outlineVariant),
          Expanded(
            child: Material(
              color: Color.alphaBlend(
                colors.surfaceContainerHighest.withValues(alpha: 0.45),
                colors.surface,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final radix in ProgrammerRadix.values)
                    Expanded(child: _button(context, radix)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _button(BuildContext context, ProgrammerRadix radix) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selected = radix == input.format.radix;
    void select() => input.selectRadix(radix);

    return Semantics(
      label: radix.label,
      button: true,
      selected: selected,
      onTap: select,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('programmer-radix-${radix.name}'),
        onTap: select,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    radix.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: selected
                          ? colors.primary
                          : colors.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w700 : null,
                    ),
                  ),
                ),
              ),
            ),
            if (selected)
              Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: 24,
                  height: 3,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProgrammerKeypad extends StatelessWidget {
  const _ProgrammerKeypad({
    required this.input,
    required this.gap,
    required this.onEquals,
    required this.onHoldEquals,
  });

  static const _rows = [
    ['A', 'B', 'C', 'D', 'E', 'F'],
    ['AND', 'OR', 'XOR', 'NOT', '<<', '>>'],
    ['7', '8', '9', '(', 'AC', '⌫'],
    ['4', '5', '6', ')', '×', '÷'],
    ['1', '2', '3', 'MOD', '−', '+'],
    ['±', '0', '00', '>>>', '='],
  ];

  final ProgrammerInput input;
  final double gap;
  final VoidCallback onEquals;
  final VoidCallback? onHoldEquals;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Column(
      spacing: gap,
      children: [
        for (final row in _rows)
          Expanded(
            child: Row(
              spacing: gap,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final symbol in row)
                  Expanded(
                    flex: symbol == '=' ? 2 : 1,
                    child: _button(symbol, strings),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _button(String symbol, AppStrings strings) {
    const digit = CalculatorKeyRole.digit;
    const op = CalculatorKeyRole.operator;
    const edit = CalculatorKeyRole.edit;
    final (command, role, label) = switch (symbol) {
      'AND' => ('&', op, strings.bitwiseAnd),
      'OR' => ('|', op, strings.bitwiseOr),
      'XOR' => ('^', op, strings.bitwiseXor),
      'NOT' => ('~', op, strings.bitwiseNot),
      'MOD' => ('%', op, strings.remainder),
      '<<' => (symbol, op, strings.shiftLeft),
      '>>' => (symbol, op, strings.shiftRight),
      '>>>' => (symbol, op, strings.logicalShiftRight),
      '±' => ('−', op, strings.changeSign),
      'AC' => (symbol, edit, strings.clear),
      '⌫' => (symbol, edit, strings.backspace),
      '=' => (symbol, CalculatorKeyRole.equals, strings.equals),
      '(' || ')' || '×' || '÷' || '−' || '+' => (symbol, op, symbol),
      _ => (symbol, digit, symbol),
    };
    final action = switch (symbol) {
      '=' => onEquals,
      'NOT' || '±' => () => input.applyUnary(command),
      _ => input.canPress(command) ? () => input.press(command) : null,
    };
    final button = CalculatorKeyButton(
      key: ValueKey('programmer-key-$symbol'),
      symbol: symbol,
      onTap: action,
      onLongPress: symbol == '=' ? onHoldEquals : null,
      role: role,
      semanticLabel: label,
    );
    return label == symbol || symbol == '='
        ? button
        : Tooltip(message: label, excludeFromSemantics: true, child: button);
  }
}

class _BitPanel extends StatelessWidget {
  const _BitPanel({required this.input});

  static const _rowHeight = 28.0;
  final ProgrammerInput input;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final colors = Theme.of(context).colorScheme;
      final strings = AppStrings.of(context);
      final bits = input.format.wordSize.bits;
      final value = input.value?.toUnsigned(bits);
      final groupsPerRow = math.min(bits ~/ 4, bounds.maxWidth >= 368 ? 4 : 2);
      final bitsPerRow = groupsPerRow * 4;
      final rule = BorderSide(
        color: Color.alphaBlend(
          colors.outlineVariant.withValues(alpha: 0.55),
          colors.surface,
        ),
      );

      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 176.0 * groupsPerRow),
          child: Material(
            color: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colors.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: Table(
              border: TableBorder(horizontalInside: rule),
              columnWidths: {
                for (var group = 0; group < groupsPerRow; group++)
                  group * 5 + 4: const FixedColumnWidth(23),
              },
              children: [
                for (
                  var rowHigh = bits - 1;
                  rowHigh >= 0;
                  rowHigh -= bitsPerRow
                )
                  TableRow(
                    children: [
                      for (
                        var high = rowHigh;
                        high > rowHigh - bitsPerRow;
                        high -= 4
                      ) ...[
                        for (var bit = high; bit > high - 4; bit--)
                          _bit(colors, strings, bit, value),
                        _index(colors, rule, high - 3),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _index(ColorScheme colors, BorderSide rule, int index) {
    return ExcludeSemantics(
      child: Container(
        height: _rowHeight,
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            colors.surfaceContainerHighest.withValues(alpha: 0.65),
            colors.surface,
          ),
          border: Border(left: rule, right: rule),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$index',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bit(ColorScheme colors, AppStrings strings, int bit, BigInt? value) {
    final set = value != null && (value & (BigInt.one << bit)) != BigInt.zero;
    final bitLabel = strings.bitPosition(bit);
    final digit = value == null ? '–' : (set ? '1' : '0');
    final onTap = value == null ? null : () => input.toggleBit(bit);
    return Semantics(
      label: bitLabel,
      value: digit,
      toggled: set,
      enabled: onTap != null,
      onTap: onTap,
      excludeSemantics: true,
      child: Tooltip(
        message: bitLabel,
        excludeFromSemantics: true,
        child: SizedBox(
          height: _rowHeight,
          child: InkWell(
            key: ValueKey('programmer-bit-$bit'),
            onTap: onTap,
            hoverColor: colors.primary.withValues(alpha: 0.08),
            child: Center(
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: set
                    ? BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(5),
                      )
                    : null,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    digit,
                    style: TextStyle(
                      color: set ? colors.onPrimary : colors.onSurface,
                      fontSize: 14,
                      fontWeight: set ? FontWeight.w700 : FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
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
