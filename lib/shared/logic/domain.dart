class SeoulClock {
  static const offset = Duration(hours: 9);

  static DateTime toSeoul(DateTime instant) => instant.toUtc().add(offset);

  static DateTime seoulMidnightToUtc(int year, int month, int day) {
    return DateTime.utc(year, month, day).subtract(offset);
  }

  /// Monday 00:00 Asia/Seoul of the week that contains [instant].
  static DateTime startOfWeek(DateTime instant) {
    final seoul = toSeoul(instant);
    final day = DateTime.utc(seoul.year, seoul.month, seoul.day);
    final monday = day.subtract(Duration(days: day.weekday - 1));
    return seoulMidnightToUtc(monday.year, monday.month, monday.day);
  }

  static DateTime addWeeks(DateTime weekStartUtc, int weeks) {
    final seoul = toSeoul(weekStartUtc);
    final shifted = DateTime.utc(seoul.year, seoul.month, seoul.day)
        .add(Duration(days: 7 * weeks));
    return seoulMidnightToUtc(shifted.year, shifted.month, shifted.day);
  }

  static bool inWeek(DateTime instant, DateTime weekStartUtc) {
    final end = addWeeks(weekStartUtc, 1);
    return !instant.isBefore(weekStartUtc) && instant.isBefore(end);
  }
}

class BalancePoint {
  const BalancePoint({
    required this.id,
    required this.occurredAt,
    required this.amount,
    required this.isIncome,
  });

  final String id;
  final DateTime occurredAt;
  final int amount;
  final bool isIncome;
}

/// Income adds and expense subtracts, ordered by occurredAt then id.
Map<String, int> runningBalances(List<BalancePoint> items) {
  final sorted = [...items]..sort((a, b) {
      final byTime = a.occurredAt.compareTo(b.occurredAt);
      if (byTime != 0) {
        return byTime;
      }
      return a.id.compareTo(b.id);
    });
  final result = <String, int>{};
  var running = 0;
  for (final item in sorted) {
    running += item.isIncome ? item.amount : -item.amount;
    result[item.id] = running;
  }
  return result;
}

class WeekTotals {
  const WeekTotals({
    required this.income,
    required this.expense,
    required this.net,
  });

  final int income;
  final int expense;
  final int net;
}

WeekTotals weekTotals(Iterable<BalancePoint> weekItems) {
  var income = 0;
  var expense = 0;
  for (final item in weekItems) {
    if (item.isIncome) {
      income += item.amount;
    } else {
      expense += item.amount;
    }
  }
  return WeekTotals(income: income, expense: expense, net: income - expense);
}

bool isUnexpired(DateTime expireAt, DateTime now) => expireAt.isAfter(now);

int remainingHours(DateTime expireAt, DateTime now) {
  final hours = expireAt.difference(now).inHours;
  if (hours < 0) {
    return 0;
  }
  if (hours > 120) {
    return 120;
  }
  return hours;
}

const allowedMenus = {
  'schedule',
  'balance',
  'weather',
  'exchange',
  'news',
  'calculator',
  'general',
};

const allowedSaveModes = {'auto', 'confirm', 'none'};

class TableModel {
  const TableModel({required this.headers, required this.rows});

  final List<String> headers;
  final List<List<String>> rows;

  bool get isEmpty => headers.isEmpty || rows.isEmpty;

  Map<String, dynamic> toJson() => {'headers': headers, 'rows': rows};

  static TableModel? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final headers = _stringList(raw['headers']);
    final rowsRaw = raw['rows'];
    if (headers.isEmpty || rowsRaw is! List) {
      return null;
    }
    final rows = <List<String>>[];
    for (final row in rowsRaw) {
      if (row is List) {
        rows.add(row.map((cell) => '$cell').toList());
      }
    }
    if (rows.isEmpty) {
      return null;
    }
    return TableModel(headers: headers, rows: rows);
  }
}

class ChartModel {
  const ChartModel({
    required this.type,
    required this.labels,
    required this.values,
  });

  final String type;
  final List<String> labels;
  final List<double> values;

  bool get isEmpty => labels.isEmpty || labels.length != values.length;

  Map<String, dynamic> toJson() => {
        'hasChart': !isEmpty,
        'type': type,
        'labels': labels,
        'values': values,
      };

  static ChartModel? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final hasChart = raw['hasChart'] == true;
    if (!hasChart) {
      return null;
    }
    final type = '${raw['type'] ?? 'bar'}';
    final labels = _stringList(raw['labels']);
    final valuesRaw = raw['values'];
    if (valuesRaw is! List || labels.length != valuesRaw.length || labels.isEmpty) {
      return null;
    }
    final values = <double>[];
    for (final value in valuesRaw) {
      final number = value is num ? value.toDouble() : double.tryParse('$value');
      if (number == null) {
        return null;
      }
      values.add(number);
    }
    final safeType = switch (type) {
      'line' || 'pie' || 'bar' => type,
      _ => 'bar',
    };
    return ChartModel(type: safeType, labels: labels, values: values);
  }
}

class ScheduleDraft {
  const ScheduleDraft({
    required this.title,
    required this.startAt,
    required this.endAt,
    required this.allDay,
  });

  final String title;
  final DateTime? startAt;
  final DateTime? endAt;
  final bool allDay;

  Map<String, dynamic> toJson() => {
        'title': title,
        'startAt': startAt?.toIso8601String(),
        'endAt': endAt?.toIso8601String(),
        'allDay': allDay,
      };

