import 'dart:convert';

import 'package:http/http.dart' as http;

import '../system/logger_service.dart';

/// 天天基金净值抓取服务。
///
/// 数据源：`https://fundgz.1234567.com.cn/js/{基金代码}.js`，
/// 返回 JSONP 壳 `jsonpgz({...})`，优先取 `dwjz`（最新单位净值），
/// 缺失时用 `gsz`（估算净值）兜底；单只失败跳过，不抛整批。
class NavFetchService {
  static const String _endpoint = 'https://fundgz.1234567.com.cn/js/';
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
    final resp =
        await _client.get(Uri.parse('$_endpoint$code.js')).timeout(_timeout);
    if (resp.statusCode != 200) {
      logger.warning('NavFetchService', '基金 $code HTTP ${resp.statusCode}');
      return null;
    }

    final body = resp.body;
    final jsonStart = body.indexOf('{');
    final jsonEnd = body.lastIndexOf('}');
    if (jsonStart < 0 || jsonEnd <= jsonStart) {
      logger.warning('NavFetchService', '基金 $code 响应缺少 JSONP 数据');
      return null;
    }

    final decoded = jsonDecode(body.substring(jsonStart, jsonEnd + 1));
    if (decoded is! Map<String, dynamic>) {
      logger.warning('NavFetchService', '基金 $code 响应 JSON 结构异常');
      return null;
    }

    final dwjz = double.tryParse(decoded['dwjz']?.toString() ?? '');
    if (dwjz != null && dwjz > 0) return dwjz;

    final gsz = double.tryParse(decoded['gsz']?.toString() ?? '');
    if (gsz != null && gsz > 0) return gsz;

    logger.warning('NavFetchService', '基金 $code 无有效净值字段');
    return null;
  }
}
