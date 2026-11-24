import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_localization.dart';
import 'programmer_calculation.dart';

enum CalculatorMode { standard, programmer }

class CalculatorSettings {
  const CalculatorSettings({
    this.mode = CalculatorMode.standard,
    this.language = AppLanguage.simplifiedChinese,
    this.themeMode = ThemeMode.system,
    this.persistHistory = true,
    this.showHistory = true,
    this.saveHistoryOnLongPress = false,
    this.portraitHistoryFraction = 0.36,
    this.landscapeHistoryFraction = 0.25,
  });

  factory CalculatorSettings.fromJson(Map<String, dynamic> json) {
    return CalculatorSettings(
      mode: CalculatorMode.values.firstWhere(
        (mode) => mode.name == json['mode'],
        orElse: () => CalculatorMode.standard,
      ),
      language: AppLanguage.fromTag(json['language']),
      themeMode: ThemeMode.values.firstWhere(
        (mode) => mode.name == json['themeMode'],
        orElse: () => ThemeMode.system,
      ),
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

  final CalculatorMode mode;
  final AppLanguage language;
  final ThemeMode themeMode;
  final bool persistHistory;
  final bool showHistory;
  final bool saveHistoryOnLongPress;
  final double portraitHistoryFraction;
  final double landscapeHistoryFraction;

  CalculatorSettings copyWith({
    CalculatorMode? mode,
    AppLanguage? language,
    ThemeMode? themeMode,
    bool? persistHistory,
    bool? showHistory,
    bool? saveHistoryOnLongPress,
    double? portraitHistoryFraction,
    double? landscapeHistoryFraction,
  }) => CalculatorSettings(
    mode: mode ?? this.mode,
    language: language ?? this.language,
    themeMode: themeMode ?? this.themeMode,
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
    'mode': mode.name,
    'language': language.locale.toLanguageTag(),
    'themeMode': themeMode.name,
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
  const HistoryEntry({
    required this.expression,
    required this.result,
    this.programmerFormat,
  });

  final String expression;
  final String result;
  final ProgrammerFormat? programmerFormat;

  Map<String, Object> toJson() => {
    'expression': expression,
    'result': result,
    if (programmerFormat case final format?)
      'programmer': {
        'radix': format.radix.name,
        'wordSize': format.wordSize.name,
      },
  };
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
          ProgrammerFormat? programmerFormat;
          if (item case {
            'programmer': {
              'radix': final String radixName,
              'wordSize': final String wordSizeName,
            },
          }) {
            final radix = ProgrammerRadix.values
                .where((radix) => radix.name == radixName)
                .firstOrNull;
            final wordSize = ProgrammerWordSize.values
                .where((size) => size.name == wordSizeName)
                .firstOrNull;
            if (radix == null || wordSize == null) continue;
            programmerFormat = (radix: radix, wordSize: wordSize);
          } else if (item case {'programmer': _}) {
            continue;
          }
          entries.add(
            HistoryEntry(
              expression: expression,
              result: result,
              programmerFormat: programmerFormat,
            ),
          );
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
  CalculatorStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _key = 'jotcalc.state';

  final SharedPreferencesAsync _preferences;
  ({CalculatorSnapshot snapshot, Completer<void> completion})? _queuedWrite;
  bool _writing = false;

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
    // Every snapshot contains the full state. Replace any pending snapshot
    // and complete its callers when the newer state reaches storage.
    final completion = _queuedWrite?.completion ?? Completer<void>();
    _queuedWrite = (snapshot: snapshot, completion: completion);
    if (!_writing) {
      _writing = true;
      scheduleMicrotask(_writeQueued);
    }
    return completion.future;
  }

  Future<void> _writeQueued() async {
    while (_queuedWrite != null) {
      final write = _queuedWrite!;
      _queuedWrite = null;
      try {
        await _preferences.setString(_key, jsonEncode(write.snapshot));
        write.completion.complete();
      } catch (error, stack) {
        write.completion.completeError(error, stack);
      }
    }
    _writing = false;
  }
}
