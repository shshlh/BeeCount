import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db.dart';
import '../../providers.dart';
import '../../styles/tokens.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/biz/amount_text.dart';
import '../../widgets/biz/section_card.dart';
import '../../widgets/investment/holding_card.dart';
import '../../services/data/investment_service.dart';
import 'holding_detail_page.dart';
import '../../widgets/investment/buy_dialog.dart';
import '../../widgets/investment/initial_holding_dialog.dart';

/// 持仓列表页 — 展示当前账本下所有投资持仓。
///
/// v4.7: 导入初始持仓按钮常驻（不仅限于空态）。
/// v5.4: 投资组合摘要固定占位，只滚动持仓列表；导入按钮移入顶部栏右侧。
///
/// 功能：
/// - 顶部固定组合摘要卡片（总市值/总成本/盈亏/收益率/持仓数）
/// - v5.4: 顶部栏右侧「导入初始持仓」按钮（常驻）
/// - 持仓卡片列表（基金名称、代码、份额、市值、盈亏）
/// - 下拉刷新（刷新净值数据）
/// - 空状态提示（无持仓时）
class HoldingsListPage extends ConsumerStatefulWidget {
  /// 是否作为 Tab 嵌入底部导航（asTab=true 时不显示返回按钮）。
  final bool asTab;
  const HoldingsListPage({super.key, this.asTab = false});

  @override
  ConsumerState<HoldingsListPage> createState() => _HoldingsListPageState();
}

