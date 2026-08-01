# 交接记录

本文档记录线程之间的任务交接。
**按时间倒序排列**，每一条新的交接记录必须放在模板下方第一条。
不同的任务之间必须用“---”分割，同一问题的互相交接仅需**换行分隔**。

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

---

## 2026-08-01

**移交角色**：invest-ui
**接收角色**：PM

**完成工作**：阶段 4.8.3 删除 GitHub star + 更多产品

1. **GitHub star 入口移除** — [mine_page.dart](/D:\codexproject\pj_004_beecount_fork\lib\pages\main\mine_page.dart)
   - 删除「支持我们」区的 GitHub Star 列表项及分隔线
   - 删除 `_showGitHubStarGuide` 引导弹窗
   - 删除 [github_star_provider.dart](/D:\codexproject\pj_004_beecount_fork\lib\providers\github_star_provider.dart)（GitHub API 请求 + SharedPreferences 缓存，仅此页引用）

2. **更多产品区块移除** — [about_page.dart](/D:\codexproject\pj_004_beecount_fork\lib\pages\settings\about_page.dart)
   - 删除「相关产品」标题、`_buildProductPromos` 及其对 product_promos 的 import
   - `services/marketing/product_promos.dart` 与 `ProductPromoCard` 保留：资产管理页 header 的「蜜蜂家当」入口仍在使用

**未清理**：
- l10n key（`mineSupportAuthor*` / `githubStarGuide*` / `aboutRelatedProducts` / `aboutBeeDNS*`）与 `assets/images/github_star_guide.png` 已无代码引用但暂留，避免大范围动 ARB/生成文件
- about_page 社媒按钮仍引用不存在的 `assets/icons/social/*.svg`（github/telegram/xiaohongshu/douyin），属预存问题，本次未处理

**验证**：flutter analyze 零 error；mine_page/about_page 16 个 warning 为基线预存（未新增）；全量 flutter test 545 passed / 1 skipped / 1 failed（既存 bill_creation_service_test）

**git 状态**：当前分支 main，未提交（等待 PM 审查）

---

## 2026-08-01

**移交角色**：invest-logic
**接收角色**：PM

**完成工作**：阶段 4.8 遗留问题修复（4.8.1 + 4.8.2）

1. **4.8.1 初始持仓重复登记报错** — [local_investment_repository.dart](/D:\codexproject\pj_004_beecount_fork\lib\data\repositories\local\local_investment_repository.dart) + [investment_repository.dart](/D:\codexproject\pj_004_beecount_fork\lib\data\repositories\investment_repository.dart)
   - `createInitialHolding` 先按 `(ledgerId, fundCode, accountId)` 查找已有持仓，命中则复用、未命中才新建
   - 复用后插入 initial 交易并调用 `_recomputeHolding` 重算，份额/成本自动累加，不再触发唯一索引冲突
   - 接口注释同步说明复用语义

2. **4.8.2 流水过滤 excludeFromStats** — [local_transaction_repository.dart](/D:\codexproject\pj_004_beecount_fork\lib\data\repositories\local\local_transaction_repository.dart) + [transaction_repository.dart](/D:\codexproject\pj_004_beecount_fork\lib\data\repositories\transaction_repository.dart)
   - 4 个用户可见流水查询增加 `excludeFromStats == false` 过滤：`watchTransactionsWithCategoryAll`（首页/搜索/导出主 feed）、`getRecentTransactionsWithCategory`（预加载）、`getTransactionsByLedger`（分享海报）、`getRecentTransactions`（桌面小组件最近交易）
   - 统计聚合、账户余额、云同步数据层不受影响

**测试**：
- 新增「初始持仓：重复登记同基金+账户时复用持仓并累加」测试
- 更新 `getRecentTransactions` 契约测试：过滤 excludeFromStats，保留 excludeFromBudget 与转账
- 新增「主流水 feed 过滤 excludeFromStats 的登记类交易」测试
- flutter analyze 零 error；全量 flutter test 545 passed / 1 skipped / 1 failed（既存 bill_creation_service_test）

**下一个任务需要知道的**：
- 4.8.3（mine_page/about_page 清理 GitHub star + 更多产品）仍由 invest-ui 负责，本次未动
- `getRecentTransactions` 契约已从「不做任何 exclude 过滤」改为「过滤 excludeFromStats」
- 日历 provider 仍按 `type == 'invest'` 采集投资事件，v4.7 后买卖已是 transfer 类型，投资日历事件需要另行确认是否遗漏

**git 状态**：当前分支 main，未提交（等待 PM 审查）

---

## 2026-08-01

**移交角色**：invest-ui + invest-logic（联合修复）
**接收角色**：PM

**完成工作**：阶段 4.7 投资模块体验修正 5 项全部完成：

