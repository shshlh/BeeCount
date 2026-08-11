# 废弃资产清单

自 7.5.2/7.5.3 品牌切换后，以下旧蜜蜂资产不再被 App 代码引用。保留文件仅作
历史归档，不再参与打包（如已从 pubspec 移除的条目），等待后续清理。

## 已从打包移除

- `assets/bee.svg` — 旧蜜蜂图标，原 `BeeIcon` 使用；现 `BeeIcon` 改用
  `assets/icon/adaptive_foreground.png`
- `assets/logo.svg` — 旧蜜蜂图标，原自适应图标几何来源

## 仓库内但不再被引用

- `assets/logo_216.png` / `assets/logo_512.png` — 旧蜜蜂图标尺寸版本，原
  `scripts/tools/generate_android_icons.py` 使用
- `assets/images/beeassets_*.png` / `assets/images/beeassets_logo.svg` —
  旧蜜蜂素材与截图
- `assets/images/beedns_logo.png` — 旧域名/品牌图

## 已禁用的废弃脚本

- `scripts/gen_adaptive_icons.py` — 会重新生成旧蜜蜂自适应图标并覆盖
  `assets/icon/*`，已禁用
- `scripts/tools/generate_android_icons.py` — 会把旧蜜蜂图标白底化并覆盖
  android mipmap，已禁用

当前品牌资产入口：

- `assets/icon/adaptive_foreground.png` — 透明底「托」字，App 内 BeeIcon /
  logo2 使用
- `assets/icon/launcher_legacy.png` — 米白底合成，Android legacy 启动图标
- `assets/icon/adaptive_monochrome.png` — themed icon 单色层
- 图标生成：`dart run flutter_launcher_icons`（配置见 pubspec.yaml）
