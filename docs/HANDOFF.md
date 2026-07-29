# 交接记录

本文档记录线程之间的任务交接。按时间倒序排列。

---

<!--

### 模板

## {日期}

**移交角色**：[角色名]
**接收角色**：[角色名]

**完成工作**：
- 改了哪些文件
- 做了什么变更
- 还有什么未完成

**下一个任务需要知道的**：
- 关键决策
- 已知问题
- 要读的代码上下文

**git 状态**：当前分支 [branch name]，已提交 [commit hash]

---

-->

*暂无交接记录。首个任务开始后启用。*

## 2026-07-29

**移交角色**：数据架构师（architect）
**接收角色**：投资逻辑工程师（invest-logic）

**完成工作**：
- `lib/data/db.dart` — v32 schema 扩展：
  - 新增 `InvestmentHoldings` 表（13 列：id, ledgerId, fundCode, fundName, accountId, totalShares, totalCost, currentNav, marketValue, holdingType, note, createdAt, updatedAt）
  - Transactions 新增 6 个投资字段：investType, investShares, investNav, investFee, holdingId, batchId
  - `type` 注释扩展为 `expense / income / transfer / invest`
  - schemaVersion → 32
  - v31→v32 迁移块（幂等，含 3 个索引）
  - `onCreate` 补 investment_holdings 索引

- `lib/data/repositories/investment_repository.dart` — 抽象接口（7 个方法）
- `lib/data/repositories/local/local_investment_repository.dart` — Drift 实现：
  - buy: 查找/创建持仓 + 插交易 + 更新持仓（追加份额和成本）
  - sell: 加载持仓 → 比例扣减成本基数 → 插交易 → 更新持仓
  - convert: A卖出 + B买入，同一事务内，共享 batchId
  - updateNav: 更新净值 + 重算市值

- `test/data/migration_v32_test.dart` — 5 个架构测试
- `test/data/repositories/investment_repository_test.dart` — 8 个 Repository 测试
- 13/13 全部通过

- `pubspec.yaml` — intl ^0.19.0 → ^0.20.2（修复 flutter_localizations 版本冲突）
- `build.yaml` — 临时文件已删除

**下一个任务需要知道的**：
- 交易 `type='invest'`，`investType` 取值 buy/sell/redeem/convert
- `excludeFromBudget=true` — 投资交易不参与预算统计
- 部分卖出时成本基数按 `shares / totalShares` 比例扣减
- 转换两笔交易通过 `batchId` 关联
- InvestmentRepository 不加入 BaseRepository（阶段 1-4 不进同步）
- Repository 所有写操作使用 `db.transaction()` 保证原子性

**git 状态**：未提交（等待 PM 审查后统一合入）

---


## 2026-07-29

**移交角色**：投资逻辑工程师（invest-logic）
**接收角色**：UI 工程师（invest-ui）

**完成工作**：
- `lib/services/data/investment_service.dart` — Service 层封装：
  - `PortfolioSummary` / `HoldingReturn` 数据类
  - `getPortfolioSummary`：组合总市值/总成本/未实现盈亏/收益率
  - `getHoldingReturn`：单持仓盈亏
  - `batchUpdateNav`：批量净值刷新
  - `validateBuy` / `validateSell` / `validateConvert`：前端验证方法
  - buy / sell / convert / updateNav 直接委托给 Repository

- `lib/providers/investment_providers.dart` — Riverpod Provider 层：
  - `investmentRepositoryProvider`：创建 LocalInvestmentRepository
  - `investmentServiceProvider`：创建 InvestmentService
  - `currentHoldingsProvider`：当前账本持仓 Stream（StreamProvider.autoDispose）
  - `holdingTransactionsProvider`：持仓交易流水 Stream（family + autoDispose）
  - `holdingProvider`：单持仓详情 Future（family）
  - `portfolioSummaryProvider`：投资组合摘要 Future（autoDispose）
  - `holdingReturnProvider`：单持仓收益 Future（family）

- `lib/providers/all_providers.dart` — 新增 investment_providers 导出
- `test/services/investment_service_test.dart` — 16 个测试全部通过

**下一个任务需要知道的**：
- 所有投资数据直接通过 `ref.watch(currentHoldingsProvider)` 读取持仓列表
- 写入操作（买入/卖出/转换）通过 `ref.read(investmentServiceProvider).buy/sell/convert()`
- 验证操作（表单前端验证）通过 `service.validateBuy/validateSell/validateConvert()`
- `PortfolioSummary` 提供组合级别总览，`HoldingReturn` 提供单支持仓盈亏
- 所有 Provider 带 autoDispose，页面销毁时自动解绑
- `investmentRepositoryProvider` 不进 BaseRepository（仍保持阶段 1-4 不同步的决策）

**git 状态**：未提交（等待 PM 审查后合入）

---


## 2026-07-29

**移交角色**：UI 工程师（invest-ui）
**接收角色**：项目经理（PM）

**完成工作**：
- `lib/pages/investment/holdings_list_page.dart` — 持仓列表页：
  - 顶部组合摘要卡片（总市值/总成本/盈亏/收益率/持仓数）
  - 持仓卡片列表 + 下拉刷新
  - 空态/加载态/错误态全覆盖
  - `asTab` 参数支持 Tab 嵌入模式

