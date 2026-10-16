import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/assistant_api.dart';
import '../../features/calculator/calc_engine.dart';

final apiProvider = Provider<AssistantApi>((ref) => AssistantApi());

final authUserProvider = StreamProvider<User?>((ref) => FirebaseAuth.instance.userChanges());

final uidProvider = Provider<String?>((ref) => ref.watch(authUserProvider).value?.uid);

final introEnabledProvider = NotifierProvider<IntroEnabledController, bool>(IntroEnabledController.new);

class IntroEnabledController extends Notifier<bool> {
  static const _key = 'introEnabled';

  @override
  bool build() {
    SharedPreferences.getInstance().then((prefs) {
      final stored = prefs.getBool(_key);
      if (stored != null && stored != state) {
        state = stored;
      }
    });
    return true;
  }

  Future<void> set(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale>(LocaleController.new);

class LocaleController extends Notifier<Locale> {
  static const _key = 'locale';

  @override
  Locale build() {
    SharedPreferences.getInstance().then((prefs) {
      final code = prefs.getString(_key);
      if (code != null && code != state.languageCode) {
        state = Locale(code);
      }
    });
    return const Locale('ko');
  }

  Future<void> setCode(String code) async {
    state = Locale(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
  }
}

enum AppMenu { schedules, balance, weather, exchange, news, calculator }

AppMenu? menuById(String? id) => switch (id) {
  'schedule' || 'schedules' => AppMenu.schedules,
  'balance' => AppMenu.balance,
  'weather' => AppMenu.weather,
  'exchange' || 'exchangeRate' => AppMenu.exchange,
  'news' => AppMenu.news,
  'calculator' => AppMenu.calculator,
  _ => null,
};

/// `null` is the chat-only home; a menu opens the split view with that menu on the right.
final menuProvider = NotifierProvider<MenuController, AppMenu?>(MenuController.new);

class MenuController extends Notifier<AppMenu?> {
  @override
  AppMenu? build() {
    ref.watch(uidProvider);
    return null;
  }

  void select(AppMenu menu) => state = menu;

  void home() => state = null;

  void selectById(String id) => state = menuById(id) ?? state;
}

final accountOpenProvider = NotifierProvider<AccountOpenController, bool>(AccountOpenController.new);

class AccountOpenController extends Notifier<bool> {
  @override
  bool build() => false;

  void open() => state = true;
  void close() => state = false;
}

final calcProvider = NotifierProvider<CalcController, CalcEngine>(CalcController.new);

class CalcController extends Notifier<CalcEngine> {
  @override
  CalcEngine build() => CalcEngine();

  void _touch(void Function(CalcEngine engine) change) {
    final next = state.duplicate();
    change(next);
    state = next;
  }

  void digit(String digit) => _touch((engine) => engine.inputDigit(digit));
  void dot() => _touch((engine) => engine.inputDot());
  void op(String operator) => _touch((engine) => engine.inputOperator(operator));
  void equals() {
    _touch((engine) => engine.equals());
    if (state.lastRecord case final record?) {
      ref.read(calcHistoryProvider.notifier).add(record);
    }
  }

  void clear() => _touch((engine) => engine.clear());
  void backspace() => _touch((engine) => engine.backspace());
  void sign() => _touch((engine) => engine.toggleSign());
}

class CalcRecord {
  const CalcRecord({required this.id, required this.expression, required this.at});

  final String id;
  final String expression;
  final DateTime at;

  Map<String, dynamic> toJson() => {'id': id, 'expression': expression, 'at': at.toIso8601String()};

  static CalcRecord? fromJson(Object? raw) {
    if (raw is! Map || raw['id'] is! String || raw['expression'] is! String) {
      return null;
    }
    return CalcRecord(
      id: raw['id'] as String,
      expression: raw['expression'] as String,
      at: DateTime.tryParse('${raw['at']}') ?? DateTime.now(),
    );
  }
}

/// Finished calculations, newest first; kept on this device per account, never sent to the server.
final calcHistoryProvider = NotifierProvider<CalcHistory, List<CalcRecord>>(CalcHistory.new);

class CalcHistory extends Notifier<List<CalcRecord>> {
  static const _limit = 100;
  late String _key;

  @override
  List<CalcRecord> build() {
    _key = 'calcHistory.${ref.watch(uidProvider) ?? 'signedOut'}';
    final key = _key;
    SharedPreferences.getInstance().then((prefs) {
      final raw = prefs.getString(key);
      if (raw == null || key != _key) {
        return;
      }
      final stored = (jsonDecode(raw) as List).map(CalcRecord.fromJson).whereType<CalcRecord>();
      state = [...state, ...stored.where((item) => state.every((current) => current.id != item.id))];
    });
    return const [];
  }

  void add(String expression) {
    final now = DateTime.now();
    state = [CalcRecord(id: '${now.microsecondsSinceEpoch}', expression: expression, at: now), ...state].take(_limit).toList();
    _save();
  }

  void remove(Iterable<String> ids) {
    final drop = ids.toSet();
    state = state.where((item) => !drop.contains(item.id)).toList();
    _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode([for (final item in state) item.toJson()]));
  }
}

class FloatPos {
  const FloatPos({required this.open, this.left, this.top});

  final bool open;
  final double? left;
  final double? top;

  FloatPos copy({bool? open, double? left, double? top, bool clearOffset = false}) {
    return FloatPos(open: open ?? this.open, left: clearOffset ? null : left ?? this.left, top: clearOffset ? null : top ?? this.top);
  }
}

final floatProvider = NotifierProvider<FloatController, FloatPos>(FloatController.new);

class FloatController extends Notifier<FloatPos> {
  @override
  FloatPos build() => const FloatPos(open: false);

  void open() => state = state.copy(open: true);
  void close() => state = const FloatPos(open: false);

  void moveBy(double dx, double dy, Size screen, Size popup) {
    final left = (state.left ?? (screen.width - popup.width - 20)) + dx;
    final top = (state.top ?? 70) + dy;
    final maxLeft = (screen.width - popup.width).clamp(0.0, double.infinity);
    final maxTop = (screen.height - popup.height).clamp(0.0, double.infinity);
    state = FloatPos(open: true, left: left.clamp(0.0, maxLeft), top: top.clamp(0.0, maxTop));
  }
}

class InsertRequest {
  const InsertRequest(this.nonce, this.text);
  final int nonce;
  final String text;
}

final insertProvider = NotifierProvider<InsertController, InsertRequest?>(InsertController.new);

class InsertController extends Notifier<InsertRequest?> {
  var _nonce = 0;

  @override
  InsertRequest? build() => null;

  void insert(String text) {
    _nonce += 1;
    state = InsertRequest(_nonce, text);
  }
}

Stream<List<T>> _forUser<T>(Ref ref, Stream<List<T>> Function(AssistantApi api) watch) {
  if (ref.watch(uidProvider) == null) {
    return Stream.value(<T>[]);
  }
  return watch(ref.watch(apiProvider));
}

final schedulesProvider = StreamProvider<List<ScheduleItem>>((ref) {
  return _forUser(ref, (api) => api.watchSchedules());
});

final balancesProvider = StreamProvider<List<BalanceItem>>((ref) {
  return _forUser(ref, (api) => api.watchBalances());
});

final newsProvider = StreamProvider<List<NewsItem>>((ref) {
  return _forUser(ref, (api) => api.watchNews());
});

final weatherProvider = StreamProvider<List<WeatherItem>>((ref) {
  return _forUser(ref, (api) => api.watchWeather());
});

final exchangeProvider = StreamProvider<List<ExchangeItem>>((ref) {
  return _forUser(ref, (api) => api.watchExchange());
});

final turnsProvider = StreamProvider<List<ChatTurn>>((ref) {
  return _forUser(ref, (api) => api.watchTurns());
});

final localTurnsProvider = NotifierProvider<LocalTurns, List<ChatTurn>>(LocalTurns.new);

class LocalTurns extends Notifier<List<ChatTurn>> {
  @override
  List<ChatTurn> build() {
    ref.watch(uidProvider);
    return const [];
  }

  void add(ChatTurn turn) => state = [...state, turn];

  void replace(String id, ChatTurn turn) {
    state = [for (final item in state) item.id == id ? turn : item];
  }

  void dropIds(Set<String> ids) {
    state = state.where((turn) => !ids.contains(turn.id)).toList();
  }

  /// Applies a deletion locally; a turn with both halves gone disappears.
  void hideParts(Map<String, ({bool user, bool ai})> parts) {
    state = [for (final turn in state) ?hideTurnParts(turn, parts[turn.id])];
  }
}

/// [turn] with the chosen halves hidden, or null once neither half is left.
ChatTurn? hideTurnParts(ChatTurn turn, ({bool user, bool ai})? part) {
  if (part == null) {
    return turn;
  }
  final userHidden = part.user || turn.userHidden;
  final aiHidden = part.ai || turn.aiHidden;
  return userHidden && aiHidden ? null : turn.copyWith(userHidden: userHidden, aiHidden: aiHidden);
}
