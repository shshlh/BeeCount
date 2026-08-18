import 'dart:convert';

import 'package:http/http.dart' as http;

import '../system/logger_service.dart';

/// 单只基金的最新净值快照。
class FundNavQuote {
  final double nav;
  final DateTime navDate;
  final DateTime? updatedAt;

  const FundNavQuote({
    required this.nav,
    required this.navDate,
    this.updatedAt,
  });
}

/// 基金净值抓取服务。
///
/// 主数据源：天天基金 `pingzhongdata`，取 `Data_netWorthTrend`
/// 数组末尾 3 档单位净值（历史收益/涨跌幅需要 3 档）；
/// 主源失败时回退腾讯行情 `https://qt.gtimg.cn/q=jj{基金代码}`，仅提供
/// 最新一档。单只失败跳过，不抛整批。
class NavFetchService {
  static const String _historyEndpoint =
      'https://fund.eastmoney.com/pingzhongdata/';
  static const String _fallbackEndpoint = 'https://qt.gtimg.cn/q=jj';
  static final RegExp _codePattern = RegExp(r'^\d{6}$');
  static const int _maxConcurrency = 8;
  static const Duration _timeout = Duration(seconds: 10);

  final http.Client _client;

  NavFetchService({http.Client? client}) : _client = client ?? http.Client();

  /// 并发抓取多只基金最新净值，返回 `fundCode -> FundNavQuote`。
  /// 无效代码被过滤；单只失败/无净值时跳过并记日志。
  Future<Map<String, FundNavQuote>> fetchLatestNavs(
      List<String> fundCodes) async {
    final histories = await fetchNavHistories(fundCodes);
    return {
      for (final entry in histories.entries)
        if (entry.value.isNotEmpty) entry.key: entry.value.last,
    };
  }

  /// 并发抓取多只基金最近 3 档净值，返回 `fundCode -> 按日期升序的净值列表`。
  /// 腾讯行情只有最新一档；天天基金取末尾 3 档。无效代码被过滤；
  /// 单只失败/无净值时跳过并记日志。
  Future<Map<String, List<FundNavQuote>>> fetchNavHistories(
      List<String> fundCodes) async {
    final codes = fundCodes
        .map((c) => c.trim())
        .where((c) => _codePattern.hasMatch(c))
        .toSet()
        .toList();
    if (codes.isEmpty) return const {};

    final results = <String, List<FundNavQuote>>{};
    var nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        final index = nextIndex++;
        if (index >= codes.length) return;
        final code = codes[index];
        try {
          final quotes = await _fetchOne(code);
          if (quotes.isNotEmpty) {
            final sorted = [...quotes]
              ..sort((a, b) => a.navDate.compareTo(b.navDate));
            results[code] = sorted;
          }
        } catch (e) {
          logger.warning('NavFetchService', '基金 $code 净值抓取失败: $e');
        }
      }
    }

    await Future.wait([
      for (var i = 0; i < _maxConcurrency && i < codes.length; i++) worker(),
    ]);
    return results;
  }

  Future<List<FundNavQuote>> _fetchOne(String code) async {
    final history = await _fetchFromEastmoney(code);
    if (history.isNotEmpty) return history;
    return _fetchFromTencent(code);
  }

  Future<List<FundNavQuote>> _fetchFromTencent(String code) async {
    final resp = await _client
        .get(Uri.parse('$_fallbackEndpoint$code'))
        .timeout(_timeout);
    if (resp.statusCode != 200) {
      logger.warning('NavFetchService', '基金 $code HTTP ${resp.statusCode}');
      return const [];
    }

    final quote = _parseTencentQuote(resp.body, code);
    if (quote != null) return [quote];

    logger.warning('NavFetchService', '基金 $code 腾讯行情响应无有效净值');
    return const [];
  }

  FundNavQuote? _parseTencentQuote(String body, String code) {
    final match = RegExp('v_jj$code="([^"]*)"').firstMatch(body);
    if (match == null) return null;

    final fields = match.group(1)!.split('~');
    // 字段顺序：代码、名称、预留、预留、空、单位净值、累计净值、日增长率、日期。
    final navDate = _parseDate(fields.length > 8 ? fields[8] : null);
    for (final index in [5, 6]) {
      if (index >= fields.length) break;
      final nav = double.tryParse(fields[index]);
      if (nav != null && nav > 0 && navDate != null) {
        return FundNavQuote(nav: nav, navDate: navDate);
      }
    }
    return null;
  }

  Future<List<FundNavQuote>> _fetchFromEastmoney(String code) async {
    final resp = await _client
        .get(Uri.parse('$_historyEndpoint$code.js'))
        .timeout(_timeout);
    if (resp.statusCode != 200) {
      logger.warning('NavFetchService', '基金 $code HTTP ${resp.statusCode}');
      return const [];
    }

    final quote = _parseEastmoneyHistory(resp.body);
    if (quote != null) return quote;

    logger.warning('NavFetchService', '基金 $code 天天基金响应无有效净值');
    return const [];
  }

  List<FundNavQuote>? _parseEastmoneyHistory(String body) {
    const marker = 'Data_netWorthTrend = ';
    final markerIndex = body.indexOf(marker);
    if (markerIndex < 0) return null;
    final arrayStart = markerIndex + marker.length;
    final arrayEnd = body.indexOf('];', arrayStart);
    if (arrayEnd <= arrayStart) return null;

    final raw = body.substring(arrayStart, arrayEnd + 1);
    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! List || decoded.isEmpty) return null;

    final quotes = <FundNavQuote>[];
    for (final item in decoded.whereType<Map<String, dynamic>>()) {
      final nav = double.tryParse(item['y']?.toString() ?? '');
      final navDate = _parseTimestamp(item['x']);
      if (nav != null && nav > 0 && navDate != null) {
        quotes.add(FundNavQuote(nav: nav, navDate: navDate));
      }
    }
    if (quotes.isEmpty) return null;
    quotes.sort((a, b) => a.navDate.compareTo(b.navDate));
    return quotes.length <= 3 ? quotes : quotes.sublist(quotes.length - 3);
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim());
  }

  DateTime? _parseTimestamp(dynamic raw) {
    final ts = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
    if (ts == null) return null;
    if (ts.abs() > 100000000000) {
      return DateTime.fromMillisecondsSinceEpoch(ts);
    }
    return DateTime.fromMillisecondsSinceEpoch(ts * 1000);
  }
}
