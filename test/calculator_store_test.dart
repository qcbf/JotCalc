import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jotcalc/calculator_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('stores the newest queued snapshot after the active write', () async {
    final preferences = _Preferences();
    final store = CalculatorStore(preferences: preferences);

    final first = store.save(_snapshot('1'));
    await preferences.started.future;
    final second = store.save(_snapshot('2'));
    final third = store.save(_snapshot('3'));

    expect(preferences.writes, 1);
    preferences.finishFirstWrite.complete();
    await Future.wait([first, second, third]);

    expect(preferences.writes, 2);
    expect((await store.load()).history.single.result, '3');
  });

  test('writes the queued state after a storage failure', () async {
    final preferences = _Preferences();
    final store = CalculatorStore(preferences: preferences);

    final first = expectLater(store.save(_snapshot('1')), throwsStateError);
    await preferences.started.future;
    final second = store.save(_snapshot('2'));
    preferences.finishFirstWrite.completeError(StateError('Write failed'));

    await first;
    await second;
    expect((await store.load()).history.single.result, '2');
  });
}

CalculatorSnapshot _snapshot(String result) => CalculatorSnapshot(
  history: [HistoryEntry(expression: result, result: result)],
);

class _Preferences implements SharedPreferencesAsync {
  final started = Completer<void>();
  final finishFirstWrite = Completer<void>();
  final _attemptedWrites = <String>[];
  final _completedWrites = <String>[];

  int get writes => _attemptedWrites.length;

  @override
  Future<String?> getString(String key) async => _completedWrites.lastOrNull;

  @override
  Future<void> setString(String key, String value) async {
    _attemptedWrites.add(value);
    if (writes == 1) {
      started.complete();
      await finishFirstWrite.future;
    }
    _completedWrites.add(value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
