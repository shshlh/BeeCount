import 'package:decimal/decimal.dart';

import '../../data/db.dart';
import '../../data/repositories/base_repository.dart';
import '../../data/repositories/investment_repository.dart';
import '../../utils/account_type_utils.dart';

/// AI 财务分析师上下文数据类。
///
/// 7.2.1 把当前账本的账户/收支/分类/预算/净资产/投资持仓与近期投资交易
/// 打包成纯数据快照，由应用层显式构造后注入 AI 提示词。底座只读取字段，
/// 不反向依赖 Repository。
class FinancialAnalystSnapshot {
  final String ledgerName;
  final String baseCurrency;
  final int recentDays;
  final List<AnalystAccountBalance> accounts;
  final AnalystIncomeExpense? recent30;
  final AnalystIncomeExpense? thisMonth;
  final List<AnalystCategoryTotal> topExpenseCategories;
  final AnalystBudgetProgress? budgetProgress;
  final AnalystNetWorthSummary? netWorth;
  final List<AnalystHolding> holdings;
  final List<AnalystInvestmentTx> recentInvestmentTransactions;
  final List<String> missingRateCurrencies;

  const FinancialAnalystSnapshot({
    this.ledgerName = '',
    this.baseCurrency = 'CNY',
    this.recentDays = 30,
    this.accounts = const [],
    this.recent30,
    this.thisMonth,
    this.topExpenseCategories = const [],
    this.budgetProgress,
    this.netWorth,
    this.holdings = const [],
    this.recentInvestmentTransactions = const [],
    this.missingRateCurrencies = const [],
  });

  /// 无账本 / 无数据场景的 fallback。
  static const FinancialAnalystSnapshot empty = FinancialAnalystSnapshot();

  /// 中文格式化的分析上下文，限制在 [maxChars] 字符内以控制 token。
  String toPromptText({int maxChars = 4000}) {
    final sb = StringBuffer();
    sb.writeln('【财务上下文】账本：$ledgerName（本位币 $baseCurrency）');
    sb.writeln('范围：${scopeLabel()}');

    if (accounts.isNotEmpty) {
      sb.writeln('账户与余额：');
      for (final a in accounts) {
        sb.writeln(
            '- ${a.name}（${a.type}）：${_fmtMoney(a.balance)} ${a.currency}');
      }
    }

    if (recent30 != null) {
      sb.writeln('近 $recentDays 天：收入 ${_fmtMoney(recent30!.income)} / '
          '支出 ${_fmtMoney(recent30!.expense)}');
    }
    if (thisMonth != null) {
      sb.writeln('本月：收入 ${_fmtMoney(thisMonth!.income)} / '
          '支出 ${_fmtMoney(thisMonth!.expense)}');
    }

    if (topExpenseCategories.isNotEmpty) {
      sb.writeln('支出分类 Top${topExpenseCategories.length}：');
      for (final c in topExpenseCategories) {
        sb.writeln('- ${c.name}：${_fmtMoney(c.total)}');
      }
    }

    if (budgetProgress != null) {
      final b = budgetProgress!;
      final totalText = b.totalBudget == null
          ? '未设置总预算'
          : '总预算 ${_fmtMoney(b.totalBudget!)}，已用 ${_fmtMoney(b.used ?? 0)}'
              '（${_fmtPercent(b.rate ?? 0)}）';
      sb.writeln('预算：$totalText，剩余天数 ${b.daysRemaining}，'
          '日均可用 ${_fmtMoney(b.dailyAvailable)}，分类预算 ${b.categoryBudgetCount} 项');
    }

    if (netWorth != null) {
      final n = netWorth!;
      final rangeText = (n.startDate != null && n.endDate != null)
          ? '${_fmtDate(n.startDate!)} 至 ${_fmtDate(n.endDate!)}'
          : '';
      final changeText = n.netWorthChange == null
          ? ''
          : '，$rangeText 变动 ${_fmtMoney(n.netWorthChange!)}';
      sb.writeln(
          '净资产：资产 ${_fmtMoney(n.assets)} / 负债 ${_fmtMoney(n.liabilities)} / '
          '净值 ${_fmtMoney(n.netWorth)}$changeText');
    }

    if (holdings.isNotEmpty) {
      sb.writeln('投资持仓（${holdings.length} 只）：');
      for (final h in holdings) {
        final navDateText = h.navDate == null ? '无净值日期' : _fmtDate(h.navDate!);
        sb.writeln('- ${h.fundCode} ${h.fundName}：份额 ${_fmtShares(h.shares)}，'
            '成本 ${_fmtMoney(h.cost)}，市值 ${_fmtMoney(h.marketValue)}，'
            '盈亏 ${_fmtMoney(h.pnl)}（${_fmtPercent(h.returnRate)}），'
            '净值 ${_fmtNav(h.nav)}（$navDateText）');
      }
    }

    if (recentInvestmentTransactions.isNotEmpty) {
      sb.writeln('近期投资交易（${recentInvestmentTransactions.length} 笔）：');
      for (final t in recentInvestmentTransactions) {
        final typeText = t.type == 'buy'
            ? '买入'
            : t.type == 'sell'
                ? '卖出'
                : t.type;
        final convertText = t.batchId == null ? '' : '（转换）';
        sb.writeln('- ${_fmtDate(t.happenedAt)} $typeText ${t.fundName} '
            '${_fmtShares(t.shares)} 份 @ ${_fmtNav(t.nav)}$convertText');
      }
    }

    if (missingRateCurrencies.isNotEmpty) {
      sb.writeln('提示：以下币种缺少汇率，未折算到本位币：'
          '${missingRateCurrencies.join('、')}');
    }

    return _truncate(sb.toString().trim(), maxChars);
  }

