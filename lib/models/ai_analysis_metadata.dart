import 'dart:convert';

/// 分析类消息的 metadata 编码 / 解码。
///
/// 只在普通文本回复上附带 `analysisScope`，记账卡片走既有 bill metadata，
/// 两者互不覆盖。
String encodeAnalysisScopeMetadata(String scope) =>
    jsonEncode({'analysisScope': scope});

String? analysisScopeFromMetadata(String? metadata) {
  if (metadata == null || metadata.isEmpty) return null;
  try {
    final map = jsonDecode(metadata);
    if (map is Map<String, dynamic>) {
      final value = map['analysisScope'];
      return value is String ? value : null;
    }
  } catch (_) {
    return null;
  }
  return null;
}
