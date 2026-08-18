// v41 迁移（7.17.1）：基金净值历史表 fund_nav_history。
// in-memory db 由 create_all 建出 v41 全 schema，验证表结构 + upsert 语义。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_investment_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;
  late LocalInvestmentRepository repo;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalInvestmentRepository(db);
  });

  tearDown(() async => db.close());

  Future<int> rowCount(String fundCode) async {
    final row = await db
        .customSelect(
          'SELECT COUNT(*) AS c FROM fund_nav_history WHERE fund_code = ?',
          variables: [Variable<String>(fundCode)],
        )
        .getSingle();
    return row.read<int>('c');
  }

  test('schemaVersion = 42', () {
    expect(db.schemaVersion, 42);
  });

  test('fund_nav_history 表存在且字段齐全', () async {
    final cols =
        await db.customSelect('PRAGMA table_info(fund_nav_history)').get();
    final names = cols.map((r) => r.read<String>('name')).toSet();
    expect(names, containsAll(['fund_code', 'nav_date', 'unit_nav', 'updated_at']));
  });

  test('净值历史按日期 upsert、查询降序且 limit 生效', () async {
    await repo.upsertNavHistory('000001', DateTime(2026, 8, 15), 1.0);
    await repo.upsertNavHistory('000001', DateTime(2026, 8, 16), 1.1);
    await repo.upsertNavHistory('000001', DateTime(2026, 8, 17), 1.2);
    await repo.upsertNavHistory('000001', DateTime(2026, 8, 18), 1.3);

    final history = await repo.getNavHistory('000001', limit: 3);
    expect(history.map((h) => h.navDate.day).toList(), [18, 17, 16]);
    expect(history.map((h) => h.unitNav).toList(), [1.3, 1.2, 1.1]);

    // 同日期再次写入覆盖，不新增行。
    await repo.upsertNavHistory('000001', DateTime(2026, 8, 17), 1.25);
    final updated = await repo.getNavHistory('000001', limit: 3);
    expect(updated.length, 3);
    expect(updated.firstWhere((h) => h.navDate.day == 17).unitNav, 1.25);
  });

  test('不同基金净值历史互相隔离', () async {
    await repo.upsertNavHistory('000001', DateTime(2026, 8, 18), 1.1);
    await repo.upsertNavHistory('000002', DateTime(2026, 8, 18), 2.2);

    final a = await repo.getNavHistory('000001', limit: 3);
    final b = await repo.getNavHistory('000002', limit: 3);
    expect(a.single.unitNav, 1.1);
    expect(b.single.unitNav, 2.2);
  });

  test('连续 upsert 超过 3 档后物理行数不超过 3', () async {
    for (var day = 10; day <= 15; day++) {
      await repo.upsertNavHistory(
        '000001',
        DateTime(2026, 8, day),
        day.toDouble(),
      );
    }

    expect(await rowCount('000001'), 3);
    final history = await repo.getNavHistory('000001', limit: 3);
    expect(history.map((h) => h.navDate.day).toList(), [15, 14, 13]);
  });

  test('同日期再次 upsert 只覆盖、不新增物理行', () async {
    await repo.upsertNavHistory('000001', DateTime(2026, 8, 15), 1.0);
    await repo.upsertNavHistory('000001', DateTime(2026, 8, 16), 1.1);
    await repo.upsertNavHistory('000001', DateTime(2026, 8, 16), 1.2);
    await repo.upsertNavHistory('000001', DateTime(2026, 8, 17), 1.3);

    expect(await rowCount('000001'), 3);
  });

  test('pruneAllNavHistories 清理存量超过 3 档的旧数据', () async {
    for (var day = 10; day <= 15; day++) {
      await db.into(db.fundNavHistories).insert(
            FundNavHistoriesCompanion.insert(
              fundCode: '000001',
              navDate: DateTime(2026, 8, day),
              unitNav: day.toDouble(),
              updatedAt: DateTime(2026, 8, day),
            ),
          );
    }
    for (var day = 10; day <= 12; day++) {
      await db.into(db.fundNavHistories).insert(
            FundNavHistoriesCompanion.insert(
              fundCode: '000002',
              navDate: DateTime(2026, 8, day),
              unitNav: day.toDouble(),
              updatedAt: DateTime(2026, 8, day),
            ),
          );
    }

    await repo.pruneAllNavHistories();

    expect(await rowCount('000001'), 3);
    expect(await rowCount('000002'), 3);
  });
}
