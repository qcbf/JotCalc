import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_localization.dart';
import 'calculator_store.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.initialSettings,
    required this.onChanged,
  });

  final CalculatorSettings initialSettings;
  final ValueChanged<CalculatorSettings> onChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late var _settings = widget.initialSettings;

  void _update(CalculatorSettings settings) {
    setState(() => _settings = settings);
    widget.onChanged(settings);
  }

  Future<T?> _chooseOption<T>({
    required String title,
    required T selected,
    required List<T> choices,
    required Widget Function(T) label,
  }) {
    return showDialog<T>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(title),
        contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
        content: RadioGroup<T>(
          groupValue: selected,
          onChanged: (value) => Navigator.pop(context, value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final choice in choices)
                RadioListTile<T>(value: choice, title: label(choice)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _chooseLanguage() async {
    final language = await _chooseOption(
      title: AppStrings.of(context).language,
      selected: _settings.language,
      choices: AppLanguage.values,
      label: (choice) => Text(choice.label, locale: choice.locale),
    );
    if (!mounted || language == null || language == _settings.language) return;
    _update(_settings.copyWith(language: language));
  }

  Future<void> _chooseTheme() async {
    final strings = AppStrings.of(context);
    final mode = await _chooseOption(
      title: strings.theme,
      selected: _settings.themeMode,
      choices: ThemeMode.values,
      label: (choice) => Text(strings.themeModeLabel(choice)),
    );
    if (!mounted || mode == null || mode == _settings.themeMode) return;
    _update(_settings.copyWith(themeMode: mode));
  }

  void _showShortcuts() {
    final strings = AppStrings.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(strings.shortcuts),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            for (final instruction in strings.shortcutInstructions)
              Text(instruction),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).closeButtonLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _openAbout() async {
    try {
      final opened = await launchUrl(
        Uri.https('github.com', '/qcbf/JotCalc'),
        mode: LaunchMode.externalApplication,
      );
      if (opened) return;
    } on PlatformException catch (error) {
      debugPrint('Could not open the JotCalc project page: $error');
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.of(context).openProjectFailed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.settings)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            ListTile(
              title: Text(strings.language),
              subtitle: Text(
                _settings.language.label,
                locale: _settings.language.locale,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _chooseLanguage,
            ),
            ListTile(
              title: Text(strings.theme),
              subtitle: Text(strings.themeModeLabel(_settings.themeMode)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _chooseTheme,
            ),
            SwitchListTile(
              title: Text(strings.persistHistory),
              subtitle: Text(strings.persistHistoryDescription),
              value: _settings.persistHistory,
              onChanged: (value) =>
                  _update(_settings.copyWith(persistHistory: value)),
            ),
            SwitchListTile(
              title: Text(strings.showHistory),
              value: _settings.showHistory,
              onChanged: (value) =>
                  _update(_settings.copyWith(showHistory: value)),
            ),
            SwitchListTile(
              title: Text(strings.saveOnLongPress),
              value: _settings.saveHistoryOnLongPress,
              onChanged: (value) =>
                  _update(_settings.copyWith(saveHistoryOnLongPress: value)),
            ),
            const Divider(indent: 16, endIndent: 16),
            ListTile(
              title: Text(strings.shortcuts),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _showShortcuts,
            ),
            ListTile(
              title: Text(strings.about),
              subtitle: Text(strings.projectPage),
              trailing: const Icon(Icons.open_in_new_rounded, size: 20),
              onTap: _openAbout,
            ),
          ],
        ),
      ),
    );
  }
}