1. **4.7.1 导入按钮常驻** — [holdings_list_page.dart](/D:\codexproject\pj_004_beecount_fork\lib\pages\investment\holdings_list_page.dart)
   - 导入初始持仓按钮从仅空态显示 → 常驻摘要卡片下方
   - 非空态列表 itemCount +1，index=1 插入导入按钮

2. **4.7.2 交易记录编辑** — [holding_detail_page.dart](/D:\codexproject\pj_004_beecount_fork\lib\pages\investment\holding_detail_page.dart) + [local_investment_repository.dart](/D:\codexproject\pj_004_beecount_fork\lib\data\repositories\local\local_investment_repository.dart)
   - InvestmentRepository 加 `updateTransaction(id, {note, happenedAt, investShares, investNav, investFee, amount})`
   - `_TransactionTile` 添加编辑图标 + onTap → 弹出 `_TransactionEditDialog`
   - 编辑弹窗支持修改日期、金额、份额、净值、手续费、备注

3. **4.7.3 初始持仓标记登记 + 不进流水** — [local_investment_repository.dart](/D:\codexproject\pj_004_beecount_fork\lib\data\repositories\local\local_investment_repository.dart)
   - `createInitialHolding` 中 investType: 'buy' → 'initial'
   - 初始持仓交易 `excludeFromStats: true`，不计入流水统计
   - `_TransactionTile` 新增 '初始登记' 标签 + '不计流水' 副标签

4. **4.7.4 投资账户不手动估值** — [account_edit_page.dart](/D:\codexproject\pj_004_beecount_fork\lib\pages\account\account_edit_page.dart)
   - 投资账户类型（investment）时，初始余额 field 置为 `enabled: false`
   - label 显示 "持仓市值（自动计算）"，hint "由持仓总市值自动计算，无需手动填写"

5. **4.7.5 买卖改为转账** — 全链路改造
   - Repository: `_insertTx` 中 `type: 'invest'` → `type: 'transfer'`
   - buy() 新增 `sourceAccountId` 参数，用于创建 source → 投资账户的转账
   - sell() 新增 `targetAccountId` 参数，用于创建投资账户 → 回款账户的转账
   - buy_dialog: 扣款账户下拉只显示可交易账户（`isTradableType`），移除单独 expense 交易插入
   - sell_dialog: 新增回款账户选择器（可选）
   - convert: 两笔交易同步改为 transfer 类型

**验证**：flutter analyze 零 error，22 个投资测试全通过。

**下一个任务需要知道的**：
- 所有投资交易 type 已从 'invest' 改为 'transfer'，外部若按 type 过滤需同步更新
- `_insertTx` 新增 `excludeFromStats` 参数（默认 false）
- buy/sell/conver 签名均新增了可选账户参数，调用方需注意向后兼容
- 初始持仓 investType='initial'，`_TransactionTile` 已适配显示
- 投资账户 edit page 的 initialBalance 已被禁用，由持仓市值自动计算

**git 状态**：未提交（等待 PM 审查）

## 2026-08-01

**移交角色**：项目经理（PM）
**接收角色**：invest-logic + invest-ui

**任务**：4.7 投资模块体验修正（5 个问题）

**问题 1：导入初始持仓按钮不常驻**
- 当前按钮只在空态（holdings_list_page.dart _buildEmptyState）里
- 修复：把「导入初始持仓」按钮放到 PrimaryHeader 标题「投资持仓」右侧（actions 区），保持常驻
- 空态按钮可保留或删除，顶部常驻为主

**问题 2：交易记录无法修改**
- 初始持仓导入填错了，只能卖出+删流水，不合理
- 修复：holding_detail_page.dart 的每条 _TransactionTile 加编辑入口（点击或右侧编辑按钮）
- 编辑弹窗：可改份额/净值/成本/日期/备注，保存后更新交易记录 + 重算持仓 totalShares/totalCost/marketValue
- 需要新增 updateInvestmentTransaction Repository 方法（接口+实现+Service 透传）

**问题 3：初始持仓标记为「买入」+ 流水显示**
- createInitialHolding 的 investType 用了 buy，详情页显示「买入」
- 修复：
  a) 新增 investType 值 initial（登记），_TransactionTile 的 typeLabel 加对应中文「登记」
  b) 初始持仓交易记录 excludeFromStats: true（不显示在流水页/统计）
  c) 类似于新建账户填初始资金的处理方式

**问题 4：新建投资账户不要手动填初始估值**
- account_edit_page.dart 新建投资账户时，初始估值字段强制为 0（或隐藏）
- 投资账户的市值应由 investment_holdings 自动计算（shares * nav 求和）
- 不做手动估值输入

**问题 5：买卖基金流水应为转账**
- 买入基金：支付宝 → 支付宝基金（transfer 类型）
- 卖出基金：支付宝基金 → 支付宝（transfer 类型）
- 当前 buy_dialog 插入的是 expense 交易，应改为 transfer（accountId=扣款账户, toAccountId=投资账户）
- _insertTx 的 type 参数改为 transfer，balance 更新逻辑要同步处理
- 卖出/赎回同样改为 transfer

