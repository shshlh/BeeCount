# 旧数据迁移输出 · 2026-07-30 01:15

**来源数据库**：`D:\codexproject\pj_004_beecount_fork\scripts\_test_old.db`
**总计导出行数**：9

## 输出文件一览

| 文件 | 内容 | 用途 |
|---|---|---|
| `books.csv` | 账本信息 | 参考用，新 App 初始化后自动创建默认账本 |
| `accounts.csv` | 账户列表（含名称、类型、余额、信用卡信息） | 在新 App 中手动创建同名的账户，或参考此表核对 |
| `categories.csv` | 分类列表（含父分类名） | 在新 App 中按名称创建对应分类 |
| `transactions.csv` | 全部交易记录（外键已解析为名称） | 主要数据源 |
| `investment_holdings.csv` | 投资持仓 | 需在新 App 中手动重建持仓 |
| `periodic_bills.csv` | 定期账单 | 需在新 App 的"周期交易"页面重新创建 |

## 迁移步骤建议

### 1. 在新 App 中创建账本 + 账户
- 打开新 App，创建默认账本
- 根据 `accounts.csv` 中的信息，手动创建同名账户
  - 现金/储蓄卡/信用卡/投资账户等
  - 注意信用卡的账单日（billing_day）和还款日（repayment_day）

### 2. 创建分类
- 在新 App 中根据 `categories.csv` 创建对应分类
- 一级分类先创建，二级分类选好父分类

### 3. 导入交易
- 交易记录已导出为 `transactions.csv`，但 BeeCount 的 CSV 导入目前主要用于支付宝/微信账单格式
- 建议：
  - **方案 A**：利用 BeeCount 的「配置导出/导入」功能（设置 → 数据管理 → 配置导入导出）
    将 `transactions.csv` 格式化为 YAML 后导入
  - **方案 B**：待 App 增加通用 CSV 导入功能后直接导入
  - **方案 C**：手工方式 — 按账户/分类名称在新 App 中重新录入关键交易

### 4. 重建投资持仓
- 在新 App 的投资页，根据 `investment_holdings.csv` 逐条「初始持仓导入」
- 注意：需要先创建投资类型的账户

### 5. 重建周期交易
- 在新 App 的"周期交易"页面，根据 `periodic_bills.csv` 逐条重建

## 字段映射（旧 → 新）

### 旧 transactions 表 → 新 Transactions 表

| 旧字段 | 新字段 | 说明 |
|---|---|---|
| id (UUID) | id (INTEGER 自增) | 主键类型变化，无法直接迁移 |
| book_id → book_name | ledgerId | 通过账本名称关联 |
| account_id → account_name | accountId | 通过账户名称关联 |
| to_account_id → to_account_name | toAccountId | 通过账户名称关联 |
| category_id → category_name | categoryId | 通过分类名称关联 |
| type | type | 直接映射：expense/income/transfer/invest |
| amount | amount | 直接映射 |
| datetime | happenedAt | 直接映射（DateTime 格式） |
| note | note | 直接映射 |
| invest_type | investType | 直接映射：buy/sell/redeem/switch_out/switch_in |
| invest_shares | investShares | 直接映射 |
| invest_nav | investNav | 直接映射 |
| invest_fee | investFee | 直接映射 |
| batch_id | batchId | 直接映射 |
| is_investment | [ERR] | 已废弃，用 type='invest' 替代 |
| code | [ERR] | 通过 holdingId 关联持仓 |
| related_investment_id | holdingId | 需要转换为新 int ID |

### 旧 investment_holdings 表 → 新 InvestmentHoldings 表

| 旧字段 | 新字段 | 说明 |
|---|---|---|
| id (UUID) | id (INTEGER 自增) | 主键类型变化 |
| book_id → book_name | ledgerId | 通过账本名称关联 |
| account_id → account_name | accountId | 通过账户名称关联 |
| code | fundCode | 直接映射 |
| name | fundName | 直接映射 |
| inv_type | holdingType | fund/stock/etf |
| total_cost | totalCost | 成本基数 |
| total_shares | totalShares | 持有份额 |
| latest_nav | currentNav | 最新净值 |
| nav_date | [ERR] | 新表无此字段 |
| fee_type | [ERR] | 新表无此字段 |
| is_liquidated | [ERR] | 可用 total_shares=0 判断 |

### 旧 periodic_bills 表 → 新 RecurringTransactions 表

| 旧字段 | 新字段 | 说明 |
|---|---|---|
| id (UUID) | id (INTEGER 自增) | 主键类型变化 |
| book_id → book_name | ledgerId | 通过账本名称关联 |
| name | name | 直接映射 |
| type | type | expense/income/transfer |
| amount | amount | 直接映射 |
| account_id → account_name | accountId | 通过账户名称关联 |
| category_id → category_name | categoryId | 通过分类名称关联 |
| frequency | frequency | daily/weekly/monthly/yearly |
| start_date | startDate | 直接映射 |
| end_date | endDate | 直接映射 |
| next_run_date | nextRunDate | 直接映射 |
| enabled | enabled | 直接映射 |

---

*此文件由 `scripts/migrate_from_old.py` 自动生成*
