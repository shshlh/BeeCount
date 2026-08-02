import 'package:drift/drift.dart' as d;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart';
import '../../data/repositories/local/local_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../models/note_history.dart';
import '../../pages/category/category_manage_page.dart';
import '../../pages/tag/widgets/tag_selector.dart';
import '../../providers.dart';
import '../../providers/budget_providers.dart';
import '../../services/attachment_service.dart';
import '../../services/billing/post_processor.dart';
import '../../services/data/note_history_service.dart';
import '../../services/data/tx_author_service.dart';
import '../../styles/tokens.dart';
import '../../utils/account_type_utils.dart';
import '../../utils/category_utils.dart';
import '../../utils/currencies.dart';
import '../../utils/shared_ledger_picker_filter.dart';
import 'account_drawer_sheet.dart';
import '../biz/amount_editor_sheet.dart';
import '../biz/format_money.dart';
import '../biz/note_picker_dialog.dart';
import '../category_icon.dart';
import '../ui/wheel_date_picker.dart';

/// 记账页表单体（v5.1 记账界面体验优化）
///
/// 字段顺序：金额-分类-账户-时间-标签-备注，全部独立填写；金额不再要求
/// 分类前置。支出/收入共用；转账仍走 [TransferForm]。
class TxEntryForm extends ConsumerStatefulWidget {
  final String kind; // 'expense' / 'income'
  final int? initialCategoryId;
  final String? initialNote;
  final double? initialAmount;
  final DateTime? initialDate;
  final int? editingTransactionId;
  final int? initialAccountId;
  final List<int>? initialTagIds;
  final bool initialExcludeFromStats;
  final bool initialExcludeFromBudget;
  final String? initialCurrencyCode;
  final double? initialNativeAmount;

  const TxEntryForm({
    super.key,
    required this.kind,
    this.initialCategoryId,
    this.initialNote,
    this.initialAmount,
    this.initialDate,
    this.editingTransactionId,
    this.initialAccountId,
    this.initialTagIds,
    this.initialExcludeFromStats = false,
    this.initialExcludeFromBudget = false,
    this.initialCurrencyCode,
    this.initialNativeAmount,
  });

  @override
  ConsumerState<TxEntryForm> createState() => _TxEntryFormState();
}

class _TxEntryFormState extends ConsumerState<TxEntryForm> {
  Category? _category;
  Category? _parentCategory;
  Account? _account;
  late DateTime _date;
  double _amount = 0;
  List<int> _tagIds = [];
  late final TextEditingController _noteCtrl;
  final FocusNode _noteFocusNode = FocusNode();
  List<NoteHistoryEntry> _frequentNotes = [];

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? DateTime.now();
    _amount = widget.initialAmount ?? 0;
    _tagIds = List.from(widget.initialTagIds ?? []);
    _noteCtrl = TextEditingController(text: widget.initialNote ?? '');
    _resolveInitials();
    _loadFrequentNotes();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  Future<void> _resolveInitials() async {
    final categoryId = widget.initialCategoryId;
    if (categoryId != null) {
      final c = await _resolveCategory(categoryId);
      if (c != null && mounted) {
        setState(() {
          _category = c;
          if (c.level == 2 && c.parentId != null) {
            _resolveParent(c.parentId!);
          }
        });
        _loadFrequentNotes();
      }
    }
    final accountId = widget.initialAccountId;
    if (accountId != null) {
      final a = await _resolveAccount(accountId);
      if (a != null && mounted) {
        setState(() => _account = a);
      }
    }
  }

  Future<void> _resolveParent(int parentId) async {
    final parent = await _resolveCategory(parentId);
    if (parent != null && mounted) {
      setState(() => _parentCategory = parent);
    }
  }

  Future<Category?> _resolveCategory(int id) async {
    final repo = ref.read(repositoryProvider);
    if (repo is LocalRepository) {
      return repo.db.findCategoryBySyntheticId(id);
    }
    return repo.getCategoryById(id);
  }