  /// 本次分析覆盖的数据范围标签，供 UI 展示。
  String scopeLabel() {
    final holdingText = holdings.isEmpty ? '无持仓' : '${holdings.length} 只持仓';
    return '近 $recentDays 天 · $holdingText';
  }
}

/// 账户与余额（账本本位币之外的账户保留原币种展示）。
class AnalystAccountBalance {
  final int accountId;
  final String name;
  final String type;
  final String currency;
  final double balance;

  const AnalystAccountBalance({
    required this.accountId,
    required this.name,
    required this.type,
    required this.currency,
    required this.balance,
  });
}

/// 收支摘要。
class AnalystIncomeExpense {
  final double income;
  final double expense;

  const AnalystIncomeExpense({required this.income, required this.expense});
}

/// 分类汇总。
class AnalystCategoryTotal {
  final String name;
  final double total;

  const AnalystCategoryTotal({required this.name, required this.total});
}

/// 预算进度摘要。
class AnalystBudgetProgress {
  final double? totalBudget;
  final double? used;
  final double? rate;
  final int daysRemaining;
  final double dailyAvailable;
  final int categoryBudgetCount;

  const AnalystBudgetProgress({
    this.totalBudget,
    this.used,
    this.rate,
    required this.daysRemaining,
    required this.dailyAvailable,
    required this.categoryBudgetCount,
  });
}

/// 净资产趋势摘要。
class AnalystNetWorthSummary {
  final double assets;
  final double liabilities;
  final double netWorth;
  final double? netWorthChange;
  final DateTime? startDate;
  final DateTime? endDate;

  const AnalystNetWorthSummary({
    required this.assets,
    required this.liabilities,
    required this.netWorth,
    this.netWorthChange,
    this.startDate,
    this.endDate,
  });
}

/// 单只持仓摘要。
class AnalystHolding {
  final int id;
  final String fundCode;
  final String fundName;
  final double shares;
  final double cost;
  final double marketValue;
  final double nav;
  final DateTime? navDate;
  final double pnl;
  final double returnRate;

  const AnalystHolding({
    required this.id,
    required this.fundCode,
    required this.fundName,
    required this.shares,
    required this.cost,
    required this.marketValue,
    required this.nav,
    this.navDate,
    required this.pnl,
    required this.returnRate,
  });
}

/// 近期投资交易（买入 / 卖出 / 转换）。
class AnalystInvestmentTx {
  final DateTime happenedAt;
  final String type;
  final String fundName;
  final double shares;
  final double nav;
  final double? amount;
  final String? batchId;

  const AnalystInvestmentTx({
    required this.happenedAt,
    required this.type,
    required this.fundName,
    required this.shares,
    required this.nav,
    this.amount,
    this.batchId,
  });
}

/// 财务分析师上下文工厂。
///
/// 只取当前账本；隐藏账户不进入上下文，不计入资产 / 不计入统计的记录按
/// Repository 现有口径过滤；多币种按本位币折算并标注缺失汇率。
class FinancialAnalystContext {
  FinancialAnalystContext._();

  static const int defaultRecentTxLimit = 10;
  static const int defaultHoldingsLimit = 10;
  static const int defaultTrendDays = 30;
  static const int defaultMaxChars = 4000;

