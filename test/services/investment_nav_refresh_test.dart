import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_investment_repository.dart';
import 'package:beecount/services/data/investment_service.dart';
import 'package:beecount/services/data/nav_fetch_service.dart';

class _FakeNavFetchService extends NavFetchService {
  _FakeNavFetchService(this.navs, {this.failAll = false});

  final Map<String, double> navs;
  final bool failAll;
  int calls = 0;

  @override
  Future<Map<String, double>> fetchLatestNavs(List<String> fundCodes) async {
    calls++;
    if (failAll) return const {};
    return {
      for (final code in fundCodes)
        if (navs.containsKey(code)) code: navs[code]!,
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalInvestmentRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalInvestmentRepository(db);

    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, type, currency) "
        "VALUES (10, 1, '投资账户', 'investment', 'CNY')");
  });

  tearDown(() async => db.close());

  Future<double> accountValue() async {
    final row = await (db.select(db.accounts)..where((a) => a.id.equals(10)))
        .getSingle();
    return row.initialBalance;
  }

  test('刷新成功：净值/市值/账户市值联动', () async {
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '基金A',
        amount: 1000,
        shares: 1000,
        nav: 1.0);
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000002',
        fundName: '基金B',
        amount: 2000,
        shares: 1000,
        nav: 2.0);

    final fake = _FakeNavFetchService({'000001': 1.5, '000002': 2.5});
    final service = InvestmentService(repo, navFetch: fake);

    final updated = await service.refreshNavsForLedger(1);

    expect(updated, 2);
    expect(fake.calls, 1);
    final h1 = await repo.getHolding(1);
    expect(h1!.currentNav, 1.5);
    expect(h1.marketValue, 1500.0);
    final h2 = await repo.getHolding(2);
    expect(h2!.currentNav, 2.5);
    expect(h2.marketValue, 2500.0);
    expect(await accountValue(), closeTo(4000, 0.01));
  });

  test('节流命中返回 0，force 绕过', () async {
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '基金A',
        amount: 1000,
        shares: 1000,
        nav: 1.0);

    final fake = _FakeNavFetchService({'000001': 1.5});
    final service = InvestmentService(repo, navFetch: fake);

    expect(await service.refreshNavsForLedger(1), 1);
    expect(await service.refreshNavsForLedger(1), 0);
    expect(fake.calls, 1);

    expect(await service.refreshNavsForLedger(1, force: true), 1);
    expect(fake.calls, 2);
  });

  test('超过 15 分钟允许再次刷新', () async {
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '基金A',
        amount: 1000,
        shares: 1000,
        nav: 1.0);
    SharedPreferences.setMockInitialValues({
      'investment_nav_refresh_at_1': DateTime.now()
          .subtract(const Duration(minutes: 16))
          .millisecondsSinceEpoch,
    });

    final fake = _FakeNavFetchService({'000001': 1.5});
    final service = InvestmentService(repo, navFetch: fake);

    expect(await service.refreshNavsForLedger(1), 1);
    expect(fake.calls, 1);
  });

  test('整批失败抛错且不记录节流时间', () async {
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '基金A',
        amount: 1000,
        shares: 1000,
        nav: 1.0);

    final fake = _FakeNavFetchService({}, failAll: true);
    final service = InvestmentService(repo, navFetch: fake);

    await expectLater(
      () => service.refreshNavsForLedger(1),
      throwsA(isA<StateError>()),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('investment_nav_refresh_at_1'), isNull);
  });

  test('多账本节流 key 隔离', () async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (2, 'L2', 'CNY')");
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, type, currency) "
        "VALUES (20, 2, '投资账户2', 'investment', 'CNY')");
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '基金A',
        amount: 1000,
        shares: 1000,
        nav: 1.0);
    await repo.buy(
        ledgerId: 2,
        accountId: 20,
        fundCode: '000003',
        fundName: '基金C',
        amount: 3000,
        shares: 1000,
        nav: 3.0);

    final fake = _FakeNavFetchService({'000001': 1.5, '000003': 3.5});
    final service = InvestmentService(repo, navFetch: fake);

    expect(await service.refreshNavsForLedger(1), 1);
    expect(await service.refreshNavsForLedger(2), 1);
    expect(fake.calls, 2);

    expect(await service.refreshNavsForLedger(1), 0);
    expect(fake.calls, 2);
  });

  test('部分成功只更新命中的持仓', () async {
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '基金A',
        amount: 1000,
        shares: 1000,
        nav: 1.0);
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000002',
        fundName: '基金B',
        amount: 2000,
        shares: 1000,
        nav: 2.0);

    final fake = _FakeNavFetchService({'000001': 1.5});
    final service = InvestmentService(repo, navFetch: fake);

    final updated = await service.refreshNavsForLedger(1);

    expect(updated, 1);
    expect((await repo.getHolding(1))!.currentNav, 1.5);
    expect((await repo.getHolding(2))!.currentNav, 2.0);
  });
}
