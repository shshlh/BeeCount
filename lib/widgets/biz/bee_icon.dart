import 'package:flutter/material.dart';

/// App 内品牌「托」字标。
///
/// 7.5.3 起从旧蜜蜂 SVG 切换到 `assets/icon/adaptive_foreground.png`(透明底
/// 书法托字),用 [ColorFiltered] 保留原有 [color] 语义;glyph 在画布内占比约
/// 55%,在 [size] 内放大 1.35 倍,让标记在 18~80px 等小尺寸下仍醒目。
class BeeIcon extends StatelessWidget {
  final Color color; // 类似 Web 中的 color 属性
  final double size;

  const BeeIcon({super.key, required this.color, this.size = 256});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glyph = _buildGlyph(color, size);

    if (!isDark) return glyph;

    // 暗黑模式：在图标后面加浅色圆形遮罩，让深色笔迹保持可见
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 1.1,
            height: size * 1.1,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),
          glyph,
        ],
      ),
    );
  }

  Widget _buildGlyph(Color color, double size) {
    return ClipRect(
      child: Transform.scale(
        scale: 1.35,
        alignment: Alignment.center,
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          child: Image.asset(
            'assets/icon/adaptive_foreground.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}
