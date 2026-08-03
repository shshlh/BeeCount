import 'package:drift/drift.dart' as d;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart';
import '../../data/repositories/local/local_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../models/note_history.dart';
import '../../pages/tag/widgets/tag_selector.dart';
import '../../providers.dart';
import '../../services/attachment_service.dart';
import '../../services/billing/post_processor.dart';
import '../../services/data/note_history_service.dart';
import '../../services/data/tx_author_service.dart';
import '../../styles/tokens.dart';
import '../../utils/currencies.dart';
import '../../utils/shared_ledger_picker_filter.dart';
import '../../utils/tx_date_format.dart';
import '../biz/amount_editor_sheet.dart';
import '../biz/format_money.dart';
import '../biz/note_picker_dialog.dart';
import '../ui/ui.dart';
import 'account_drawer_sheet.dart';

/// 转账表单组件（v5.2 转账模式体验统一）
/// 字段顺序：金额-账户-时间-标签-备注；账户行点击弹抽屉分格，
/// 先选转出再选转入；金额可独立填写，不依赖账户选择。
class TransferForm extends ConsumerStatefulWidget {
  /// 转账完成回调
  final VoidCallback onTransferComplete;

  /// 初始转出账户ID（可选）
  final int? initialFromAccountId;

  /// 初始转入账户ID（可选）
  final int? initialToAccountId;

  /// 正在编辑的交易ID（编辑模式）
  final int? editingTransactionId;

  /// 初始金额（可选）
  final double? initialAmount;

  /// 初始备注（可选）
  final String? initialNote;

  /// 初始日期（可选）
  final DateTime? initialDate;

  /// 初始标签ID列表（可选）
  final List<int>? initialTagIds;

  const TransferForm({
    super.key,
    required this.onTransferComplete,
    this.initialFromAccountId,
    this.initialToAccountId,
    this.editingTransactionId,
    this.initialAmount,
    this.initialNote,
    this.initialDate,
    this.initialTagIds,
  });

  @override
  ConsumerState<TransferForm> createState() => _TransferFormState();
}

class _TransferFormState extends ConsumerState<TransferForm> {
  Account? _fromAccount;
  Account? _toAccount;
  int? _fromAccountId;
  int? _toAccountId;
  late DateTime _date;
  double _amount = 0;
  String? _pickedCurrency;
  List<int> _tagIds = [];
  late final TextEditingController _noteCtrl;
  final FocusNode _noteFocusNode = FocusNode();
  List<NoteHistoryEntry> _frequentNotes = [];

