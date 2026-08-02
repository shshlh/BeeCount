/// v5.0 账户放开：支出/收入/转账选择器允许债权(receivable)与负债(loan)
/// 账户，投资(investment)账户仍不可选；隐藏账户继续被过滤。
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/widgets/biz/account_picker.dart';
import 'package:beecount/widgets/biz/account_selector.dart';
import 'package:beecount/widgets/transaction/transfer_form.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;
  late LocalRepository repo;
  late Ledger ledger;
  late List<Account> accounts;

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
    await repo.createAccount(ledgerId: ledgerId, name: '现金', type: 'cash');
    await repo.createAccount(
      ledgerId: ledgerId,
      name: '借出款',
      type: 'receivable',
    );
    await repo.createAccount(ledgerId: ledgerId, name: '房贷', type: 'loan');
    await repo.createAccount(
      ledgerId: ledgerId,
      name: '基金账户',
      type: 'investment',
    );
    final hiddenId =
        await repo.createAccount(ledgerId: ledgerId, name: '隐藏账户');
    await repo.setAccountHidden(hiddenId, true);
    accounts = await repo.getAllAccounts();
  });

  tearDown(() async => db.close());

  Widget wrap(Widget child, {bool overrideAccountsStream = false}) {
    return ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        currentLedgerProvider
            .overrideWith((ref) => Stream<Ledger?>.value(ledger)),
        if (overrideAccountsStream)
          allAccountsStreamProvider.overrideWith(
            (ref) => Stream<List<Account>>.value(accounts),
          ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('AccountSelector: 应收款/贷款可选,投资不可选,隐藏被过滤',
      (tester) async {
    await tester.pumpWidget(wrap(AccountSelector(
      selectedAccountId: null,
      onAccountSelected: (_) {},
      ledgerId: ledger.id,
    )));
    await tester.pumpAndSettle();

    expect(find.text('现金'), findsOneWidget);
    expect(find.text('借出款'), findsOneWidget);
    expect(find.text('房贷'), findsOneWidget);
    expect(find.text('基金账户'), findsNothing);
    expect(find.text('隐藏账户'), findsNothing);

    // AccountSelector 内部 logger.debug 会挂 2 秒节流定时器,推进时间让其
    // 触发,避免 testWidgets 结束时判定 timersPending
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
  });

  testWidgets('AccountPicker: 应收款/贷款可选,投资不可选', (tester) async {
    await tester.pumpWidget(
        wrap(const AccountPicker(selectedAccountId: null),
            overrideAccountsStream: true));
    await tester.pumpAndSettle();

    // CupertinoPicker 只构建可视区域内的选项,滚一下让应收款/贷款进入视口
    await tester.drag(find.byType(CupertinoPicker), const Offset(0, -80));
    // 滚轮惯性动画不保证收敛,用固定步进推进而非 pumpAndSettle
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('借出款'), findsWidgets);
    expect(find.text('房贷'), findsWidgets);
    expect(find.text('基金账户'), findsNothing);
    expect(find.text('隐藏账户'), findsNothing);
  });

  testWidgets('TransferForm: 抽屉分格出现债权/负债类型,投资与隐藏不可选',
      (tester) async {
    await tester.pumpWidget(wrap(TransferForm(onTransferComplete: () {})));
    await tester.pumpAndSettle();

    // 点击账户行打开转出抽屉
    await tester.tap(find.text('账户'));
    await tester.pumpAndSettle();
    expect(find.text('转出账户'), findsOneWidget);

    // 左侧类型导航包含债权/负债（应收款/贷款类型已放开）
    expect(find.text('应收款'), findsOneWidget);
    expect(find.text('贷款'), findsOneWidget);

    // 切换到债权类型 → 借出款可见
    await tester.tap(find.text('应收款'));
    await tester.pumpAndSettle();
    expect(find.text('借出款'), findsOneWidget);

    // 切换到负债类型 → 房贷可见
    await tester.tap(find.text('贷款'));
    await tester.pumpAndSettle();
    expect(find.text('房贷'), findsOneWidget);

    // 投资/隐藏账户始终不可选
    expect(find.text('基金账户'), findsNothing);
    expect(find.text('隐藏账户'), findsNothing);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
  });
}
