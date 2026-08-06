import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../pages/account/accounts_page.dart';
import '../../pages/settings/automation_page.dart';
import '../../pages/settings/data_management_page.dart';
import '../../pages/settings/smart_billing_page.dart';
import '../../providers.dart';
import '../../styles/tokens.dart';
import '../../utils/format_utils.dart';
import '../../widgets/biz/home_header_bar.dart';
import '../../widgets/ui/ui.dart';

/// 首页仪表盘（v6.0）：Bento 便当格 + 顶部明细头（账本切换/AI/日历/搜索）
final homePeriodStatsProvider = FutureProvider.autoDispose<
    Map<String,
        ({double income, double expense, DateTime start, DateTime end})>>(
    (ref) async {
  ref.watch(statsRefreshProvider);
  final repo = ref.watch(repositoryProvider);
  final ledgerId = ref.watch(currentLedgerIdProvider);
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
  final monthStart = DateTime(now.year, now.month, 1);
  final yearStart = DateTime(now.year, 1, 1);

  Future<({double income, double expense, DateTime start, DateTime end})>
      range(DateTime s, DateTime e) async {
    final totals =
        await repo.totalsInRange(ledgerId: ledgerId, start: s, end: e);
    return (income: totals.$1, expense: totals.$2, start: s, end: e);
  }

  final today = await range(todayStart, todayStart.add(const Duration(days: 1)));
  final week = await range(weekStart, weekStart.add(const Duration(days: 7)));
  final month =
      await range(monthStart, DateTime(monthStart.year, monthStart.month + 1, 1));
  final year = await range(yearStart, DateTime(yearStart.year + 1, 1, 1));
  return {'today': today, 'week': week, 'month': month, 'year': year};
});

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: '',
            showTitleSection: false,
            compact: true,
            content: const HomeHeaderBar(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _buildBentoEntries(context, l10n),
                const SizedBox(height: 12),
                _buildAssetOverview(context, ref, l10n),
                const SizedBox(height: 12),
                _buildPeriodStats(context, ref, l10n),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoEntries(BuildContext context, AppLocalizations l10n) {
    final entries = [
      (
        icon: Icons.account_balance_wallet_outlined,
        label: l10n.accountOverview,
        page: const AccountsPage(),
      ),
      (
        icon: Icons.auto_awesome_outlined,
        label: l10n.smartBilling,
        page: const SmartBillingPage(),
      ),
      (
        icon: Icons.storage_outlined,
        label: l10n.dataManagement,
        page: const DataManagementPage(),
      ),
      (
        icon: Icons.schedule_outlined,
        label: l10n.automation,
        page: const AutomationPage(),
      ),
    ];

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildEntryTile(context, entries[0]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildEntryTile(context, entries[1]),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildEntryTile(context, entries[2]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildEntryTile(context, entries[3]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEntryTile(
    BuildContext context,
    ({IconData icon, String label, Widget page}) entry,
  ) {
    return _BentoCard(
      height: 86,
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => entry.page),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              entry.icon,
              size: 24,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              entry.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: BeeTokens.textPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetOverview(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final netWorthAsync = ref.watch(netWorthBreakdownProvider);
    return _BentoCard(
      height: 200,
      padding: EdgeInsets.zero,
      child: InkWell(
        key: const ValueKey('home_asset_overview_tap'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AccountsPage()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: netWorthAsync.when(
          data: (nw) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    l10n.assetOverviewTitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: BeeTokens.textPrimary(context),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: BeeTokens.iconTertiary(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l10n.accountTotalBalance,
                style: TextStyle(
                  fontSize: 12,
                  color: BeeTokens.textTertiary(context),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatFullAmount(nw.netWorth),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: BeeTokens.textPrimary(context),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _overviewStat(
                context,
                label: l10n.accountsTotalAssets,
                value: nw.totalAssets,
                valueColor: BeeTokens.incomeColor(context, ref),
              ),
              const SizedBox(height: 6),
              _overviewStat(
                context,
                label: l10n.accountsTotalLiabilities,
                value: nw.totalLiabilities.abs(),
                valueColor: BeeTokens.expenseColor(context, ref),
              ),
            ],
          ),
          loading: () => const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, __) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  Widget _overviewStat(
    BuildContext context, {
    required String label,
    required double value,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: BeeTokens.textTertiary(context),
          ),
        ),
        const Spacer(),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            formatFullAmount(value),
            maxLines: 1,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodStats(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final statsAsync = ref.watch(homePeriodStatsProvider);
    final incomeColor = BeeTokens.incomeColor(context, ref);
    final expenseColor = BeeTokens.expenseColor(context, ref);
    return _BentoCard(
      child: statsAsync.when(
          data: (stats) {
            final rows = [
              (key: 'today', label: l10n.periodToday, v: stats['today']!),
              (key: 'week', label: l10n.periodWeek, v: stats['week']!),
              (key: 'month', label: l10n.periodMonth, v: stats['month']!),
              (key: 'year', label: l10n.periodYear, v: stats['year']!),
            ];
            return Column(
              children: [
                for (final row in rows) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: BeeTokens.textPrimary(context),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatPeriodRange(row.key, row.v.start, row.v.end),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: BeeTokens.textTertiary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _incomeExpenseLine(
                              context,
                              l10n.homeIncome,
                              row.v.income,
                              incomeColor,
                            ),
                            const SizedBox(height: 2),
                            _incomeExpenseLine(
                              context,
                              l10n.homeExpense,
                              row.v.expense,
                              expenseColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (row != rows.last)
                    Divider(height: 1, color: BeeTokens.divider(context)),
                ],
              ],
            );
          },
          loading: () => const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),
    );
  }

  String _formatPeriodRange(String key, DateTime start, DateTime end) {
    final endInclusive = end.subtract(const Duration(days: 1));
    switch (key) {
      case 'today':
        return '${start.year}.${start.month}.${start.day}';
      case 'year':
        return '${start.year}';
      default:
        return '${start.month}.${start.day}-'
            '${endInclusive.month}.${endInclusive.day}';
    }
  }

  Widget _incomeExpenseLine(
    BuildContext context,
    String label,
    double value,
    Color valueColor,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: BeeTokens.textTertiary(context),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          formatFullAmount(value),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

/// Bento 便当格卡片：统一 8px 圆角、表面色、无彩色渐变。
class _BentoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? height;

  const _BentoCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = BeeTokens.isDark(context);
    final borderWidth = BeeTokens.cardOuterBorderWidth(context);
    final borderColor = BeeTokens.cardOuterBorderColor(context);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: BeeTokens.surface(context),
        borderRadius: BorderRadius.circular(8),
        border: borderWidth > 0
            ? Border.all(color: borderColor, width: borderWidth)
            : null,
        boxShadow: isDark ? null : BeeShadows.card,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
