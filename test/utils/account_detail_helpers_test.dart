// 7.14 账户详情页：tab→flow 映射 + 逐笔余额累计（含转出/转入）。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/pages/account/account_detail_page.dart';

Transaction tx({
  required int id,
  required String type,
  required double amount,
  DateTime? happenedAt,
  int? accountId,
  int? toAccountId,
}) =>
    Transaction(
      id: id,
      ledgerId: 1,
      type: type,
      amount: amount,
      accountId: accountId,
      toAccountId: toAccountId,
      happenedAt: happenedAt ?? DateTime(2026, 8, 1),
      excludeFromStats: false,
      excludeFromBudget: false,
    );

void main() {
  test('tab → flow 映射：全部 null / 支出 expense / 收入 income', () {
    expect(accountDetailFlowForTab(0), isNull);
    expect(accountDetailFlowForTab(1), 'expense');
    expect(accountDetailFlowForTab(2), 'income');
  });

  test('逐笔余额按当前余额反推，收入/支出/转出/转入累计正确', () {
    final transferIn = tx(
        id: 4,
        type: 'transfer',
        amount: 50,
        toAccountId: 1,
        happenedAt: DateTime(2026, 8, 4));
    final income = tx(
        id: 3,
        type: 'income',
        amount: 500,
        accountId: 1,
        happenedAt: DateTime(2026, 8, 3));
    final expense = tx(
        id: 2,
        type: 'expense',
        amount: 100,
        accountId: 1,
        happenedAt: DateTime(2026, 8, 2));
    final transferOut = tx(
        id: 1,
        type: 'transfer',
        amount: 200,
        accountId: 1,
        happenedAt: DateTime(2026, 8, 1));

    // 展示顺序：时间倒序。当前余额 = 1000 + 50 + 500 - 100 - 200 = 1250。
    final balances = computeAccountRunningBalances(
      accountId: 1,
      currentBalance: 1250,
      isValuation: false,
      transactions: [transferIn, income, expense, transferOut],
    );

    expect(balances[4], 1250); // 转入后
    expect(balances[3], 1200); // 收入后
    expect(balances[2], 700); // 支出后
    expect(balances[1], 800); // 转出后
  });

  test('估值账户逐笔余额恒为缓存市值', () {
    final balances = computeAccountRunningBalances(
      accountId: 1,
      currentBalance: 5000,
      isValuation: true,
      transactions: [
        tx(id: 1, type: 'income', amount: 100, accountId: 1),
        tx(id: 2, type: 'expense', amount: 50, accountId: 1),
      ],
    );
    expect(balances[1], 5000);
    expect(balances[2], 5000);
  });
}
