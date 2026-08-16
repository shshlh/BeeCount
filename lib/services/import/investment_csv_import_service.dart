import 'package:drift/drift.dart' as d;

import '../../data/db.dart';
import '../../data/repositories/base_repository.dart';
import '../../data/repositories/investment_repository.dart';
import 'csv_parser.dart';

/// 投资 CSV 导入结果（7.10.3）。
class InvestmentImportResult {
  final int holdingsImported;
  final int flowsImported;
  final int flowsSkipped;
  final int groupsImported;

  const InvestmentImportResult({
    required this.holdingsImported,
    required this.flowsImported,
    required this.flowsSkipped,
    required this.groupsImported,
  });
}

/// 【账户】段的账户规格（7.12.2：type / 初始资金 / 排序等恢复依据）。
class _AccountSpec {
  final String type;
  final String currency;
  final double initialBalance;
  final DateTime? initialDate;
  final String? note;
  final String? bankName;
  final String? cardLastFour;
  final double? creditLimit;
  final int? billingDay;
  final int? paymentDueDay;
  final int sortOrder;
  final bool hidden;
  final bool excludeFromAssets;
  final bool isOffBalance;
  final String? iconType;
  final String? customIconPath;

  const _AccountSpec({
    required this.type,
    required this.currency,
    required this.initialBalance,
    this.initialDate,
    this.note,
    this.bankName,
    this.cardLastFour,
    this.creditLimit,
    this.billingDay,
    this.paymentDueDay,
    required this.sortOrder,
    required this.hidden,
    required this.excludeFromAssets,
    required this.isOffBalance,
    this.iconType,
    this.customIconPath,
  });
}

/// 投资 CSV 专用导入（7.10.3）。
///
/// 解析 [InvestmentCsvExportService] 生成的多段归档格式：持仓、投资流水、
/// 分组与分组归属。投资流水按「流水ID」（syncId）幂等；持仓与分组按
/// (账本, 基金代码, 账户) / 分组名 幂等。只创建投资相关流水，不影响普通
/// CSV 导入路径。
class InvestmentCsvImportService {
  final BaseRepository repo;
  final InvestmentRepository investmentRepo;

  const InvestmentCsvImportService({
    required this.repo,
    required this.investmentRepo,
  });

