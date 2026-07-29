/// Excel (.xlsx) 导入服务
///
/// 提供将 .xlsx 文件字节转换为 CSV 文本的能力，作为 FileReaderService 的
/// xlsxConverter 参数使用。核心逻辑移植自 pj_003_账本app。
library;

import 'dart:typed_data';
import 'package:excel/excel.dart';

/// 将 Excel (.xlsx) 字节转换为 CSV 文本。
String convertXlsxToCsv(Uint8List bytes) {
  final excel = Excel.decodeBytes(bytes);
  final tableKey = excel.tables.keys.first;
  final sheet = excel.tables[tableKey]!;
  final buffer = StringBuffer();
  for (final excelRow in sheet.rows) {
    if (buffer.isNotEmpty) buffer.write('\n');
    final cells = excelRow.map<Data?>((data) => data).toList();
    buffer.write(cells.map((d) => _escapeCsvField(cellValueToString(d?.value))).join(','));
  }
  return buffer.toString();
}

/// Excel CellValue 转字符串
String cellValueToString(CellValue? cv) {
  if (cv == null) return '';
  return switch (cv) {
    IntCellValue v => v.value.toString(),
    DoubleCellValue v => fmtDouble(v.value),
    TextCellValue v => v.value.text ?? '',
    BoolCellValue v => v.value.toString(),
    DateCellValue v => v.value.toString(),
    _ => cv.toString(),
  };
}

/// 格式化数字
String fmtDouble(double d) {
  if (d == d.roundToDouble()) return d.toInt().toString();
  final s = d.toStringAsFixed(4);
  if (s.endsWith('0000')) return d.toStringAsFixed(0);
  return s.replaceFirst(RegExp(r'\.?0+$'), '');
}

String _escapeCsvField(String field) {
  if (field.contains(',') || field.contains('"') || field.contains('\n')) {
    return '"${field.replaceAll('"', '""')}"';
  }
  return field;
}
