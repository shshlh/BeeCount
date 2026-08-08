/// v6.10 洞察页排行金额精度：一级/二级分类金额显示 2 位小数
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/widgets/analytics/category_rank_row.dart';
import 'package:beecount/widgets/biz/amount_text.dart';

void main() {
  testWidgets('排行金额 2 位小数、百分比 1 位不变', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: CategoryRankRow(
              categoryId: 1,
              name: '餐饮',
              value: 1234.56,
              percent: 0.5,
              color: Colors.orange,
              start: DateTime(2026, 8, 1),
              end: DateTime(2026, 9, 1),
              scope: 'month',
              selMonth: DateTime(2026, 8, 1),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final amountTexts = tester.widgetList<AmountText>(find.byType(AmountText));
    expect(amountTexts.length, 1);
    expect(amountTexts.single.decimals, 2);
    expect(find.text('50.0%'), findsOneWidget);
  });
}
