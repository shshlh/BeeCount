import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:decimal/decimal.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/services/data/daily_return_calculator.dart';
import 'package:beecount/widgets/investment/holding_card.dart';

void main() {
  InvestmentHolding buildHolding() => InvestmentHolding(
        id: 1,
        ledgerId: 1,
        fundCode: '000001',
        fundName: '基金A',
        accountId: 10,
        totalShares: 100,
        totalCost: 100,
        currentNav: 1.1,
        marketValue: 110,
        holdingType: 'fund',
      isQdii: false,
        createdAt: DateTime(2026),
      );

  Widget host(HoldingCard card) => ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: card),
        ),
      );

  testWidgets('有日收益数据时展示今日/昨日收益与涨跌幅', (tester) async {
    await tester.pumpWidget(
      host(
        HoldingCard(
          holding: buildHolding(),
          dailyReturn: DailyReturnSnapshot(
            todayProfit: Decimal.fromInt(10),
            yesterdayProfit: Decimal.fromInt(-5),
            todayChangePct: Decimal.parse('0.09'),
            yesterdayChangePct: Decimal.parse('-0.05'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('今日收益'), findsOneWidget);
    expect(find.textContaining('昨日收益'), findsOneWidget);
    expect(find.text('+10.00'), findsOneWidget);
    expect(find.text('-5.00'), findsOneWidget);
    expect(find.text('+9.00%'), findsOneWidget);
    expect(find.text('-5.00%'), findsOneWidget);
  });

  testWidgets('货币基金收益/涨跌幅显示 --', (tester) async {
    await tester.pumpWidget(
      host(
        HoldingCard(
          holding: buildHolding(),
          dailyReturn: DailyReturnSnapshot.notApplicable,
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('今日收益'), findsOneWidget);
    expect(find.textContaining('今日涨跌'), findsOneWidget);
    expect(find.text('--'), findsNWidgets(4));
  });

  testWidgets('今日未更新时今日/昨日收益显示 --（7.19.3）', (tester) async {
    await tester.pumpWidget(
      host(
        HoldingCard(
          holding: buildHolding(),
          dailyReturn: const DailyReturnSnapshot(
            todayProfit: null,
            yesterdayProfit: null,
            todayChangePct: null,
            yesterdayChangePct: null,
            todayUpdated: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('今日收益'), findsOneWidget);
    expect(find.text('--'), findsNWidgets(4));
  });
}
