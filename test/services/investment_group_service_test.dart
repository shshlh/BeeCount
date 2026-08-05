import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_investment_repository.dart';
import 'package:beecount/services/data/investment_service.dart';

void main() {
  late BeeDatabase db;
  late LocalInvestmentRepository repo;
  late InvestmentService service;

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalInvestmentRepository(db);
    service = InvestmentService(repo);

    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, type, currency) "
        "VALUES (10, 1, '投资账户', 'investment', 'CNY')");
  });

  tearDown(() async => db.close());

  Future<int> createHolding(String code, String name) async {
    await service.buy(
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

  test('分组方法：创建/改名/成员/删除全链路', () async {
    final h1 = await createHolding('000001', '基金A');
    final h2 = await createHolding('000002', '基金B');
    final groupId = await service.createGroup(
      ledgerId: 1,
      name: '组合A',
      sortOrder: 3,
    );

    await service.addHoldingsToGroup(groupId, [h1, h2]);
    expect(await service.watchGroupHoldingIds(groupId).first, [h1, h2]);

    await service.renameGroup(groupId, '组合A改');
    final groups = await service.watchGroups(ledgerId: 1).first;
    expect(groups.single.name, '组合A改');

    await service.removeHoldingFromGroup(groupId, h1);
    expect(await service.watchGroupHoldingIds(groupId).first, [h2]);

    await service.setGroupMembers(groupId, [h1, h2]);
    expect(await service.watchGroupHoldingIds(groupId).first, [h1, h2]);

    await service.deleteGroup(groupId);
    expect(await service.watchGroups(ledgerId: 1).first, isEmpty);
  });
}
