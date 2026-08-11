import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_investment_repository.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/investment/holding_detail_page.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/services/data/investment_service.dart';

void main() {
  late BeeDatabase db;
  late _SpyRepository repo;
  late _SpyService service;
  late InvestmentHolding holding;
  late Transaction tx;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = _SpyRepository(db);
    service = _SpyService(LocalInvestmentRepository(db));
    holding = InvestmentHolding(
      id: 1,
      ledgerId: 1,
      fundCode: '110017',
      fundName: '基金A',
      accountId: 10,
      totalShares: 500,
      totalCost: 500,
      currentNav: 1.0,
      marketValue: 500,
      holdingType: 'fund',
      createdAt: DateTime(2026),
    );
    tx = Transaction(
      id: 1,
      ledgerId: 1,
      type: 'transfer',
      amount: 0,
      happenedAt: DateTime(2026, 8, 8),
      excludeFromStats: false,
      excludeFromBudget: true,
      investType: 'initial',
      investShares: 500,
      investNav: 1.0,
      investFee: 0,
      holdingId: 1,
    );
  });

  tearDown(() async => db.close());

  Widget host() {
    return ProviderScope(
      overrides: [
        holdingProvider(1).overrideWith((ref) async => holding),
        holdingTransactionsProvider(1)
            .overrideWith((ref) => Stream.value([tx])),
        holdingReturnProvider(1).overrideWith(
          (ref) async => const HoldingReturn(unrealizedPnL: 0, returnRate: 0),
        ),
        repositoryProvider.overrideWithValue(repo),
        investmentServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: const HoldingDetailPage(holdingId: 1),
      ),
    );
  }

  testWidgets('删除单笔流水需确认并调用仓库', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('删除流水'));
    await tester.pumpAndSettle();
    expect(find.text('删除流水'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(repo.deleteTransactionCalls, 1);
  });

  testWidgets('删除整个持仓需确认并调用服务', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('删除持仓'));
    await tester.pumpAndSettle();
    expect(find.text('删除持仓'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(service.deleteHoldingCalls, 1);
  });

  testWidgets('转换批次流水删除整批并调用服务', (tester) async {
    final batchTx = Transaction(
      id: 2,
      ledgerId: 1,
      type: 'transfer',
      amount: 0,
      happenedAt: DateTime(2026, 8, 8),
      excludeFromStats: false,
      excludeFromBudget: true,
      investType: 'buy',
      investShares: 100,
      investNav: 1.0,
      investFee: 0,
      holdingId: 1,
      batchId: 'batch-1',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          holdingProvider(1).overrideWith((ref) async => holding),
          holdingTransactionsProvider(1)
              .overrideWith((ref) => Stream.value([batchTx])),
          holdingReturnProvider(1).overrideWith(
            (ref) async => const HoldingReturn(unrealizedPnL: 0, returnRate: 0),
          ),
          repositoryProvider.overrideWithValue(repo),
          investmentServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const HoldingDetailPage(holdingId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('删除流水'));
    await tester.pumpAndSettle();

    expect(find.text('删除转换记录'), findsOneWidget);
    expect(find.textContaining('删除完整的转换记录'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(service.deleteConversionCalls, 1);
    expect(repo.deleteTransactionCalls, 0);
  });
}

class _SpyRepository extends LocalRepository {
  int deleteTransactionCalls = 0;

  _SpyRepository(super.db);

  @override
  Future<void> deleteTransaction(int id) async {
    deleteTransactionCalls++;
  }
}

class _SpyService extends InvestmentService {
  int deleteHoldingCalls = 0;
  int deleteConversionCalls = 0;

  _SpyService(super.repo);

  @override
  Future<void> deleteHolding(int holdingId) async {
    deleteHoldingCalls++;
  }

  @override
  Future<void> deleteConversion(String batchId) async {
    deleteConversionCalls++;
  }
}
