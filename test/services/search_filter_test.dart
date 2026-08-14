// 7.13.2 搜索筛选纯逻辑：类型筛选 / 转账筛选 / 二级分类筛选。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/pages/transaction/search_page.dart';

Category cat({
  required int id,
  required String name,
  required String kind,
  int? parentId,
  int level = 1,
}) =>
    Category(
      id: id,
      name: name,
      kind: kind,
      sortOrder: 0,
      parentId: parentId,
      level: level,
      iconType: 'material',
    );

Transaction tx({required int id, required String type, int? categoryId}) =>
    Transaction(
      id: id,
      ledgerId: 1,
      type: type,
      amount: 10,
      categoryId: categoryId,
      happenedAt: DateTime(2026, 8, 1),
      excludeFromStats: false,
      excludeFromBudget: false,
    );

bool match({
  required Transaction transaction,
  Category? category,
  String? selectedType,
  Category? selectedCategory,
}) =>
    searchTransactionMatches(
      transaction: transaction,
      category: category,
      searchText: '',
      categoryDisplayName: (n) => n ?? '',
      selectedType: selectedType,
      selectedCategory: selectedCategory,
    );

void main() {
  test('类型筛选：收入/支出/转账按 type 匹配', () {
    final income = tx(id: 1, type: 'income');
    final expense = tx(id: 2, type: 'expense');
    final transfer = tx(id: 3, type: 'transfer');

    expect(match(transaction: income, selectedType: 'income'), isTrue);
    expect(match(transaction: expense, selectedType: 'income'), isFalse);
    expect(match(transaction: transfer, selectedType: 'transfer'), isTrue);
    expect(match(transaction: income, selectedType: 'transfer'), isFalse);
  });

  test('转账筛选：只命中 type == transfer', () {
    final transfer = tx(id: 3, type: 'transfer');
    final income = tx(id: 1, type: 'income');

    expect(match(transaction: transfer, selectedType: 'transfer'), isTrue);
    expect(match(transaction: income, selectedType: 'transfer'), isFalse);
  });

  test('二级分类筛选：选中一级分类包含子分类，选中二级分类精确匹配', () {
    final parent = cat(id: 10, name: '餐饮', kind: 'expense');
    final child = cat(id: 11, name: '外卖', kind: 'expense', parentId: 10, level: 2);

    final parentTx = tx(id: 1, type: 'expense', categoryId: 10);
    final childTx = tx(id: 2, type: 'expense', categoryId: 11);

    // 选中一级分类 → 一级与二级交易都命中
    expect(match(transaction: parentTx, category: parent, selectedCategory: parent), isTrue);
    expect(match(transaction: childTx, category: child, selectedCategory: parent), isTrue);

    // 选中二级分类 → 只命中该二级分类
    expect(match(transaction: childTx, category: child, selectedCategory: child), isTrue);
    expect(match(transaction: parentTx, category: parent, selectedCategory: child), isFalse);
  });
}
