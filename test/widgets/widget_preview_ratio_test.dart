import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/pages/settings/widget_management_page.dart';

void main() {
  group('widgetPreviewDisplaySize', () {
    test('可用宽度充足时保留原生尺寸', () {
      expect(
        widgetPreviewDisplaySize(400, const Size(155, 155)),
        const Size(155, 155),
      );
      expect(
        widgetPreviewDisplaySize(400, const Size(364, 169)),
        const Size(364, 169),
      );
      expect(
        widgetPreviewDisplaySize(400, const Size(364, 382)),
        const Size(364, 382),
      );
    });

    test('可用宽度不足时等比缩小,比例不变', () {
      final size = widgetPreviewDisplaySize(200, const Size(364, 169));
      expect(size.width, closeTo(200, 0.0001));
      expect(size.height, closeTo(92.86, 0.01));
      expect(size.height / size.width, closeTo(169 / 364, 0.0001));
    });
  });
}
