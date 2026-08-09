import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 7.1.2 App 更名「记账助手」回归扫描。
void main() {
  group('l10n 应用名断言', () {
    test('zh/zh_TW 更名，en/ko 按 PM 口径保留 BeeCount', () {
      expect(_arbValue('lib/l10n/app_zh.arb', 'appName'), '记账助手');
      expect(_arbValue('lib/l10n/app_zh_TW.arb', 'appName'), '記帳助手');
      expect(_arbValue('lib/l10n/app_en.arb', 'appName'), 'BeeCount');
      expect(_arbValue('lib/l10n/app_ko.arb', 'appName'), 'BeeCount');
    });
  });

  group('用户可见旧名扫描', () {
    test('lib 非 l10n 下无「蜜蜂记账/蜜蜂記帳」残留', () {
      final hits = _scanDir(
        'lib',
        const {'.dart', '.arb'},
        _containsOldChineseName,
      ).where((path) => !_isL10nFile(path)).toList();
      expect(hits, isEmpty, reason: '残留文件: $hits');
    });

    test('用户可见文档无「蜜蜂记账」残留', () {
      const files = [
        'README.md',
        'README_EN.md',
        'PRIVACY.md',
        'docs/cloud-setup.md',
      ];
      final hits = files
          .where((f) => File(f).readAsStringSync().contains('蜜蜂记账'))
          .toList();
      expect(hits, isEmpty, reason: '残留文件: $hits');
    });

    test('README 标题已更名', () {
      expect(File('README.md').readAsStringSync(), contains('# 记账助手'));
      expect(
        File('README_EN.md').readAsStringSync(),
        contains('# BeeCount (Fork)'),
      );
    });
  });

  group('Android 资源断言', () {
    test('build.gradle app_name 已更名', () {
      final gradle = File('android/app/build.gradle').readAsStringSync();
      expect(gradle, contains('resValue "string", "app_name", "记账助手测试版"'));
      expect(gradle, contains('resValue "string", "app_name", "记账助手"'));
      expect(gradle.contains('蜜蜂记账'), isFalse);
    });

    test('values strings.xml app_name 已更名', () {
      final xml = File('android/app/src/main/res/values/strings.xml')
          .readAsStringSync();
      expect(xml, contains('<string name="app_name">记账助手</string>'));
      expect(xml.contains('蜜蜂记账'), isFalse);
    });
  });
}

String _arbValue(String path, String key) {
  final data =
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return data[key]! as String;
}

List<String> _scanDir(
  String root,
  Set<String> extensions,
  bool Function(String content) predicate,
) {
  final hits = <String>[];
  for (final entity in Directory(root).listSync(recursive: true)) {
    if (entity is! File) continue;
    if (!extensions.contains(entity.path.toLowerCase().split('.').last)) {
      continue;
    }
    if (predicate(entity.readAsStringSync())) {
      hits.add(entity.path);
    }
  }
  return hits;
}

bool _containsOldChineseName(String content) {
  return content
      .split('\n')
      .where((line) => line.contains('蜜蜂记账') || line.contains('蜜蜂記帳'))
      .any((line) {
    final trimmed = line.trimLeft();
    return !trimmed.startsWith('//') &&
        !trimmed.startsWith('/*') &&
        !trimmed.startsWith('*');
  });
}

bool _isL10nFile(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.contains('/l10n/');
}