  Future<InvestmentImportResult> importCsv({
    required int ledgerId,
    required String csvText,
  }) async {
    final rows = CsvParser.parse(csvText);
    final accountRows = _sectionRows(rows, '【账户】');
    final holdings = _sectionRows(rows, '【持仓】');
    final flows = _sectionRows(rows, '【投资流水】');
    final groups = _sectionRows(rows, '【分组】');
    final members = _sectionRows(rows, '【分组归属】');

    final ledger = await repo.getLedgerById(ledgerId);
    final currency = (ledger?.currency.isNotEmpty ?? false)
        ? ledger!.currency
        : 'CNY';

    final accountIdByKey = <String, int>{
      for (final a in await repo.getAllAccounts()) '${a.ledgerId}|${a.name}': a.id,
    };
    final accountSpecs = <String, _AccountSpec>{
      for (final r in accountRows)
        if (_get(r, '账户名').trim().isNotEmpty)
          _get(r, '账户名').trim(): _AccountSpec(
            type: _get(r, '类型').trim(),
            currency: _get(r, '币种').trim(),
            initialBalance: _num(r, '初始资金'),
            initialDate: _date(_get(r, '初始资金日期')),
            note: _get(r, '备注').trim().isEmpty
                ? null
                : _get(r, '备注').trim(),
            bankName: _get(r, '开户行').trim().isEmpty
                ? null
                : _get(r, '开户行').trim(),
            cardLastFour: _get(r, '卡号后四位').trim().isEmpty
                ? null
                : _get(r, '卡号后四位').trim(),
            creditLimit: _get(r, '信用额度').trim().isEmpty
                ? null
                : _num(r, '信用额度'),
            billingDay: _get(r, '账单日').trim().isEmpty
                ? null
                : _int(r, '账单日'),
            paymentDueDay: _get(r, '还款日').trim().isEmpty
                ? null
                : _int(r, '还款日'),
            sortOrder: _int(r, '排序'),
            hidden: _bool(r, '隐藏'),
            excludeFromAssets: _bool(r, '不计入资产'),
            isOffBalance: _bool(r, '表外'),
            iconType: _get(r, '图标类型').trim().isEmpty
                ? null
                : _get(r, '图标类型').trim(),
            customIconPath: _get(r, '自定义图标路径').trim().isEmpty
                ? null
                : _get(r, '自定义图标路径').trim(),
          ),
    };
    final investmentAccountNames = <String>{
      for (final r in holdings)
        if (_get(r, '所属账户').trim().isNotEmpty) _get(r, '所属账户').trim(),
    };

    Future<int?> ensureAccount(String name) async {
      final trimmed = name.trim();
      if (trimmed.isEmpty) return null;
      final key = '$ledgerId|$trimmed';
      final existing = accountIdByKey[key];
      if (existing != null) return existing;
      final spec = accountSpecs[trimmed];
      final id = await repo.createAccount(
        ledgerId: ledgerId,
        name: trimmed,
        type: (spec?.type.isNotEmpty ?? false) ? spec!.type : 'cash',
        currency:
            (spec?.currency.isNotEmpty ?? false) ? spec!.currency : currency,
        initialBalance: spec?.initialBalance ?? 0,
        initialDate: spec?.initialDate,
        note: spec?.note,
        bankName: spec?.bankName,
        cardLastFour: spec?.cardLastFour,
        creditLimit: spec?.creditLimit,
        billingDay: spec?.billingDay,
        paymentDueDay: spec?.paymentDueDay,
        sortOrder: spec?.sortOrder,
        excludeFromAssets: spec?.excludeFromAssets ?? false,
        isOffBalance: spec?.isOffBalance ?? false,
        iconType: spec?.iconType,
        customIconPath: spec?.customIconPath,
      );
      if (spec?.hidden ?? false) {
        await repo.setAccountHidden(id, true);
      }
      accountIdByKey[key] = id;
      return id;
    }

    // 7.13.5/7.13.6: 先按【账户】段主动建全部账户，避免无持仓/无流水的
    // 账户（银行卡/微信/数字人民币/应收款/信用卡/表外等）导入后丢失。
    for (final r in accountRows) {
      final name = _get(r, '账户名').trim();
      if (name.isNotEmpty) {
        await ensureAccount(name);
      }
    }

    // 1. 持仓：按 (账本, 基金代码, 账户) 幂等恢复。
    final holdingIdByFundAccount = <String, int>{};
    final fundCodeToHoldingId = <String, int>{};
    var holdingsImported = 0;
    for (final r in holdings) {
      final accountId = await ensureAccount(_get(r, '所属账户'));
      if (accountId == null) continue;
      final fundCode = _get(r, '基金代码').trim();
      if (fundCode.isEmpty) continue;
      final holdingId = await investmentRepo.upsertHoldingForImport(
        ledgerId: ledgerId,
        accountId: accountId,
        fundCode: fundCode,
        fundName: _get(r, '基金名称').trim(),
        totalShares: _num(r, '份额'),
        totalCost: _num(r, '成本'),
        currentNav: _num(r, '当前净值'),
        navDate: _date(_get(r, '净值日期')),
        marketValue: _num(r, '市值'),
        note: _get(r, '备注').trim().isEmpty ? null : _get(r, '备注').trim(),
      );
      holdingIdByFundAccount['$fundCode|${_get(r, '所属账户').trim()}'] =
          holdingId;
      fundCodeToHoldingId.putIfAbsent(fundCode, () => holdingId);
      holdingsImported++;
    }

    // 2. 分组与归属：按分组名幂等。
    final groupIdByName = <String, int>{};
    var groupsImported = 0;
    for (final r in groups) {
      final name = _get(r, '分组名称').trim();
      if (name.isEmpty) continue;
      final id = await investmentRepo.ensureGroupForImport(
        ledgerId: ledgerId,
        name: name,
        sortOrder: _int(r, '排序'),
      );
      groupIdByName.putIfAbsent(name, () => id);
      groupsImported++;
    }
    for (final r in members) {
      final groupId = groupIdByName[_get(r, '分组名称').trim()];
      final holdingId = fundCodeToHoldingId[_get(r, '基金代码').trim()];
      if (groupId != null && holdingId != null) {
        await investmentRepo.addHoldingsToGroup(groupId, [holdingId]);
      }
    }

    // 3. 投资流水：按流水ID 幂等，只写投资相关 transfer 流水。
    final existingSyncIds = await repo.getTransactionSyncIdsForLedger(ledgerId);
    var flowsSkipped = 0;
    final companions = <TransactionsCompanion>[];
    for (final r in flows) {
      final syncId = _get(r, '流水ID').trim();
      if (syncId.isNotEmpty && existingSyncIds.contains(syncId)) {
        flowsSkipped++;
        continue;
      }

      final label = _get(r, '类型').trim();
      final investType = switch (label) {
        '初始登记' => 'initial',
        '买入' || '转换买入' => 'buy',
        '卖出' || '转换卖出' => 'sell',
        '赎回' => 'redeem',
        '退回' => null,
        _ => label.isEmpty ? null : label,
      };
      final isConvert = label.contains('转换');
      final shares = _num(r, '份额').abs();
      final nav = _num(r, '净值');
      final fee = _num(r, '手续费');
      final isSell = investType == 'sell' ||
          investType == 'redeem' ||
          label == '转换卖出';
      final isBuy = investType == 'buy' || investType == 'initial';
      final amount = isBuy
          ? (_num(r, '转入成本') > 0
              ? _num(r, '转入成本')
              : shares * nav)
          : (label == '退回'
              ? _num(r, '退回金额')
              : (_num(r, '金额') > 0 ? _num(r, '金额') : shares * nav - fee));

      final investmentAccountName =
          investmentAccountNames.contains(_get(r, '转入账户').trim())
              ? _get(r, '转入账户').trim()
              : (investmentAccountNames.contains(_get(r, '转出账户').trim())
                  ? _get(r, '转出账户').trim()
                  : '');
      final fundCode = _get(r, '基金代码').trim();
      final holdingId = (fundCode.isNotEmpty && investmentAccountName.isNotEmpty)
          ? holdingIdByFundAccount['$fundCode|$investmentAccountName']
          : null;

      final fromAccountId = await ensureAccount(_get(r, '转出账户'));
      final toAccountId = await ensureAccount(_get(r, '转入账户'));
      final batchId = _get(r, '批次ID').trim();

      companions.add(TransactionsCompanion.insert(
        ledgerId: ledgerId,
        type: 'transfer',
        amount: amount,
        accountId: d.Value(fromAccountId),
        toAccountId: d.Value(toAccountId),
        happenedAt: d.Value(_dateTime(_get(r, '日期'))),
        note: d.Value(_get(r, '备注').trim().isEmpty
            ? null
            : _get(r, '备注').trim()),
        syncId: d.Value(syncId.isEmpty ? null : syncId),
        investType: d.Value(investType),
        investShares: d.Value(isSell ? -shares : shares),
        investNav: d.Value(nav > 0 ? nav : null),
        investFee: d.Value(fee > 0 ? fee : null),
        holdingId: d.Value(holdingId),
        batchId: d.Value(batchId.isEmpty ? null : batchId),
        excludeFromStats:
            d.Value(investType == 'initial' || isConvert ? true : false),
        excludeFromBudget: const d.Value(true),
        currencyCode: d.Value(null),
        nativeAmount: d.Value(null),
      ));
    }

    var flowsImported = 0;
    if (companions.isNotEmpty) {
      flowsImported =
          (await repo.insertTransactionsBatchWithRelations(
                transactions: companions,
              ))
              .length;
    }

    // 刷新投资账户市值缓存，保证资产页立即一致。
    for (final name in investmentAccountNames) {
      final id = accountIdByKey['$ledgerId|$name'];
      if (id != null) {
        await investmentRepo.syncInvestmentAccountValue(id);
      }
    }

    return InvestmentImportResult(
      holdingsImported: holdingsImported,
      flowsImported: flowsImported,
      flowsSkipped: flowsSkipped,
      groupsImported: groupsImported,
    );
  }

