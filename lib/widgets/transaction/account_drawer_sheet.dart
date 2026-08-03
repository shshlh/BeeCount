import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart';
import '../../data/repositories/base_repository.dart';
import '../../data/repositories/local/local_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../pages/account/accounts_page.dart';
import '../../providers.dart';
import '../../styles/tokens.dart';
import '../../utils/account_type_utils.dart';
import '../../utils/currencies.dart';
import '../../utils/shared_ledger_picker_filter.dart';
import '../biz/format_money.dart';

class _AccountDrawerData {
  final List<String> types;
  final Map<String, List<Account>> accountsByType;
  final Map<int, double> balances;

  const _AccountDrawerData({
    required this.types,
    required this.accountsByType,
    required this.balances,
  });
}

/// 账户选择抽屉（v5.2 公共组件，支出/收入/转账共用）
///
/// 左侧一级账户类型竖向导航，右侧该类型账户一户一行 + 余额。
/// [excludedAccountId] 用于转账选转入账户时排除已选转出账户。
Future<Account?> showAccountDrawerSheet(
  BuildContext context, {
  String? title,
  Account? initialAccount,
  int? pinnedAccountId,
  int? excludedAccountId,
}) {
  return showModalBottomSheet<Account>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.6,
      child: _AccountDrawerSheet(
        title: title,
        initialAccount: initialAccount,
        pinnedAccountId: pinnedAccountId,
        excludedAccountId: excludedAccountId,
      ),
    ),
  );
}

class _AccountDrawerSheet extends ConsumerStatefulWidget {
  final String? title;
  final Account? initialAccount;
  final int? pinnedAccountId;
  final int? excludedAccountId;

  const _AccountDrawerSheet({
    this.title,
    this.initialAccount,
    this.pinnedAccountId,
    this.excludedAccountId,
  });

  @override
  ConsumerState<_AccountDrawerSheet> createState() =>
      _AccountDrawerSheetState();
}

class _AccountDrawerSheetState extends ConsumerState<_AccountDrawerSheet> {
  late Future<_AccountDrawerData> _future;
  String? _selectedType;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Account?> _lookupAccount(BaseRepository repo, int id) async {
    if (repo is LocalRepository) return repo.db.findAccountBySyntheticId(id);
    return repo.getAccount(id);
  }

  Future<_AccountDrawerData> _load() async {
    final repo = ref.read(repositoryProvider);
    final all = await repo.getAllAccounts();
    var accounts = all;
    String currency = 'CNY';
    if (repo is LocalRepository) {
      final ledgerId = ref.read(currentLedgerIdProvider);
      final ctx = await repo.db.loadLedgerPickerContext(ledgerId);
      accounts = await repo.db.filterAccountsForLedger(all, ctx);
      final ledger = await repo.getLedgerById(ledgerId);
      currency = ledger?.currency ?? 'CNY';
    } else {
      currency = ref.read(currentLedgerProvider).valueOrNull?.currency ?? 'CNY';
    }

    // v5.0: 放开债权/负债账户，投资账户仍不可选；隐藏账户由
    // filterAccountsForLedger 排除（编辑态钉住的隐藏账户补回）
    var visible = accounts
        .where((a) =>
            a.currency == currency &&
            isBookingAccountType(a.type) &&
            a.id != widget.excludedAccountId)
        .toList();
    final pinnedId = widget.pinnedAccountId;
    if (pinnedId != null &&
        pinnedId != widget.excludedAccountId &&
        !visible.any((a) => a.id == pinnedId)) {
      final pinned = await _lookupAccount(repo, pinnedId);
      if (pinned != null && pinned.hidden) {
        visible = [...visible, pinned];
      }
    }

    Map<int, double> balances = const {};
    try {
      balances = await repo.getAllAccountBalances(
        ref.read(currentLedgerIdProvider),
      );
    } catch (_) {
      balances = const {};
    }

    final byType = <String, List<Account>>{};
    for (final a in visible) {
      final t = normalizeAccountType(a.type);
      byType.putIfAbsent(t, () => []).add(a);
    }
    final types = allAccountTypes.where(byType.containsKey).toList();
    final initial = widget.initialAccount;
    final initialType =
        initial != null ? normalizeAccountType(initial.type) : null;
    final selected = (initialType != null && types.contains(initialType))
        ? initialType
        : (types.isEmpty ? null : types.first);
    _selectedType = selected;
    return _AccountDrawerData(
      types: types,
      accountsByType: byType,
      balances: balances,
    );
  }

