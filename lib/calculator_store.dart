import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_localization.dart';

class CalculatorSettings {
  const CalculatorSettings({
    this.language = AppLanguage.simplifiedChinese,
    this.persistHistory = true,
    this.showHistory = true,
    this.saveHistoryOnLongPress = false,
    this.portraitHistoryFraction = 0.36,
    this.landscapeHistoryFraction = 0.25,
  });

  factory CalculatorSettings.fromJson(Map<String, dynamic> json) {
    return CalculatorSettings(
      language: AppLanguage.fromTag(json['language']),
      persistHistory: json['persistHistory'] != false,
      showHistory: json['showHistory'] != false,
      saveHistoryOnLongPress: json['saveHistoryOnLongPress'] == true,
      portraitHistoryFraction: _readFraction(
        json['portraitHistoryFraction'],
        0.36,
      ),
      landscapeHistoryFraction: _readFraction(
        json['landscapeHistoryFraction'],
        0.25,
      ),
    );
  }

  final AppLanguage language;
  final bool persistHistory;
  final bool showHistory;
  final bool saveHistoryOnLongPress;
  final double portraitHistoryFraction;
  final double landscapeHistoryFraction;

  CalculatorSettings copyWith({
    AppLanguage? language,
    bool? persistHistory,
    bool? showHistory,
    bool? saveHistoryOnLongPress,
    double? portraitHistoryFraction,
    double? landscapeHistoryFraction,
  }) => CalculatorSettings(
    language: language ?? this.language,
    persistHistory: persistHistory ?? this.persistHistory,
    showHistory: showHistory ?? this.showHistory,
    saveHistoryOnLongPress:
        saveHistoryOnLongPress ?? this.saveHistoryOnLongPress,
    portraitHistoryFraction:
        portraitHistoryFraction ?? this.portraitHistoryFraction,
    landscapeHistoryFraction:
        landscapeHistoryFraction ?? this.landscapeHistoryFraction,
  );

  Map<String, Object> toJson() => {
    'language': language.locale.toLanguageTag(),
    'persistHistory': persistHistory,
    'showHistory': showHistory,
    'saveHistoryOnLongPress': saveHistoryOnLongPress,
    'portraitHistoryFraction': portraitHistoryFraction,
    'landscapeHistoryFraction': landscapeHistoryFraction,
  };

  static double _readFraction(Object? value, double fallback) {
    if (value is num && value.isFinite && value >= 0 && value <= 1) {
      return value.toDouble();
    }
    return fallback;
  }
}

class HistoryEntry {
  const HistoryEntry({required this.expression, required this.result});

  final String expression;
  final String result;

  Map<String, String> toJson() => {'expression': expression, 'result': result};
}

class CalculatorSnapshot {
  const CalculatorSnapshot({
    this.settings = const CalculatorSettings(),
    this.history = const [],
  });

  factory CalculatorSnapshot.fromJson(Map<String, dynamic> json) {
    final savedSettings = json['settings'];
    final settings = savedSettings is Map<String, dynamic>
        ? CalculatorSettings.fromJson(savedSettings)
        : const CalculatorSettings();
    final entries = <HistoryEntry>[];
    final savedHistory = json['history'];
    if (settings.persistHistory && savedHistory is List) {
      for (final item in savedHistory) {
        if (item case {
          'expression': final String expression,
          'result': final String result,
        }) {
          entries.add(HistoryEntry(expression: expression, result: result));
        }
      }
    }
    return CalculatorSnapshot(settings: settings, history: entries);
  }

  final CalculatorSettings settings;
  final List<HistoryEntry> history;

  Map<String, Object> toJson() => {
    'settings': settings.toJson(),
    if (settings.persistHistory)
      'history': history.map((entry) => entry.toJson()).toList(),
  };
}

class CalculatorStore {
  static const _key = 'jotcalc.state';

  final _preferences = SharedPreferencesAsync();
  Future<void> _pendingWrite = Future<void>.value();

  Future<CalculatorSnapshot> load() async {
    final raw = await _preferences.getString(_key);
    if (raw != null) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return CalculatorSnapshot.fromJson(decoded);
      }
    }
    return const CalculatorSnapshot();
  }

  Future<void> save(CalculatorSnapshot snapshot) {
    final data = jsonEncode(snapshot.toJson());
    final write = _pendingWrite.then((_) => _preferences.setString(_key, data));
    _pendingWrite = write.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return write;
  }
}