  Future<Account?> _resolveAccount(int id) async {
    final repo = ref.read(repositoryProvider);
    if (repo is LocalRepository) {
      return repo.db.findAccountBySyntheticId(id);
    }
    return repo.getAccount(id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ref.watch(showTransactionTimeProvider);
    final currency = ref.watch(currentLedgerCurrencyProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildFieldRow(
          icon: Icons.keyboard_alt_outlined,
          label: l10n.txFormAmount,
          value: _amount == 0
              ? '${getCurrencySymbol(currency)} 0.00'
              : '${getCurrencySymbol(currency)} ${formatMoneyCompact(_amount)}',
          selected: _amount > 0,
          onTap: _openAmountSheet,
        ),
        const SizedBox(height: 12),
        _buildFieldRow(
          icon: Icons.category_outlined,
          label: l10n.txFormCategory,
          value: _category == null
              ? l10n.txFormCategoryHint
              : _categoryLabel(context),
          selected: _category != null,
          onTap: _pickCategory,
        ),
        const SizedBox(height: 12),
        _buildFieldRow(
          icon: Icons.account_balance_wallet_outlined,
          label: l10n.txFormAccount,
          value: _account == null
              ? l10n.txFormAccountHint
              : _accountLabel(context),
          selected: _account != null,
          onTap: _pickAccount,
        ),
        const SizedBox(height: 12),
        _buildFieldRow(
          icon: Icons.schedule_outlined,
          label: l10n.txFormTime,
          value: _formatDateTime(context),
          selected: true,
          onTap: _pickDateTime,
        ),
        const SizedBox(height: 12),
        _buildTagRow(context),
        const SizedBox(height: 12),
        _buildNoteField(context),
      ],
    );
  }