  String _balanceText(BuildContext context, Account account, double balance) {
    final l10n = AppLocalizations.of(context);
    final symbol = getCurrencySymbol(account.currency);
    if (account.type == accountTypeCreditCard) {
      // 余额为负 = 欠款，已用额度取其绝对值
      final used = balance < 0 ? -balance : 0.0;
      final limit = account.creditLimit;
      final usedText = '${l10n.creditUsed} $symbol${formatMoneyCompact(used)}';
      return limit != null && limit > 0
          ? '$usedText / ${l10n.creditLimit} $symbol${formatMoneyCompact(limit)}'
          : usedText;
    }
    return '${l10n.accountBalance} $symbol${formatMoneyCompact(balance)}';
  }

  void _openAccountManage() {
    final nav = Navigator.of(context, rootNavigator: true);
    nav.pop();
    nav.push(MaterialPageRoute(builder: (_) => const AccountsPage()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primary = ref.watch(primaryColorProvider);
    final title = widget.title ?? l10n.txFormAccount;
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
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: BeeTokens.textPrimary(context),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _openAccountManage,
                  icon: Icon(
                    Icons.settings_outlined,
                    color: BeeTokens.iconSecondary(context),
                  ),
                  tooltip: l10n.accountManage,
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
            child: FutureBuilder<_AccountDrawerData>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data!;
                if (data.types.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.accountNone,
                      style: TextStyle(
                        color: BeeTokens.textTertiary(context),
                      ),
                    ),
                  );
                }
                final selectedType =
                    _selectedType ?? data.types.first;
                final accounts =
                    data.accountsByType[selectedType] ?? const <Account>[];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 92,
                      color: BeeTokens.surfaceSheet(context),
                      child: ListView.builder(
                        itemCount: data.types.length,
                        itemBuilder: (context, index) {
                          final type = data.types[index];
                          final selected = type == selectedType;
                          return InkWell(
                            onTap: () =>
                                setState(() => _selectedType = type),
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
                                  AccountTypeIcon(
                                    type: type,
                                    size: 26,
                                  ),
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: Text(
                                      getAccountTypeLabel(context, type),
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
                              getAccountTypeLabel(context, selectedType),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: BeeTokens.textPrimary(context),
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.only(bottom: 12),
                              itemCount: accounts.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: BeeTokens.divider(context),
                              ),
                              itemBuilder: (context, index) {
                                final account = accounts[index];
                                final selected =
                                    widget.initialAccount?.id == account.id;
                                final balance = data.balances[account.id] ??
                                    account.initialBalance;
                                return InkWell(
                                  onTap: () =>
                                      Navigator.pop(context, account),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    color: selected
                                        ? primary.withValues(alpha: 0.08)
                                        : Colors.transparent,
                                    child: Row(
                                      children: [
                                        AccountTypeIcon(
                                          type: account.type,
                                          size: 30,
                                          iconType: account.iconType,
                                          customIconPath: account.customIconPath,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  // 账户隐藏(#240)E1 钉住:
                                                  // 编辑态补回的隐藏账户打灰标
                                                  if (account.hidden) ...[
                                                    Icon(
                                                      Icons.visibility_off,
                                                      size: 13,
                                                      color: BeeTokens
                                                          .textTertiary(
                                                        context,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                  ],
                                                  Flexible(
                                                    child: Text(
                                                      account.name,
                                                      maxLines: 1,
                                                      overflow: TextOverflow
                                                          .ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        color: BeeTokens
                                                            .textPrimary(
                                                          context,
                                                        ),
                                                        fontWeight: selected
                                                            ? FontWeight.w600
                                                            : FontWeight.w400,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                getAccountTypeLabel(
                                                  context,
                                                  account.type,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: BeeTokens
                                                      .textTertiary(context),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _balanceText(
                                            context,
                                            account,
                                            balance,
                                          ),
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: selected
                                                ? primary
                                                : BeeTokens.textSecondary(
                                                    context,
                                                  ),
                                          ),
                                        ),
                                        if (selected) ...[
                                          const SizedBox(width: 6),
                                          Icon(
                                            Icons.check_circle,
                                            size: 18,
                                            color: primary,
                                          ),
                                        ],
                                      ],
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
