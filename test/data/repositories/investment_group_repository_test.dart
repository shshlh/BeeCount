import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_investment_repository.dart';

void main() {
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
  });

  tearDown(() async => db.close());

  Future<int> createHolding(String code, String name) async {
    await repo.buy(
      ledgerId: 1,
      accountId: 10,
      fundCode: code,
      fundName: name,
      amount: 100,
      shares: 100,
      nav: 1.0,
    );
    final holding = await (db.select(db.investmentHoldings)
          ..where((h) => h.fundCode.equals(code)))
        .getSingle();
    return holding.id;
  }

  test('分组 CRUD：创建/改名/删除', () async {
    final groupId = await repo.createGroup(
      ledgerId: 1,
      name: '组合A',
      sortOrder: 2,
    );
    await repo.createGroup(
      ledgerId: 1,
      name: '组合B',
      sortOrder: 1,
    );

    final groups = await repo.watchGroups(ledgerId: 1).first;
    expect(groups.map((g) => g.name).toList(), ['组合B', '组合A']);

    await repo.renameGroup(groupId, '组合A改');
    final renamed = await repo.watchGroups(ledgerId: 1).first;
    expect(renamed.firstWhere((g) => g.id == groupId).name, '组合A改');

    await repo.deleteGroup(groupId);
    final afterDelete = await repo.watchGroups(ledgerId: 1).first;
    expect(afterDelete.map((g) => g.id), isNot(contains(groupId)));
  });

  test('分组 CRUD：不存在时改名/删除抛 StateError', () async {
    await expectLater(
      () => repo.renameGroup(999, 'x'),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      () => repo.deleteGroup(999),
      throwsA(isA<StateError>()),
    );
  });

  test('成员管理：添加去重/移除/整组替换', () async {
    final h1 = await createHolding('000001', '基金A');
    final h2 = await createHolding('000002', '基金B');
    final groupId = await repo.createGroup(ledgerId: 1, name: '组合A');

    await repo.addHoldingsToGroup(groupId, [h1, h2, h1]);
    expect(await repo.watchGroupHoldingIds(groupId).first, [h1, h2]);

    await repo.removeHoldingFromGroup(groupId, h1);
    expect(await repo.watchGroupHoldingIds(groupId).first, [h2]);

    await repo.setGroupMembers(groupId, [h1, h2]);
    expect(await repo.watchGroupHoldingIds(groupId).first, [h1, h2]);
  });

  test('多对多：一只基金可属于多个分组', () async {
    final h1 = await createHolding('000001', '基金A');
    final groupA = await repo.createGroup(ledgerId: 1, name: '组合A');
    final groupB = await repo.createGroup(ledgerId: 1, name: '组合B');

    await repo.addHoldingsToGroup(groupA, [h1]);
    await repo.addHoldingsToGroup(groupB, [h1]);

    expect(await repo.watchGroupHoldingIds(groupA).first, [h1]);
    expect(await repo.watchGroupHoldingIds(groupB).first, [h1]);
  });

  test('删分组：成员关联级联清理', () async {
    final h1 = await createHolding('000001', '基金A');
    final groupId = await repo.createGroup(ledgerId: 1, name: '组合A');
    await repo.addHoldingsToGroup(groupId, [h1]);

    await repo.deleteGroup(groupId);

    final rows =
        await db.customSelect('SELECT * FROM investment_group_holdings').get();
    expect(rows, isEmpty);
  });

  test('删持仓：成员关联级联清理', () async {
    final h1 = await createHolding('000001', '基金A');
    final groupId = await repo.createGroup(ledgerId: 1, name: '组合A');
    await repo.addHoldingsToGroup(groupId, [h1]);

    await (db.delete(db.investmentHoldings)..where((h) => h.id.equals(h1)))
        .go();

    final rows =
        await db.customSelect('SELECT * FROM investment_group_holdings').get();
    expect(rows, isEmpty);
  });
}