  @override
  void initState() {
    super.initState();
    _fromAccountId = widget.initialFromAccountId;
    _toAccountId = widget.initialToAccountId;
    _date = widget.initialDate ?? DateTime.now();
    _amount = widget.initialAmount ?? 0;
    _tagIds = List.from(widget.initialTagIds ?? []);
    _noteCtrl = TextEditingController(text: widget.initialNote ?? '');
    _loadFrequentNotes();
    _resolveInitialAccounts();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  Future<void> _resolveInitialAccounts() async {
    final fromId = widget.initialFromAccountId;
    if (fromId != null) {
      final a = await _lookupAccount(fromId);
      if (a != null && mounted) setState(() => _fromAccount = a);
    }
    final toId = widget.initialToAccountId;
    if (toId != null) {
      final a = await _lookupAccount(toId);
      if (a != null && mounted) setState(() => _toAccount = a);
    }
  }

  // 检查两个账户是否是相同币种
  Future<bool> _checkSameCurrency() async {
    if (_fromAccountId == null || _toAccountId == null) return false;

    final fromAccount = await _lookupAccount(_fromAccountId!);
    final toAccount = await _lookupAccount(_toAccountId!);
    return fromAccount?.currency == toAccount?.currency;
  }

  /// 反查账户:正数 id → 主表 accounts;负数 synthetic id → 扫
  /// SharedLedgerAccounts 找 syntheticIdForSyncId 命中(共享账本 Editor
  /// 视角下 picker 给出的是 Owner 的 synthetic 账户)。
  Future<Account?> _lookupAccount(int accountId) async {
    final repo = ref.read(repositoryProvider);
    if (accountId >= 0) return repo.getAccount(accountId);
    if (repo is! LocalRepository) return null;
    return repo.db.findAccountBySyntheticId(accountId);
  }

  /// 把 synthetic accountId(负数)反查回 Owner 的 syncId(正数 id 时返 null)。
  /// 用 ledger.syncId 限定 SharedLedgerAccounts 的查询范围。
  Future<String?> _resolveSyncIdByAccountId(int accountId, int ledgerId) async {
    if (accountId >= 0) return null;
    final repo = ref.read(repositoryProvider);
    if (repo is! LocalRepository) return null;
    final ledger = await (repo.db.select(repo.db.ledgers)
          ..where((l) => l.id.equals(ledgerId)))
        .getSingleOrNull();
    if (ledger?.syncId == null) return null;
    final rows = await (repo.db.select(repo.db.sharedLedgerAccounts)
          ..where((t) => t.ledgerSyncId.equals(ledger!.syncId!)))
        .get();
    for (final r in rows) {
      if (syntheticIdForSyncId(r.syncId) == accountId) return r.syncId;
    }
    return null;
  }

  Future<void> _loadFrequentNotes() async {
    final repo = ref.read(repositoryProvider);
    final notes = await NoteHistoryService.getHistoryNotes(
      repository: repo,
      ledgerId: ref.read(currentLedgerIdProvider),
      scope: ref.read(noteHistoryScopeProvider),
      sort: ref.read(noteHistorySortProvider),
      categoryId: null,
      categorySyncId: null,
      limit: ref.read(noteHistoryLimitProvider),
    );
    if (!mounted) return;
    setState(() => _frequentNotes = notes);
  }

  Future<void> _openNoteHistory() async {
    await showDialog(
      context: context,
      builder: (context) => NotePickerDialog(
        ledgerId: ref.read(currentLedgerIdProvider),
        onNotePicked: (note) {
          _noteCtrl.text = note;
          _noteCtrl.selection =
              TextSelection.fromPosition(TextPosition(offset: note.length));
        },
      ),
    );
  }

  Future<void> _pickTransferDate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    final showTime = ref.read(showTransactionTimeProvider);
    if (showTime) {
      final res = await showWheelDateTimePicker(
        context,
        initial: _date,
      );
      if (res != null && mounted) setState(() => _date = res);
    } else {
      final res = await showWheelDatePicker(
        context,
        initial: _date,
        mode: WheelDatePickerMode.ymd,
      );
      if (res != null && mounted) setState(() => _date = res);
    }
  }

  Future<void> _pickTransferTag() async {
    final result = await TagSelector.show(context, selectedTagIds: _tagIds);
    if (result != null && mounted) {
      setState(() => _tagIds = result);
    }
  }

  int? _pinnedIdFor(String side) {
    if (widget.editingTransactionId == null) return null;
    return side == 'from'
        ? widget.initialFromAccountId
        : widget.initialToAccountId;
  }

  /// v5.5: 转出/转入完全独立选择——点哪端只弹哪端抽屉，不再自动连选
  Future<void> _pickFromAccount() async {
    final l10n = AppLocalizations.of(context);
    final from = await showAccountDrawerSheet(
      context,
      title: l10n.transferFromAccount,
      initialAccount: _fromAccount,
      excludedAccountId: _toAccountId,
      pinnedAccountId: _pinnedIdFor('from'),
    );
    if (from == null || !mounted) return;
    setState(() {
      _fromAccount = from;
      _fromAccountId = from.id;
      if (_toAccountId == from.id) {
        _toAccount = null;
        _toAccountId = null;
      }
    });
  }

  /// v5.5: 转入独立选择，排除已选转出账户
  Future<void> _pickToAccount() async {
    final l10n = AppLocalizations.of(context);
    final to = await showAccountDrawerSheet(
      context,
      title: l10n.transferToAccount,
      initialAccount: _toAccount,
      excludedAccountId: _fromAccountId,
      pinnedAccountId: _pinnedIdFor('to'),
    );
    if (to != null && mounted) {
      setState(() {
        _toAccount = to;
        _toAccountId = to.id;
      });
    }
  }

