/// v5.3 日期显示周几：今天 / 周几自动计算，可追加 HH:mm
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/utils/tx_date_format.dart';

void main() {
  Widget host(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: Scaffold(body: child),
    );
  }

  testWidgets('非今天显示自动周几', (tester) async {
    String? result;
    await tester.pumpWidget(host(Builder(
      builder: (context) {
        result = formatEntryDateTime(
          context,
          DateTime(2026, 8, 1, 15, 30),
          showTime: false,
        );
        return const SizedBox.shrink();
      },
    )));
    expect(result, '2026年8月1日 周六');
  });

  testWidgets('今天显示「今天」,开启时间追加 HH:mm', (tester) async {
    String? result;
    final now = DateTime.now();
    await tester.pumpWidget(host(Builder(
      builder: (context) {
        result = formatEntryDateTime(
          context,
          DateTime(now.year, now.month, now.day, 9, 5),
          showTime: true,
        );
        return const SizedBox.shrink();
      },
    )));
    expect(result, contains('今天'));
    expect(result, endsWith(' 09:05'));
  });
}