  static Future<FinancialAnalystSnapshot> forLedger({
    required BaseRepository repository,
    required InvestmentRepository investmentRepository,
    required int ledgerId,
    int recentTxLimit = defaultRecentTxLimit,
    int holdingsLimit = defaultHoldingsLimit,
    int trendDays = defaultTrendDays,
  }) async {
    final ledger = await repository.getLedgerById(ledgerId);
    final base = (ledger?.currency ?? 'CNY').toUpperCase();
    final now = DateTime.now();
    final ratesToBase = await _loadRatesToBase(repository, base);

    final allAccounts = (await repository.getAllAccounts())
        .where((a) => a.ledgerId == ledgerId && !a.hidden && !a.isOffBalance)
        .toList();
    final balances = await repository.getAllAccountBalances(ledgerId);
    final accounts = [
      for (final a in allAccounts)
        AnalystAccountBalance(
          accountId: a.id,
          name: a.name,
          type: a.type,
          currency: a.currency.toUpperCase(),
          balance: balances[a.id] ?? 0,
        ),
    ];

    final recentStart = now.subtract(Duration(days: trendDays - 1));
    final recent30 = await repository.totalsInRange(
      ledgerId: ledgerId,
      start: recentStart,
      end: now,
    );
    final thisMonth = await repository.monthlyTotals(
      ledgerId: ledgerId,
      month: DateTime(now.year, now.month, 1),
    );

    final categoryTotals = await repository.totalsByCategory(
      ledgerId: ledgerId,
      type: 'expense',
      start: recentStart,
      end: now,
    );
    final topCategories = (categoryTotals.toList()
          ..sort((a, b) => b.total.compareTo(a.total)))
        .take(5)
        .map((c) => AnalystCategoryTotal(name: c.name, total: c.total))
        .toList();

    final budget = await repository.getBudgetOverview(ledgerId, now);
    final budgetProgress =
        budget.totalBudget == null && budget.categoryBudgets.isEmpty
            ? null
            : AnalystBudgetProgress(
                totalBudget: budget.totalBudget?.budget,
                used: budget.totalBudget?.used,
                rate: budget.totalBudget?.rate,
                daysRemaining: budget.daysRemaining,
                dailyAvailable: budget.dailyAvailable,
                categoryBudgetCount: budget.categoryBudgets.length,
              );

    final netWorth = await _buildNetWorthSummary(
      repository: repository,
      accounts: allAccounts,
      ratesToBase: ratesToBase,
      trendDays: trendDays,
    );

    final holdingsAll =
        await investmentRepository.watchHoldings(ledgerId: ledgerId).first;
    final holdings =
        holdingsAll.take(holdingsLimit).map(_buildHolding).toList();

    final recentTx = await repository.getRecentTransactions(
      ledgerId,
      limit: recentTxLimit * 10,
    );
    final holdingById = {for (final h in holdingsAll) h.id: h};
    final investTx = recentTx
        .where((t) => t.investType != null && t.investType != 'initial')
        .take(recentTxLimit)
        .map((t) => _buildInvestmentTx(t, holdingById))
        .toList();

    final missingRates = _missingRateCurrencies(
      allAccounts,
      base,
      ratesToBase,
    );

    return FinancialAnalystSnapshot(
      ledgerName: ledger?.name ?? '',
      baseCurrency: base,
      recentDays: trendDays,
      accounts: accounts,
      recent30: AnalystIncomeExpense(
        income: recent30.$1,
        expense: recent30.$2,
      ),
      thisMonth: AnalystIncomeExpense(
        income: thisMonth.$1,
        expense: thisMonth.$2,
      ),
      topExpenseCategories: topCategories,
      budgetProgress: budgetProgress,
      netWorth: netWorth,
      holdings: holdings,
      recentInvestmentTransactions: investTx,
      missingRateCurrencies: missingRates,
    );
  }

  static Future<Map<String, double>> _loadRatesToBase(
    BaseRepository repository,
    String base,
  ) async {
    final rates = <String, double>{base: 1.0};
    for (final r in await repository.getLatestAutoRates(base)) {
      final v = double.tryParse(r.rate);
      if (v != null && v > 0) rates[r.quoteCurrency.toUpperCase()] = v;
    }
    for (final o in await repository.getOverrides(base)) {
      final v = double.tryParse(o.rate);
      if (v != null && v > 0) rates[o.quoteCurrency.toUpperCase()] = v;
    }
    return rates;
  }

