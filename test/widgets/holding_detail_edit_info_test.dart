import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_investment_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/investment/holding_detail_page.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/services/data/investment_service.dart';

void main() {
  testWidgets('编辑基金信息入口 + 6 位代码校验', (tester) async {
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final spy = _SpyInvestmentService(LocalInvestmentRepository(db));

    final holding = InvestmentHolding(
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
      isQdii: false,
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          holdingProvider(1).overrideWith((ref) async => holding),
          holdingTransactionsProvider(1)
              .overrideWith((ref) => Stream.value(const <Transaction>[])),
          holdingReturnProvider(1).overrideWith(
            (ref) async =>
                const HoldingReturn(unrealizedPnL: 100, returnRate: 0.2),
          ),
          holdingDailyReturnProvider(1).overrideWith((ref) async => null),
          investmentServiceProvider.overrideWithValue(spy),
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

    await tester.tap(find.byTooltip('编辑基金信息'));
    await tester.pumpAndSettle();
    expect(find.text('编辑基金信息'), findsOneWidget);
    expect(find.text('QDII 基金'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), '11017');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.text('基金代码必须为6位数字'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), '110017');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(spy.updateCalls, 1);
    expect(find.text('编辑基金信息'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}

class _SpyInvestmentService extends InvestmentService {
  int updateCalls = 0;

  _SpyInvestmentService(super.repo);

  @override
  Future<void> updateHoldingInfo(
    int holdingId, {
    required String fundCode,
    String? fundName,
    bool isQdii = false,
  }) async {
    updateCalls++;
  }
}
