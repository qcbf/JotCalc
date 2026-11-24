import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;

enum AppLanguage {
  simplifiedChinese(Locale('zh', 'CN'), '简体中文'),
  english(Locale('en'), 'English');

  const AppLanguage(this.locale, this.label);

  final Locale locale;
  final String label;

  static AppLanguage fromTag(Object? tag) => values.firstWhere(
    (language) => language.locale.toLanguageTag() == tag,
    orElse: () => simplifiedChinese,
  );
}

class AppStrings {
  const AppStrings._(this._isEnglish);

  final bool _isEnglish;

  static AppStrings of(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'en'
      ? const AppStrings._(true)
      : const AppStrings._(false);

  String _translate(String chinese, String english) =>
      _isEnglish ? english : chinese;

  String get settings => _translate('设置', 'Settings');
  String get language => _translate('语言', 'Language');
  String get theme => _translate('主题', 'Theme');
  String themeModeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => _translate('跟随系统', 'Follow system'),
    ThemeMode.light => _translate('浅色', 'Light'),
    ThemeMode.dark => _translate('深色', 'Dark'),
  };

  String get persistHistory =>
      _translate('持久化历史', 'Keep history across sessions');
  String get persistHistoryDescription => _translate(
    '关闭后清除已保存的历史，本次运行仍可查看。',
    'Turning this off clears saved history. You can still use it during this session.',
  );
  String get showHistory => _translate('显示历史记录', 'Show history');
  String get saveOnLongPress => _translate(
    '仅长按 = 或回车添加到历史',
    'Save to history only when holding = or Enter',
  );
  String get shortcuts => _translate('快捷操作', 'Shortcuts');
  List<String> get shortcutInstructions => _isEnglish
      ? const [
          'Use 0–9, +, -, *, /, . and % to enter an expression.',
          'Press Enter to calculate. With hold-to-save enabled, hold Enter or = to add the result to history.',
          'Press Delete to clear the calculation or Backspace to erase at the cursor.',
          'Click or tap the current result to copy it.',
          'Tap a history entry to copy its result. Double-tap to load it into the calculator. Press and hold to delete it.',
          'Drag the handle at the top of the history pane to resize it.',
        ]
      : const [
          '用数字键和 +、-、*、/、.、% 输入算式。',
          '按回车计算。开启仅长按保存后，长按回车或 = 将结果加入历史。',
          '按 Del 清空当前计算，按 Backspace 退格。',
          '单击当前结果可复制。',
          '单击历史记录可复制结果，双击可载入计算区，长按可删除。',
          '拖动历史栏右上角可调整宽度。',
        ];
  String get about => _translate('关于', 'About');
  String get projectPage => _translate('GitHub 项目主页', 'JotCalc on GitHub');
  String get openProjectFailed =>
      _translate('无法打开 GitHub 项目页面', 'Could not open JotCalc on GitHub');

  String get history => _translate('历史记录', 'History');
  String get closeHistory => _translate('关闭历史记录', 'Close history');
  String get clearHistory => _translate('清空历史记录', 'Clear history');
  String get clearHistoryConfirmation =>
      _translate('清空全部历史记录？', 'Clear all history?');
  String get noHistory => _translate('暂无记录', 'No history yet');
  String get resizeHistory => _translate('拖动调整历史栏宽度', 'Drag to resize history');
  String historyWidth(int percent) =>
      _translate('历史栏宽度 $percent%', 'History width $percent%');
  String get deleteConfirmation =>
      _translate('删除这条历史记录？', 'Delete this history entry?');
  String get skipDeleteConfirmation =>
      _translate('本次运行不再提示', 'Don’t ask again this session');
  String get delete => _translate('删除', 'Delete');
  String get recallCalculation => _translate('载入计算区', 'Load into calculator');

  String get expression => _translate('算式', 'Expression');
  String get result => _translate('结果', 'Result');
  String get previewResult => _translate('预览结果', 'Result preview');
  String get calculationError => _translate('计算错误', 'Calculation error');
  String get incompleteExpression =>
      _translate('算式尚未输完', 'Incomplete expression');
  String get divisionByZero => _translate('不能除以零', 'Cannot divide by zero');
  String get invalidExpression => _translate('算式格式有误', 'Invalid expression');
  String get clear => _translate('清空', 'Clear');
  String get backspace => _translate('退格', 'Backspace');
  String get percent => _translate('百分号', 'Percent');
  String get equals => _translate('等于', 'Equals');
  String get holdToSave => _translate('长按添加到历史', 'Hold to add to history');
  String get copied => _translate('已复制', 'Copied');
  String get copyResult => _translate('复制结果', 'Copy result');
  String get copyFailed => _translate('无法复制结果', 'Could not copy the result');
  String get saveFailed =>
      _translate('无法保存设置或历史记录', 'Could not save settings or history');
}
