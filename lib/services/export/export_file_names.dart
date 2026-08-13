/// 导出文件命名（7.10.2：项目前缀由 beecount_ 改为 jizhang_zhushou_）。
String normalCsvFileName(String ts) => 'jizhang_zhushou_$ts.csv';

String investmentCsvFileName(String ts) =>
    'jizhang_zhushou_investments_$ts.csv';

String configYamlFileName(String ts) => 'jizhang_zhushou_config_$ts.yml';