  // 金额独立填写，不依赖账户选择；提交时才校验两端账户
  Future<void> _openAmountSheet() async {
    final l10n = AppLocalizations.of(context);

    // 两端已选时做币种守卫(跨币种转账守卫,.docs/multi-currency-ledger 01 §4.4)
    if (_fromAccountId != null && _toAccountId != null) {
      final sameCurrency = await _checkSameCurrency();
      if (!sameCurrency) {
        // 存量数据放行(2026-07-12 细则):编辑模式且账户对未改动(老数据在
        // 守卫上线前就是跨币种)→ 放行让用户能改备注/日期等,不强迫重选账户。
        final isOriginalPair = widget.editingTransactionId != null &&
            _fromAccountId == widget.initialFromAccountId &&
            _toAccountId == widget.initialToAccountId;
        if (!isOriginalPair) {
          if (mounted) {
            showToast(context, l10n.transferDifferentCurrencyError);
            setState(() {
              _toAccountId = null;
              _toAccount = null;
            });
          }
          return;
        }
      }
    }

    final ledgerId = ref.read(currentLedgerIdProvider);

    if (!mounted) return;

    final result = await showModalBottomSheet<
        ({double amount, String currencyCode})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BeeTokens.surfaceSheet(context),
      builder: (_) => AmountEditorSheet(
        categoryName: l10n.transferTitle,
        initialDate: _date,
        initialAmount: _amount,
        initialNote: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
        initialTagIds: _tagIds,
        showAccountPicker: false,
        ledgerId: ledgerId,
        editingTransactionId: widget.editingTransactionId,
        transactionKind: 'transfer',
        confirmOnly: true,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _amount = result.amount;
        _pickedCurrency = result.currencyCode;
      });
    }
  }

  Future<void> _performTransferSave(
    BuildContext? sheetContext,
    AmountEditorResult result,
    int ledgerId, {
    required bool exitAfterSave,
  }) async {
    final l10n = AppLocalizations.of(context);
    _amount = result.amount;
    if (_fromAccountId == null || _toAccountId == null) {
      if (mounted) {
        showToast(context, l10n.transferSelectAccount);
      }
      return;
    }
    final repo = ref.read(repositoryProvider);
    final attachmentService = ref.read(attachmentServiceProvider);
    // 获取虚拟转账分类ID
    final transferCategory = await ref.read(transferCategoryProvider.future);
    final transferCategoryId = transferCategory.id;
    int? savedTxId;

    // §7 共享账本:Editor picker 给的是 synthetic Account(负数 id)。
    // 写本地 Drift 时 accountId / toAccountId 留 null,override 字段
    // 走 Owner 的 syncId;push 序列化时按 override 输出 payload。
    final isSyntheticFrom = _fromAccountId != null && _fromAccountId! < 0;
    final isSyntheticTo = _toAccountId != null && _toAccountId! < 0;
    final fromAccountForAdd = isSyntheticFrom ? null : _fromAccountId;
    final toAccountForAdd = isSyntheticTo ? null : _toAccountId;
    final fromOverride = isSyntheticFrom
        ? await _resolveSyncIdByAccountId(_fromAccountId!, ledgerId)
        : null;
    final toOverride = isSyntheticTo
        ? await _resolveSyncIdByAccountId(_toAccountId!, ledgerId)
        : null;

    try {
      if (widget.editingTransactionId != null) {
        // 编辑模式：更新现有转账记录
        await repo.updateTransaction(
          id: widget.editingTransactionId!,
          type: 'transfer',
          amount: result.amount,
          categoryId: transferCategoryId, // 使用虚拟转账分类ID
          note: result.note,
          happenedAt: result.date,
          accountId: d.Value<int?>(fromAccountForAdd),
          accountSyncIdOverride: fromOverride,
        );
        // 更新 toAccountId(同时写 toAccountSyncIdOverride,共享账本场景)
        await repo.updateTransactionFields(
          id: widget.editingTransactionId!,
          toAccountId: d.Value<int?>(toAccountForAdd),
          toAccountSyncIdOverride: toOverride,
          writeToAccountSyncIdOverride: true,
        );
        // 共享账本:回填编辑人,UI 头像组立即展示
        await TxAuthorService.markEdited(ref, widget.editingTransactionId!);
        // 更新标签
        if (result.tagIds.isNotEmpty) {
          await repo.updateTransactionTags(
            transactionId: widget.editingTransactionId!,
            tagIds: result.tagIds,
          );
          ref.read(tagListRefreshProvider.notifier).state++;
        } else {
          await repo.removeAllTagsFromTransaction(
              widget.editingTransactionId!);
          ref.read(tagListRefreshProvider.notifier).state++;
        }
      } else {
        // 创建模式：新建转账记录
        final txId = await repo.addTransaction(
          ledgerId: ledgerId,
          type: 'transfer',
          amount: result.amount,
          categoryId: transferCategoryId, // 使用虚拟转账分类ID
          accountId: fromAccountForAdd,
          toAccountId: toAccountForAdd,
          accountSyncIdOverride: fromOverride,
          toAccountSyncIdOverride: toOverride,
          note: result.note,
          happenedAt: result.date,
        );
        savedTxId = txId;
        // 共享账本:本地立即标记创建人 + 编辑人
        await TxAuthorService.markCreated(ref, txId);
        // 关联标签
        if (result.tagIds.isNotEmpty) {
          await repo.updateTransactionTags(
            transactionId: txId,
            tagIds: result.tagIds,
          );
          ref.read(tagListRefreshProvider.notifier).state++;
        }
      }

      // 保存待上传的附件
      if (result.pendingAttachments.isNotEmpty) {
        await attachmentService.saveAttachments(
          transactionId: savedTxId ?? widget.editingTransactionId ?? 0,
          sourceFiles: result.pendingAttachments,
          startIndex: 0,
        );
        ref.read(attachmentListRefreshProvider.notifier).state++;
      }

      // 统一处理：自动/手动同步与状态刷新
      await PostProcessor.sync(ref, ledgerId: ledgerId);
      ref.invalidate(countsForLedgerProvider(ledgerId));
      ref.read(statsRefreshProvider.notifier).state++;

      if (!mounted) return;
      if (exitAfterSave) {
        if (sheetContext != null &&
            sheetContext.mounted &&
            Navigator.of(sheetContext).canPop()) {
          Navigator.of(sheetContext).pop();
        }
        showToast(
          context,
          widget.editingTransactionId != null
              ? l10n.transferUpdateSuccess
              : l10n.transferCreateSuccess,
        );
        widget.onTransferComplete();
        // 保存后跳到首页「明细」流水列表
        ref.read(bottomTabIndexProvider.notifier).state = 0;
      } else {
        // 再记一笔：保留转出/转入/时间，清空金额/标签/备注
        showToast(
          context,
          widget.editingTransactionId != null
              ? l10n.transferUpdateSuccess
              : l10n.transferCreateSuccess,
        );
        setState(() {
          _amount = 0;
          _tagIds = [];
          _noteCtrl.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        if (sheetContext != null &&
            sheetContext.mounted &&
            Navigator.of(sheetContext).canPop()) {
          Navigator.of(sheetContext).pop();
        }
        showToast(context, '${l10n.commonError}: $e');
      }
    }
  }

  /// 底部「再记一笔 / 保存」直接提交，不经过金额小键盘。
  Future<void> _save({required bool exitAfterSave}) async {
    final l10n = AppLocalizations.of(context);
    if (_amount <= 0) {
      showToast(context, l10n.txAmountRequired);
      return;
    }
    if (_fromAccountId == null || _toAccountId == null) {
      showToast(context, l10n.transferSelectAccount);
      return;
    }
    final ledgerId = ref.read(currentLedgerIdProvider);
    final ledgerBase = ref.read(currentLedgerCurrencyProvider);
    final result = (
      amount: _amount,
      note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
      date: _date,
      accountId: _fromAccountId,
      tagIds: _tagIds,
      pendingAttachments: const <File>[],
      excludeFromStats: false,
      excludeFromBudget: false,
      currencyCode: _pickedCurrency ?? ledgerBase,
      nativeAmount: _pickedCurrency == null || _pickedCurrency == ledgerBase
          ? _amount
          : _amount,
    );
    await _performTransferSave(
      null,
      result,
      ledgerId,
      exitAfterSave: exitAfterSave,
    );
  }

  void _swapTransferAccounts() {
    if (_fromAccount == null || _toAccount == null) return;
    setState(() {
      final tmpAccount = _fromAccount;
      _fromAccount = _toAccount;
      _toAccount = tmpAccount;
      final tmpId = _fromAccountId;
      _fromAccountId = _toAccountId;
      _toAccountId = tmpId;
    });
  }

  /// 账户行：转出 | 转入 两格布局，中间固定反转按钮（v5.5）
  Widget _buildTransferAccountRow(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final canSwap = _fromAccount != null && _toAccount != null;
    return Material(
      color: BeeTokens.surfaceSheet(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: _buildAccountSide(
                context,
                l10n,
                side: 'from',
                onTap: _pickFromAccount,
              ),
            ),
            const SizedBox(width: 4),
            // 固定宽度列，两侧名称长度变化不移动按钮
            SizedBox(
              width: 44,
              child: IconButton(
                onPressed: canSwap ? _swapTransferAccounts : null,
                icon: const Icon(Icons.swap_horiz, size: 22),
                tooltip: l10n.txSwapAccounts,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildAccountSide(
                context,
                l10n,
                side: 'to',
                onTap: _pickToAccount,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 转出/转入单格：左上灰字标签 + 账户名（未选显示「请选择」）
  Widget _buildAccountSide(
    BuildContext context,
    AppLocalizations l10n, {
    required String side,
    required VoidCallback onTap,
  }) {
    final isFrom = side == 'from';
    final account = isFrom ? _fromAccount : _toAccount;
    final label = isFrom ? l10n.txTransferFrom : l10n.txTransferTo;
    final selected = account != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: BeeTokens.surfaceInput(context),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
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
            Text(
              account?.name ?? l10n.txFormPleaseSelect,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: selected
                    ? BeeTokens.textPrimary(context)
                    : BeeTokens.textTertiary(context),
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, AppLocalizations l10n) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: BeeTokens.surfaceSheet(context),
          border: Border(
            top: BorderSide(color: BeeTokens.divider(context)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _save(exitAfterSave: false),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(l10n.txSaveAndContinue),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _save(exitAfterSave: true),
                icon: const Icon(Icons.check, size: 18),
                label: Text(l10n.commonSave),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferFieldRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    final primary = ref.watch(primaryColorProvider);
    return Material(
      color: BeeTokens.surfaceSheet(context),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 20, color: BeeTokens.iconSecondary(context)),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: BeeTokens.textSecondary(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    color: selected
                        ? primary
                        : BeeTokens.textTertiary(context),
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: BeeTokens.iconTertiary(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransferNoteField(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: BeeTokens.surfaceSheet(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.edit_note_outlined,
                  size: 18,
                  color: BeeTokens.iconSecondary(context),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.txFormNote,
                  style: TextStyle(
                    fontSize: 13,
                    color: BeeTokens.textSecondary(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _noteCtrl,
                    focusNode: _noteFocusNode,
                    minLines: 1,
                    maxLines: 3,
                    style: TextStyle(
                      fontSize: 15,
                      color: BeeTokens.textPrimary(context),
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.txFormNoteHint,
                      hintStyle: TextStyle(
                        color: BeeTokens.textTertiary(context),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                if (_frequentNotes.isNotEmpty)
                  IconButton(
                    onPressed: _openNoteHistory,
                    icon: Icon(
                      Icons.history,
                      size: 20,
                      color: BeeTokens.iconSecondary(context),
                    ),
                    tooltip: l10n.txFormNote,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTransferDate() {
    return formatEntryDateTime(
      context,
      _date,
      showTime: ref.read(showTransactionTimeProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currency = ref.watch(currentLedgerCurrencyProvider);
    final tagsAsync = ref.watch(tagsForCurrentLedgerProvider);
    final tags = tagsAsync.valueOrNull ?? [];
    final selectedTags = tags.where((t) => _tagIds.contains(t.id)).toList();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildTransferFieldRow(
                icon: Icons.keyboard_alt_outlined,
                label: l10n.txFormAmount,
                value: _amount == 0
                    ? '${getCurrencySymbol(currency)} 0.00'
                    : '${getCurrencySymbol(currency)} ${formatMoneyCompact(_amount)}',
                selected: _amount > 0,
                onTap: _openAmountSheet,
              ),
              // v5.5: 字段行间浅灰分隔线
              Divider(
                height: 13,
                thickness: 0.5,
                color: BeeTokens.divider(context),
              ),
              _buildTransferAccountRow(context, l10n),
              Divider(
                height: 13,
                thickness: 0.5,
                color: BeeTokens.divider(context),
              ),
              _buildTransferFieldRow(
                icon: Icons.schedule_outlined,
                label: l10n.txFormTime,
                value: _formatTransferDate(),
                selected: true,
                onTap: _pickTransferDate,
              ),
              Divider(
                height: 13,
                thickness: 0.5,
                color: BeeTokens.divider(context),
              ),
              _buildTransferFieldRow(
                icon: Icons.label_outline,
                label: l10n.txFormTag,
                value: selectedTags.isEmpty
                    ? l10n.tagSelectTitle
                    : selectedTags.map((t) => t.name).join('、'),
                selected: selectedTags.isNotEmpty,
                onTap: _pickTransferTag,
              ),
              Divider(
                height: 13,
                thickness: 0.5,
                color: BeeTokens.divider(context),
              ),
              _buildTransferNoteField(context),
            ],
          ),
        ),
        _buildBottomBar(context, l10n),
      ],
    );
  }
}
