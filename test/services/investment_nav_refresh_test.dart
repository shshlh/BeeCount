import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_investment_repository.dart';
import 'package:beecount/services/data/investment_service.dart';
import 'package:beecount/services/data/nav_fetch_service.dart';

class _FakeNavFetchService extends NavFetchService {
  _FakeNavFetchService(this.navs, {this.failAll = false, this.histories});

  final Map<String, FundNavQuote> navs;
  final Map<String, List<FundNavQuote>>? histories;
  final bool failAll;
  int calls = 0;

  @override
  Future<Map<String, List<FundNavQuote>>> fetchNavHistories(
      List<String> fundCodes) async {
    calls++;
    if (failAll) return const {};
    if (histories != null) {
      return {
        for (final code in fundCodes)
          if (histories!.containsKey(code)) code: histories![code]!,
      };
    }
    return {
      for (final code in fundCodes)
        if (navs.containsKey(code)) code: [navs[code]!],
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

    final navDate = DateTime(2026, 8, 7);
    final fake = _FakeNavFetchService({
      '000001': FundNavQuote(nav: 1.5, navDate: navDate),
      '000002': FundNavQuote(nav: 2.5, navDate: navDate),
    });
    final service = InvestmentService(repo, navFetch: fake);

    final updated = await service.refreshNavsForLedger(1);

    expect(updated, 2);
    expect(fake.calls, 1);
    final h1 = await repo.getHolding(1);
    expect(h1!.currentNav, 1.5);
    expect(h1.marketValue, 1500.0);
    expect(h1.navDate, navDate);
    final h2 = await repo.getHolding(2);
    expect(h2!.currentNav, 2.5);
    expect(h2.marketValue, 2500.0);
    expect(h2.navDate, navDate);
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

    final fake = _FakeNavFetchService({
      '000001': FundNavQuote(nav: 1.5, navDate: DateTime(2026, 8, 7)),
    });
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

    final fake = _FakeNavFetchService({
      '000001': FundNavQuote(nav: 1.5, navDate: DateTime(2026, 8, 7)),
    });
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

    final fake = _FakeNavFetchService({
      '000001': FundNavQuote(nav: 1.5, navDate: DateTime(2026, 8, 7)),
      '000003': FundNavQuote(nav: 3.5, navDate: DateTime(2026, 8, 8)),
    });
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

    final fake = _FakeNavFetchService({
      '000001': FundNavQuote(nav: 1.5, navDate: DateTime(2026, 8, 7)),
    });
    final service = InvestmentService(repo, navFetch: fake);

    final updated = await service.refreshNavsForLedger(1);

    expect(updated, 1);
    expect((await repo.getHolding(1))!.currentNav, 1.5);
    expect((await repo.getHolding(1))!.navDate, DateTime(2026, 8, 7));
    expect((await repo.getHolding(2))!.currentNav, 2.0);
  });

