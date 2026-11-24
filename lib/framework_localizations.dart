import 'package:cupertino_ui/cupertino_ui.dart'
    show
        CupertinoLocalizationEn,
        CupertinoLocalizationZh,
        CupertinoLocalizations;
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter_localizations/flutter_localizations.dart'
    show WidgetsLocalizationEn, WidgetsLocalizationZh;
import 'package:intl/date_symbol_data_custom.dart';
import 'package:intl/date_symbols.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'app_localization.dart';

// Reference the generated bundles directly so release builds can discard the
// other framework translations and their date locale data.
const calculatorLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  _CalculatorLocalizationsDelegate<MaterialLocalizations>(_material),
  _CalculatorLocalizationsDelegate<CupertinoLocalizations>(_cupertino),
  _CalculatorLocalizationsDelegate<WidgetsLocalizations>(_widgets),
];

class _CalculatorLocalizationsDelegate<T> extends LocalizationsDelegate<T> {
  const _CalculatorLocalizationsDelegate(this._load);

  final T Function(Locale) _load;

  @override
  bool isSupported(Locale locale) =>
      AppLanguage.values.any((language) => language.locale == locale);

  @override
  Future<T> load(Locale locale) => SynchronousFuture(_load(locale));

  @override
  bool shouldReload(_CalculatorLocalizationsDelegate<T> old) => false;
}

MaterialLocalizations _material(Locale locale) {
  final dates = _dateLocale(locale);
  final numbers = locale.toString();
  final create = locale.languageCode == 'zh'
      ? MaterialLocalizationZh.new
      : MaterialLocalizationEn.new;
  return create(
    fullYearFormat: DateFormat.y(dates),
    compactDateFormat: DateFormat.yMd(dates),
    shortDateFormat: DateFormat.yMMMd(dates),
    mediumDateFormat: DateFormat.MMMEd(dates),
    longDateFormat: DateFormat.yMMMMEEEEd(dates),
    yearMonthFormat: DateFormat.yMMMM(dates),
    shortMonthDayFormat: DateFormat.MMMd(dates),
    decimalFormat: NumberFormat.decimalPattern(numbers),
    twoDigitZeroPaddedFormat: NumberFormat('00', numbers),
  );
}

CupertinoLocalizations _cupertino(Locale locale) {
  final dates = _dateLocale(locale);
  final create = locale.languageCode == 'zh'
      ? CupertinoLocalizationZh.new
      : CupertinoLocalizationEn.new;
  return create(
    fullYearFormat: DateFormat.y(dates),
    dayFormat: DateFormat.d(dates),
    weekdayFormat: DateFormat.E(dates),
    mediumDateFormat: DateFormat.MMMEd(dates),
    singleDigitHourFormat: DateFormat('HH', dates),
    singleDigitMinuteFormat: DateFormat.m(dates),
    doubleDigitMinuteFormat: DateFormat('mm', dates),
    singleDigitSecondFormat: DateFormat.s(dates),
    decimalFormat: NumberFormat.decimalPattern(locale.toString()),
  );
}

WidgetsLocalizations _widgets(Locale locale) => locale.languageCode == 'zh'
    ? const WidgetsLocalizationZh()
    : const WidgetsLocalizationEn();

String _dateLocale(Locale locale) {
  return locale.languageCode == 'zh' ? _chineseDateLocale : 'en_US';
}

final _chineseDateLocale = _initializeChineseDates();

String _initializeChineseDates() {
  // Register English before replacing intl's built-in fallback table.
  initializeDateFormattingCustom(
    locale: 'en_US',
    symbols: en_USSymbols,
    patterns: en_USPatterns,
  );
  // zh symbols and date patterns from Flutter's generated CLDR date data.
  const eras = ['公元前', '公元'];
  final monthNumbers = List.generate(12, (index) => '${index + 1}');
  const months = [
    '一月',
    '二月',
    '三月',
    '四月',
    '五月',
    '六月',
    '七月',
    '八月',
    '九月',
    '十月',
    '十一月',
    '十二月',
  ];
  final shortMonths = [for (final month in monthNumbers) '$month月'];
  const days = ['日', '一', '二', '三', '四', '五', '六'];
  final weekdays = [for (final day in days) '星期$day'];
  final shortWeekdays = [for (final day in days) '周$day'];
  initializeDateFormattingCustom(
    locale: 'zh',
    symbols: DateSymbols(
      NAME: 'zh',
      ERAS: eras,
      ERANAMES: eras,
      NARROWMONTHS: monthNumbers,
      STANDALONENARROWMONTHS: monthNumbers,
      MONTHS: months,
      STANDALONEMONTHS: months,
      SHORTMONTHS: shortMonths,
      STANDALONESHORTMONTHS: shortMonths,
      WEEKDAYS: weekdays,
      STANDALONEWEEKDAYS: weekdays,
      SHORTWEEKDAYS: shortWeekdays,
      STANDALONESHORTWEEKDAYS: shortWeekdays,
      NARROWWEEKDAYS: days,
      STANDALONENARROWWEEKDAYS: days,
      SHORTQUARTERS: const ['1季度', '2季度', '3季度', '4季度'],
      QUARTERS: const ['第一季度', '第二季度', '第三季度', '第四季度'],
      AMPMS: const ['上午', '下午'],
      DATEFORMATS: const ['y年M月d日EEEE', 'y年M月d日', 'y年M月d日', 'y/M/d'],
      TIMEFORMATS: const ['zzzz HH:mm:ss', 'z HH:mm:ss', 'HH:mm:ss', 'HH:mm'],
      DATETIMEFORMATS: const ['{1} {0}', '{1} {0}', '{1} {0}', '{1} {0}'],
      FIRSTDAYOFWEEK: 0,
      WEEKENDRANGE: const [5, 6],
      FIRSTWEEKCUTOFFDAY: 6,
    ),
    patterns: const {
      'd': 'd日',
      'E': 'ccc',
      'MMMEd': 'M月d日EEE',
      'MMMd': 'M月d日',
      'm': 'm',
      's': 's',
      'y': 'y年',
      'yMd': 'y/M/d',
      'yMMMd': 'y年M月d日',
      'yMMMM': 'y年M月',
      'yMMMMEEEEd': 'y年M月d日EEEE',
    },
  );
  return 'zh';
}