  static Future<AnalystNetWorthSummary?> _buildNetWorthSummary({
    required BaseRepository repository,
    required List<Account> accounts,
    required Map<String, double> ratesToBase,
    required int trendDays,
  }) async {
    final visible = accounts
        .where((a) => !a.excludeFromAssets && !a.isOffBalance)
        .toList();
    if (visible.isEmpty) return null;

    final now = DateTime.now();
    final endDate = DateTime(now.year, now.month, now.day);
    final effectiveDays = trendDays < 1 ? 1 : trendDays;
    final startDate = endDate.subtract(Duration(days: effectiveDays - 1));
    final daily = <int, List<({DateTime date, double balance})>>{};
    for (final a in visible) {
      daily[a.id] = await repository.getAccountDailyBalances(
        a.id,
        startDate: startDate,
        endDate: endDate,
      );
    }

    // 首日 / 末日净资产（含资产与负债口径）。
    double assets(int index, {required bool last}) {
      double total = 0;
      for (final a in visible) {
        if (!isAssetType(a.type)) continue;
        final rate = ratesToBase[a.currency.toUpperCase()];
        if (rate == null) continue;
        final list = daily[a.id]!;
        final balance = index < list.length
            ? list[index].balance
            : (last && list.isNotEmpty ? list.last.balance : 0);
        total += balance * rate;
      }
      return total;
    }

    double liabilities(int index, {required bool last}) {
      double total = 0;
      for (final a in visible) {
        if (isAssetType(a.type)) continue;
        final rate = ratesToBase[a.currency.toUpperCase()];
        if (rate == null) continue;
        final list = daily[a.id]!;
        final balance = index < list.length
            ? list[index].balance
            : (last && list.isNotEmpty ? list.last.balance : 0);
        total += balance * rate;
      }
      return total;
    }

    final firstAssets = assets(0, last: false);
    final firstLiabilities = liabilities(0, last: false);
    final lastAssets = assets(effectiveDays - 1, last: true);
    final lastLiabilities = liabilities(effectiveDays - 1, last: true);
    final firstNet = firstAssets + firstLiabilities;
    final lastNet = lastAssets + lastLiabilities;

    return AnalystNetWorthSummary(
      assets: lastAssets,
      liabilities: lastLiabilities,
      netWorth: lastNet,
      netWorthChange: lastNet - firstNet,
      startDate: startDate,
      endDate: endDate,
    );
  }

  static AnalystHolding _buildHolding(InvestmentHolding h) {
    final mv = _toDecimal(h.marketValue);
    final cost = _toDecimal(h.totalCost);
    final pnl = mv - cost;
    final rate = cost > Decimal.zero ? _divide(pnl, cost) : Decimal.zero;
    return AnalystHolding(
      id: h.id,
      fundCode: h.fundCode,
      fundName: h.fundName,
      shares: h.totalShares,
      cost: h.totalCost,
      marketValue: h.marketValue,
      nav: h.currentNav,
      navDate: h.navDate,
      pnl: pnl.toDouble(),
      returnRate: rate.toDouble(),
    );
  }

  static AnalystInvestmentTx _buildInvestmentTx(
    Transaction t,
    Map<int, InvestmentHolding> holdingById,
  ) {
    return AnalystInvestmentTx(
      happenedAt: t.happenedAt,
      type: t.investType ?? 'unknown',
      fundName:
          t.holdingId == null ? '' : (holdingById[t.holdingId]?.fundName ?? ''),
      shares: t.investShares ?? 0,
      nav: t.investNav ?? 0,
      amount: t.amount,
      batchId: t.batchId,
    );
  }

  static List<String> _missingRateCurrencies(
    List<Account> accounts,
    String base,
    Map<String, double> ratesToBase,
  ) {
    final missing = <String>{};
    for (final a in accounts) {
      final c = a.currency.toUpperCase();
      if (c != base && ratesToBase[c] == null) missing.add(c);
    }
    return missing.toList()..sort();
  }
}

Decimal _toDecimal(double value) => Decimal.parse(value.toString());

Decimal _divide(Decimal a, Decimal b) =>
    (a / b).toDecimal(scaleOnInfinitePrecision: 18);

String _fmtMoney(double value) => value.toStringAsFixed(2);

String _fmtNav(double value) => value.toStringAsFixed(4);

String _fmtShares(double value) => value.toStringAsFixed(2);

String _fmtPercent(double rate) => '${(rate * 100).toStringAsFixed(2)}%';

String _fmtDate(DateTime d) {
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

String _truncate(String text, int maxChars) {
  if (maxChars <= 0) return '';
  if (text.length <= maxChars) return text;
  final keep = maxChars > 3 ? maxChars - 3 : 0;
  return '${text.substring(0, keep)}...';
}
