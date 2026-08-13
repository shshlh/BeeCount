// 7.10.1 默认收支账户偏好清理：账户随账本删除后，指向被删账户的偏好清空。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/services/account_default_prefs_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('只清空指向被删账户的默认收支偏好', () async {
    SharedPreferences.setMockInitialValues({
      'default_income_account_id': 1,
      'default_expense_account_id': 2,
    });

    final cleared =
        await AccountDefaultPrefsService().clearIfDeleted({1, 3});

    expect(cleared, contains(AccountDefaultPrefsService.incomeKey));
    expect(cleared, isNot(contains(AccountDefaultPrefsService.expenseKey)));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('default_income_account_id'), isNull);
    expect(prefs.getInt('default_expense_account_id'), 2);
  });

  test('被删账户集合为空时不改动偏好', () async {
    SharedPreferences.setMockInitialValues({
      'default_income_account_id': 1,
      'default_expense_account_id': 2,
    });

    final cleared = await AccountDefaultPrefsService().clearIfDeleted({});
    expect(cleared, isEmpty);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('default_income_account_id'), 1);
    expect(prefs.getInt('default_expense_account_id'), 2);
  });
}
