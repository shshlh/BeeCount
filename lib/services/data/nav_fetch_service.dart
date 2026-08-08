import 'dart:convert';

import 'package:http/http.dart' as http;

import '../system/logger_service.dart';

/// 基金净值抓取服务。
///
/// 主数据源：腾讯行情 `https://qt.gtimg.cn/q=jj{基金代码}`，返回
/// `v_jj<code>="...~单位净值~累计净值~日增长率~日期~"`，取单位净值；
/// 主源失败时回退天天基金 `pingzhongdata`，取 `Data_netWorthTrend`
/// 数组中最后一个单位净值。单只失败跳过，不抛整批。
class NavFetchService {
  static const String _primaryEndpoint = 'https://qt.gtimg.cn/q=jj';
  static const String _fallbackEndpoint =
      'https://fund.eastmoney.com/pingzhongdata/';
  static final RegExp _codePattern = RegExp(r'^\d{6}$');
  static const int _maxConcurrency = 8;
  static const Duration _timeout = Duration(seconds: 10);

  final http.Client _client;

  NavFetchService({http.Client? client}) : _client = client ?? http.Client();

  /// 并发抓取多只基金最新净值，返回 `fundCode -> nav`。
  /// 无效代码被过滤；单只失败/无净值时跳过并记日志。
  Future<Map<String, double>> fetchLatestNavs(List<String> fundCodes) async {
    final codes = fundCodes
        .map((c) => c.trim())
        .where((c) => _codePattern.hasMatch(c))
        .toSet()
        .toList();
    if (codes.isEmpty) return const {};

    final results = <String, double>{};
    var nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        final index = nextIndex++;
        if (index >= codes.length) return;
        final code = codes[index];
        try {
          final nav = await _fetchOne(code);
          if (nav != null) results[code] = nav;
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

  Future<double?> _fetchOne(String code) async {
    final primary = await _fetchFromTencent(code);
    if (primary != null) return primary;
    return _fetchFromEastmoney(code);
  }

  Future<double?> _fetchFromTencent(String code) async {
    final resp =
        await _client.get(Uri.parse('$_primaryEndpoint$code')).timeout(_timeout);
    if (resp.statusCode != 200) {
      logger.warning('NavFetchService', '基金 $code HTTP ${resp.statusCode}');
      return null;
    }

    final nav = _parseTencentQuote(resp.body, code);
    if (nav != null) return nav;

    logger.warning('NavFetchService', '基金 $code 腾讯行情响应无有效净值');
    return null;
  }

  double? _parseTencentQuote(String body, String code) {
    final match = RegExp('v_jj$code="([^"]*)"').firstMatch(body);
    if (match == null) return null;

    final fields = match.group(1)!.split('~');
    // 字段顺序：代码、名称、预留、预留、空、单位净值、累计净值、日增长率、日期。
    for (final index in [5, 6]) {
      if (index >= fields.length) break;
      final nav = double.tryParse(fields[index]);
      if (nav != null && nav > 0) return nav;
    }
    return null;
  }

  Future<double?> _fetchFromEastmoney(String code) async {
    final resp = await _client
        .get(Uri.parse('$_fallbackEndpoint$code.js'))
        .timeout(_timeout);
    if (resp.statusCode != 200) {
      logger.warning('NavFetchService', '基金 $code HTTP ${resp.statusCode}');
      return null;
    }

    final nav = _parseEastmoneyHistory(resp.body);
    if (nav != null) return nav;

    logger.warning('NavFetchService', '基金 $code 天天基金响应无有效净值');
    return null;
  }

  double? _parseEastmoneyHistory(String body) {
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

    final last = decoded.last;
    if (last is Map<String, dynamic>) {
      final nav = double.tryParse(last['y']?.toString() ?? '');
      if (nav != null && nav > 0) return nav;
    }
    return null;
  }
}