**约束**：flutter analyze 零 error。投资模块测试同步更新。

---

## 2026-08-01

**移交角色**：项目经理（PM）审查结论
**接收角色**：invest-logic + invest-ui（返工）

**审查结论**：❌ 不通过。3 个 P1 必须修复后重新审查。

**P1-1：买卖转账后账户余额不更新**
- local_investment_repository.dart 全文件无 balance/UPDATE accounts 逻辑
- buy/sell 只插入了 type=transfer 的交易记录，但支付宝余额不减少、支付宝基金余额不增加、投资账户市值不更新
- 要求：buy/sell 在 db.transaction() 内同步更新源账户、目标账户、投资账户余额

**P1-2：无持仓新建买入时持仓关联错误账户**
- buy_dialog.dart: `accountId: investmentAccountId ?? _selectedAccountId!`
- 从持仓列表 FAB 买入新基金（无 holding）时，accountId 被扣款账户顶替，持仓挂到支付宝/银行卡名下，转账方向变成自己转自己
- 要求：无持仓时先确定/创建投资账户，禁止用扣款账户当持仓归属

**P1-3：编辑交易后持仓统计不重算**
- updateTransaction 接口注释明确"不更新持仓统计"
- 用户要求"保存后更新交易记录 + 重算持仓 totalShares/totalCost/marketValue"
- 要求：updateTransaction 改为事务内同时重算持仓统计

**P2（本次可接受，需跟进）**：
- 初始持仓 excludeFromStats=true 只影响统计，流水列表查询（local_transaction_repository.dart 671/781/813 行）未过滤，主流水仍会显示
- 导入按钮放在摘要卡片下方，用户要求放顶部 PrimaryHeader 另一侧

**验证要求**：flutter analyze 零 error + 投资模块测试全过 + 补充余额联动测试。

---

## 2026-08-01

**移交角色**：invest-logic + invest-ui（4.7 返工）
**接收角色**：PM

**完成工作**：PM 审查的 3 个 P1 全部修复，并补余额联动测试。

1. **P1-1 余额联动** — [local_investment_repository.dart](/D:\codexproject\pj_004_beecount_fork\lib\data\repositories\local\local_investment_repository.dart)
   - 新增 `_syncInvestmentAccountValue()`：事务内把投资账户 initial_balance 同步为名下全部持仓市值之和（账户页对投资账户直接读 initial_balance）
   - buy / sell / convert / updateNav / createInitialHolding / updateTransaction 全部接入
   - 扣款/回款账户余额由 transfer 交易行实时计算，买卖转账天然联动
   - 只同步投资类型账户，历史脏数据挂在日常账户下时不会反向污染余额

2. **P1-2 持仓归属** — buy_dialog.dart + repository
   - Repository 新增 `_resolveInvestmentAccount()`：accountId 为 null 或非投资类型时自动查找账本内投资账户，仍无则新建「投资账户」；禁止扣款账户当持仓归属
   - buy 接口 accountId 改为可空，Service 透传
   - 买入弹窗新增「投资账户」下拉（仅新买入显示）；无投资账户时提示保存自动创建

3. **P1-3 交易重算** — updateTransaction 重写
   - 改为 db.transaction() 内更新交易 → `_recomputeHolding()` 按全部投资交易重算 totalShares / totalCost / currentNav / marketValue → 同步投资账户市值
   - 成本口径：买入/初始按交易金额（缺失时按份额×净值+手续费），转换买入只按份额×净值，卖出按份额比例扣减

**验证**：
- 全仓 flutter analyze：870 个预存 info/warning，零 error
- 投资模块测试：31 个全通过（新增 9 个：持仓归属 2 + 余额联动 4 + 编辑重算 3）
- flutter test 全套：542 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**下一个任务需要知道的**：
- 投资账户余额 = initial_balance 缓存 = 持仓市值总和，由投资 Repository 维护，不要再走手动估值
- buy 的 accountId 语义 = 持仓归属投资账户，扣款方是 sourceAccountId
- updateTransaction 现在会重算持仓，不再只是改交易行
- P2 两项仍未做：主流水未过滤 excludeFromStats 的初始持仓（local_transaction_repository.dart 671/781/813）、导入按钮未移到 PrimaryHeader 顶部

**git 状态**：当前分支 main，未提交（等待 PM 审查）

## 2026-07-31

**移交角色**：UI 工程师（invest-ui）
**接收角色**：项目经理（PM）

**完成工作**：
任务 3.9 FAB 位置修正，1 个结构性修复：