class _HoldingsListPageState extends ConsumerState<HoldingsListPage> {
  @override
  void initState() {
    super.initState();
    // v6.11.3: 进入页面自动刷新净值（15 分钟节流，内部静默跳过）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshOnEnter();
    });
  }

  Future<void> _refreshOnEnter() async {
    final ledgerId = ref.read(currentLedgerIdProvider);
    try {
      final result = await ref
          .read(investmentServiceProvider)
          .refreshNavsForLedgerDetailed(ledgerId);
      _showSkippedCodes(result.skippedCodes);
      if (result.updatedCount > 0 && mounted) _invalidateHoldings();
    } catch (_) {
      // 进入页面自动刷新失败静默，不打断列表
    }
  }

  Future<void> _refreshByPull() async {
    final ledgerId = ref.read(currentLedgerIdProvider);
    try {
      final result = await ref
          .read(investmentServiceProvider)
          .refreshNavsForLedgerDetailed(ledgerId, force: true);
      _invalidateHoldings();
      _showSkippedCodes(result.skippedCodes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('净值刷新失败')),
        );
      }
    }
  }

  void _showSkippedCodes(List<String> skippedCodes) {
    if (!mounted || skippedCodes.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('以下基金未更新：${skippedCodes.join('、')}')),
    );
  }

  void _invalidateHoldings() {
    ref.invalidate(currentHoldingsProvider);
    ref.invalidate(portfolioSummaryProvider);
    ref.invalidate(filteredHoldingsProvider);
  }

  @override
  Widget build(BuildContext context) {
    // v6.11 返工：资产 tab 在 IndexedStack 常驻，切回时再次触发自动刷新
    ref.listen<int>(bottomTabIndexProvider, (prev, next) {
      if (next == 2 && prev != 2) _refreshOnEnter();
    });

    final holdingsAsync = ref.watch(currentHoldingsProvider);
    final filteredAsync = ref.watch(filteredHoldingsProvider);
    final groupsAsync = ref.watch(groupsProvider);
    final selectedGroupId = ref.watch(selectedGroupProvider);
    final sort = ref.watch(holdingsSortProvider);
    final summaryAsync = ref.watch(portfolioSummaryProvider);
    final hasHoldings = holdingsAsync.asData?.value.isNotEmpty ?? false;

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: '投资持仓',
            showBack: !widget.asTab,
            compact: true,
            actions: [
              IconButton(
                onPressed: () => _importInitialHoldings(context, ref),
                icon: const Icon(Icons.file_upload_outlined),
                tooltip: '导入初始持仓',
              ),
            ],
          ),
          // 投资组合摘要固定占位，不随持仓滚动（v5.4）
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BeeDimens.p12,
              BeeDimens.p8,
              BeeDimens.p12,
              0,
            ),
            child: _buildSummaryCard(context, ref, summaryAsync),
          ),
          // v6.2: 分组 chips + 排序行固定在摘要下方，列表只滚动持仓
          if (hasHoldings) ...[
            _buildGroupChipsRow(
              context,
              ref,
              groupsAsync.valueOrNull ?? const [],
              selectedGroupId,
            ),
            _buildSortRow(context, ref, sort),
          ],
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshByPull,
              child: holdingsAsync.when(
                skipLoadingOnReload: true,
                data: (holdings) {
                  if (holdings.isEmpty) {
                    return _buildEmptyState(context, ref);
                  }
                  return filteredAsync.when(
                    skipLoadingOnReload: true,
                    data: (filtered) {
                      if (filtered.isEmpty) {
                        return _buildGroupEmptyState(context, ref);
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          BeeDimens.p12,
                          BeeDimens.p8,
                          BeeDimens.p12,
                          BeeDimens.p12,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final holding = filtered[index];
                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: BeeDimens.p8),
                            child: GestureDetector(
                              onLongPress: () =>
                                  _confirmDeleteHolding(context, holding),
                              child: HoldingCard(
                                holding: holding,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => HoldingDetailPage(
                                        holdingId: holding.id),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(
                      child: Text(
                        '加载失败：$err',
                        style:
                            TextStyle(color: BeeTokens.textSecondary(context)),
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(
                  child: Text(
                    '加载失败：$err',
                    style: TextStyle(color: BeeTokens.textSecondary(context)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 打开导入初始持仓弹窗（顶部栏 + 空态共用）
  Future<void> _importInitialHoldings(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result = await showInitialHoldingDialog(
      context,
      ledgerId: ref.read(currentLedgerIdProvider),
    );
    if (result == true) {
      ref.invalidate(currentHoldingsProvider);
      ref.invalidate(portfolioSummaryProvider);
    }
  }

  /// 长按删除整个持仓（v6.13.4）
  Future<void> _confirmDeleteHolding(
    BuildContext context,
    InvestmentHolding holding,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除持仓'),
        content: Text(
            '删除持仓「${holding.fundName}」？将同时删除该持仓的全部交易记录，此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: BeeTokens.error(context),
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(investmentServiceProvider)
          .deleteHolding(holding.id);
      _invalidateHoldings();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除持仓失败：$e')),
        );
      }
    }
  }

  /// 空态：暂无持仓
  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    final primaryColor = ref.watch(primaryColorProvider);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart_rounded,
            size: 64,
            color: primaryColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无持仓',
            style: TextStyle(
              fontSize: 16,
              color: BeeTokens.textSecondary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '买入基金或股票后，持仓将显示在这里',
            style: TextStyle(
              fontSize: 13,
              color: BeeTokens.textTertiary(context),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              final result = await showBuyDialog(
                context,
                ledgerId: ref.read(currentLedgerIdProvider),
              );
              if (result == true) {
                ref.invalidate(currentHoldingsProvider);
                ref.invalidate(portfolioSummaryProvider);
              }
            },
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('买入基金'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _importInitialHoldings(context, ref),
            icon: const Icon(Icons.file_upload_outlined, size: 20),
            label: const Text('导入初始持仓'),
          ),
        ],
      ),
    );
  }

  /// 组合摘要卡片
  Widget _buildSummaryCard(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<PortfolioSummary> summaryAsync,
  ) {
    return summaryAsync.when(
      skipLoadingOnReload: true,
      data: (summary) => SectionCard(
        padding: const EdgeInsets.fromLTRB(
          BeeDimens.p16,
          BeeDimens.p12,
          BeeDimens.p16,
          BeeDimens.p12,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  '投资组合',
                  style: BeeTextTokens.strongTitle(context),
                ),
                const SizedBox(width: BeeDimens.p8),
                Text(
                  '共 ${summary.holdingCount} 只',
                  style: TextStyle(
                    fontSize: 12,
                    color: BeeTokens.textTertiary(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: BeeDimens.p12),
            _summaryRow(
              context,
              label: '总市值',
              value: summary.totalMarketValue,
              isMain: true,
            ),
            const SizedBox(height: BeeDimens.p8),
            _summaryRow(
              context,
              label: '总成本',
              value: summary.totalCost,
            ),
            const SizedBox(height: BeeDimens.p8),
            _summaryPnlRow(context, ref, summary),
          ],
        ),
      ),
      loading: () => const SectionCard(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _summaryRow(
    BuildContext context, {
    required String label,
    required double value,
    bool isMain = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isMain ? 15 : 13,
            color: isMain
                ? BeeTokens.textPrimary(context)
                : BeeTokens.textSecondary(context),
            fontWeight: isMain ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        AmountText(
          value: value,
          signed: false,
          useCompactFormat: false,
          style: TextStyle(
            fontSize: isMain ? 20 : 14,
            fontWeight: isMain ? FontWeight.bold : FontWeight.w500,
            color: BeeTokens.textPrimary(context),
          ),
        ),
      ],
    );
  }

  Widget _summaryPnlRow(
    BuildContext context,
    WidgetRef ref,
    PortfolioSummary summary,
  ) {
    final isProfit = summary.unrealizedPnL >= 0;
    final pnlColor = isProfit
        ? BeeTokens.incomeColor(context, ref)
        : BeeTokens.expenseColor(context, ref);

    final rateStr = (summary.returnRate * 100).toStringAsFixed(2);
    final sign = isProfit ? '+' : '';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '持仓盈亏',
          style: TextStyle(
            fontSize: 13,
            color: BeeTokens.textSecondary(context),
          ),
        ),
        Row(
          children: [
            AmountText(
              value: summary.unrealizedPnL,
              signed: true,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: pnlColor,
              ),
            ),
            const SizedBox(width: BeeDimens.p8),
            Text(
              '$sign$rateStr%',
              style: TextStyle(
                fontSize: 12,
                color: pnlColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---- v6.2 排序 ----

  Widget _buildSortRow(
      BuildContext context, WidgetRef ref, HoldingsSort current) {
    const options = <(HoldingsSort, String)>[
      (HoldingsSort.marketValue, '持有金额'),
      (HoldingsSort.pnl, '持有收益'),
      (HoldingsSort.returnRate, '持有收益率'),
    ];
    final currentLabel = options.firstWhere((o) => o.$1 == current).$2;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BeeDimens.p12,
        0,
        BeeDimens.p12,
        4,
      ),
      child: Row(
        children: [
          Text(
            '排序',
            style: TextStyle(
              fontSize: 12,
              color: BeeTokens.textTertiary(context),
            ),
          ),
          // 单边向下箭头：代表排序方向从大到小（降序）
          Icon(
            Icons.arrow_drop_down,
            size: 18,
            color: BeeTokens.iconTertiary(context),
          ),
          const Spacer(),
          PopupMenuButton<HoldingsSort>(
            initialValue: current,
            position: PopupMenuPosition.under,
            onSelected: (value) =>
                ref.read(holdingsSortProvider.notifier).state = value,
            itemBuilder: (ctx) => [
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0) const PopupMenuDivider(),
                PopupMenuItem<HoldingsSort>(
                  value: options[i].$1,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(options[i].$2),
                  ),
                ),
              ],
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: BeeTokens.border(context)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: BeeTokens.textPrimary(context),
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 18,
                    color: BeeTokens.iconTertiary(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- v6.2 分组 ----

  Widget _buildGroupChipsRow(
    BuildContext context,
    WidgetRef ref,
    List<InvestmentGroup> groups,
    int? selectedGroupId,
  ) {
    final primaryColor = ref.watch(primaryColorProvider);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: BeeDimens.p12,
          vertical: 4,
        ),
        children: [
          _buildGroupChip(
            context,
            primaryColor,
            label: '全部',
            selected: selectedGroupId == null,
            onTap: () => ref.read(selectedGroupProvider.notifier).reset(),
            onLongPress: null,
          ),
          for (final group in groups)
            _buildGroupChip(
              context,
              primaryColor,
              label: group.name,
              selected: selectedGroupId == group.id,
              onTap: () =>
                  ref.read(selectedGroupProvider.notifier).select(group.id),
              onLongPress: () => _showGroupMenu(context, ref, group),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: GestureDetector(
              onTap: () => _showCreateGroupDialog(context, ref),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: BeeTokens.border(context)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 16, color: primaryColor),
                    const SizedBox(width: 4),
                    Text(
                      '新建分组',
                      style: TextStyle(fontSize: 12, color: primaryColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupChip(
    BuildContext context,
    Color primaryColor, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: BeeDimens.p8),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          constraints: const BoxConstraints(minWidth: 80),
          decoration: BoxDecoration(
            color: selected
                ? primaryColor.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? primaryColor : BeeTokens.border(context),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: selected ? primaryColor : BeeTokens.textSecondary(context),
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupEmptyState(BuildContext context, WidgetRef ref) {
    final primaryColor = ref.watch(primaryColorProvider);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 56,
            color: primaryColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            '该分组暂无基金',
            style: TextStyle(
              fontSize: 15,
              color: BeeTokens.textSecondary(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '长按分组可编辑成员',
            style: TextStyle(
              fontSize: 12,
              color: BeeTokens.textTertiary(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showGroupMenu(
    BuildContext context,
    WidgetRef ref,
    InvestmentGroup group,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: BeeTokens.surface(context),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              title: Text(
                group.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: BeeTokens.textPrimary(ctx),
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('重命名'),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add_check),
              title: const Text('编辑成员'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: BeeTokens.error(context),
              ),
              title: Text(
                '删除分组',
                style: TextStyle(color: BeeTokens.error(context)),
              ),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted) return;
    switch (action) {
      case 'rename':
        await _showRenameGroupDialog(context, ref, group);
      case 'edit':
        await _showEditGroupMembersDialog(context, ref, group);
      case 'delete':
        await _confirmDeleteGroup(context, ref, group);
    }
  }

  Future<void> _showCreateGroupDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    List<InvestmentHolding> holdings;
    try {
      holdings = await ref.read(currentHoldingsProvider.future);
    } catch (_) {
      holdings = const <InvestmentHolding>[];
    }
    if (!context.mounted) return;
    final nameCtrl = TextEditingController();
    final selectedIds = <int>{};
    try {
      final created = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('新建分组'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: '分组名称',
                        hintText: '如 宽基指数',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '选择基金（可多选）',
                      style: TextStyle(
                        fontSize: 12,
                        color: BeeTokens.textSecondary(ctx),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 220,
                      child: holdings.isEmpty
                          ? Center(
                              child: Text(
                                '暂无基金可选',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: BeeTokens.textTertiary(ctx),
                                ),
                              ),
                            )
                          : ListView(
                              shrinkWrap: true,
                              children: [
                                for (final h in holdings)
                                  CheckboxListTile(
                                    dense: true,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    value: selectedIds.contains(h.id),
                                    title: Text(
                                      h.fundName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(h.fundCode),
                                    onChanged: (checked) => setDialogState(() {
                                      if (checked ?? false) {
                                        selectedIds.add(h.id);
                                      } else {
                                        selectedIds.remove(h.id);
                                      }
                                    }),
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('取消'),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: nameCtrl,
                  builder: (ctx, value, _) => FilledButton(
                    onPressed: value.text.trim().isEmpty
                        ? null
                        : () => Navigator.pop(ctx, true),
                    child: const Text('创建'),
                  ),
                ),
              ],
            );
          },
        ),
      );

      if (created != true) return;
      final name = nameCtrl.text.trim();
      if (name.isEmpty) return;
      try {
        final service = ref.read(investmentServiceProvider);
        final groupId = await service.createGroup(
          ledgerId: ref.read(currentLedgerIdProvider),
          name: name,
        );
        if (selectedIds.isNotEmpty) {
          await service.addHoldingsToGroup(groupId, selectedIds.toList());
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('创建分组失败：$e')),
          );
        }
      }
    } finally {
      nameCtrl.dispose();
    }
  }

  Future<void> _showRenameGroupDialog(
    BuildContext context,
    WidgetRef ref,
    InvestmentGroup group,
  ) async {
    final nameCtrl = TextEditingController(text: group.name);
    try {
      final renamed = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('重命名分组'),
          content: TextField(
            controller: nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: '分组名称'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: nameCtrl,
              builder: (ctx, value, _) => FilledButton(
                onPressed: value.text.trim().isEmpty
                    ? null
                    : () => Navigator.pop(ctx, value.text.trim()),
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      );
      if (renamed == null ||
          renamed.trim().isEmpty ||
          renamed.trim() == group.name) {
        return;
      }
      try {
        await ref
            .read(investmentServiceProvider)
            .renameGroup(group.id, renamed.trim());
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('重命名失败：$e')),
          );
        }
      }
    } finally {
      nameCtrl.dispose();
    }
  }

  Future<void> _showEditGroupMembersDialog(
    BuildContext context,
    WidgetRef ref,
    InvestmentGroup group,
  ) async {
    List<InvestmentHolding> holdings;
    try {
      holdings = await ref.read(currentHoldingsProvider.future);
    } catch (_) {
      holdings = const <InvestmentHolding>[];
    }
    final service = ref.read(investmentServiceProvider);
    List<int> currentMembers = [];
    try {
      currentMembers = await service.watchGroupHoldingIds(group.id).first;
    } catch (_) {
      currentMembers = [];
    }
    if (!context.mounted) return;

    final selectedIds = <int>{...currentMembers};
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text('编辑成员 · ${group.name}'),
            content: SizedBox(
              width: double.maxFinite,
              child: SizedBox(
                height: 300,
                child: holdings.isEmpty
                    ? Center(
                        child: Text(
                          '暂无基金可选',
                          style: TextStyle(
                            fontSize: 12,
                            color: BeeTokens.textTertiary(ctx),
                          ),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final h in holdings)
                            CheckboxListTile(
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: selectedIds.contains(h.id),
                              title: Text(
                                h.fundName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(h.fundCode),
                              onChanged: (checked) => setDialogState(() {
                                if (checked ?? false) {
                                  selectedIds.add(h.id);
                                } else {
                                  selectedIds.remove(h.id);
                                }
                              }),
                            ),
                        ],
                      ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );

    if (saved != true) return;
    try {
      await service.setGroupMembers(group.id, selectedIds.toList());
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存分组失败：$e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteGroup(
    BuildContext context,
    WidgetRef ref,
    InvestmentGroup group,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除分组'),
        content: Text('删除分组「${group.name}」？不会删除其中的基金。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: BeeTokens.error(context),
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(investmentServiceProvider).deleteGroup(group.id);
      if (ref.read(selectedGroupProvider) == group.id) {
        ref.read(selectedGroupProvider.notifier).reset();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除分组失败：$e')),
        );
      }
    }
  }
}
