import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'app_localization.dart';
import 'calculator_page.dart';
import 'calculator_store.dart';
import 'framework_localizations.dart';

ThemeData _calculatorTheme(Brightness brightness) {
  const accent = Color(0xFF0F6E6E);
  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: brightness,
  );
  final colors = brightness == Brightness.light
      ? scheme.copyWith(
          primary: accent,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: const Color(0xFF1F2328),
          onSurfaceVariant: const Color(0xFF5B6169),
          surfaceContainerLow: const Color(0xFFF3EFE4),
          surfaceContainerHighest: const Color(0xFFF0F1F3),
          outline: const Color(0xFFB9B2A0),
          outlineVariant: const Color(0xFFC9CDD3),
          secondaryContainer: const Color(0xFFE1EEEE),
          onSecondaryContainer: const Color(0xFF0B4F4F),
          error: const Color(0xFF8F2323),
          errorContainer: const Color(0xFFF7E6E6),
          onErrorContainer: const Color(0xFF8F2323),
        )
      : scheme.copyWith(
          primary: const Color(0xFF81D4C8),
          onPrimary: const Color(0xFF103431),
          surface: const Color(0xFF15191C),
          onSurface: const Color(0xFFE9ECEE),
          onSurfaceVariant: const Color(0xFFB0B9BF),
          surfaceContainerLow: const Color(0xFF211F1C),
          surfaceContainerHighest: const Color(0xFF272E33),
          outline: const Color(0xFF786F61),
          outlineVariant: const Color(0xFF647078),
          secondaryContainer: const Color(0xFF263B3A),
          onSecondaryContainer: const Color(0xFFC1EDE6),
          errorContainer: const Color(0xFF482C2C),
          onErrorContainer: const Color(0xFFFFC2BC),
        );
  final theme = ThemeData(
    colorScheme: colors,
    scaffoldBackgroundColor: colors.surface,
    appBarTheme: AppBarTheme(backgroundColor: colors.surface),
  );
  return theme.copyWith(
    textTheme: theme.textTheme.apply(
      bodyColor: colors.onSurface,
      displayColor: colors.onSurface,
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = CalculatorStore();
  var snapshot = const CalculatorSnapshot();
  try {
    snapshot = await store.load();
  } catch (error) {
    debugPrint('Could not load JotCalc settings and history: $error');
  }
  runApp(JotCalcApp(initialSnapshot: snapshot, onSave: store.save));
}

class JotCalcApp extends StatefulWidget {
  const JotCalcApp({
    super.key,
    required this.initialSnapshot,
    required this.onSave,
  });

  final CalculatorSnapshot initialSnapshot;
  final Future<void> Function(CalculatorSnapshot) onSave;

  @override
  State<JotCalcApp> createState() => _JotCalcAppState();
}

class _JotCalcAppState extends State<JotCalcApp> {
  static final _lightTheme = _calculatorTheme(Brightness.light);
  static final _darkTheme = _calculatorTheme(Brightness.dark);

  late var _settings = widget.initialSnapshot.settings;

  void _onSettingsChanged(CalculatorSettings settings) {
    if (settings.language == _settings.language &&
        settings.themeMode == _settings.themeMode) {
      return;
    }
    setState(() => _settings = settings);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = switch (_settings.themeMode) {
      ThemeMode.system => MediaQuery.platformBrightnessOf(context),
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
    };

    return MaterialApp(
      title: 'JotCalc',
      debugShowCheckedModeBanner: false,
      locale: _settings.language.locale,
      supportedLocales: AppLanguage.values.map((language) => language.locale),
      localizationsDelegates: calculatorLocalizationsDelegates,
      theme: brightness == Brightness.dark ? _darkTheme : _lightTheme,
      builder: (context, child) {
        final colors = Theme.of(context).colorScheme;
        final overlay = colors.brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlay.copyWith(
            statusBarColor: colors.surface,
            systemNavigationBarColor: colors.surface,
          ),
          child: child!,
        );
      },
      home: CalculatorPage(
        initialSnapshot: widget.initialSnapshot,
        onSave: widget.onSave,
        onSettingsChanged: _onSettingsChanged,
      ),
    );
  }
}
