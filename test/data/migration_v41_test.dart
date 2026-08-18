// v41 迁移（7.17.1）：基金净值历史表 fund_nav_history。
// in-memory db 由 create_all 建出 v41 全 schema，验证表结构 + upsert 语义。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
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

  test('schemaVersion = 41', () {
    expect(db.schemaVersion, 41);
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
}
