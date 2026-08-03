/// v5.6.3 账户「不计入资产」：净资产业务口径排除 excludeFromAssets=true 的账户
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

  test('createAccount 持久化 excludeFromAssets', () async {
    final lid = await repo.createLedger(name: 'L');
    final aid = await repo.createAccount(
      ledgerId: lid,
      name: '代管账户',
      type: 'cash',
      initialBalance: 100,
      excludeFromAssets: true,
    );
    final a = await repo.getAccount(aid);
    expect(a!.excludeFromAssets, isTrue);
  });

  test('净资产/资产构成/净值趋势排除不计入资产账户', () async {
    final lid = await repo.createLedger(name: 'L');
    await repo.createAccount(
      ledgerId: lid,
      name: '自有现金',
      type: 'cash',
      initialBalance: 100,
    );
    await repo.createAccount(
      ledgerId: lid,
      name: '代管',
      type: 'cash',
      initialBalance: 500,
      excludeFromAssets: true,
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
