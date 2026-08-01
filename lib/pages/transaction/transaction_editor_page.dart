import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../styles/tokens.dart';
import '../../widgets/transaction/tx_entry_form.dart';
import '../../widgets/transaction/transfer_form.dart';
import '../../widgets/ui/ui.dart';

/// 交易编辑器页面
/// 支持创建/编辑收入、支出和转账记录
class TransactionEditorPage extends ConsumerStatefulWidget {
  final String initialKind; // 'expense', 'income', or 'transfer'
  /// quickAdd 保留以兼容调用方；v5.0 起交互顺序改为「先表单后金额」，
  /// 不再由分类点击自动叠加金额弹窗
  final bool quickAdd;
  final int? initialCategoryId;
  final String? initialNote; // 用于金额输入弹窗回填备注
  final double? initialAmount;
  final DateTime? initialDate;
  final int? editingTransactionId;
  final int? initialAccountId;
  final int? initialToAccountId; // 转账时的目标账户
  final List<int>? initialTagIds; // 初始标签ID列表
  final bool initialExcludeFromStats; // 不计入收支，编辑模式回显
  final bool initialExcludeFromBudget; // 不计入预算，编辑模式回显
  // v30 多币种编辑回显(推隐含汇率用)
  final String? initialCurrencyCode;
  final double? initialNativeAmount;

  const TransactionEditorPage({
    super.key,
    required this.initialKind,
    this.quickAdd = false,
    this.initialCategoryId,
    this.initialNote,
    this.initialAmount,
    this.initialDate,
    this.editingTransactionId,
    this.initialAccountId,
    this.initialToAccountId,
    this.initialTagIds,
    this.initialExcludeFromStats = false,
    this.initialExcludeFromBudget = false,
    this.initialCurrencyCode,
    this.initialNativeAmount,
  });

  @override
  ConsumerState<TransactionEditorPage> createState() =>
      _TransactionEditorPageState();
}

class _TransactionEditorPageState extends ConsumerState<TransactionEditorPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    // 设置初始tab: 0=支出, 1=收入, 2=转账
    if (widget.initialKind == 'income') {
      _tab.index = 1;
    } else if (widget.initialKind == 'transfer') {
      _tab.index = 2;
    } else {
      _tab.index = 0;
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Column(
        children: [
          // 顶部两排：第一排返回 + 标题「记一笔」，第二排支出/收入/转账 Tab
          PrimaryHeader(
            title: l10n.txEditorTitle,
            showBack: true,
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            bottom: SizedBox(
              height: 44,
              child: TabBar(
                controller: _tab,
                isScrollable: false,
                labelColor: BeeTokens.textPrimary(context),
                unselectedLabelColor: BeeTokens.textSecondary(context),
                indicator: UnderlineTabIndicator(
                  borderSide: BorderSide(
                    width: 2,
                    color: BeeTokens.textPrimary(context),
                  ),
                  insets: const EdgeInsets.symmetric(horizontal: 0),
                ),
                tabs: [
                  Tab(text: l10n.categoryExpense),
                  Tab(text: l10n.categoryIncome),
                  Tab(text: l10n.transferTitle),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                TxEntryForm(
                  kind: 'expense',
                  initialCategoryId: widget.initialCategoryId,
                  initialNote: widget.initialNote,
                  initialAmount: widget.initialAmount,
                  initialDate: widget.initialDate,
                  editingTransactionId: widget.editingTransactionId,
                  initialAccountId: widget.initialAccountId,
                  initialTagIds: widget.initialTagIds,
                  initialExcludeFromStats: widget.initialExcludeFromStats,
                  initialExcludeFromBudget: widget.initialExcludeFromBudget,
                  initialCurrencyCode: widget.initialCurrencyCode,
                  initialNativeAmount: widget.initialNativeAmount,
                ),
                TxEntryForm(
                  kind: 'income',
                  initialCategoryId: widget.initialCategoryId,
                  initialNote: widget.initialNote,
                  initialAmount: widget.initialAmount,
                  initialDate: widget.initialDate,
                  editingTransactionId: widget.editingTransactionId,
                  initialAccountId: widget.initialAccountId,
                  initialTagIds: widget.initialTagIds,
                  initialExcludeFromStats: widget.initialExcludeFromStats,
                  initialExcludeFromBudget: widget.initialExcludeFromBudget,
                  initialCurrencyCode: widget.initialCurrencyCode,
                  initialNativeAmount: widget.initialNativeAmount,
                ),
                TransferForm(
                  onTransferComplete: () {
                    if (mounted && Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  initialFromAccountId: widget.initialAccountId,
                  initialToAccountId: widget.initialToAccountId,
                  editingTransactionId: widget.editingTransactionId,
                  initialAmount: widget.initialAmount,
                  initialNote: widget.initialNote,
                  initialDate: widget.initialDate,
                  initialTagIds: widget.initialTagIds,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
