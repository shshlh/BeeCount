/// v5.0 记账页重构：顶部返回 + 标题「记一笔」+ 三 Tab；支出表单为
/// 分类/账户/时间/备注四行 + 底部金额栏；转账 Tab 继续走 TransferForm。
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/transaction/transaction_editor_page.dart';
import 'package:beecount/providers.dart';

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
    await repo.createAccount(
      ledgerId: ledgerId,
      name: '钱包A',
      type: 'cash',
      initialBalance: 12345.67,
    );
    await repo.createAccount(
      ledgerId: ledgerId,
      name: '招行信用卡',
      type: 'credit_card',
      initialBalance: -800,
      creditLimit: 50000,
    );
  });

  tearDown(() async => db.close());

  Widget wrap() {
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
        home: const TransactionEditorPage(initialKind: 'expense'),
      ),
    );
  }

  testWidgets('支出页显示金额-分类-账户-时间-标签-备注,无取消按钮',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('记一笔'), findsOneWidget);
    expect(find.text('金额'), findsOneWidget);
    expect(find.text('分类'), findsOneWidget);
    expect(find.text('账户'), findsOneWidget);
    expect(find.text('时间'), findsOneWidget);
    expect(find.text('标签'), findsOneWidget);
    expect(find.text('备注'), findsOneWidget);
    expect(find.text('¥ 0.00'), findsOneWidget);
    // 备注行内填写：直接是 TextField，不再弹 AlertDialog
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('取消'), findsNothing);
  });

  testWidgets('转账 Tab 仍加载 TransferForm 账户网格', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('转账'));
    await tester.pumpAndSettle();

    expect(find.text('钱包A'), findsNWidgets(2));
    expect(find.text('招行信用卡'), findsNWidgets(2));
  });

  testWidgets('账户抽屉:一户一行显示余额,信用卡显示已用额度', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('账户'));
    await tester.pumpAndSettle();

    expect(find.text('钱包A'), findsOneWidget);
    expect(find.textContaining('12,345.67'), findsOneWidget);

    await tester.tap(find.text('信用卡'));
    await tester.pumpAndSettle();

    expect(find.text('招行信用卡'), findsOneWidget);
    expect(find.textContaining('已用额度'), findsOneWidget);
    expect(find.textContaining('50,000'), findsOneWidget);
  });
}
