// 7.5.3 App 内品牌图替换：BeeIcon 使用「托」字 PNG，并通过 ColorFiltered
// 保留 color 语义。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/widgets/biz/bee_icon.dart';

void main() {
  testWidgets('BeeIcon 使用新品牌资产并以 ColorFiltered 着色', (tester) async {
    const brandColor = Color(0xFF336699);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BeeIcon(color: brandColor, size: 40),
        ),
      ),
    );
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));
    final asset = image.image as AssetImage;
    expect(asset.assetName, 'assets/icon/adaptive_foreground.png');
    expect(image.width, 40);
    expect(image.height, 40);

    final filter = tester.widget<ColorFiltered>(find.byType(ColorFiltered));
    expect(filter.colorFilter, ColorFilter.mode(brandColor, BlendMode.srcIn));
  });

  testWidgets('BeeIcon 暗黑模式保留浅色圆形遮罩', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(
          body: BeeIcon(color: Colors.white, size: 48),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(ColorFiltered), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BeeIcon),
        matching: find.byType(Stack),
      ),
      findsOneWidget,
    );
  });
}