  Widget _buildFieldRow({
    required IconData icon,
    required String label,
    required String value,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: BeeTokens.surfaceSheet(context),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
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

  Widget _buildTagRow(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tagsAsync = ref.watch(tagsForCurrentLedgerProvider);
    final tags = tagsAsync.valueOrNull ?? [];
    final selected = tags.where((t) => _tagIds.contains(t.id)).toList();
    final value = selected.isEmpty
        ? l10n.tagSelectTitle
        : selected.map((t) => t.name).join('、');
    return _buildFieldRow(
      icon: Icons.label_outline,
      label: l10n.txFormTag,
      value: value,
      selected: selected.isNotEmpty,
      onTap: _pickTag,
    );
  }

  /// 备注行内填写：多行 TextField + 高频备注历史入口（不弹备注编辑框）
  Widget _buildNoteField(BuildContext context) {
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

  String _categoryLabel(BuildContext context) {
    final c = _category;
    if (c == null) return AppLocalizations.of(context).txFormCategoryHint;
    final own = CategoryUtils.getDisplayName(c.name, context, kind: widget.kind);
    final parent = _parentCategory;
    if (parent != null) {
      final parentName =
          CategoryUtils.getDisplayName(parent.name, context, kind: widget.kind);
      return '$parentName > $own';
    }
    return own;
  }

  String _accountLabel(BuildContext context) {
    final a = _account;
    if (a == null) return AppLocalizations.of(context).txFormAccountHint;
    return '${a.name} · ${getAccountTypeLabel(context, a.type)}';
  }

  String _formatDateTime(BuildContext context) {
    final showTime = ref.read(showTransactionTimeProvider);
    final date = '${_date.year}/${_date.month}/${_date.day}';
    if (!showTime) return date;
    final hh = _date.hour.toString().padLeft(2, '0');
    final mm = _date.minute.toString().padLeft(2, '0');
    return '$date $hh:$mm';
  }

  Future<void> _loadFrequentNotes() async {
    final repo = ref.read(repositoryProvider);
    final category = _category;
    final notes = await NoteHistoryService.getHistoryNotes(
      repository: repo,
      ledgerId: ref.read(currentLedgerIdProvider),
      scope: ref.read(noteHistoryScopeProvider),
      sort: ref.read(noteHistorySortProvider),
      categoryId: category != null && category.id >= 0 ? category.id : null,
      categorySyncId: category != null && category.id < 0
          ? category.syncId
          : null,
      limit: ref.read(noteHistoryLimitProvider),
    );
    if (!mounted) return;
    setState(() => _frequentNotes = notes);
  }

  Future<void> _openNoteHistory() async {
    final category = _category;
    await showDialog(
      context: context,
      builder: (context) => NotePickerDialog(
        ledgerId: ref.read(currentLedgerIdProvider),
        categoryId: category != null && category.id >= 0 ? category.id : null,
        categorySyncId: category != null && category.id < 0
            ? category.syncId
            : null,
        onNotePicked: (note) {
          _noteCtrl.text = note;
          _noteCtrl.selection =
              TextSelection.fromPosition(TextPosition(offset: note.length));
        },
      ),
    );
  }

  Future<void> _pickCategory() async {
    final result = await _showCategoryDrawer(
      context,
      kind: widget.kind,
      initialCategory: _category,
    );
    if (result != null && mounted) {
      setState(() {
        _category = result.category;
        _parentCategory = result.parent;
      });
      _loadFrequentNotes();
    }
  }

  Future<void> _pickAccount() async {
    final account = await showAccountDrawerSheet(
      context,
      title: AppLocalizations.of(context).txFormAccount,
      initialAccount: _account,
      pinnedAccountId: widget.editingTransactionId != null
          ? widget.initialAccountId
          : null,
    );
    if (account != null && mounted) {
      setState(() => _account = account);
    }
  }

  Future<void> _pickTag() async {
    final result = await TagSelector.show(context, selectedTagIds: _tagIds);
    if (result != null && mounted) {
      setState(() => _tagIds = result);
    }
  }

  Future<void> _pickDateTime() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    final showTime = ref.read(showTransactionTimeProvider);
    if (showTime) {
      final res = await showWheelDateTimePicker(
        context,
        initial: _date,
        maxDate: DateTime.now(),
      );
      if (res != null && mounted) setState(() => _date = res);
    } else {
      final res = await showWheelDatePicker(
        context,
        initial: _date,
        mode: WheelDatePickerMode.ymd,
        maxDate: DateTime.now(),
      );
      if (res != null && mounted) setState(() => _date = res);
    }
  }

  /// 获取默认账户ID（验证币种匹配）
  Future<int?> _getDefaultAccountId(String kind, int ledgerId) async {
    try {
      final defaultAccountId = kind == 'income'
          ? await ref.read(defaultIncomeAccountIdProvider.future)
          : await ref.read(defaultExpenseAccountIdProvider.future);

      if (defaultAccountId == null) return null;

      final ledger = await ref.read(ledgerByIdProvider(ledgerId).future);
      if (ledger == null) return null;

      final account =
          await ref.read(accountByIdProvider(defaultAccountId).future);
      if (account == null) return null;

      // 账户隐藏 #240 E3:默认账户已被隐藏时按「无默认」处理
      if (account.hidden) return null;
      if (account.currency != ledger.currency) return null;

      return defaultAccountId;
    } catch (e) {
      return null;
    }
  }

  Future<void> _openAmountSheet() async {
    final ledgerId = ref.read(currentLedgerIdProvider);
    int? accountId = _account?.id;
    if (widget.editingTransactionId == null && accountId == null) {
      accountId = await _getDefaultAccountId(widget.kind, ledgerId);
    }
    if (!mounted) return;

    final category = _category;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BeeTokens.surfaceSheet(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => AmountEditorSheet(
        categoryName: category?.name ?? '',
        categoryId: category != null && category.id >= 0 ? category.id : null,
        categorySyncId: category != null && category.id < 0
            ? category.syncId
            : null,
        initialDate: _date,
        initialAmount: _amount,
        initialNote: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
        initialAccountId: accountId,
        initialTagIds: _tagIds,
        showAccountPicker: false,
        ledgerId: ledgerId,
        editingTransactionId: widget.editingTransactionId,
        transactionKind: widget.kind,
        initialExcludeFromStats: widget.initialExcludeFromStats,
        initialExcludeFromBudget: widget.initialExcludeFromBudget,
        initialCurrencyCode: widget.initialCurrencyCode,
        initialNativeAmount: widget.initialNativeAmount,
        onSubmit: (res) => _submitTransaction(sheetContext, res, ledgerId),
      ),
    );
  }

  Future<void> _submitTransaction(
    BuildContext sheetContext,
    AmountEditorResult res,
    int ledgerId,
  ) async {
    final repo = ref.read(repositoryProvider);
    final attachmentService = ref.read(attachmentServiceProvider);
    final category = _category;
    final context = this.context;
    int transactionId;

    // §7 v25:Category 是来自 SharedLedger* 的 synthetic (id<0)时,
    // categoryId 留 null,override 走 syncId。同理对 account。
    final isSyntheticCategory = category != null && category.id < 0;
    final isSyntheticAccount = res.accountId != null && res.accountId! < 0;
    final categoryIdForWrite =
        category != null && !isSyntheticCategory ? category.id : null;
    final accountIdForAdd = isSyntheticAccount ? null : res.accountId;
    final accountIdForUpdate = d.Value<int?>(accountIdForAdd);
    final categoryOverride = isSyntheticCategory ? category.syncId : null;
    final accountOverride = isSyntheticAccount
        ? await _resolveSyncIdByAccountId(res.accountId!, ledgerId)
        : null;

    if (widget.editingTransactionId != null) {
      await repo.updateTransaction(
        id: widget.editingTransactionId!,
        type: widget.kind,
        amount: res.amount,
        categoryId: categoryIdForWrite,
        note: res.note,
        happenedAt: res.date,
        accountId: accountIdForUpdate,
        categorySyncIdOverride: categoryOverride,
        accountSyncIdOverride: accountOverride,
        excludeFromStats: res.excludeFromStats,
        excludeFromBudget: res.excludeFromBudget,
        currencyCode: res.currencyCode,
        nativeAmount: res.nativeAmount,
      );
      transactionId = widget.editingTransactionId!;
      await TxAuthorService.markEdited(ref, transactionId);
    } else {
      transactionId = await repo.addTransaction(
        ledgerId: ledgerId,
        type: widget.kind,
        amount: res.amount,
        categoryId: categoryIdForWrite,
        happenedAt: res.date,
        note: res.note,
        accountId: accountIdForAdd,
        categorySyncIdOverride: categoryOverride,
        accountSyncIdOverride: accountOverride,
        excludeFromStats: res.excludeFromStats,
        excludeFromBudget: res.excludeFromBudget,
        currencyCode: res.currencyCode,
        nativeAmount: res.nativeAmount,
      );
      await TxAuthorService.markCreated(ref, transactionId);
    }

    // 保存待上传的附件
    if (res.pendingAttachments.isNotEmpty) {
      await attachmentService.saveAttachments(
        transactionId: transactionId,
        sourceFiles: res.pendingAttachments,
        startIndex: 0,
      );
      ref.read(attachmentListRefreshProvider.notifier).state++;
    }

    // §7 共享账本:tag.id < 0 是 synthetic,不能直接写 transaction_tags。
    final normalTagIds = res.tagIds.where((id) => id >= 0).toList();
    final syntheticTagIds = res.tagIds.where((id) => id < 0).toList();

    if (normalTagIds.isNotEmpty) {
      await repo.updateTransactionTags(
        transactionId: transactionId,
        tagIds: normalTagIds,
      );
      ref.read(tagListRefreshProvider.notifier).state++;
    } else if (widget.editingTransactionId != null) {
      await repo.removeAllTagsFromTransaction(transactionId);
      ref.read(tagListRefreshProvider.notifier).state++;
    }

    if (repo is LocalRepository) {
      final txRow = await (repo.db.select(repo.db.transactions)
            ..where((t) => t.id.equals(transactionId)))
          .getSingleOrNull();
      final txSyncId = txRow?.syncId;
      if (txSyncId != null) {
        await (repo.db.delete(repo.db.transactionTagOverrides)
              ..where((t) => t.transactionSyncId.equals(txSyncId)))
            .go();
        if (syntheticTagIds.isNotEmpty) {
          final allShared = await repo.db.select(repo.db.sharedLedgerTags).get();
          final now = DateTime.now().toUtc();
          for (final sid in syntheticTagIds) {
            for (final s in allShared) {
              if (syntheticIdForSyncId(s.syncId) == sid) {
                await repo.db.into(repo.db.transactionTagOverrides).insert(
                  TransactionTagOverridesCompanion.insert(
                    transactionSyncId: txSyncId,
                    tagSyncId: s.syncId,
                    createdAt: now,
                  ),
                );
                break;
              }
            }
          }
          ref.read(tagListRefreshProvider.notifier).state++;
        }
      }
    }

    PostProcessor.sync(ref, ledgerId: ledgerId);
    ref.invalidate(countsForLedgerProvider(ledgerId));
    ref.read(statsRefreshProvider.notifier).state++;
    ref.read(budgetRefreshProvider.notifier).state++;
    if (context.mounted) {
      updateAppWidget(ref, context);
    }

    if (sheetContext.mounted && Navigator.of(sheetContext).canPop()) {
      Navigator.of(sheetContext).pop();
    }
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);
  }

  /// §7 v25:account picker 返 synthetic Account(id<0)时,把 id 反查
  /// SharedLedgerAccounts 拿 syncId,写到 tx.accountSyncIdOverride。
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
}

typedef _CategoryPick = ({Category category, Category? parent});

class _CategoryDrawerData {
  final List<Category> tops;
  final Map<int, List<Category>> subs;

