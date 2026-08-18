import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/services/data/daily_return_calculator.dart';
import 'package:beecount/services/data/nav_fetch_service.dart';

void main() {
  List<FundNavQuote> history(List<double> navs) => [
        for (var i = 0; i < navs.length; i++)
          FundNavQuote(
            nav: navs[i],
            navDate: DateTime(2026, 8, 15 + i),
          ),
      ];

  test('三档净值计算今日/昨日收益与涨跌幅', () {
    final result = calculateDailyReturn(
      history: history([1.0, 1.1, 1.2]),
      shares: 100,
    );

    expect(result, isNotNull);
    expect(result!.todayProfit, closeTo(10, 0.001)); // (1.2-1.1)*100
    expect(result.yesterdayProfit, closeTo(10, 0.001)); // (1.1-1.0)*100
    expect(result.todayChangePct, closeTo(0.1 / 1.1, 0.0001));
    expect(result.yesterdayChangePct, closeTo(0.1, 0.0001));
  });

  test('下跌时收益与涨跌幅为负', () {
    final result = calculateDailyReturn(
      history: history([1.2, 1.1, 1.0]),
      shares: 50,
    );

    expect(result!.todayProfit, closeTo(-5, 0.001));
    expect(result.yesterdayProfit, closeTo(-5, 0.001));
    expect(result.todayChangePct, closeTo(-0.1 / 1.1, 0.0001));
    expect(result.yesterdayChangePct, closeTo(-0.1 / 1.2, 0.0001));
  });

  test('QDII 滞后场景：净值日期不连续仍按最新三档计算', () {
    final result = calculateDailyReturn(
      history: [
        FundNavQuote(nav: 1.0, navDate: DateTime(2026, 8, 13)),
        FundNavQuote(nav: 1.05, navDate: DateTime(2026, 8, 14)),
        FundNavQuote(nav: 1.08, navDate: DateTime(2026, 8, 17)),
      ],
      shares: 200,
    );

    expect(result!.todayProfit, closeTo(6, 0.001));
    expect(result.yesterdayProfit, closeTo(10, 0.001));
    expect(result.todayChangePct, closeTo(0.03 / 1.05, 0.0001));
  });

  test('历史不足三档或份额非法返回 null', () {
    expect(
      calculateDailyReturn(history: history([1.0, 1.1]), shares: 100),
      isNull,
    );
    expect(
      calculateDailyReturn(history: history([1.0, 1.1, 1.2]), shares: 0),
      isNull,
    );
  });

  test('货币基金识别：名称含「货币」或类型为 money', () {
    expect(isMoneyFund(fundName: '余额宝货币A'), isTrue);
    expect(isMoneyFund(fundName: '华夏成长混合'), isFalse);
    expect(isMoneyFund(fundName: '基金', holdingType: 'money'), isTrue);
    expect(isMoneyFund(fundName: '基金', holdingType: 'fund'), isFalse);
  });
}
