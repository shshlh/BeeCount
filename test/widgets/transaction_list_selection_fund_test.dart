// 7.9.2 明细页多选批量删除 + 7.9.5 投资流水显示基金代码/名称小标签。
// 直接驱动 TransactionList 组件，用假仓库避免真实 Drift 流在 widget 测试
// 中阻塞 pump。
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/investment_repository.dart';
import 'package:beecount/data/repositories/local/local_investment_repository.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/widgets/biz/transaction_list.dart';
import 'package:beecount/widgets/biz/transaction_list_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;
  late _FakeTxRepo repo;
  late _FakeInvestmentRepo investmentRepo;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = _FakeTxRepo(db);
    investmentRepo = _FakeInvestmentRepo(db);
  });

  tearDown(() async => db.close());

  ({Transaction t, Category? category, Account? account, Account? toAccount})
      txRow(int id, String type, double amount, DateTime happenedAt,
          String? note,
          {String? investType, int? holdingId}) {
    return (
      t: Transaction(
        id: id,
        ledgerId: 1,
        type: type,
        amount: amount,
        happenedAt: happenedAt,
        note: note,
        excludeFromStats: false,
        excludeFromBudget: false,
        investType: investType,
        holdingId: holdingId,
      ),
      category: null,
      account: null,
      toAccount: null,
    );
  }

  Future<void> pumpList(
    WidgetTester tester,
    List<({Transaction t, Category? category, Account? account, Account? toAccount})>
        transactions,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          investmentRepositoryProvider.overrideWithValue(investmentRepo),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: TransactionList(
              transactions: transactions,
              hideAmounts: false,
              enableSelection: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('投资流水行显示基金代码/名称且备注不被覆盖', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentLedgerProvider
              .overrideWith((ref) => Stream<Ledger?>.value(null)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: TransactionListItem(
              icon: Icons.trending_up,
              title: '买入备注',
              categoryName: '投资',
              amount: 1000,
              isExpense: false,
              isTransfer: true,
              accountName: '钱包 → 投资账户',
              fundLabel: '000001 基金A',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('000001 基金A'), findsOneWidget);
    expect(find.textContaining('买入备注'), findsOneWidget);
  });

  testWidgets('多选模式可全选/批量删除并退出选择状态（7.9.2）', (tester) async {
    await pumpList(tester, [
      txRow(1, 'transfer', 1000, DateTime(2026, 8, 1), '买入备注',
          investType: 'buy', holdingId: 1),
      txRow(2, 'transfer', 600, DateTime(2026, 8, 2), '卖出备注',
          investType: 'sell', holdingId: 1),
    ]);

    final state = tester.state<TransactionListState>(
        find.byType(TransactionList));
    state.enterSelectionMode();
    await tester.pumpAndSettle();

    // FlutterListView 在 widget 测试中懒加载不构建行，但底部批量操作栏
    // 独立于列表渲染，选择逻辑仍走真实的 _transactionsList。
    expect(find.text('全选'), findsOneWidget);
    await tester.tap(find.text('全选'));
    await tester.pumpAndSettle();
    expect(find.text('已选 2 条'), findsOneWidget);

    await tester.tap(find.text('删除 (2)'));
    await tester.pumpAndSettle();
    expect(find.text('确定删除选中的 2 条流水吗？此操作不可恢复。'), findsOneWidget);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    // 确认后退出多选模式（假仓库不实际删行，这里只验证 UI 流程）。
    expect(state.isSelectionMode, isFalse);
    expect(find.text('全选'), findsNothing);
    // 冲掉 toast / 同步触发的 pending Timer，避免测试结束断言失败。
    await tester.pump(const Duration(seconds: 3));
  });
}

class _FakeTxRepo extends LocalRepository {
  _FakeTxRepo(super.db);

  @override
  Future<int> deleteTransactionsBatchByIds(List<int> ids) async => 0;
}

class _FakeInvestmentRepo extends LocalInvestmentRepository
    implements InvestmentRepository {
  _FakeInvestmentRepo(super.db);

  @override
  Future<List<InvestmentHolding>> getHoldingsForLedger(int ledgerId) async {
    return [
      InvestmentHolding(
        id: 1,
        ledgerId: 1,
        fundCode: '000001',
        fundName: '基金A',
        accountId: 10,
        totalShares: 100,
        totalCost: 100,
        currentNav: 1.2345,
        marketValue: 123.45,
        holdingType: 'fund',
      isQdii: false,
        createdAt: DateTime(2026),
      ),
    ];
  }
}
