import 'package:flutter_test/flutter_test.dart';
import 'package:decimal/decimal.dart';

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
    expect(result!.todayProfit, Decimal.parse('10')); // (1.2-1.1)*100
    expect(result.yesterdayProfit, Decimal.parse('10')); // (1.1-1.0)*100
    expect(result.todayChangePct.toStringAsFixed(10), '0.0909090909');
    expect(result.yesterdayChangePct, Decimal.parse('0.1'));
  });

  test('下跌时收益与涨跌幅为负', () {
    final result = calculateDailyReturn(
      history: history([1.2, 1.1, 1.0]),
      shares: 50,
    );

    expect(result!.todayProfit, Decimal.parse('-5'));
    expect(result.yesterdayProfit, Decimal.parse('-5'));
    expect(result.todayChangePct.toStringAsFixed(10), '-0.0909090909');
    expect(result.yesterdayChangePct.toStringAsFixed(10), '-0.0833333333');
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

    expect(result!.todayProfit, Decimal.parse('6'));
    expect(result.yesterdayProfit, Decimal.parse('10'));
    expect(result.todayChangePct.toStringAsFixed(10), '0.0285714286');
  });

  test('精度敏感：小数份额不引入浮点误差', () {
    final result = calculateDailyReturn(
      history: history([1.0, 1.1, 1.2]),
      shares: 0.1,
    );

    expect(result!.todayProfit, Decimal.parse('0.01'));
    expect(result.yesterdayProfit, Decimal.parse('0.01'));
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
