import 'package:csv/csv.dart';

import '../../data/db.dart';
import '../../data/repositories/base_repository.dart';

/// 判断一笔流水是否属于投资模块（投资买入/卖出/转换内部记录/转换退回）。
///
/// 7.9.1：普通流水 CSV 以此为唯一出处过滤条件，投资 CSV 负责导出这些记录，
/// 避免同一笔业务在两个文件里重复。
bool isInvestmentTransaction(Transaction t) {
  return t.investType != null ||
      t.batchId != null ||
      t.note == '基金转换退回';
}

/// 普通流水 CSV 导出服务（7.9.1 抽取，便于单元测试）。
///
/// 与 7.8.1 的投资 CSV 分离：普通 CSV 只含用户可见的收支/转账流水，
/// 投资相关流水统一由 [InvestmentCsvExportService] 归档。
class TransactionCsvExportService {
  final BaseRepository repo;

  const TransactionCsvExportService({required this.repo});

  Future<String> buildCsv({
    required int ledgerId,
    required List<String> headers,
    required String Function(String type) typeDisplayName,
    required String Function(String? name) categoryDisplayName,
    void Function(int done, int total)? onProgress,
  }) async {
    final transactionsWithCategory =
        await repo.transactionsWithCategoryAll(ledgerId: ledgerId).first;
    final visible = transactionsWithCategory
        .where((e) => !isInvestmentTransaction(e.t))
        .toList();
    final total = visible.length;
    final rows = <List<dynamic>>[headers];

    // 批量获取所有交易的标签与附件
    final transactionIds = visible.map((tx) => tx.t.id).toList();
    final tagsMap = await repo.getTagsForTransactions(transactionIds);
    final attachmentsMap =
        await repo.getAttachmentsForTransactions(transactionIds);

    // 缓存所有账户信息，避免重复查询
    final allAccounts = await repo.getAllAccounts();
    final accountMap = {for (final acc in allAccounts) acc.id: acc};

    // 账本本位币：currencyCode 为 NULL 的历史行按账户/本位币兜底
    final ledgerData = await repo.getLedgerById(ledgerId);
    final ledgerBase =
        ((ledgerData?.currency.isNotEmpty ?? false) ? ledgerData!.currency : 'CNY')
            .toUpperCase();

    // 缓存所有分类信息（包括父分类）
    final incomeCategories = await repo.getTopLevelCategories('income');
    final expenseCategories = await repo.getTopLevelCategories('expense');
    final allCategories = <int, Category>{};
    for (final cat in [...incomeCategories, ...expenseCategories]) {
      allCategories[cat.id] = cat;
      final subCategories = await repo.getSubCategories(cat.id);
      for (final subCat in subCategories) {
        allCategories[subCat.id] = subCat;
      }
    }

    for (int i = 0; i < visible.length; i++) {
      final txWithCat = visible[i];
      final t = txWithCat.t;
      final c = txWithCat.category;
      final a = t.accountId != null ? accountMap[t.accountId] : null;

      final timeStr = () {
        try {
          final localTime = t.happenedAt.toLocal();
          return '  ${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')} ${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}:${localTime.second.toString().padLeft(2, '0')}  ';
        } catch (_) {
          return '';
        }
      }();
      final typeStr = typeDisplayName(t.type);

      String accountName;
      String accountType;
      String fromAccountName;
      String fromAccountType;
      String toAccountName;
      String toAccountType;
      String categoryName;
      String subCategoryName;

      if (t.type == 'transfer') {
        accountName = '';
        accountType = '';
        final fromAccount = accountMap[t.accountId];
        final toAccount = accountMap[t.toAccountId];
        fromAccountName = fromAccount?.name ?? '';
        toAccountName = toAccount?.name ?? '';
        fromAccountType = fromAccount?.type ?? '';
        toAccountType = toAccount?.type ?? '';
        categoryName = '';
        subCategoryName = '';
      } else {
        accountName = a?.name ?? '';
        accountType = a?.type ?? '';
        fromAccountName = '';
        fromAccountType = '';
        toAccountName = '';
        toAccountType = '';
        if (c != null) {
          if (c.level == 2 && c.parentId != null) {
            final parentCategory = allCategories[c.parentId];
            categoryName = categoryDisplayName(parentCategory?.name);
            subCategoryName = categoryDisplayName(c.name);
          } else {
            categoryName = categoryDisplayName(c.name);
            subCategoryName = '';
          }
        } else {
          categoryName = '';
          subCategoryName = '';
        }
      }

      final transactionTags = tagsMap[t.id] ?? [];
      final tagsStr = transactionTags.map((tag) => tag.name).join(',');

      final transactionAttachments = attachmentsMap[t.id] ?? [];
      final attachmentsStr =
          transactionAttachments.map((a) => a.fileName).join(',');

      final currencyStr =
          (t.currencyCode ??
                  (a?.currency.isNotEmpty ?? false ? a!.currency : null) ??
                  ledgerBase)
              .toUpperCase();

      rows.add([
        typeStr,
        categoryName,
        subCategoryName,
        t.amount.toStringAsFixed(2),
        currencyStr,
        accountName,
        accountType,
        fromAccountName,
        fromAccountType,
        toAccountName,
        toAccountType,
        t.note ?? '',
        timeStr,
        tagsStr,
        attachmentsStr,
        t.syncId ?? '',
      ]);
      if (i % 50 == 0) onProgress?.call(i + 1, total == 0 ? 1 : total);
    }

    return const ListToCsvConverter(eol: '\n').convert(rows);
  }
}
