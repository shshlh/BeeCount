/// 7.3.1 表外/受托账户：is_off_balance 联动不计入资产，且不参与净资产统计。
import 'package:flutter_test/flutter_test.dart';
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

  test('createAccount(isOffBalance: true) 持久化表外并隐式不计入资产', () async {
    final lid = await repo.createLedger(name: 'L');
    final aid = await repo.createAccount(
      ledgerId: lid,
      name: '受托账户',
      type: 'cash',
      initialBalance: 500,
      isOffBalance: true,
    );

    final a = await repo.getAccount(aid);
    expect(a!.isOffBalance, isTrue);
    expect(a.excludeFromAssets, isTrue);
  });

  test('updateAccount 开启表外强制不计入资产', () async {
    final lid = await repo.createLedger(name: 'L');
    final aid = await repo.createAccount(
      ledgerId: lid,
      name: '普通账户',
      type: 'cash',
    );

    await repo.updateAccount(aid, isOffBalance: true);

    final a = await repo.getAccount(aid);
    expect(a!.isOffBalance, isTrue);
    expect(a.excludeFromAssets, isTrue);
  });

  test('updateAccount 显式取消不计入资产会同步关闭表外', () async {
    final lid = await repo.createLedger(name: 'L');
    final aid = await repo.createAccount(
      ledgerId: lid,
      name: '受托账户',
      type: 'cash',
      isOffBalance: true,
    );

    await repo.updateAccount(aid, excludeFromAssets: false);

    final a = await repo.getAccount(aid);
    expect(a!.isOffBalance, isFalse);
    expect(a.excludeFromAssets, isFalse);
  });

  test('updateAccount 单独关闭表外保留不计入资产状态', () async {
    final lid = await repo.createLedger(name: 'L');
    final aid = await repo.createAccount(
      ledgerId: lid,
      name: '受托账户',
      type: 'cash',
      isOffBalance: true,
    );

    await repo.updateAccount(aid, isOffBalance: false);

    final a = await repo.getAccount(aid);
    expect(a!.isOffBalance, isFalse);
    expect(a.excludeFromAssets, isTrue);
  });

  test('净资产/资产构成/净值趋势排除表外账户', () async {
    final lid = await repo.createLedger(name: 'L');
    await repo.createAccount(
      ledgerId: lid,
      name: '自有现金',
      type: 'cash',
      initialBalance: 100,
    );
    await repo.createAccount(
      ledgerId: lid,
      name: '受托资金',
      type: 'cash',
      initialBalance: 500,
      isOffBalance: true,
    );

    final breakdown = await repo.getNetWorthBreakdown();
    expect(breakdown.totalAssets, 100);
    expect(breakdown.netWorth, 100);

    final composition = await repo.getAssetCompositionByType();
    expect(composition.single.totalBalance, 100);

    final now = DateTime.now();
    final series = await repo.getNetWorthTrendSeries(
      startDate: now,
      endDate: now,
      ratesToBase: const {'CNY': 1.0},
    );
    expect(series.single.assets, 100);
  });
}