  static ScheduleDraft? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final title = '${raw['title'] ?? ''}'.trim();
    if (title.isEmpty) {
      return null;
    }
    return ScheduleDraft(
      title: title,
      startAt: DateTime.tryParse('${raw['startAt'] ?? ''}'),
      endAt: DateTime.tryParse('${raw['endAt'] ?? ''}'),
      allDay: raw['allDay'] == true,
    );
  }
}

class BalanceDraft {
  const BalanceDraft({
    required this.description,
    required this.amount,
    required this.isIncome,
    required this.occurredAt,
  });

  final String description;
  final int amount;
  final bool isIncome;
  final DateTime? occurredAt;

  Map<String, dynamic> toJson() => {
        'description': description,
        'amount': amount,
        'isIncome': isIncome,
        'occurredAt': occurredAt?.toIso8601String(),
      };

  static BalanceDraft? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final description = '${raw['description'] ?? ''}'.trim();
    final amount = raw['amount'] is num
        ? (raw['amount'] as num).round()
        : int.tryParse('${raw['amount']}'.replaceAll(',', '')) ?? 0;
    if (description.isEmpty || amount <= 0) {
      return null;
    }
    return BalanceDraft(
      description: description,
      amount: amount,
      isIncome: raw['isIncome'] == true,
      occurredAt: DateTime.tryParse('${raw['occurredAt'] ?? ''}'),
    );
  }
}

class IntentPayload {
  const IntentPayload({
    required this.targetMenu,
    required this.saveMode,
    required this.summaryText,
    this.table,
    this.chart,
    this.schedule,
    this.balance,
    this.cityQuery = '',
    this.currencyCode = '',
    this.newsCountry = '',
    this.extractedSchedules = const [],
    this.extractedBalances = const [],
  });

  final String targetMenu;
  final String saveMode;
  final String summaryText;
  final TableModel? table;
  final ChartModel? chart;
  final ScheduleDraft? schedule;
  final BalanceDraft? balance;
  final String cityQuery;
  final String currencyCode;
  final String newsCountry;
  final List<ScheduleDraft> extractedSchedules;
  final List<BalanceDraft> extractedBalances;
}

List<String> _stringList(Object? raw) {
  if (raw is! List) {
    return const [];
  }
  return raw.map((item) => '$item').where((item) => item.isNotEmpty).toList();
}

List<T> _draftList<T>(Object? raw, T? Function(Object? item) parse) {
  if (raw is! List) {
    return const [];
  }
  return raw.map(parse).whereType<T>().toList();
}

/// Parses a Gemini JSON object. Unknown menus become general / none.
IntentPayload parseIntent(Object? raw) {
  if (raw is! Map) {
    throw const FormatException('intent-json');
  }
  final menuRaw = '${raw['targetMenu'] ?? 'general'}';
  final modeRaw = '${raw['saveMode'] ?? 'none'}';
  final menu = allowedMenus.contains(menuRaw) ? menuRaw : 'general';
  var mode = allowedSaveModes.contains(modeRaw) ? modeRaw : 'none';
  if (menu == 'general' || menu == 'calculator') {
    mode = 'none';
  }
  final extractedSchedules = _draftList(raw['extractedSchedules'], ScheduleDraft.fromJson);
  final extractedBalances = _draftList(raw['extractedBalances'], BalanceDraft.fromJson);
  return IntentPayload(
    targetMenu: menu,
    saveMode: mode,
    summaryText: '${raw['summaryText'] ?? ''}'.trim(),
    table: TableModel.fromJson(raw['table']),
    chart: ChartModel.fromJson(raw['chart']),
    schedule: ScheduleDraft.fromJson(raw['schedule']),
    balance: BalanceDraft.fromJson(raw['balance']),
    cityQuery: '${raw['weather'] is Map ? (raw['weather'] as Map)['cityQuery'] ?? '' : ''}',
    currencyCode:
        '${raw['exchange'] is Map ? (raw['exchange'] as Map)['currencyCode'] ?? '' : ''}',
    newsCountry: '${raw['news'] is Map ? (raw['news'] as Map)['country'] ?? '' : ''}',
    extractedSchedules: extractedSchedules,
    extractedBalances: extractedBalances,
  );
}

class CityPreset {
  const CityPreset(this.label, this.query);
  final String label;
  final String query;
}

const defaultCities = [
  CityPreset('서울', 'Seoul,KR'),
  CityPreset('Yokohama', 'Yokohama,JP'),
  CityPreset('Singapore', 'Singapore,SG'),
  CityPreset('경기도 성남시', 'Seongnam,KR'),
  CityPreset('부산', 'Busan,KR'),
];

class CurrencyPreset {
  const CurrencyPreset(this.code, this.ko, this.en, this.ja);
  final String code;
  final String ko;
  final String en;
  final String ja;

  String label(String languageCode) {
    return switch (languageCode) {
      'en' => en,
      'ja' => ja,
      _ => ko,
    };
  }
}

const currencies = [
  CurrencyPreset('USD', 'USA달러', 'US dollar', '米ドル'),
  CurrencyPreset('JPY', 'Japan엔', 'Japanese yen', '日本円'),
  CurrencyPreset('EUR', 'Europe유로', 'Euro', 'ユーロ'),
  CurrencyPreset('CNY', '중국Yuan', 'Chinese yuan', '中国元'),
  CurrencyPreset('SGD', 'Singapore달러', 'Singapore dollar', 'シンガポールドル'),
  CurrencyPreset('MYR', 'Malaysia링깃', 'Malaysian ringgit', 'マレーシアリンギット'),
];

const allowedExtensions = {
  'txt',
  'pdf',
  'doc',
  'docx',
  'xls',
  'xlsx',
  'ppt',
  'pptx',
};

const maxUploadBytes = 20 * 1024 * 1024;
