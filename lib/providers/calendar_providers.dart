import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/db.dart';
import '../providers.dart';


/// 日历事件类型
enum CalendarEventType {
  billDate,
  paymentDue,
  invest,
  recurring,
}

/// 单个日历事件
class CalendarEvent {
  final CalendarEventType type;
  final String title;
  final String? subtitle;

  const CalendarEvent({
    required this.type,
    required this.title,
    this.subtitle,
  });
}
/// 当前选中的日历月份（默认当前月）
final calendarSelectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

/// 当前选中的日期（默认 null，未选中任何日期）
final calendarSelectedDateProvider = StateProvider<DateTime?>((ref) => null);

/// 获取指定月份的每日统计
/// 参数: (ledgerId, month)
final dailyTotalsByMonthProvider = FutureProvider.autoDispose
    .family<Map<String, (double, double)>, ({int ledgerId, DateTime month})>(
  (ref, params) async {
    // 监听刷新触发器
    ref.watch(calendarRefreshProvider);

    final repo = ref.watch(repositoryProvider);
    return repo.getDailyTotalsByMonth(
      ledgerId: params.ledgerId,
      month: params.month,
    );
  },
);

/// 获取选中日期的交易详情
/// 参数: (ledgerId, date)
final transactionsByDateProvider = FutureProvider.autoDispose.family<
    List<({
      Transaction t,
      Category? category,
      List<Tag> tags,
      List<TransactionAttachment> attachments,
      Account? account,
    })>,
    ({int ledgerId, DateTime date})>(
  (ref, params) async {
    // 监听刷新触发器
    ref.watch(calendarRefreshProvider);

    final repo = ref.watch(repositoryProvider);
    return repo.getTransactionsByDate(
      ledgerId: params.ledgerId,
      date: params.date,
    );
  },
);

/// 获取指定月份有交易的日期列表
/// 参数: (ledgerId, month)
final transactionDatesByMonthProvider = FutureProvider.autoDispose
    .family<List<String>, ({int ledgerId, DateTime month})>(
  (ref, params) async {
    // 监听刷新触发器
    ref.watch(calendarRefreshProvider);

    final repo = ref.watch(repositoryProvider);
    return repo.getTransactionDatesByMonth(
      ledgerId: params.ledgerId,
      month: params.month,
    );
  },
);

/// 获取指定时间范围的交易列表（用于当月交易列表）
/// 参数: (ledgerId, startDate, endDate)
final monthTransactionsProvider = FutureProvider.autoDispose.family<
    List<({
      Transaction t,
      Category? category,
      List<Tag> tags,
      List<TransactionAttachment> attachments,
      Account? account,
    })>,
    ({int ledgerId, DateTime startDate, DateTime endDate})>(
  (ref, params) async {
    // 监听刷新触发器
    ref.watch(calendarRefreshProvider);

    final repo = ref.watch(repositoryProvider);

    // 查询时间范围内的所有交易
    final transactions = await repo.getTransactionsByDateRange(
      ledgerId: params.ledgerId,
      startDate: params.startDate,
      endDate: params.endDate,
    );

    return transactions;
  },
);


