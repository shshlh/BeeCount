/// v5.5 日期选择器：年份范围 = 今年 ±30，月份 1-12，日期格显示周几/今天
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/widgets/ui/wheel_date_picker.dart';

void main() {
  Widget host(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: Scaffold(body: child),
    );
  }

  String textOf(Widget w) {
    if (w is Text) return w.data ?? '';
    if (w is Center) return textOf(w.child ?? const SizedBox.shrink());
    if (w is Padding) return textOf(w.child ?? const SizedBox.shrink());
    return '';
  }

  List<String> pickerTexts(WidgetTester tester, int index) {
    final pickers = tester
        .widgetList<CupertinoPicker>(find.byType(CupertinoPicker))
        .toList();
    final delegate =
        pickers[index].childDelegate as ListWheelChildListDelegate;
    return delegate.children.map(textOf).toList();
  }

  testWidgets('年份范围 = 今年 ±30,月份 1-12', (tester) async {
    await tester.pumpWidget(host(WheelDatePicker(
      key: UniqueKey(),
      initial: DateTime(2026, 8, 1),
    )));
    await tester.pumpAndSettle();

    final years = pickerTexts(tester, 0);
    expect(years.first, '1996');
    expect(years.last, '2056');
    final months = pickerTexts(tester, 1);
    expect(months.first, '1');
    expect(months.last, '12');
  });

  testWidgets('日期格显示周几,今天显示「今天」', (tester) async {
    await tester.pumpWidget(host(WheelDatePicker(
      key: UniqueKey(),
      initial: DateTime(2026, 8, 1), // 周六
    )));
    await tester.pumpAndSettle();

    final days = pickerTexts(tester, 2);
    expect(days, contains('8月1日 周六'));

    final now = DateTime.now();
    await tester.pumpWidget(host(WheelDatePicker(
      key: UniqueKey(),
      initial: DateTime(now.year, now.month, now.day),
    )));
    await tester.pumpAndSettle();
    final todayDays = pickerTexts(tester, 2);
    expect(todayDays, contains('${now.month}月${now.day}日 今天'));
  });
}
