import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/models/ai_analysis_metadata.dart';

void main() {
  group('analysisScope metadata', () {
    test('encode 后能 decode 回 scopeLabel', () {
      const scope = '近 30 天 · 3 只持仓';
      final encoded = encodeAnalysisScopeMetadata(scope);
      expect(analysisScopeFromMetadata(encoded), scope);
    });

    test('非分析 metadata / 非法 JSON 返回 null', () {
      expect(analysisScopeFromMetadata(null), isNull);
      expect(analysisScopeFromMetadata('not-json'), isNull);
      expect(analysisScopeFromMetadata('{"bills":[]}'), isNull);
    });
  });
}
