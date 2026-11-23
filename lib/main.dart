import 'package:material_ui/material_ui.dart';

import 'app_localization.dart';
import 'calculator_page.dart';
import 'calculator_store.dart';
import 'calculator_widgets.dart';

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
  late AppLanguage _language = widget.initialSnapshot.settings.language;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: JotCalcColors.accent),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(backgroundColor: Colors.white),
    );

    return MaterialApp(
      title: 'JotCalc',
      debugShowCheckedModeBanner: false,
      locale: _language.locale,
      supportedLocales: AppLanguage.values.map((language) => language.locale),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: theme.copyWith(
        textTheme: theme.textTheme.apply(
          bodyColor: JotCalcColors.ink,
          displayColor: JotCalcColors.ink,
        ),
      ),
      home: CalculatorPage(
        initialSnapshot: widget.initialSnapshot,
        onSave: widget.onSave,
        onLanguageChanged: (language) => setState(() => _language = language),
      ),
    );
  }
}