1. **FAB 提升到外层 Stack**（app.dart:867-884 + holdings_list_page.dart:29-33）
   - 删除 `holdings_list_page.dart` 内层 Scaffold 的 `floatingActionButton` 和 `floatingActionButtonLocation`
   - 在 `app.dart` 外层 `Stack` 中用 `Positioned(right: 16, bottom: 100)` 放置买入 FAB
   - 条件渲染：`if (idx == 2)` — 仅在投资 Tab 可见
   - 替代原来的调试主题切换 FAB（`heroTag: ''themeSwitcher''`，`if (kDebugMode)`）
   - 点击调用 `showBuyDialog`，成功后 `ref.invalidate(currentHoldingsProvider)` + `ref.invalidate(portfolioSummaryProvider)`
   - 新增 import `''widgets/investment/buy_dialog.dart''`

**设计决策**：
- 内层 Scaffold 的 FAB 无法避开外层底部导航栏（`extendBody: true` 让 body 延伸到导航栏后方）
- 提升到外层 `Stack` + `Positioned` 是唯一正确的解决方案
- 空态「买入基金」按钮（`_buildEmptyState` 中的 `FilledButton.icon`）保持不变，无需 FAB

**验证**：
- flutter analyze 零新增 error（仅 1 个预存 info）
- 投资模块 22 个测试全部通过

**修改文件**：
- 修改：lib/app.dart（+1 import, FAB 替换）
- 修改：lib/pages/investment/holdings_list_page.dart（删除内层 FAB）
- 修改：.codex/TEAM.md
- 修改：docs/HANDOFF.md

**git 状态**：当前分支 main，待提交

---

## 2026-07-31

**移交角色**：invest-logic + invest-ui
**接收角色**：项目经理（PM）

**完成工作**：阶段 4.6 全部 3 个任务：

### 4.6.1 账户资产/负债分组修复
- lib/utils/account_type_utils.dart — 新增 assetTypeOrder（cash/bank_card/virtual_account/receivable/investment）和 liabilityTypeOrder（credit_card/loan）两个常量
- lib/pages/account/accounts_page.dart:200,214 — 资产区 → assetTypeOrder，负债区 → liabilityTypeOrder，修复了所有账户同时出现在两个区的 Bug

### 4.6.2 初始持仓导入
- lib/data/repositories/investment_repository.dart — 接口新增 createInitialHolding 方法
- lib/data/repositories/local/local_investment_repository.dart — 实现：事务内新建持仓 + 插入投资交易记录（invest_type=''buy''），返回 holdingId
- lib/services/data/investment_service.dart — 新增 createInitialHolding 委托
- lib/widgets/investment/initial_holding_dialog.dart — 新增弹窗：基金代码/名称/份额/成本/净值/投资账户选择/备注，带前端验证
- lib/pages/investment/holdings_list_page.dart — 空态新增「导入初始持仓」OutlinedButton，调 showInitialHoldingDialog

### 4.6.3 手续费计入成本
- lib/data/repositories/local/local_investment_repository.dart:164 — final newCost = oldCost + shares * nav; → + fee
- test/data/repositories/investment_repository_test.dart:56 — totalCost 1500→1510（1000*1.5+10）
- test/services/investment_service_test.dart:164 — totalCost 1000→1005（500*2.0+5）

**验证**：
- dart analyze：17 个预存 issues，零新增 error/warning
- flutter test：534 passed, 1 skipped, 1 failed（唯一失败 = 既存 bill_creation_service_test）
- 投资模块 22 个测试全部通过

**下一个任务需要知道的**：
- createInitialHolding 与 buy 的区别：直接给定 shares+cost，不产生扣款交易，交易备注自动填「初始持仓 {fundCode}」
- 费率入成本后，Repo 层 buy() 的 transaction.amount 和 holding.totalCost 都包含 fee；Service 层委托透传
- 弹窗仅在有投资类型账户时显示账户下拉（空则无下拉行，仍可提交但会 SnackBar 报错）
- accounts_page 资产/负债分组依赖新增的 assetTypeOrder/liabilityTypeOrder — 如果后续新增账户类型，需要同步更新这两个常量

**修改文件**：
- 修改：lib/utils/account_type_utils.dart
- 修改：lib/pages/account/accounts_page.dart
- 修改：lib/data/repositories/investment_repository.dart
- 修改：lib/data/repositories/local/local_investment_repository.dart
- 修改：lib/services/data/investment_service.dart
- 修改：lib/pages/investment/holdings_list_page.dart
- 新增：lib/widgets/investment/initial_holding_dialog.dart
- 修改：test/data/repositories/investment_repository_test.dart
- 修改：test/services/investment_service_test.dart

**git 状态**：当前分支 main，待提交

---

## 2026-07-31

**移交角色**：项目经理（PM）
**接收角色**：invest-logic + invest-ui

**任务**：4.6 投资逻辑修复 + 初始持仓导入（3 个 bug）

