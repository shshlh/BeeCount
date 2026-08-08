# 项目规划书：个人记账 App（基于 BeeCount Fork + 投资模块集成）

**项目代号**：Fork & Invest
**版本**：v1.0
**日期**：2026-07-29
**目标平台**：Android（交付） · Windows（开发/调试/打包）

---

## 一、项目概述

### 1.1 定位

一款自用 Android 个人记账 App，以 [BeeCount](https://github.com/shshlh/BeeCount) 为技术基座进行二次开发。继承其成熟的记账基础设施（Riverpod 状态管理、Drift ORM、云端同步框架、AI OCR 自动记账、桌面小组件），叠加自有的**投资管理模块**（基金买卖/转换/赎回/净值跟踪）。

### 1.2 核心目标

| 优先 | 目标 | 说明 |
|---|---|---|
| P0 | Fork + 瘦身 | 拿到干净的、可编译的基线 |
| P0 | 投资模块数据层 | Drift schema 扩展 + Repository |
| P0 | 投资模块业务逻辑层 | Service + Riverpod Provider |
| P1 | 投资模块 UI | 持仓列表/明细/操作弹窗 + 导航改造 |
| P1 | 特色功能搬运 | Excel 导入/日历视图/WebDAV 等 |
| P2 | OCR 截图自动记账 | 继承 BeeCount 现有功能，直接可用 |
| P2 | 桌面小组件 | 继承 BeeCount 现有功能（6类×12种） |

### 1.3 交付物

- Android APK（可装手机日常使用）
- 完整源码（GitHub 私有仓库）
- 旧数据迁移脚本（从 sqflite 迁移至 Drift）

---

## 二、技术基线

### 2.1 继承自 BeeCount

| 层 | 技术选型 | 对应文件位置 |
|---|---|---|
| UI 框架 | Flutter 3.27+ | — |
| 状态管理 | Riverpod（flutter_riverpod ^2.5.1） | lib/providers/（29 文件） |
| 本地数据库 | Drift ORM + 代码生成（build_runner） | lib/data/db.dart + db.g.dart |
| 云同步 | flutter_cloud_sync 抽象框架 + 多后端 | lib/cloud/sync/（15 文件）+ packages/ |
| AI 能力 | flutter_ai_kit + OpenAI/Zhipu GLM | lib/ai/（10 文件）+ packages/（3 包） |
| OCR 自动记账 | AutoBillingService + ScreenshotMonitorService | lib/services/automation/（2 文件） |
| 桌面小组件 | home_widget + Android 原生 Widget | lib/widget/（10 文件）+ android/ 原生代码 |
| 导入系统 | BillParser 接口 + 支付宝/微信 CSV 解析 | lib/services/import/（6 文件） |
| 图表分析 | fl_chart | lib/widgets/charts/ |
| 安全 | 应用锁屏 + 生物识别 | lib/services/security/ |

### 2.2 自研模块（增量添加）

| 模块 | 说明 | 来源 |
|---|---|---|
| 投资持仓管理 | InvestmentHoldings 表 + Repository | 从原项目移植 |
| 投资原子事务 | 买入/卖出/转换/赎回的成本基数逻辑 | 同上 |
| 净值批量刷新 | 批量更新持仓净值 + 账户市值 | 同上 |
| Excel 导入 | 支付宝/微信 .xlsx 文件解析 | 直接复用原项目代码 |
| 日历视图 | 账单日/还款日/投资日/周期账单聚合 | 重写（复用 table_calendar） |
| 账户统计 | 总资产/总负债/净资产 | 从原项目移植 |
| WebDAV 设置 | WebDAV 同步配置 + 安全存储密码 | 移植 |

---

## 三、功能范围

### 3.1 保留（继承自 BeeCount）

- 核心记账（支出/收入/转账/多账本/多账户/二级分类）
- AI OCR 自动记账（截图识别 + AI 对话录入）
- 桌面小组件（6 类 × 12 种规格）
- CSV 导入（支付宝/微信）
- 数据分析报表（月度/年度/分类排行/趋势）
- 预算管理 + 超支提醒
- 周期交易（每日/周/月/年自动记账）
- 标签系统（彩色标签 + 筛选）
- 信用卡账单管理 + 还款提醒
- 应用锁屏 + 生物识别
- 通知提醒系统 + 多币种支持 + 汇率自动更新
- 数据导入导出（CSV + YAML）
- 头部装饰皮肤系统（18 种）
- WebDAV / Supabase / S3 云同步框架

### 3.2 删除（不需要）

- iOS 平台代码（ios/ 目录 + iCloud 同步包 + StoreKit + WKWebView）
- 共享账本（LedgerMembers 表 + override 字段 + 同步逻辑）
- 应用内购买（billing 服务 + payment 服务 + 捐赠页）
- 多语言（只保留简体中文）
- 营销 + 更新提示服务
- 云设置页（用自建 WebDAV 入口替代）
- 附件功能（TransactionAttachments 表 + 页面）
- 数据维护页（可选）

### 3.3 新增（自研）

- 投资持仓管理（InvestmentHoldings 表 + Drift Repository）
- 基金买入/卖出/赎回原子事务
- 基金转换（A→B 换仓，成本基数按比例转移）
- 净值批量刷新与账户市值联动
- 初始持仓导入
- Excel 导入（支付宝/微信 .xlsx 文件）
- 日历视图（账单日/还款日/投资日/周期账单聚合）
- WebDAV 加密同步配置 + 自定义时间选择器

---

## 四、项目阶段

### 阶段 0：Fork + 瘦身（3 天）

目标：拿到一个干净的、去掉不必要功能、在 Android 和 Windows 上都能编译的基线。

| 子任务 | 天数 | 交付物 |
|---|---|---|
| 0.1 Fork 仓库 + 改包名 + 项目名 | 0.5 | 私有 GitHub 仓库 |
| 0.2 删除 iOS 代码（ios/ 目录 + icloud 包 + 依赖） | 0.5 | iOS 残留清除 |
| 0.3 删除不需要功能（共享账本 / IAP / 营销 / 多语言 / 云页 / 附件） | 1 | 瘦身完成 |
| 0.4 添加 Windows 支持（flutter create --platforms windows） | 0.5 | Windows 可编译 |
| 0.5 验证：flutter analyze + flutter test + flutter run | 0.5 | 基线锁定 |

关键检查点：flutter test 通过（BeeCount 原有的 ~70 个测试全部通过）。

---

### 阶段 1：投资模块 - 数据层（5 天）

目标：在 Drift schema 中扩展投资相关表与字段，编写迁移、Repository、单元测试。

| 子任务 | 天数 | 详情 |
|---|---|---|
| 1.1 扩展 Drift Schema | 2 | 新增 InvestmentHoldings 表；Transactions 加投资字段 |
| 1.2 Schema 迁移 | 1 | 从 v30 迁徙到 v32（建表 + 加列） |
| 1.3 代码生成 | 0.5 | dart run build_runner build |
| 1.4 InvestmentRepository | 1 | 4 个核心事务：买入/卖出/转换/净值更新 |
| 1.5 Repository 单元测试 | 0.5 | 覆盖事务原子性 + 成本基数正确性 |

注意事项：
- 投资事务需要多步骤原子操作（扣余额 + 插交易 + 更新持仓），使用 Drift 的 transaction() 回调
- 成本基数计算：部分卖出时按 shares / total_shares 比例扣减 total_cost
- invest 类型加到 Transaction.type 有效取值中（不影响现有 expense/income/transfer）

---

### 阶段 2：投资模块 - 业务逻辑层（3 天）

目标：Service 层封装 + Riverpod Provider，让 UI 可以消费数据。

| 子任务 | 天数 | 详情 |
|---|---|---|
| 2.1 InvestmentService | 1 | 包装 Repository 的高阶操作 |
| 2.2 Riverpod Providers | 1.5 | 持仓列表/详情/操作 Action 等 Provider |
| 2.3 单元测试 | 0.5 | Action Provider 正确性测试 |

---

### 阶段 3：投资模块 - UI 层（5 天）

| 子任务 | 天数 | 详情 |
|---|---|---|
| 3.1 持仓列表页 | 2 | 卡片列表 + 右滑操作 + 下拉刷新净值 |
| 3.2 持仓明细页 | 1.5 | 交易流水 + 累计投入/市值/收益概览 |
| 3.3 买入/卖出/转换弹窗 | 1.5 | 份额/净值/手续费表单，复用 BeeCount 编辑器模式 |
| 3.4 首页导航 5 Tab 改造 | 1 | 流水/报表/投资/记一笔/设置 |

---

### 阶段 4：特色功能搬运（3 天）

| 子任务 | 天数 | 详情 |
|---|---|---|
| 4.1 Excel 导入 | 1 | 移植 excel_import_service.dart |
| 4.2 日历视图 | 1 | 复用 table_calendar，叠加事件聚合 |
| 4.3 设置页整合 | 0.5 | WebDAV 配置 + 账户统计 |
| 4.4 自定义时间选择器 | 0.5 | 直接拷贝 |

---

### 阶段 5：端到端测试 + 上线（3 天）

| 子任务 | 天数 | 详情 |
|---|---|---|
| 5.1 手工全流程测试 | 1.5 | 日常记账→投资买入→持有→卖出→转换→导入导出 |
| 5.2 单元测试补充 | 1 | 对标 BeeCount 70 个测试的覆盖质量 |
| 5.3 旧数据迁移 | 0.5 | sqflite 导出 CSV → 新 App 导入 |

验证清单：
- 新建账本 → 默认账户正确
- 日常支出 → 余额正确
- 转账 → 双方余额正确
- 导入支付宝/微信 CSV → 分类匹配正确
- 买入基金 → 持仓显示 + 投资账户市值正确
- 查看持仓流水 → invest_type/batchId 正确
- 部分卖出 → 成本按比例扣减 + 损益流水
- 基金转换 → A 清仓/B 开仓 + 手续费 + 退回余额
- 批量刷新净值 → 全部更新
- Excel 导入 / OCR 截图自动记账 / 桌面小组件 / WebDAV 同步
- Windows 和 Android 两端各跑一遍

---

## 五、时间汇总

| 阶段 | 内容 | 天数 | 里程碑 |
|---|---|---|---|
| 0 | Fork + 瘦身 | 3 天 | 基线锁定，测试全过 |
| 1 | 投资数据层 | 5 天 | Schema 扩展完成，Repository 可用 |
| 2 | 投资逻辑层 | 3 天 | Provider 就绪，数据可消费 |
| 3 | 投资 UI 层 | 5 天 | 持仓页面可用，导航改造完成 |
| 4 | 特色搬运 | 3 天 | 全部原功能集成完毕 |
| 5 | 测试 + 上线 | 3 天 | APK 发布 |
| 合计 | | 22 天（约 4.5 周） | |

---

## 六、风险与应对

| 风险 | 概率 | 影响 | 应对 |
|---|---|---|---|
| Drift 写法学习成本高 | 高 | 阶段 1/2 延期 | BeeCount 的 db.dart + Repository 就是现成教材 |
| 投资事务原子性 Bug | 中 | 阶段 1/5 返工 | 每步写单元测试验证，不跳过 |
| Fork 后上游更新难合并 | 低 | 长期维护 | 投资模块是纯增量，不修改 BeeCount 原有实体定义 |
| OCR 需 Android 无障碍权限 | 中 | 用户体验 | 已有现成引导流程 |
| Excel 编码问题（GBK/UTF-8） | 低 | 阶段 4 | 原项目已有 GBK 处理经验 |

---

## 七、架构决策记录

| 决策 | 选择 | 理由 |
|---|---|---|
| 状态管理 | Riverpod | BeeCount 已有 29 个 Provider 文件，保持一致 |
| 数据库 ORM | Drift | 类型安全 + 代码生成 + 迁移管理 |
| 投资持仓是否进同步 | 阶段 1-4 不进，后续迭代 | 减少同步层适配工作量 |
| 图片皮肤 | 保留 | 无负担，18 个 part 文件已存在 |
| 云同步 | 保留 WebDAV + 框架 | 自用场景 WebDAV 足够 |
| 多语言 | 仅简体中文 | 个人自用 |

---

*本规划书随项目推进更新。阶段性验收后更新里程碑状态。*