  const _CategoryDrawerData({required this.tops, required this.subs});
}

Future<_CategoryPick?> _showCategoryDrawer(
  BuildContext context, {
  required String kind,
  Category? initialCategory,
}) {
  return showModalBottomSheet<_CategoryPick>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.72,
      child: _CategoryDrawerSheet(
        kind: kind,
        initialCategory: initialCategory,
      ),
    ),
  );
}

/// 底部分类面板：左侧一级竖向导航（选中主题色竖条高亮），右侧二级图标网格 3 列
class _CategoryDrawerSheet extends ConsumerStatefulWidget {
  final String kind;
  final Category? initialCategory;

  const _CategoryDrawerSheet({
    required this.kind,
    this.initialCategory,
  });

  @override
  ConsumerState<_CategoryDrawerSheet> createState() =>
      _CategoryDrawerSheetState();
}

class _CategoryDrawerSheetState extends ConsumerState<_CategoryDrawerSheet> {
  late Future<_CategoryDrawerData> _future;
  int? _selectedTopId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_CategoryDrawerData> _load() async {
    final repo = ref.read(repositoryProvider);
    final cats = await repo.getTopLevelCategories(widget.kind);
    var tops = cats;
    LedgerPickerContext? ctx;
    if (repo is LocalRepository) {
      final ledgerId = ref.read(currentLedgerIdProvider);
      ctx = await repo.db.loadLedgerPickerContext(ledgerId);
      tops = await repo.db.filterCategoriesForLedger(
        cats,
        ctx,
        kind: widget.kind,
      );
    }
    final isSharedEditor = ctx?.isEditorInShared == true;
    final ledgerSyncId = ctx?.ledgerSyncId;
    final subs = <int, List<Category>>{};
    for (final cat in tops) {
      List<Category> children;
      if (isSharedEditor &&
          cat.id < 0 &&
          repo is LocalRepository &&
          ledgerSyncId != null) {
        children = await repo.db
            .getSharedSubCategoriesBySyntheticParentId(cat.id, ledgerSyncId);
      } else {
        children = await repo.getSubCategories(cat.id);
      }
      if (children.isNotEmpty) subs[cat.id] = children;
    }

    final initial = widget.initialCategory;
    int? selected;
    if (initial != null) {
      selected = initial.level == 2 && initial.parentId != null
          ? initial.parentId
          : initial.id;
    }
    if (selected == null || !tops.any((c) => c.id == selected)) {
      selected = tops.isEmpty ? null : tops.first.id;
    }
    _selectedTopId = selected;
    return _CategoryDrawerData(tops: tops, subs: subs);
  }

