/// 账户隐藏(#240)E1 钉住 —— v5.2 转账抽屉分格后的等价验证:
///   - 编辑历史转账(有 editingTransactionId)时,转出/转入抽屉会钉住
///     已被隐藏的账户并打「已隐藏」灰标,让用户能原样保存
///   - 新建转账不钉住,隐藏账户不出现
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/widgets/transaction/transfer_form.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;
  late LocalRepository repo;
  late Ledger ledger;

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    final ledgerId = await repo.createLedger(name: 'L', currency: 'CNY');
    ledger = Ledger(
      id: ledgerId,
      name: 'L',
      currency: 'CNY',
      type: 'personal',
      createdAt: DateTime(2026, 1, 1),
      myRole: 'owner',
      memberCount: 1,
      isShared: false,
      monthStartDay: 1,
    );
    await repo.createAccount(ledgerId: ledgerId, name: '现金');
    final hiddenId = await repo.createAccount(ledgerId: ledgerId, name: '旧钱包');
    await repo.setAccountHidden(hiddenId, true);
  });

  tearDown(() async => db.close());

  Widget host({
    int? editingTransactionId,
    int? initialFromAccountId,
    int? initialToAccountId,
  }) {
    return ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        currentLedgerProvider
            .overrideWith((ref) => Stream<Ledger?>.value(ledger)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: TransferForm(
            onTransferComplete: () {},
            editingTransactionId: editingTransactionId,
            initialFromAccountId: initialFromAccountId,
            initialToAccountId: initialToAccountId,
          ),
        ),
      ),
    );
  }

  Future<void> closeDrawer(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
  }

  testWidgets('编辑历史转账:两端已选,抽屉分格钉住隐藏账户 + 灰标',
      (tester) async {
    // 旧钱包(id=2)已隐藏;编辑态转出=旧钱包,转入=现金
    await tester.pumpWidget(host(
      editingTransactionId: 999,
      initialFromAccountId: 2,
      initialToAccountId: 1,
    ));
    await tester.pumpAndSettle();

    // 账户行两格回显：转出 / 转入 + 反转按钮
    expect(find.text('旧钱包'), findsOneWidget);
    expect(find.text('现金'), findsOneWidget);
    expect(find.text('转出'), findsOneWidget);
    expect(find.text('转入'), findsOneWidget);
    expect(find.byIcon(Icons.swap_horiz), findsOneWidget);

    // 点转出格 → 转出抽屉钉住隐藏的旧钱包并打灰标
    await tester.tap(find.text('转出'));
    await tester.pumpAndSettle();
    expect(find.text('转出账户'), findsOneWidget);
    // 表单账户行 + 抽屉内各出现一次
    expect(find.text('旧钱包'), findsNWidgets(2));
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    await closeDrawer(tester);
  });

  testWidgets('编辑历史转账:只设转出,直接进入转入抽屉不出现隐藏账户',
      (tester) async {
    await tester.pumpWidget(host(
      editingTransactionId: 999,
      initialFromAccountId: 1, // 现金
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('转入'));
    await tester.pumpAndSettle();

    // 转出已选 → 直接是转入抽屉;隐藏的旧钱包不出现
    expect(find.text('转入账户'), findsOneWidget);
    expect(find.text('旧钱包'), findsNothing);
    await closeDrawer(tester);
  });

  testWidgets('新建转账:转出抽屉不出现隐藏账户', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('转出'));
    await tester.pumpAndSettle();

    expect(find.text('转出账户'), findsOneWidget);
    expect(find.text('旧钱包'), findsNothing);
    expect(find.byIcon(Icons.visibility_off), findsNothing);
    await closeDrawer(tester);
  });
}
