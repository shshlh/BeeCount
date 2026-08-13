// 7.10.2 导出文件名前缀由 beecount_ 改为 jizhang_zhushou_。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/services/export/export_file_names.dart';

void main() {
  test('普通/投资/配置导出文件名使用 jizhang_zhushou_ 前缀', () {
    expect(normalCsvFileName('20260813_100000'),
        'jizhang_zhushou_20260813_100000.csv');
    expect(investmentCsvFileName('20260813_100000'),
        'jizhang_zhushou_investments_20260813_100000.csv');
    expect(configYamlFileName('2026-08-13T10-00-00'),
        'jizhang_zhushou_config_2026-08-13T10-00-00.yml');
  });
}
