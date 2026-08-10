// 7.5.1 同名不同币种账户契约回归。
//
// 锁死:accounts.name 全局唯一(与币种无关),createAccount 撞同名一律抛
// DuplicateNameException;静默路径(import / app-link)走 upsertAccount 复用,
// 不抛异常。
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/exceptions.dart';
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

  test('同名不同币种 createAccount 仍抛 DuplicateNameException', () async {
    final lid = await repo.createLedger(name: 'L');
    await repo.createAccount(ledgerId: lid, name: '支付宝', currency: 'CNY');

    await expectLater(
      repo.createAccount(ledgerId: lid, name: '支付宝', currency: 'USD'),
      throwsA(isA<DuplicateNameException>()),
    );
  });

  test('upsertAccount 同名不同币种仍复用已有账户(静默路径不变)', () async {
    final lid = await repo.createLedger(name: 'L');
    final cnyId = await repo.createAccount(
      ledgerId: lid,
      name: '支付宝',
      currency: 'CNY',
    );

    final reusedId = await repo.upsertAccount(
      name: '支付宝',
      ledgerId: lid,
      currency: 'USD',
    );

    expect(reusedId, cnyId);
    final accounts = await repo.getAllAccounts();
    expect(accounts.length, 1);
    expect(accounts.single.currency, 'CNY');
  });
}
