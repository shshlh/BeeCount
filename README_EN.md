# BeeCount (Fork)

<div align="center">

![License](https://img.shields.io/badge/license-Business%20Source%20License-orange.svg)
![Flutter](https://img.shields.io/badge/Flutter-3.27%2B-02569B?logo=flutter)

[📦 Releases](https://github.com/shshlh/BeeCount/releases) · [🐛 Issues](https://github.com/shshlh/BeeCount/issues) · [中文](README.md)

</div>

## What is this

A personal-use Android bookkeeping app forked from the open-source BeeCount project by TNT-Likely. It keeps the original bookkeeping features and adds an investment module (fund buy/sell/convert/redeem, holding cost basis, NAV refresh). Built for personal and a small circle of users, not for profit.

## Features

- Investment: fund buy/sell/convert/redeem, holding cost, NAV refresh
- Bookkeeping: multi-ledger, multi-account, categories, budgets, recurring entries, tags, charts
- AI: OCR / voice / screenshot auto bookkeeping
- Cloud sync: BeeCount Cloud / iCloud / Supabase / WebDAV / S3
- Home widgets: net worth / budget / recent transactions
- Import/export: Alipay / WeChat CSV, Excel import

## Build

```bash
flutter pub get
flutter gen-l10n
flutter build apk --flavor prod --release
```

## Notes

- Use the fork repository above for releases and issues.
- This project is forked from the upstream BeeCount project by TNT-Likely; licensing terms are in `LICENSE` / `LICENSE_EN`.
