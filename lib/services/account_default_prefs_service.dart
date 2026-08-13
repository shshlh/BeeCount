import 'package:shared_preferences/shared_preferences.dart';

/// 默认收支账户偏好清理（7.10.1）。
///
/// 账户强绑定账本后，删除/清空/初始化账本会级联删除账户；若 SharedPreferences
/// 中的默认收入/支出账户指向被删账户，需要同步清空，否则记账页会落到无效 ID。
class AccountDefaultPrefsService {
  static const incomeKey = 'default_income_account_id';
  static const expenseKey = 'default_expense_account_id';

  /// 清空指向 [deletedAccountIds] 的默认账户偏好，返回被清空的键。
  Future<Set<String>> clearIfDeleted(Set<int> deletedAccountIds) async {
    final cleared = <String>{};
    if (deletedAccountIds.isEmpty) return cleared;

    final prefs = await SharedPreferences.getInstance();
    final income = prefs.getInt(incomeKey);
    if (income != null && deletedAccountIds.contains(income)) {
      await prefs.remove(incomeKey);
      cleared.add(incomeKey);
    }
    final expense = prefs.getInt(expenseKey);
    if (expense != null && deletedAccountIds.contains(expense)) {
      await prefs.remove(expenseKey);
      cleared.add(expenseKey);
    }
    return cleared;
  }
}