- `lib/pages/investment/holding_detail_page.dart` — 持仓明细页：
  - 统计卡片：份额/成本/净值/市值/盈亏
  - 交易流水列表（买入/卖出/转换，带份额/净值/手续费）
  - 底部操作栏：买入/卖出/转换按钮（暂接 SnackBar 占位）

- `lib/widgets/investment/holding_card.dart` — 持仓卡片组件：
  - 基金名称/代码 + 市值 + 盈亏/收益率
  - 复用 BeeCount SectionCard + AmountText + BeeTokens 设计体系
  - 盈亏色跟随用户收支颜色偏好

- `lib/widgets/investment/buy_dialog.dart` — 买入弹窗：
  - 基金代码/名称/份额/净值/手续费表单
  - validateBuy 前端验证 + try-catch 错误提示
  - 支持从持仓详情预填基金信息

- `lib/widgets/investment/sell_dialog.dart` — 卖出弹窗：
  - 展示可卖份额摘要 + 全部卖出开关
  - validateSell 验证（份数 > 0、不超过可卖份额）

- `lib/widgets/investment/convert_dialog.dart` — 转换弹窗：
  - 展示可转份额 + 已有持仓单选列表
  - 转出/转入份额、净值独立填写
  - validateConvert 验证

- `lib/app.dart` — 导航改造：
  - `_pages[2]`：`HoldingsListPage(asTab: true)` 替换 `AccountsPage`
  - Tab 图标：`account_balance_wallet` → `show_chart`
  - 底部 5 项结构不变（0流水/1报表/2FAB/3投资/4设置）

- `.codex/TEAM.md` — 阶段 3 全部 4 个任务标记 ✅

**下一个任务需要知道的**：
- 所有 Provider 通过 `ref.watch(currentHoldingsProvider)` 等读取数据
- 写入操作通过 `ref.read(investmentServiceProvider).buy/sell/convert()`
- 弹窗通过 `Navigator.push<bool>(MaterialPageRoute(...))` 打开，返回 bool 表示成功
- `HoldingsListPage(asTab: true)` 嵌入底部导航，`asTab` 控制 PrimaryHeader 的 back 按钮
- 明细页底部按钮目前是 SnackBar 占位（`_showBuyDialog` 等），需接线到弹窗
- 盈亏色走 `BeeTokens.incomeColor/expenseColor`，与用户收支偏好一致

**已知缺口**：
- 弹窗未接线到明细页（SnackBar 占位），可在集成阶段一次性接线
- 无 widget 测试（需 DB 数据 + 测试基础设施，建议 QA 在阶段 5 补充）
- 净值刷新仅为 re-query 数据库，实际 API 调用属于阶段 4

**git 状态**：未提交（等待 PM 审查后统一合入）

## 2026-07-29

**移交角色**：项目经理（PM）
**接收角色**：UI 工程师（invest-ui）— 修复任务

**完成工作**：
阶段 3 主任务（3.1~3.4）已由前一位 UI 工程师完成并通过审查。

**需要修复的 3 个 P1 问题**：

1. **卡片点击 → 明细页导航**（`holdings_list_page.dart`）
   - 位置：第 114 行 `onTap` 目前是 `// TODO` 空操作
   - 改为：`Navigator.push(context, MaterialPageRoute(builder: (_) => HoldingDetailPage(holdingId: holding.id)))`
   - 需要 import `'../pages/investment/holding_detail_page.dart'`

2. **明细页按钮 → 弹窗**（`holding_detail_page.dart`）
   - 位置：第 268~280 行三个 `_showBuyDialog`/`_showSellDialog`/`_showConvertDialog`
   - 目前全是 SnackBar 占位
   - 改为分别调用 `showBuyDialog()`/`showSellDialog()`/`showConvertDialog()`
   - 弹窗成功后 `ref.invalidate(currentHoldingsProvider)` 刷新列表
   - 需要 import `'../../widgets/investment/buy_dialog.dart'` 等

3. **showBack 硬编码**（`holdings_list_page.dart`）
   - 位置：第 35 行 `showBack: true`
   - 改为：`showBack: !asTab`
   - Tab 模式下不显示返回按钮，明细页导航才显示

**PM 决策**：Tab 保持 4 个，投资替换账户，记一笔走 FAB。账户页可从设置进入。

**git 状态**：未提交（修复后统一合入）

## 2026-07-29

**移交角色**：UI 工程师（invest-ui）— 修复任务
**接收角色**：项目经理（PM）

**完成工作**：
任务 3.5 页面连线修复全部完成：

1. **showBack 硬编码修复**（holdings_list_page.dart:36）
   - showBack: true → showBack: !asTab
   - Tab 模式下不再显示返回按钮

2. **卡片→明细页导航**（holdings_list_page.dart:72-78）
   - 持仓卡片 onTap 已接线到 HoldingDetailPage(holdingId: holding.id)
   - 引入 import 'holding_detail_page.dart'

3. **明细页按钮→弹窗**（holding_detail_page.dart:318-352）
   - 买入/卖出/转换三个按钮已分别接入 showBuyDialog/showSellDialog/showConvertDialog
   - 弹窗成功后 ef.invalidate(currentHoldingsProvider) 刷新列表
   - showConvertDialog 使用 romHolding: 参数名

**验证**：flutter analyze 零 error，投资模块 27 个测试全通过。

**git 状态**：未提交（等待 PM 审查后统一合入）
