# 记账助手（BeeCount Fork）

<div align="center">

![License](https://img.shields.io/badge/license-Business%20Source%20License-orange.svg)
![Flutter](https://img.shields.io/badge/Flutter-3.27%2B-02569B?logo=flutter)

[📦 Releases](https://github.com/shshlh/BeeCount/releases) · [🐛 Issues](https://github.com/shshlh/BeeCount/issues) · [English](README_EN.md)

</div>

## 这是什么

一款自用 Android 个人记账 App，fork 自原作者 TNT-Likely 的开源项目 BeeCount，在继承原有记账能力的基础上叠加了投资管理模块（基金买入/卖出/转换/赎回、持仓成本、净值批量刷新）。仅用于个人及少量周边人员使用，不做盈利。

## 功能

- 投资管理：基金买卖/转换/赎回、持仓成本、净值刷新
- 基础记账：多账本、多账户、二级分类、预算、周期记账、标签、图表
- AI 记账：OCR 拍照 / 语音 / 截图自动识别
- 云同步：BeeCount Cloud / iCloud / Supabase / WebDAV / S3
- 桌面小组件：净资产 / 预算 / 最近交易
- 导入导出：支付宝 / 微信 CSV、Excel 导入

## 构建

```bash
flutter pub get
flutter gen-l10n
flutter build apk --flavor prod --release
```

## 说明

- 更新包与问题反馈请使用上方 fork 仓库地址。
- 本项目基于上游 BeeCount 项目 fork，版权与授权条款见 `LICENSE` / `LICENSE_EN`。
