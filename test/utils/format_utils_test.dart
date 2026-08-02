/// v5.3 资产金额精度：净值 4 位、市值/成本 2 位、不做万/k/M 缩写
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/utils/format_utils.dart';

void main() {
  test('formatFullAmount: 千分号 + 固定 2 位小数', () {
    expect(formatFullAmount(12345.678), '12,345.68');
    expect(formatFullAmount(12345), '12,345.00');
    expect(formatFullAmount(0), '0.00');
    expect(formatFullAmount(-1234.5), '-1,234.50');
  });

  test('formatFullAmount: 净值 4 位小数', () {
    expect(formatFullAmount(1.23456, decimals: 4), '1.2346');
    expect(formatFullAmount(1.0, decimals: 4), '1.0000');
  });

  test('formatFullAmount: 大金额不使用万/k/M 缩写', () {
    expect(formatFullAmount(123456789), '123,456,789.00');
    expect(formatFullAmount(123456789).contains('万'), isFalse);
    expect(formatFullAmount(123456789).contains('k'), isFalse);
    expect(formatFullAmount(123456789).contains('M'), isFalse);
  });
}