  List<Map<String, String>> _sectionRows(
      List<List<String>> rows, String marker) {
    final start = rows.indexWhere(
        (r) => r.isNotEmpty && r.first.trim() == marker);
    if (start < 0) return const [];

    var headerIndex = start + 1;
    while (headerIndex < rows.length &&
        (rows[headerIndex].isEmpty ||
            rows[headerIndex].every((c) => c.trim().isEmpty))) {
      headerIndex++;
    }
    if (headerIndex >= rows.length) return const [];
    final header = rows[headerIndex]
        .map((c) => c.trim())
        .toList(growable: false);

    final out = <Map<String, String>>[];
    for (var i = headerIndex + 1; i < rows.length; i++) {
      final r = rows[i];
      if (r.isNotEmpty && r.first.trim().startsWith('【')) break;
      if (r.isEmpty || r.every((c) => c.trim().isEmpty)) continue;
      final map = <String, String>{};
      for (var j = 0; j < header.length && j < r.length; j++) {
        map[header[j]] = r[j].trim();
      }
      out.add(map);
    }
    return out;
  }

  static String _get(Map<String, String> row, String key) => row[key] ?? '';

  static double _num(Map<String, String> row, String key) =>
      double.tryParse(_get(row, key)) ?? 0;

  static int _int(Map<String, String> row, String key) =>
      int.tryParse(_get(row, key)) ?? 0;

  static bool _bool(Map<String, String> row, String key) {
    final v = _get(row, key).trim().toLowerCase();
    return v == '1' || v == 'true';
  }

  static DateTime? _date(String raw) {
    final t = DateTime.tryParse(raw.trim());
    return t;
  }

  static DateTime _dateTime(String raw) {
    final t = DateTime.tryParse(raw.trim());
    return t ?? DateTime.now();
  }
}