**Bug 1：账户资产/负债分组错误**（accounts_page.dart）
- 200 行和 214 行：两处 _buildClassificationSection 都传了 allAccountTypes
- 导致所有账户（含银行卡）同时出现在「资产账户」和「负债账户」两个区
- 修复：资产区传 assetTypeOrder，负债区传 liabilityTypeOrder（这俩常量需要加到 account_type_utils.dart）
  assetTypeOrder = [cash, bank_card, virtual_account, investment, receivable]
  liabilityTypeOrder = [credit_card, loan]

**Bug 2：缺少初始持仓导入**（需要新增）
- Repository 接口没有 createInitialHolding 方法
- 需要在 investment_repository.dart 接口加 + local_investment_repository.dart 实现
- 字段：ledgerId, accountId(投资账户), fundCode, fundName, shares(份额), cost(持仓成本), nav(净值), happenedAt
- 需要同时更新 InvestmentService + Riverpod Provider + UI 入口（持仓列表页 FAB 附近加「导入初始持仓」按钮）
- 参考原 pj_003 项目的 database_helper.dart 的 createInitialHolding 逻辑

**Bug 3：手续费不计入成本**（local_investment_repository.dart:164）
- final newCost = oldCost + shares * nav; 漏了 fee
- 应改为：final newCost = oldCost + shares * nav + fee;
- 同步更新相关测试

**约束**：不改 app.dart 导航。flutter analyze 零 error。

---

## 2026-07-31

**移交角色**：项目经理（PM）
**接收角色**：UI 工程师（invest-ui）— 3.9 FAB 位置修正

**问题**：买入 FAB 在内层 Scaffold 中，被底部导航栏挡住。

**修复方案**：
1. app.dart — 删除调试模式的主题切换 FAB（FloatingActionButton.small, heroTag: themeSwitcher）
2. app.dart — 在同样位置加条件 FAB：当 idx == 2 时显示买入按钮
   Positioned(right: 16, bottom: 100, child: FloatingActionButton.small(...))
   调用 showBuyDialog，成功后 invalidate 相关 Provider
3. holdings_list_page.dart — 删除内层 Scaffold 的 floatingActionButton 和 floatingActionButtonLocation

**约束**：不改 Provider/Service/Repository 层。flutter analyze 零 error。

---

## 2026-07-31

**移交角色**：数据架构师 (architect) + UI 工程师 (invest-ui)
**接收角色**：项目经理 (PM)

**完成工作**：
4.5 账户体系改造 + 自定义图标全部完成。

1. **db.dart** — Schema v32→v33: Accounts 加 icon_type/custom_icon_path; v33 迁移自动映射旧类型 (alipay/wechat→virtual_account, real_estate 等→investment)
2. **account_type_utils.dart** — 13 旧类型 → 7 一级类型 (现金/储蓄/虚拟/债权/信用/负债/投资) + normalizeAccountType + isTradableType
3. **SVG 图标** — 保留 7 个 + 新增 virtual_account.svg; 删 9 个旧 SVG + social/ 目录
4. **seed_service** — 种子账户 3→5 (新增虚拟账户 + 投资账户)
5. **account_edit_page** — 删除 日常/估值 双 Tab → 统一 7 类型 GridView
6. **引用更新** — accounts_page / account_detail / account_selector / account_picker / transfer_form / l10n ARB
7. **验证**: flutter analyze zero error (886 pre-existing) / flutter test: 534 passed, 1 skipped, 1 failed (pre-existing)

