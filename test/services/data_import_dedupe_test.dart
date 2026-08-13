// 7.9.4 重复导入同一份导出数据去重：普通 CSV 的「流水ID」= syncId，
// 导入时目标账本已存在相同 syncId 则跳过并统计 skipped。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/services/data_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;
  late LocalRepository repo;
  late DataImportService service;

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    service = DataImportService();
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    await db.customStatement(
        "INSERT INTO accounts (id, ledger_id, name, currency) "
        "VALUES (10, 1, '现金', 'CNY')");
  });

  tearDown(() async => db.close());

  Future<ImportResult> importOnce() {
    return service.importTransactions(
      repo,
      1,
      [
        ImportTransaction(
          type: 'expense',
          amount: 100,
          happenedAt: DateTime(2026, 8, 1),
          accountName: '现金',
          syncId: 'tx-1',
        ),
      ],
      accountNameToId: {'现金': 10},
      categoryCache: {},
      tagNameToId: {},
    );
  }

  test('同一 CSV（带流水ID）导入两次，第二次全部 skipped 不重复插入', () async {
    final first = await importOnce();
    expect(first.inserted, 1);
    expect(first.skipped, 0);

    final second = await importOnce();
    expect(second.inserted, 0);
    expect(second.skipped, 1);
    expect(second.failed, 0);

    final rows = await (db.select(db.transactions)
          ..where((t) => t.syncId.equals('tx-1')))
        .get();
    expect(rows, hasLength(1));
  });

  test('旧 CSV 无流水ID 时保持旧行为：不自动去重', () async {
    Future<ImportResult> importNoSyncId() {
      return service.importTransactions(
        repo,
        1,
        [
          ImportTransaction(
            type: 'expense',
            amount: 50,
            happenedAt: DateTime(2026, 8, 1),
            accountName: '现金',
          ),
        ],
        accountNameToId: {'现金': 10},
        categoryCache: {},
        tagNameToId: {},
      );
    }

    expect((await importNoSyncId()).inserted, 1);
    expect((await importNoSyncId()).inserted, 1);

    final count = await (db.select(db.transactions)).get();
    expect(count, hasLength(2));
  });
}
