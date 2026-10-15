import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/assistant_api.dart';
import '../../features/calculator/calc_engine.dart';

final apiProvider = Provider<AssistantApi>((ref) => AssistantApi());

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

final menuProvider = NotifierProvider<MenuController, AppMenu>(MenuController.new);

class MenuController extends Notifier<AppMenu> {
  @override
  AppMenu build() => AppMenu.schedules;

  void select(AppMenu menu) => state = menu;

  void selectById(String id) {
    state = switch (id) {
      'schedule' || 'schedules' => AppMenu.schedules,
      'balance' => AppMenu.balance,
      'weather' => AppMenu.weather,
      'exchange' || 'exchangeRate' => AppMenu.exchange,
      'news' => AppMenu.news,
      'calculator' => AppMenu.calculator,
      _ => state,
    };
  }
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
  void equals() => _touch((engine) => engine.equals());
  void clear() => _touch((engine) => engine.clear());
  void backspace() => _touch((engine) => engine.backspace());
  void sign() => _touch((engine) => engine.toggleSign());
}

class FloatPos {
  const FloatPos({required this.open, this.left, this.top});

  final bool open;
  final double? left;
  final double? top;

  FloatPos copy({bool? open, double? left, double? top, bool clearOffset = false}) {
    return FloatPos(
      open: open ?? this.open,
      left: clearOffset ? null : left ?? this.left,
      top: clearOffset ? null : top ?? this.top,
    );
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
    final top = (state.top ?? 20) + dy;
    final maxLeft = (screen.width - popup.width).clamp(0.0, double.infinity);
    final maxTop = (screen.height - popup.height).clamp(0.0, double.infinity);
    state = FloatPos(
      open: true,
      left: left.clamp(0.0, maxLeft),
      top: top.clamp(0.0, maxTop),
    );
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

final schedulesProvider = StreamProvider<List<ScheduleItem>>((ref) {
  return ref.watch(apiProvider).watchSchedules();
});

final balancesProvider = StreamProvider<List<BalanceItem>>((ref) {
  return ref.watch(apiProvider).watchBalances();
});

final newsProvider = StreamProvider<List<NewsItem>>((ref) {
  return ref.watch(apiProvider).watchNews();
});

final weatherProvider = StreamProvider<List<WeatherItem>>((ref) {
  return ref.watch(apiProvider).watchWeather();
});

final exchangeProvider = StreamProvider<List<ExchangeItem>>((ref) {
  return ref.watch(apiProvider).watchExchange();
});

final turnsProvider = StreamProvider<List<ChatTurn>>((ref) {
  return ref.watch(apiProvider).watchTurns();
});

final localTurnsProvider = NotifierProvider<LocalTurns, List<ChatTurn>>(LocalTurns.new);

class LocalTurns extends Notifier<List<ChatTurn>> {
  @override
  List<ChatTurn> build() => const [];

  void add(ChatTurn turn) => state = [...state, turn];

  void replace(String id, ChatTurn turn) {
    state = [for (final item in state) item.id == id ? turn : item];
  }

  void dropIds(Set<String> ids) {
    state = state.where((turn) => !ids.contains(turn.id)).toList();
  }
}
