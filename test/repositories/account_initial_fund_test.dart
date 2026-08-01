/// 4.9 账户创建优化 — Repository 层语义测试:
/// - 应收款余额 = 初始资金 + 流水(不再走估值固定值)
/// - createAccount / updateAccount 支持 initialDate 落库
/// - createAccount 未传 initialDate 时默认今天
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
  });

  tearDown(() async => db.close());

  test('应收款账户余额 = 初始资金 + 流水', () async {
    final lid = await repo.createLedger(name: 'L');
    final aid = await repo.createAccount(
      ledgerId: lid,
      name: '借出款',
      type: 'receivable',
      initialBalance: 1000,
    );
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        ledgerId: lid,
        type: 'income',
        amount: 500,
        accountId: d.Value(aid),
        happenedAt: d.Value(DateTime(2026, 7, 1))));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        ledgerId: lid,
        type: 'expense',
        amount: 200,
        accountId: d.Value(aid),
        happenedAt: d.Value(DateTime(2026, 7, 2))));

    expect(await repo.getAccountBalance(aid), closeTo(1300, 0.001));
  });

  test('createAccount / updateAccount 支持 initialDate 落库', () async {
    final lid = await repo.createLedger(name: 'L');
    final aid = await repo.createAccount(
      ledgerId: lid,
      name: '现金',
      initialBalance: 100,
      initialDate: DateTime(2026, 5, 1),
    );

    var account = await repo.getAccount(aid);
    expect(account!.initialDate, DateTime(2026, 5, 1));

    await repo.updateAccount(aid, initialDate: DateTime(2026, 5, 15));
    account = await repo.getAccount(aid);
    expect(account!.initialDate, DateTime(2026, 5, 15));
  });

  test('createAccount 未传 initialDate 时保持 null(不约束历史趋势)', () async {
    final lid = await repo.createLedger(name: 'L');
    final aid = await repo.createAccount(ledgerId: lid, name: '现金');

    final account = await repo.getAccount(aid);
    expect(account!.initialDate, isNull);
  });
}
