// Excel 导入服务测试
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/services/import/excel_import_service.dart';

void main() {
  group('convertXlsxToCsv', () {
    test('空表格返回空字符串', () {
      final excel = Excel.createExcel();
      excel.rename(excel.tables.keys.first, 'Sheet1');
      final bytes = Uint8List.fromList(excel.encode()!);
      final csv = convertXlsxToCsv(bytes);
      expect(csv, '');
    });

    test('多行多列 CSV 格式正确', () {
      final excel = Excel.createExcel();
      final sheet = excel[excel.tables.keys.first];
      sheet.appendRow([TextCellValue('日期'), TextCellValue('金额'), TextCellValue('分类')]);
      sheet.appendRow([TextCellValue('2026-01-01'), DoubleCellValue(100.5), TextCellValue('餐饮')]);
      sheet.appendRow([TextCellValue('2026-01-02'), DoubleCellValue(200), TextCellValue('交通')]);
      final bytes = Uint8List.fromList(excel.encode()!);
      final csv = convertXlsxToCsv(bytes);
      final lines = csv.split('\n');
      expect(lines.length, 3);
      expect(lines[0], '日期,金额,分类');
      expect(lines[1], '2026-01-01,100.5,餐饮');
      expect(lines[2], '2026-01-02,200,交通');
    });

    test('包含逗号的字段正确转义', () {
      final excel = Excel.createExcel();
      final sheet = excel[excel.tables.keys.first];
      sheet.appendRow([TextCellValue('备注,附带逗号')]);
      final bytes = Uint8List.fromList(excel.encode()!);
      final csv = convertXlsxToCsv(bytes);
      expect(csv, '"备注,附带逗号"');
    });

    test('包含引号的字段正确转义', () {
      final excel = Excel.createExcel();
      final sheet = excel[excel.tables.keys.first];
      sheet.appendRow([TextCellValue('说"你好"')]);
      final bytes = Uint8List.fromList(excel.encode()!);
      final csv = convertXlsxToCsv(bytes);
      expect(csv, '"说""你好"""');
    });
  });

  group('cellValueToString', () {
    test('null 返回空字符串', () {
      expect(cellValueToString(null), '');
    });
    test('IntCellValue 转换', () {
      expect(cellValueToString(IntCellValue(42)), '42');
      expect(cellValueToString(IntCellValue(-1)), '-1');
    });
    test('DoubleCellValue 转换', () {
      expect(cellValueToString(DoubleCellValue(100.5)), '100.5');
      expect(cellValueToString(DoubleCellValue(200.0)), '200');
    });
    test('TextCellValue 转换', () {
      expect(cellValueToString(TextCellValue('hello')), 'hello');
    });
    test('BoolCellValue 转换', () {
      expect(cellValueToString(BoolCellValue(true)), 'true');
    });
    test('DateTimeCellValue 转换', () {
      final dt = DateTimeCellValue(year: 2026, month: 1, day: 15, hour: 0, minute: 0, second: 0);
      expect(cellValueToString(dt), '2026-01-15');
    });
  });
}
