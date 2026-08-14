// 7.12.2 普通 CSV 账户类型恢复：解析器识别类型列，导入按类型建账户。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/services/data_import_service.dart';
import 'package:beecount/services/import/parsers/generic_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('通用解析器识别账户类型列', () {
    final mapping = GenericBillParser().mapColumns(const [
      '账户',
      '账户类型',
      '转出账户',
      '转出账户类型',
      '转入账户',
      '转入账户类型',
    ]);
    expect(mapping['account'], 0);
    expect(mapping['account_type'], 1);
    expect(mapping['from_account'], 2);
    expect(mapping['from_account_type'], 3);
    expect(mapping['to_account'], 4);
    expect(mapping['to_account_type'], 5);
  });

  test('导入账户保留非 cash 类型', () async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() => db.close());
    final repo = LocalRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");

    final nameToId = await DataImportService().importAccounts(
      repo,
      [
        const ImportAccount(name: '储蓄卡', type: 'bank_card'),
        const ImportAccount(name: '信用卡', type: 'credit_card'),
        const ImportAccount(name: '投资账户', type: 'investment'),
      ],
      ledgerId: 1,
    );

    expect(nameToId, hasLength(3));
    final byName = {
      for (final a in await repo.getAllAccounts()) a.name: a,
    };
    expect(byName['储蓄卡']!.type, 'bank_card');
    expect(byName['信用卡']!.type, 'credit_card');
    expect(byName['投资账户']!.type, 'investment');
  });
}