  test('修正基金代码后刷新可命中新代码', () async {
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '11017',
        fundName: '误录基金',
        amount: 1000,
        shares: 1000,
        nav: 1.0);

    final fake = _FakeNavFetchService({
      '110017': FundNavQuote(nav: 1.8, navDate: DateTime(2026, 8, 7)),
    });
    final service = InvestmentService(repo, navFetch: fake);

    await service.updateHoldingInfo(
      1,
      fundCode: '110017',
      fundName: '修正基金',
    );
    final updated = await service.refreshNavsForLedger(1);

    expect(updated, 1);
    final h = await repo.getHolding(1);
    expect(h!.fundCode, '110017');
    expect(h.currentNav, 1.8);
  });

  test('详细刷新：部分成功返回 skipped 列表', () async {
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
        amount: 500,
        shares: 500,
        nav: 1.0);

    final fake = _FakeNavFetchService({
      '000001': FundNavQuote(nav: 1.5, navDate: DateTime(2026, 8, 7)),
    });
    final service = InvestmentService(repo, navFetch: fake);

    final result = await service.refreshNavsForLedgerDetailed(1);

    expect(result.updatedCount, 1);
    expect(result.skippedCodes, ['000002']);
  });

  test('详细刷新：非法代码持仓出现在 skipped', () async {
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '11017',
        fundName: '误录基金',
        amount: 1000,
        shares: 1000,
        nav: 1.0);
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '基金A',
        amount: 500,
        shares: 500,
        nav: 1.0);

    final fake = _FakeNavFetchService({
      '000001': FundNavQuote(nav: 1.5, navDate: DateTime(2026, 8, 7)),
    });
    final service = InvestmentService(repo, navFetch: fake);

    final result = await service.refreshNavsForLedgerDetailed(1);

    expect(result.updatedCount, 1);
    expect(result.skippedCodes, ['11017']);
  });

  test('详细刷新：整批失败不抛错且 skipped 全量返回', () async {
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
        amount: 500,
        shares: 500,
        nav: 1.0);

    final fake = _FakeNavFetchService({}, failAll: true);
    final service = InvestmentService(repo, navFetch: fake);

    final result = await service.refreshNavsForLedgerDetailed(1);

    expect(result.updatedCount, 0);
    expect(result.skippedCodes.toSet(), {'000001', '000002'});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('investment_nav_refresh_at_1'), isNull);
  });

  test('刷新写入净值历史并统计 advancedCount', () async {
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '基金A',
        amount: 1000,
        shares: 1000,
        nav: 1.0,
        navDate: DateTime(2026, 8, 18));

    final fake = _FakeNavFetchService(
      {'000001': FundNavQuote(nav: 1.2, navDate: DateTime(2026, 8, 19))},
      histories: {
        '000001': [
          FundNavQuote(nav: 1.0, navDate: DateTime(2026, 8, 17)),
          FundNavQuote(nav: 1.1, navDate: DateTime(2026, 8, 18)),
          FundNavQuote(nav: 1.2, navDate: DateTime(2026, 8, 19)),
        ],
      },
    );
    final service = InvestmentService(repo, navFetch: fake);

    final result = await service.refreshNavsForLedgerDetailed(1);

    expect(result.updatedCount, 1);
    expect(result.advancedCount, 1);
    final history = await repo.getNavHistory('000001', limit: 3);
    expect(history.map((h) => h.navDate.day).toList(), [19, 18, 17]);
  });

  test('refreshDailyNavsForLedger：20:00 前待更新不拉取，20:00 后拉取', () async {
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '基金A',
        amount: 1000,
        shares: 1000,
        nav: 1.0,
        navDate: DateTime(2026, 8, 17));

    final fake = _FakeNavFetchService({
      '000001': FundNavQuote(nav: 1.2, navDate: DateTime(2026, 8, 18)),
    });
    var now = DateTime(2026, 8, 18, 15);
    final service = InvestmentService(repo, navFetch: fake, clock: () => now);

    final pending = await service.refreshDailyNavsForLedger(1);
    expect(pending.updatedCount, 0);
    expect(fake.calls, 0);
    expect(await service.getDailyNavStatus(1), DailyNavStatus.pending);

    now = DateTime(2026, 8, 18, 20, 30);
    final result = await service.refreshDailyNavsForLedger(1);
    expect(result.updatedCount, 1);
    expect(fake.calls, 1);
    expect(await service.getDailyNavStatus(1), DailyNavStatus.allUpdated);
  });

  test('非交易日不拉取并标记非交易日', () async {
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '基金A',
        amount: 1000,
        shares: 1000,
        nav: 1.0);

    final fake = _FakeNavFetchService({
      '000001': FundNavQuote(nav: 1.2, navDate: DateTime(2026, 8, 15)),
    });
    final service = InvestmentService(
      repo,
      navFetch: fake,
      clock: () => DateTime(2026, 8, 15, 20, 30),
    );

    final result = await service.refreshDailyNavsForLedger(1);
    expect(result.updatedCount, 0);
    expect(fake.calls, 0);
    expect(await service.getDailyNavStatus(1), DailyNavStatus.nonTradingDay);
  });

  test('部分更新：只有净值日期前进的持仓算已更新', () async {
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '基金A',
        amount: 1000,
        shares: 1000,
        nav: 1.0,
        navDate: DateTime(2026, 8, 18));
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000002',
        fundName: '基金B',
        amount: 500,
        shares: 500,
        nav: 1.0,
        navDate: DateTime(2026, 8, 18));

    final fake = _FakeNavFetchService(
      const {},
      histories: {
        '000001': [
          FundNavQuote(nav: 1.0, navDate: DateTime(2026, 8, 18)),
          FundNavQuote(nav: 1.2, navDate: DateTime(2026, 8, 19)),
        ],
        '000002': [
          FundNavQuote(nav: 1.0, navDate: DateTime(2026, 8, 18)),
        ],
      },
    );
    final service = InvestmentService(
      repo,
      navFetch: fake,
      clock: () => DateTime(2026, 8, 18, 20, 30),
    );

    final result = await service.refreshDailyNavsForLedger(1);

    expect(result.updatedCount, 2);
    expect(result.advancedCount, 1);
    expect(await service.getDailyNavStatus(1), DailyNavStatus.partialUpdated);
  });

  test('全部更新分母排除货币基金', () async {
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '基金A',
        amount: 1000,
        shares: 1000,
        nav: 1.0,
        navDate: DateTime(2026, 8, 18));
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000002',
        fundName: '货币基金A',
        amount: 500,
        shares: 500,
        nav: 1.0,
        navDate: DateTime(2026, 8, 18));

    final fake = _FakeNavFetchService(
      const {},
      histories: {
        '000001': [
          FundNavQuote(nav: 1.0, navDate: DateTime(2026, 8, 18)),
          FundNavQuote(nav: 1.2, navDate: DateTime(2026, 8, 19)),
        ],
      },
    );
    final service = InvestmentService(
      repo,
      navFetch: fake,
      clock: () => DateTime(2026, 8, 18, 20, 30),
    );

    final result = await service.refreshDailyNavsForLedger(1);

    expect(result.updatedCount, 1);
    expect(result.advancedCount, 1);
    expect(result.skippedCodes, isEmpty,
        reason: '货币基金不进入 skippedCodes');
    expect(await service.getDailyNavStatus(1), DailyNavStatus.allUpdated);
  });

  test('普通基金未更新 + 货币基金已更新 → partialUpdated', () async {
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '基金A',
        amount: 1000,
        shares: 1000,
        nav: 1.0,
        navDate: DateTime(2026, 8, 18));
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000002',
        fundName: '货币基金A',
        amount: 500,
        shares: 500,
        nav: 1.0,
        navDate: DateTime(2026, 8, 17));

    final fake = _FakeNavFetchService(
      const {},
      histories: {
        '000001': [
          FundNavQuote(nav: 1.0, navDate: DateTime(2026, 8, 18)),
        ],
        '000002': [
          FundNavQuote(nav: 1.0, navDate: DateTime(2026, 8, 18)),
        ],
      },
    );
    final service = InvestmentService(
      repo,
      navFetch: fake,
      clock: () => DateTime(2026, 8, 18, 20, 30),
    );

    final result = await service.refreshDailyNavsForLedger(1);

    expect(result.updatedCount, 2);
    expect(result.advancedCount, 0,
        reason: 'advancedCount 只统计非货币基金');
    expect(result.totalAdvancedCount, 1,
        reason: '货币基金仍计入 totalAdvancedCount 用于部分更新判断');
    expect(await service.getDailyNavStatus(1), DailyNavStatus.partialUpdated);
  });

  test('状态 key 带日期，跨日不残留昨日状态', () async {
    await repo.buy(
        ledgerId: 1,
        accountId: 10,
        fundCode: '000001',
        fundName: '基金A',
        amount: 1000,
        shares: 1000,
        nav: 1.0,
        navDate: DateTime(2026, 8, 18));

    final fake = _FakeNavFetchService({
      '000001': FundNavQuote(nav: 1.2, navDate: DateTime(2026, 8, 19)),
    });
    final service = InvestmentService(
      repo,
      navFetch: fake,
      clock: () => DateTime(2026, 8, 18, 20, 30),
    );

    await service.refreshDailyNavsForLedger(1);
    expect(await service.getDailyNavStatus(1), DailyNavStatus.allUpdated);

    final nextDay = InvestmentService(
      repo,
      navFetch: fake,
      clock: () => DateTime(2026, 8, 19, 10),
    );
    expect(await nextDay.getDailyNavStatus(1), DailyNavStatus.pending);
  });
}
