import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart' as db;
import '../../l10n/app_localizations.dart';
import '../../pages/account/accounts_page.dart';
import '../../pages/settings/automation_page.dart';
import '../../pages/settings/data_management_page.dart';
import '../../pages/settings/smart_billing_page.dart';
import '../../providers.dart';
import '../../styles/tokens.dart';
import '../../utils/format_utils.dart';
import '../../widgets/biz/home_header_bar.dart';
import '../../widgets/charts/category_pie_chart.dart';
import '../../widgets/ui/ui.dart';

/// 首页仪表盘（v6.0）：Bento 便当格 + 顶部明细头（账本切换/AI/日历/搜索）
final homePeriodStatsProvider = FutureProvider.autoDispose<
    Map<String, (double income, double expense)>>((ref) async {
  final repo = ref.watch(repositoryProvider);
  final ledgerId = ref.watch(currentLedgerIdProvider);
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
  final monthStart = DateTime(now.year, now.month, 1);
  final yearStart = DateTime(now.year, 1, 1);

  Future<(double income, double expense)> range(DateTime s, DateTime e) =>
      repo.totalsInRange(ledgerId: ledgerId, start: s, end: e);

  final today = await range(todayStart, todayStart.add(const Duration(days: 1)));
  final week = await range(weekStart, weekStart.add(const Duration(days: 7)));
  final month =
      await range(monthStart, DateTime(monthStart.year, monthStart.month + 1, 1));
  final year = await range(yearStart, DateTime(yearStart.year + 1, 1, 1));
  return {'today': today, 'week': week, 'month': month, 'year': year};
});

/// 本月支出分类占比
final homeCategoryExpensesProvider = FutureProvider.autoDispose<
    List<({int? id, String name, String? icon, double total})>>((ref) async {
  final repo = ref.watch(repositoryProvider);
  final ledgerId = ref.watch(currentLedgerIdProvider);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  return repo.totalsByCategory(
    ledgerId: ledgerId,
    type: 'expense',
    start: start,
    end: DateTime(start.year, start.month + 1, 1),
  );
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
                const SizedBox(height: 12),
                _buildCategoryBreakdown(context, ref, l10n),
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
              const SizedBox(height: 16),
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
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _overviewStat(
                    context,
                    label: l10n.accountsTotalAssets,
                    value: nw.totalAssets,
                  ),
                  Container(
                    width: 1,
                    height: 26,
                    color: BeeTokens.divider(context),
                  ),
                  _overviewStat(
                    context,
                    label: l10n.accountsTotalLiabilities,
                    value: nw.totalLiabilities.abs(),
                  ),
                ],
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: BeeTokens.textTertiary(context),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatFullAmount(value),
            maxLines: 1,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: BeeTokens.textPrimary(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodStats(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final statsAsync = ref.watch(homePeriodStatsProvider);
    return _BentoCard(
      height: 178,
      child: statsAsync.when(
          data: (stats) {
            final rows = [
              (label: l10n.periodToday, v: stats['today']!),
              (label: l10n.periodWeek, v: stats['week']!),
              (label: l10n.periodMonth, v: stats['month']!),
              (label: l10n.periodYear, v: stats['year']!),
            ];
            return Column(
              children: [
                for (final row in rows) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Text(
                          row.label,
                          style: TextStyle(
                            fontSize: 13,
                            color: BeeTokens.textSecondary(context),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${l10n.homeIncome} ${formatFullAmount(row.v.$1)}'
                          '    ${l10n.homeExpense} ${formatFullAmount(row.v.$2)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: BeeTokens.textPrimary(context),
                          ),
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

  Widget _buildCategoryBreakdown(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final catAsync = ref.watch(homeCategoryExpensesProvider);
    return _BentoCard(
      child: catAsync.when(
          data: (items) {
            final sum =
                items.fold<double>(0, (s, e) => s + e.total);
            if (items.isEmpty || sum <= 0) {
              return Text(
                l10n.categoryEmpty,
                style: TextStyle(
                  fontSize: 13,
                  color: BeeTokens.textTertiary(context),
                ),
              );
            }
            final pieItems = [
              for (final e in items)
                (
                  id: e.id,
                  name: e.name,
                  category: null,
                  total: e.total,
                  subCategories: const <
                      ({
                        int id,
                        db.Category category,
                        String name,
                        double total,
                      })>[],
                ),
            ];
            return Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.monthlyCategoryTitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: BeeTokens.textPrimary(context),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                for (final e in items.take(5))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: BeeTokens.textPrimary(context),
                            ),
                          ),
                        ),
                        Text(
                          '${(e.total / sum * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: BeeTokens.textTertiary(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 90,
                          child: Text(
                            formatFullAmount(e.total),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: BeeTokens.textPrimary(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                CategoryPieChart(data: pieItems, sum: sum),
              ],
            );
          },
          loading: () => const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),
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
