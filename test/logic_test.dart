import 'package:flutter_test/flutter_test.dart';

import 'package:ai_assistant/features/balance/balance_screen.dart';
import 'package:ai_assistant/features/calculator/calc_engine.dart';
import 'package:ai_assistant/shared/logic/domain.dart';
import 'package:ai_assistant/shared/api/assistant_api.dart';
import 'package:ai_assistant/shared/phone_login.dart';
import 'package:ai_assistant/shared/state/providers.dart';

void main() {
  test('week starts Monday 00:00 Asia/Seoul', () {
    final thursdayMorningKst = DateTime.utc(2026, 10, 15, 1);
    final start = SeoulClock.startOfWeek(thursdayMorningKst);
    expect(start, DateTime.utc(2026, 10, 11, 15));
    expect(SeoulClock.inWeek(start, start), isTrue);
    expect(SeoulClock.inWeek(SeoulClock.addWeeks(start, 1), start), isFalse);
    expect(SeoulClock.inWeek(start.subtract(const Duration(seconds: 1)), start), isFalse);
  });

  test('running balance follows time then id', () {
    final first = DateTime.utc(2026, 10, 13);
    final balances = runningBalances([
      BalancePoint(id: 'b', occurredAt: first, amount: 2000, isIncome: false),
      BalancePoint(id: 'a', occurredAt: first, amount: 5000, isIncome: true),
    ]);
    expect(balances['a'], 5000);
    expect(balances['b'], 3000);
    final totals = weekTotals([
      BalancePoint(id: 'a', occurredAt: first, amount: 5000, isIncome: true),
      BalancePoint(id: 'b', occurredAt: first, amount: 2000, isIncome: false),
    ]);
    expect(totals.net, 3000);
  });

  test('120 hour records disappear from the live filter at expiry', () {
    final now = DateTime.utc(2026, 10, 15, 3);
    final expire = now.add(const Duration(hours: 120));
    expect(isUnexpired(expire, now), isTrue);
    expect(remainingHours(expire, now), 120);
    expect(isUnexpired(now, now), isFalse);
    expect(remainingHours(now.subtract(const Duration(hours: 1)), now), 0);
  });

  test('intent parser keeps known menus and drops general saves', () {
    final parsed = parseIntent({
      'targetMenu': 'balance',
      'saveMode': 'auto',
      'summaryText': 'lunch',
      'balance': {'description': '점심', 'amount': 12000, 'isIncome': false},
      'chart': {'hasChart': false},
    });
    expect(parsed.targetMenu, 'balance');
    expect(parsed.balance?.amount, 12000);
    final general = parseIntent({'targetMenu': 'general', 'saveMode': 'auto', 'summaryText': 'hello'});
    expect(general.saveMode, 'none');
    expect(() => parseIntent('nope'), throwsFormatException);
  });

  test('dividing by zero sets Error and does not continue', () {
    final calc = CalcEngine();
    calc.inputDigit('8');
    calc.inputOperator('÷');
    calc.inputDigit('0');
    calc.equals();
    expect(calc.display, 'Error');
    expect(calc.hasError, isTrue);
    expect(calc.numericValue, isNull);
  });

  test('deleting one half hides it, deleting the other half removes the turn', () {
    const turn = ChatTurn(id: 't', userText: 'q', aiText: 'a');
    expect(hideTurnParts(turn, null), same(turn));
    final noPrompt = hideTurnParts(turn, (user: true, ai: false))!;
    expect(noPrompt.userHidden, isTrue);
    expect(noPrompt.aiHidden, isFalse);
    expect(hideTurnParts(noPrompt, (user: false, ai: true)), isNull);
    expect(hideTurnParts(turn, (user: true, ai: true)), isNull);
  });

  test('equals records the finished calculation once', () {
    final calc = CalcEngine();
    calc.inputDigit('1');
    calc.inputDigit('2');
    calc.inputOperator('×');
    calc.inputDigit('3');
    calc.equals();
    expect(calc.lastRecord, '12 × 3 = 36');
    expect(calc.duplicate().lastRecord, isNull);
  });

  test('current balance counts every entry up to now and none after', () {
    final now = DateTime.utc(2026, 10, 16, 12);
    BalanceItem entry(int days, int amount, bool isIncome) => BalanceItem(
      id: '$days',
      description: 'x',
      amount: amount,
      isIncome: isIncome,
      occurredAt: now.add(Duration(days: days)),
      runningBalance: 0,
    );
    expect(balanceAt([entry(-400, 100000, true), entry(-3, 25000, false), entry(0, 5000, false), entry(2, 9999, true)], now), 70000);
  });

  test('phone login maps numbers to one account per E.164 number', () {
    expect(toE164('+82', '10-1234-5678'), '+821012345678');
    expect(toE164('82', '01012345678'), '+821012345678');
    expect(toE164('+81', '90 1234 5678'), '+819012345678');
    expect(toE164('+65', '8123 4567'), '+6581234567');
    expect(toE164('', '1012345678'), isNull);
    expect(toE164('+82', '12'), isNull);
    final email = phoneLoginEmail('+821012345678');
    expect(phoneOfLoginEmail(email), '+821012345678');
    expect(phoneOfLoginEmail('someone@example.com'), isNull);
  });
}