  void _openCategoryManage() {
    final nav = Navigator.of(context, rootNavigator: true);
    nav.pop();
    nav.push(
      MaterialPageRoute(
        builder: (_) => CategoryManagePage(
          initialTabIndex: widget.kind == 'expense' ? 0 : 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primary = ref.watch(primaryColorProvider);
    return Container(
      decoration: BoxDecoration(
        color: BeeTokens.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
            child: Row(
              children: [
                Text(
                  l10n.txFormCategory,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: BeeTokens.textPrimary(context),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _openCategoryManage,
                  icon: Icon(
                    Icons.edit_outlined,
                    color: BeeTokens.iconSecondary(context),
                  ),
                  tooltip: l10n.mineCategoryManagement,
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: BeeTokens.iconSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<_CategoryDrawerData>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data!;
                final tops = data.tops;
                if (tops.isEmpty) {
                  return Center(child: Text(l10n.categoryEmpty));
                }
                final selectedTopId = _selectedTopId ?? tops.first.id;
                final selectedTop = tops.firstWhere(
                  (c) => c.id == selectedTopId,
                  orElse: () => tops.first,
                );
                final children =
                    data.subs[selectedTop.id] ?? const <Category>[];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 92,
                      color: BeeTokens.surfaceSheet(context),
                      child: ListView.separated(
                        itemCount: tops.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final cat = tops[index];
                          final selected = cat.id == selectedTopId;
                          return InkWell(
                            onTap: () {
                              setState(() => _selectedTopId = cat.id);
                              final subs =
                                  data.subs[cat.id] ?? const <Category>[];
                              // 无二级分类的一级分类：直接选中
                              if (subs.isEmpty) {
                                Navigator.pop(
                                  context,
                                  (category: cat, parent: null),
                                );
                              }
                            },
                            child: Container(
                              height: 64,
                              decoration: BoxDecoration(
                                color: selected
                                    ? primary.withValues(alpha: 0.08)
                                    : Colors.transparent,
                                border: Border(
                                  left: BorderSide(
                                    width: 3,
                                    color: selected
                                        ? primary
                                        : Colors.transparent,
                                  ),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CategoryIconWidget(
                                    category: cat,
                                    size: 26,
                                    color: selected
                                        ? primary
                                        : BeeTokens.iconSecondary(context),
                                  ),
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: Text(
                                      CategoryUtils.getDisplayName(
                                        cat.name,
                                        context,
                                        kind: widget.kind,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: selected
                                            ? primary
                                            : BeeTokens.textSecondary(context),
                                        fontWeight: selected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              CategoryUtils.getDisplayName(
                                selectedTop.name,
                                context,
                                kind: widget.kind,
                              ),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: BeeTokens.textPrimary(context),
                              ),
                            ),
                          ),
                          Expanded(
                            child: children.isEmpty
                                ? Center(
                                    child: Text(
                                      l10n.categoryEmpty,
                                      style: TextStyle(
                                        color: BeeTokens.textTertiary(context),
                                      ),
                                    ),
                                  )
                                : GridView.builder(
                                    padding: const EdgeInsets.all(12),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 0.9,
                                    ),
                                    itemCount: children.length,
                                    itemBuilder: (context, index) {
                                      final child = children[index];
                                      return _CategoryGridItem(
                                        category: child,
                                        selected: widget
                                                .initialCategory?.id ==
                                            child.id,
                                        onTap: () => Navigator.pop(
                                          context,
                                          (
                                            category: child,
                                            parent: selectedTop,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryGridItem extends StatelessWidget {
  final Category category;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryGridItem({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CategoryIconWidget(
            category: category,
            size: 30,
            color: selected ? primary : BeeTokens.iconSecondary(context),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              CategoryUtils.getDisplayName(
                category.name,
                context,
                kind: category.kind,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: BeeTokens.textSecondary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

