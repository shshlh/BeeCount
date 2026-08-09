/// 7.4.1 账户备注修复：clearMetadataFields 不再清备注；新增 clearNote 清空。
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
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

  test('非卡账户编辑后 clearMetadataFields 不再清备注', () async {
    final lid = await repo.createLedger(name: 'L');
    final aid = await repo.createAccount(
      ledgerId: lid,
      name: '现金',
      type: 'cash',
      note: '备用金',
    );

    await repo.updateAccount(aid, clearMetadataFields: true);

    final a = await repo.getAccount(aid);
    expect(a!.note, '备用金');
  });

  test('clearNote 清空备注写 NULL', () async {
    final lid = await repo.createLedger(name: 'L');
    final aid = await repo.createAccount(
      ledgerId: lid,
      name: '现金',
      type: 'cash',
      note: '旧备注',
    );

    await repo.updateAccount(aid, clearNote: true);

    final a = await repo.getAccount(aid);
    expect(a!.note, isNull);
  });

  test('非卡账户 clearMetadataFields + clearNote 同时传时清空生效', () async {
    final lid = await repo.createLedger(name: 'L');
    final aid = await repo.createAccount(
      ledgerId: lid,
      name: '现金',
      type: 'cash',
      note: '旧备注',
    );

    await repo.updateAccount(aid, clearMetadataFields: true, clearNote: true);

    final a = await repo.getAccount(aid);
    expect(a!.note, isNull);
  });

  test('银行卡编辑备注正常保存且元信息保留', () async {
    final lid = await repo.createLedger(name: 'L');
    final aid = await repo.createAccount(
      ledgerId: lid,
      name: '招行',
      type: 'bank',
      bankName: '招商银行',
      cardLastFour: '1234',
      note: '旧备注',
    );

    await repo.updateAccount(aid, note: '新备注');

    final a = await repo.getAccount(aid);
    expect(a!.note, '新备注');
    expect(a.bankName, '招商银行');
    expect(a.cardLastFour, '1234');
  });

  test('不传 note / clearNote 时不更新备注', () async {
    final lid = await repo.createLedger(name: 'L');
    final aid = await repo.createAccount(
      ledgerId: lid,
      name: '现金',
      type: 'cash',
      note: '原备注',
    );

    await repo.updateAccount(aid, name: '改名');

    final a = await repo.getAccount(aid);
    expect(a!.name, '改名');
    expect(a.note, '原备注');
  });
}