/// 当月日历事件（信用卡账单日/还款日 + 投资交易 + 周期交易到期）
/// 返回 Map<日期Key, List<CalendarEvent>>
final calendarEventsForMonthProvider = FutureProvider.autoDispose
    .family<Map<String, List<CalendarEvent>>, ({int ledgerId, DateTime month})>(
  (ref, params) async {
    ref.watch(calendarRefreshProvider);
    final repo = ref.watch(repositoryProvider);
    final events = <String, List<CalendarEvent>>{};

    void add(String key, CalendarEvent e) {
      events.putIfAbsent(key, () => []).add(e);
    }

    final year = params.month.year;
    final mon = params.month.month;
    final daysInMonth = DateTime(year, mon + 1, 0).day;

    // ── 1. 信用卡账单日 & 还款日 ──
    final cards = await repo.getCreditCardAccounts();
    for (final card in cards) {
      final name = card.name;
      if (card.billingDay != null) {
        final d = min(card.billingDay!, daysInMonth);
        add(fmtDate(year, mon, d),
            CalendarEvent(type: CalendarEventType.billDate, title: '${name} 账单日'));
      }
      if (card.paymentDueDay != null) {
        final d = min(card.paymentDueDay!, daysInMonth);
        add(fmtDate(year, mon, d),
            CalendarEvent(type: CalendarEventType.paymentDue, title: '${name} 还款日'));
      }
    }

    // ── 2. 投资交易 ──
    final txs = await repo.getTransactionsByDateRange(
      ledgerId: params.ledgerId,
      startDate: DateTime(year, mon, 1),
      endDate: DateTime(year, mon + 1, 0, 23, 59, 59),
    );
    for (final tx in txs) {
      if (tx.t.type == 'invest') {
        final key = fmtDate(tx.t.happenedAt.year, tx.t.happenedAt.month, tx.t.happenedAt.day);
        final label = switch (tx.t.investType) {
          'buy' => '买入',
          'sell' => '卖出',
          'redeem' => '赎回',
          'convert' => '转换',
          _ => '投资',
        };
        add(key, CalendarEvent(
          type: CalendarEventType.invest,
          title: label,
          subtitle: tx.t.note,
        ));
      }
    }

    // ── 3. 周期交易 ──
    final recurrings = await repo.getEnabledRecurringTransactions(params.ledgerId);
    for (final rt in recurrings) {
      final typeLabel = switch (rt.type) {
        'expense' => '支出',
        'income' => '收入',
        _ => '转账',
      };
      for (final d in recurringDatesInMonth(rt, year, mon)) {
        add(fmtDate(d.year, d.month, d.day), CalendarEvent(
          type: CalendarEventType.recurring,
          title: '周期${typeLabel}',
          subtitle: rt.note,
        ));
      }
    }

    return events;
  },
);

/// 计算一条周期交易在指定月份会触发的所有日期
List<DateTime> recurringDatesInMonth(
    RecurringTransaction rt, int year, int month) {
  final results = <DateTime>[];
  final monthStart = DateTime(year, month, 1);
  final monthEnd = DateTime(year, month + 1, 0);

  final effectiveStart =
      rt.startDate.isAfter(monthStart) ? rt.startDate : monthStart;
  final effectiveEnd = rt.endDate != null && rt.endDate!.isBefore(monthEnd)
      ? rt.endDate!
      : monthEnd;

  switch (rt.frequency) {
    case 'daily':
      for (var d = effectiveStart;
          !d.isAfter(effectiveEnd);
          d = d.add(Duration(days: rt.interval))) {
        results.add(d);
      }
    case 'weekly':
      if (rt.dayOfWeek != null) {
        for (var d = effectiveStart;
            !d.isAfter(effectiveEnd);
            d = d.add(const Duration(days: 1))) {
          if (d.weekday == rt.dayOfWeek) results.add(d);
        }
      }
    case 'monthly':
      if (rt.dayOfMonth != null) {
        final day = min(rt.dayOfMonth!, monthEnd.day);
        final candidate = DateTime(year, month, day);
        if (!candidate.isBefore(effectiveStart) &&
            !candidate.isAfter(effectiveEnd)) {
          results.add(candidate);
        }
      }
    case 'yearly':
      if (rt.monthOfYear == month && rt.dayOfMonth != null) {
        final day = min(rt.dayOfMonth!, monthEnd.day);
        final candidate = DateTime(year, month, day);
        if (!candidate.isBefore(effectiveStart) &&
            !candidate.isAfter(effectiveEnd)) {
          results.add(candidate);
        }
      }
  }

  return results;
}

String fmtDate(int y, int m, int d) =>
    '--';
/// 日历刷新触发器（添加/删除交易后触发）
final calendarRefreshProvider = StateProvider<int>((ref) => 0);