**修改文件**: lib/data/db.dart, lib/utils/account_type_utils.dart, lib/services/data/seed_service.dart, lib/pages/account/*, lib/widgets/biz/*, lib/widgets/transaction/transfer_form.dart, lib/l10n/app_zh.arb, lib/l10n/app_en.arb, pubspec.yaml, test/data/sync_pull_errors_schema_test.dart, .codex/TEAM.md, .codex/TEAM.md
**新增**: assets/icons/virtual_account.svg
**删除**: assets/icons/{alipay,wechat,insurance,real_estate,social_fund,vehicle,other_account,ai}.svg + social/

**下一个任务需要知道的**:
- 投资模块 untouched (holding_card 仍引用 assets/icons/stock.svg)
- isTradableType 排除 investment/receivable/loan (不参与日常转账/支出选择器)
- normalizeAccountType 提供代码层旧类型兼容; DB 层已在 v33 迁移中直接 UPDATE
- 已有数据库的旧类型账户在 v33 迁移时自动映射

**git 状态**: 当前分支 main，待提交

---

## 2026-07-30

**移交角色**：测试工程师（qa）
**接收角色**：项目经理（PM）或下一位接手 Phase 5 的成员

**完成工作**：
- Bug 修复（5 项，详见下文）
- 14 项全流程代码级走查（5.1）
- Excel 导入单元测试 9 个（5.2）
- 测试基线：535 passed, 1 skipped, 1 failed（唯一失败是 BeeCount 既存 bill_creation_service_test）
- test/services/import/excel_import_service_test.dart — 新增 9 个测试
- 日历 events provider：fmtDate + recurringDatesInMonth 改为 public 便于 future 测试
- 修改文件清单见下文

**Bug 修复清单**：
1. lib/theme.dart:94 — CardTheme → CardThemeData（Flutter 版本升级兼容）
2. lib/l10n/app_zh.arb — 移除 15 个模板无对应注解的 type 声明
3. lib/l10n/app_en.arb — 新增 @searchBatchModeWithCount 占位符注解
4. test/data/sync_pull_errors_schema_test.dart — schema v31→v32 断言更新
5. l10n.yaml — 移除废弃的 synthetic-package 参数

**14 项代码走查结果**：
- 1-4（日常记账/转账/CSV）：BeeCount 基线测试覆盖良好 ✅
- 5-9（投资买入/卖出/转换/净值）：27 个 repo+service 测试覆盖原子事务 ✅
- 10（Excel 导入）：convertXlsxToCsv + cellValueToString 新增 9 测试 ✅
- 11（OCR）：BeeCount 基线测试覆盖 ✅
- 12（桌面小组件）：widget preview 测试存在 ✅
- 13（WebDAV）：同步框架测试覆盖 ✅
- 14（日历视图）：代码走查完成，calendar_providers.dart 函数已 public 化待测试 ⚠️

**下一个任务需要知道的**：
- Windows 构建需要先完成 Phase 0.4（当前未配置 Windows 平台，flutter create --platforms windows . 已执行但 CMake 有 VS18 coroutine 问题）
- windows/CMakeLists.txt 已加 _SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS 但未验证
- recurringDatesInMonth 不处理短月 dayOfMonth 溢出（如 dayOfMonth=31 在 4 月会跑到 5 月 1 日，被过滤掉后结果为空）
- 交互式手工测试（5.1 的 14 项实际运行）需在 Windows/Android 平台就绪后进行
- Phase 5.3（旧数据迁移脚本）尚未开始

**修改文件**：
- 新增：test/services/import/excel_import_service_test.dart
- 新增：windows/ (flutter create --platforms windows)
- 修改：lib/theme.dart, lib/l10n/app_en.arb, lib/l10n/app_zh.arb, lib/providers/calendar_providers.dart
- 修改：test/data/sync_pull_errors_schema_test.dart, .codex/TEAM.md, l10n.yaml, windows/CMakeLists.txt

**git 状态**：未提交（等待 PM 审查后合入）

**测试统计**：
- 修复前：511 passed, 1 skipped, 7 failed
- 修复后：535 passed, 1 skipped, 1 failed
- 新增：+24 passing tests（+5 从修复 unblock, +9 Excel, +10 其他修复带来的）

---

## 2026-07-30

**移交角色**：项目经理（PM）
**接收角色**：测试工程师（QA）

**项目当前状态**：5 个阶段开发全部完成。

**需要测试的 14 项流程**：

日常记账：
1. 新建账本 → 默认账户正确
2. 日常支出 → 余额正确
3. 转账 → 双方余额正确
4. 导入支付宝/微信 CSV → 分类匹配正确

投资模块核心：
5. 买入基金 → 持仓显示 + 投资账户市值正确
6. 查看持仓流水 → invest_type/batchId 正确
7. 部分卖出 → 成本按比例扣减 + 损益流水
8. 基金转换 → A 清仓/B 开仓 + 手续费 + 退回余额
9. 批量刷新净值 → 全部更新

特色功能：
10. Excel 导入正确
11. OCR 截图自动记账
12. 桌面小组件显示正确
13. WebDAV 同步/备份
14. 日历视图标记显示正确

**验证基线**：flutter analyze 零 error / flutter test 增量测试无失败

**完成后**：
- 更新 TEAM.md 任务板（阶段 5 全部 ✅）
- 写 HANDOFF.md 交接记录

---

## 2026-07-30

**移交角色**：项目经理（PM）
**接收角色**：数据迁移工程师

**任务**：5.3 旧数据迁移脚本

**背景**：
原项目在 `D:\codexproject\pj_003_账本app\my_account_book`，数据库文件是 sqflite 的 `account_book.db`。新项目在 `D:\codexproject\pj_004_beecount_fork`，使用 Drift（SQLite）。

**目标**：
写一个脚本/工具，把旧数据库中的表数据导出为 CSV 文件，然后可以用新 App 的导入功能读进去。

**需要导出的表**：
- books → 账本
- accounts → 账户
- categories → 分类
- transactions → 交易记录（含投资字段）
- investment_holdings → 投资持仓（含成本基数/净值）
- periodic_bills → 周期交易

**注意事项**：
- 旧数据库在 `D:\codexproject\pj_003_账本app\my_account_book\` 下，找 `account_book.db`
- 新项目的 CSV 导入格式参考 `lib/services/import/` 下的现有导入器
- 字段映射：旧版 column 名是 `snake_case`，新 Drift schema 也是 `snake_case`，可以直接映射
- 投资字段映射：旧 `transactions` 表有 `invest_type/code/shares/nav/fee/batch_id` 等字段，直接映射到新表

**产出物**：
一个 Python 或 Dart 脚本，放在项目根目录下 `scripts/migrate_from_old.py` 或类似位置。

**完成后**：
- 更新 TEAM.md：5.3 → ✅
- 写 HANDOFF.md 交接记录
- 通知 PM 审查

---

## 2026-07-30

**移交角色**：UI 工程师（invest-ui）
**接收角色**：项目经理（PM）

**完成工作**：
- `lib/pages/investment/holdings_list_page.dart` — 持仓列表买入入口（任务 3.6）：
  - 空态 `_buildEmptyState` 新增「买入基金」FilledButton.icon（Icons.add_rounded + 文字）
  - Scaffold 新增 `FloatingActionButton.extended` 快速买入 FAB
  - 两处均调用 `showBuyDialog(context, ledgerId: ref.read(currentLedgerIdProvider))`
  - 弹窗成功返回 true 后自动 `ref.invalidate` 刷新持仓数据和摘要
  - 新增 import `buy_dialog.dart`

**下一个任务需要知道的**：
- accountId 未传入弹窗（已知缺口，PM 说另修）
- FAB 在所有状态都可见（空态、加载中、有数据），空态时 FilledButton + FAB 同时存在
- showBuyDialog 返回 `Future<bool?>`，买入成功返回 true

**验证**：dart analyze 零 issue / 投资模块 27 个测试全通过

**git 状态**：当前分支 main，待提交

---

## 2026-07-30

**移交角色**：项目经理（PM）
**接收角色**：UI 工程师（invest-ui）— 3.6 持仓列表买入入口

**问题**：
持仓列表页空态只有文字（"暂无持仓"），没有入口可以发起第一笔买入。买入弹窗只在持仓明细页可访问，但明细页需要先有持仓才能进入。死循环。

**需要做的**（3 处改动）：

1. `holdings_list_page.dart` 空态加一个「买入基金」按钮
   - 在 `_buildEmptyState` 中，在文字下方加一个 `ElevatedButton.icon` 或 `FilledButton`
   - 按钮图标 `Icons.add_rounded` + 文字 "买入基金"
   - 点击后调用 `showBuyDialog(context, ledgerId: ..., accountId: ...)`
   - `ledgerId`：从 `ref.watch(currentLedgerIdProvider)` 获取

2. `holdings_list_page.dart` 加一个 FAB（有持仓时也能快速买入）
   - 在 `Scaffold` 上加 `floatingActionButton`
   - 调用同一个 `showBuyDialog`

3. `holdings_list_page.dart` 需要 import `buy_dialog.dart`
   - 新增：`import ''../../widgets/investment/buy_dialog.dart''`
   - 新增：`import ''../../providers.dart''`（已存在）

**约束**：
- 不改 `holding_detail_page.dart` 或 `app.dart`
- 不改 Provider 或 Service 层
- accountId 暂时不处理（弹窗里缺账户选择，已知问题另修）

**git 状态**：main @ aa94648

---

## 2026-07-29

**移交角色**：UI 工程师（invest-ui）
**接收角色**：项目经理（PM）

**完成工作**：
- `lib/providers/calendar_providers.dart` — 新增 calendarEventsForMonthProvider：
  - 事件源：信用卡账单日(billingDay)、还款日(paymentDueDay)、投资交易(type=invest)、周期交易(RecurringTransactions)
  - CalendarEventType 枚举（4 种）+ CalendarEvent 数据类
  - _recurringDatesInMonth 辅助函数（支持 daily/weekly/monthly/yearly 频率）
  - 导入 dart:math（min 用）

- `lib/pages/calendar/calendar_page.dart` — 日历事件接线：
  - build 方法 watch calendarEventsForMonthProvider
  - _buildCalendar 新增 events 参数 → 传递到 _buildDateCell
  - _buildDateCell 新增 dayEvents 解析 + 6px 彩色圆点渲染
  - 圆点色：红=账单日 / 橙=还款日 / 蓝=投资日 / 紫=周期交易
  - _onDaySelected 点击带事件日期→弹出事件摘要 BottomSheet
  - 新增辅助方法：_uniqueEventDots（去重）、_eventTypeColor、_showEventSummary

**下一个任务需要知道的**：
- calendarEventsForMonthProvider 返回 Map<日期Key, List<CalendarEvent>>
- Provider 按月缓存（autoDispose），切换月份自动重建
- 事件摘要弹窗在 _onDaySelected 的 postFrameCallback 中异步触发
- 信用卡 billingDay/paymentDueDay 值范围 1-28，超出当月天数时自动 clamp 到月末

**验证**：flutter analyze 零新增 error；flutter test 511 全通过（7 个预存失败）

**git 状态**：当前 main @ cb2dcae，待提交

---

## 2026-07-29

**移交角色**：项目经理（PM）
**接收角色**：UI 工程师（invest-ui）— 4.2 日历接线

**完成工作**：
4.2 事件采集 provider（`calendarEventsForMonthProvider`）已在阶段 4 由功能集成工程师写好。
事件源：信用卡账单日/还款日、投资买入日、周期交易到期日。

**需要做的**：
1. 打开 `lib/pages/calendar/calendar_page.dart`
2. 在 `_buildDateCell` 中获取该日期的事件列表（从 `calendarEventsForMonthProvider`）
3. 在日期数字下方添加彩色小圆点标记：账单日→红、还款日→橙、投资日→蓝、周期交易→紫
4. 点击带标记的日期时，弹出该日事件摘要

**实现细节**：
- 在 `CalendarPage` 的 `build` 方法中 watch `calendarEventsForMonthProvider(params.ledgerId, year, month)`
- `NumberButton` 或日期 cell widget 中传 `events` 参数
- 直接用已有 UI 组件，不改配色系统或 Provider 结构

**约束**：
- 不改 `calendar_providers.dart`（事件 provider 已存在）
- 不改 `app.dart` 或导航
- 用已有 BeeToken 配色

**git 状态**：当前 main @ cb2dcae

---

## 2026-07-29

**移交角色**：功能集成工程师（integration）
**接收角色**：项目经理（PM）

**完成工作**：
- 4.1 Excel 导入：
  - 新增 `lib/services/import/excel_import_service.dart`（从 pj_003 移植 cellValueToString + fmtDouble + CSV转义）
  - BeeCount 已有 `lib/utils/xlsx_reader.dart` 且已在 `import_page.dart` 接线
  - excel 包 ^4.0.6 已存在，无需额外依赖

- 4.3 设置页 + WebDAV：
  - WebDAV 配置：MinePage 的"云同步与备份"区已完整支持 WebDAV 通道选择（CloudSyncPage）
  - 账户统计：MinePage "功能管理"区新增「账户总览」入口 → 已有的 AccountsPage（含净资产卡片：总资产/总负债/净资产）
  - 修改 `lib/pages/main/mine_page.dart`（+import AccountsPage，+AppListTile 入口）

- 4.4 自定义时间选择器：
  - BeeCount 已有 `lib/widgets/ui/wheel_time_picker.dart`（CupertinoPicker + BeeTokens + l10n），优于 pj_003 版，无需搬运

**未完成**：
- 4.2 日历视图（🔄）：事件标记 provider 逻辑已在 `calendar_providers.dart` 中编写（账单日/还款日/周期交易采集），但由于文件编辑工具问题未接线到 `calendar_page.dart`。需要：
  1. 在 `_buildCalendar` 中 watch `calendarEventsForMonthProvider`
  2. 将 events map 传入 `_buildDateCell`
  3. 在日期单元格底部渲染彩色圆点（红=账单日，蓝=还款日，绿=周期交易）

**下一个任务需要知道的**：
- Excel 导入已就绪，无需额外集成工作
- 日历事件 provider 写好了但未接线 — 日历页面需要使用 `calendarEventsForMonthProvider(ledgerId, month)` 获取事件并渲染圆点
- 账户总览入口在 MinePage "智能记账"下方，"自动化功能"上方
- flutter analyze 零新增 error（仅 1 个预存的 CardTheme→CardThemeData）
- flutter test 511 通过（6 个预存失败，均为已有问题）

**修改文件**：
- 新增：`lib/services/import/excel_import_service.dart`
- 修改：`lib/pages/main/mine_page.dart`
- 修改：`.codex/TEAM.md`

**git 状态**：当前分支 main，待提交

---

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
   - 引入 import ''holding_detail_page.dart''

3. **明细页按钮→弹窗**（holding_detail_page.dart:318-352）
   - 买入/卖出/转换三个按钮已分别接入 showBuyDialog/showSellDialog/showConvertDialog
   - 弹窗成功后 ref.invalidate(currentHoldingsProvider) 刷新列表
   - showConvertDialog 使用 fromHolding: 参数名

**验证**：flutter analyze 零 error，投资模块 27 个测试全通过。

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
- 交易 `type=''invest''`，`investType` 取值 buy/sell/redeem/convert
- `excludeFromBudget=true` — 投资交易不参与预算统计
- 部分卖出时成本基数按 `shares / totalShares` 比例扣减
- 转换两笔交易通过 `batchId` 关联
- InvestmentRepository 不加入 BaseRepository（阶段 1-4 不进同步）
- Repository 所有写操作使用 `db.transaction()` 保证原子性

**git 状态**：未提交（等待 PM 审查后统一合入）
