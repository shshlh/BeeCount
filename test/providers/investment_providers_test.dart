import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_investment_repository.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/providers/investment_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalInvestmentRepository repo;

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalInvestmentRepository(db);

    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, type, currency) "
        "VALUES (10, 1, '投资账户', 'investment', 'CNY')");

    // H1: 市值 200 / 成本 100 / 收益 100 / 收益率 100%
    await repo.buy(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000001',
      fundName: '基金A',
      amount: 100,
      shares: 100,
      nav: 2.0,
    );
    // H2: 市值 1000 / 成本 600 / 收益 400 / 收益率 66.7%
    await repo.buy(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000002',
      fundName: '基金B',
      amount: 600,
      shares: 1000,
      nav: 1.0,
    );
    // H3: 市值 150 / 成本 1000 / 收益 -850 / 收益率 -85%
    await repo.buy(
      ledgerId: 1,
      accountId: 10,
      fundCode: '000003',
      fundName: '基金C',
      amount: 1000,
      shares: 100,
      nav: 1.5,
    );
  });

  tearDown(() async => db.close());

  Future<ProviderContainer> makeContainer() async {
    final container = ProviderContainer(overrides: [
      investmentRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  List<String> codes(List<InvestmentHolding> holdings) =>
      holdings.map((h) => h.fundCode).toList();

  test('sortedHoldingsProvider：默认按市值降序，可切换收益/收益率', () async {
    final container = await makeContainer();

    final byMv = await container.read(sortedHoldingsProvider.future);
    expect(codes(byMv), ['000002', '000001', '000003']);

    container.read(holdingsSortProvider.notifier).state = HoldingsSort.pnl;
    final byPnl = await container.read(sortedHoldingsProvider.future);
    expect(codes(byPnl), ['000002', '000001', '000003']);

    container.read(holdingsSortProvider.notifier).state =
        HoldingsSort.returnRate;
    final byRate = await container.read(sortedHoldingsProvider.future);
    expect(codes(byRate), ['000001', '000002', '000003']);
  });

  test('groupsProvider + filteredHoldingsProvider：先过滤再排序', () async {
    final groupA = await repo.createGroup(
      ledgerId: 1,
      name: '组合A',
      sortOrder: 1,
    );
    final groupB = await repo.createGroup(
      ledgerId: 1,
      name: '组合B',
      sortOrder: 0,
    );
    final holdings = await repo.watchHoldings(ledgerId: 1).first;
    final byCode = {for (final h in holdings) h.fundCode: h.id};
    await repo.addHoldingsToGroup(groupA, [
      byCode['000001']!,
      byCode['000003']!,
    ]);
    await repo.addHoldingsToGroup(groupB, [byCode['000002']!]);

    final container = await makeContainer();
    final groups = await container.read(groupsProvider.future);
    expect(groups.map((g) => g.name).toList(), ['组合B', '组合A']);

    final all = await container.read(filteredHoldingsProvider.future);
    expect(codes(all), ['000002', '000001', '000003']);

    container.read(selectedGroupProvider.notifier).select(groupA);
    final filtered = await container.read(filteredHoldingsProvider.future);
    expect(codes(filtered), ['000001', '000003']);
  });

  test('切换账本后选中的分组重置为全部', () async {
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (2, 'L2', 'CNY')");
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, type, currency) "
        "VALUES (20, 2, '投资账户2', 'investment', 'CNY')");
    await repo.buy(
      ledgerId: 2,
      accountId: 20,
      fundCode: '000004',
      fundName: '基金D',
      amount: 100,
      shares: 100,
      nav: 1.0,
    );

    final groupA = await repo.createGroup(
      ledgerId: 1,
      name: '组合A',
      sortOrder: 0,
    );

    final container = await makeContainer();
    container.read(selectedGroupProvider.notifier).select(groupA);
    expect(container.read(selectedGroupProvider), groupA);

    container.read(currentLedgerIdProvider.notifier).state = 2;
    await Future<void>.delayed(Duration.zero);
    expect(container.read(selectedGroupProvider), isNull);

    final filtered = await container.read(filteredHoldingsProvider.future);
    expect(codes(filtered), ['000004']);
  });
}
