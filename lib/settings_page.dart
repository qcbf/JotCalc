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

  Future<void> _chooseLanguage() async {
    final strings = AppStrings.of(context);
    final language = await showDialog<AppLanguage>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(strings.language),
        contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
        content: RadioGroup<AppLanguage>(
          groupValue: _settings.language,
          onChanged: (value) => Navigator.pop(context, value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final choice in AppLanguage.values)
                RadioListTile<AppLanguage>(
                  value: choice,
                  title: Text(choice.label, locale: choice.locale),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || language == null || language == _settings.language) return;
    _update(_settings.copyWith(language: language));
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
