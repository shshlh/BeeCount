import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

import '../../data/db.dart';
import '../../data/repositories/base_repository.dart';
import '../../data/repositories/investment_repository.dart';

/// 7.8.1: 投资内容 CSV 导出（业务数据归档）。
///
/// 与普通流水 CSV 分开：投资 CSV 包含持仓、投资流水（含转换内部卖出/买入
/// 与退回）与分组归属，用于归档核对；普通流水 CSV 仍保持用户可见口径。
class InvestmentCsvExportService {
  final InvestmentRepository investmentRepo;
  final BaseRepository repo;

  const InvestmentCsvExportService({
    required this.investmentRepo,
    required this.repo,
  });

  Future<String> buildCsv({required int ledgerId}) async {
    final rows = <List<dynamic>>[];
    final holdings = await investmentRepo.getHoldingsForLedger(ledgerId);
    final txs =
        await investmentRepo.getInvestmentTransactionsForLedger(ledgerId);
    final groups = await investmentRepo.watchGroups(ledgerId: ledgerId).first;
    final members = <int, List<int>>{};
    for (final g in groups) {
      members[g.id] = await investmentRepo.watchGroupHoldingIds(g.id).first;
    }

    final accounts = await repo.getAllAccounts();
    final ledgerAccounts =
        accounts.where((a) => a.ledgerId == ledgerId).toList();
    final accountName = {for (final a in accounts) a.id: a.name};
    final holdingById = {for (final h in holdings) h.id: h};
    final holdingGroup = <int, String>{};
    for (final g in groups) {
      for (final hid in members[g.id] ?? const <int>[]) {
        holdingGroup.putIfAbsent(hid, () => g.name);
      }
    }

    // 账户（7.12.2）：账户 type / 初始资金 / 排序等结构的唯一权威来源。
    rows.add(const ['【账户】']);
    rows.add(const [
      '账户名',
      '类型',
      '币种',
      '初始资金',
      '初始资金日期',
      '备注',
      '开户行',
      '卡号后四位',
      '信用额度',
      '账单日',
      '还款日',
      '排序',
      '隐藏',
      '不计入资产',
      '表外',
      '图标类型',
      '自定义图标路径',
    ]);
    for (final a in ledgerAccounts) {
      rows.add([
        a.name,
        a.type,
        a.currency,
        a.initialBalance.toStringAsFixed(2),
        a.initialDate != null ? _fmtDate(a.initialDate!) : '',
        a.note ?? '',
        a.bankName ?? '',
        a.cardLastFour ?? '',
        a.creditLimit?.toStringAsFixed(2) ?? '',
        a.billingDay?.toString() ?? '',
        a.paymentDueDay?.toString() ?? '',
        a.sortOrder,
        a.hidden ? '1' : '',
        a.excludeFromAssets ? '1' : '',
        a.isOffBalance ? '1' : '',
        a.iconType ?? '',
        a.customIconPath ?? '',
      ]);
    }
    rows.add(const []);

    // 持仓
    rows.add(const ['【持仓】']);
    rows.add(const [
      '基金代码',
      '基金名称',
      '所属账户',
      '份额',
      '成本',
      '当前净值',
      '净值日期',
      '市值',
      '备注',
      '所属分组',
    ]);
    for (final h in holdings) {
      rows.add([
        h.fundCode,
        h.fundName,
        accountName[h.accountId] ?? '',
        h.totalShares.toStringAsFixed(4),
        h.totalCost.toStringAsFixed(2),
        h.currentNav.toStringAsFixed(4),
        h.navDate != null ? _fmtDate(h.navDate!) : '',
        h.marketValue.toStringAsFixed(2),
        h.note ?? '',
        holdingGroup[h.id] ?? '',
      ]);
    }

    // 投资流水
    rows.add(const []);
    rows.add(const ['【投资流水】']);
    rows.add(const [
      '类型',
      '流水ID',
      '批次ID',
      '基金代码',
      '基金名称',
      '份额',
      '净值',
      '转入成本',
      '手续费',
      '金额',
      '退回金额',
      '退回账户',
      '转出账户',
      '转入账户',
      '日期',
      '备注',
    ]);
    for (final t in txs) {
      final h = t.holdingId != null ? holdingById[t.holdingId] : null;
      final isRefund =
          t.investType == null && (t.batchId != null || t.note == '基金转换退回');
      rows.add([
        _typeLabel(t),
        t.syncId ?? '',
        t.batchId ?? '',
        h?.fundCode ?? '',
        h?.fundName ?? '',
        (t.investShares?.abs() ?? 0).toStringAsFixed(4),
        t.investNav?.toStringAsFixed(4) ?? '',
        (t.investType == 'buy' || t.investType == 'initial')
            ? t.amount.toStringAsFixed(2)
            : '',
        t.investFee?.toStringAsFixed(2) ?? '',
        t.amount.toStringAsFixed(2),
        isRefund ? t.amount.toStringAsFixed(2) : '',
        isRefund
            ? (t.toAccountId != null ? accountName[t.toAccountId] ?? '' : '')
            : '',
        t.accountId != null ? accountName[t.accountId] ?? '' : '',
        t.toAccountId != null ? accountName[t.toAccountId] ?? '' : '',
        _fmtDateTime(t.happenedAt),
        t.note ?? '',
      ]);
    }

    // 分组与归属
    rows.add(const []);
    rows.add(const ['【分组】']);
    rows.add(const ['分组名称', '排序']);
    for (final g in groups) {
      rows.add([g.name, g.sortOrder]);
    }
    rows.add(const []);
    rows.add(const ['【分组归属】']);
    rows.add(const ['分组名称', '基金代码', '基金名称']);
    for (final g in groups) {
      for (final hid in members[g.id] ?? const <int>[]) {
        final h = holdingById[hid];
        rows.add([g.name, h?.fundCode ?? '', h?.fundName ?? '']);
      }
    }

    return const ListToCsvConverter(eol: '\n').convert(rows);
  }

  String _typeLabel(Transaction t) {
    if (t.investType == null && (t.batchId != null || t.note == '基金转换退回')) {
      return '退回';
    }
    final isConvert = t.batchId != null;
    switch (t.investType) {
      case 'initial':
        return '初始登记';
      case 'buy':
        return isConvert ? '转换买入' : '买入';
      case 'sell':
        return isConvert ? '转换卖出' : '卖出';
      case 'redeem':
        return '赎回';
      default:
        return t.investType ?? '';
    }
  }

  String _fmtDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d.toLocal());

  String _fmtDateTime(DateTime d) =>
      DateFormat('yyyy-MM-dd HH:mm').format(d.toLocal());
}
