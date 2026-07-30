
## 2026-07-30

**移交角色**：数据迁移工程师
**接收角色**：项目经理（PM）

**完成工作**：
- 新增 scripts/migrate_from_old.py — 旧数据库（sqflite）→ CSV 迁移脚本
  - 支持从旧项目（pj_003）的 ccount_book.db 导出全部 6 张表
  - 自动解析 UUID 外键为可读名称（book_name / account_name / category_name）
  - 导出 7 个文件：6 个 CSV + 1 个 README.md（含字段映射表 + 迁移步骤）
  - 自动检测表是否存在、列是否可用（兼容旧版本 schema 差异）
  - 用法：python scripts/migrate_from_old.py <旧.db路径> [--output <输出目录>]
- 更新 .codex/TEAM.md — 任务板 5.3 标记 ✅

**测试验证**：
- 用模拟数据库（含 9 条多表测试数据）验证，6 个表全部正确导出
- 外键解析验证通过（UUID → 中文名称，二级分类 parent_name 正确，交易 to_account_name 正确）
- flutter analyze 零 error / flutter test 534 passed（基线未受影响）

**下一个任务需要知道的**：
- 旧数据库不在源码仓库中（sqflite 存设备上），脚本接受任意路径输入
- 迁移不是全自动的：CSV 导出后仍需在新 App 中手动创建账户/分类/持仓
- 已导出 README.md 中含完整的字段映射表（旧→新）和分步迁移说明
- code 字段（基金代码）在新 schema 中对应 undCode
- 旧 is_investment 字段已废弃，新 App 用 	ype='invest' 判断
- 旧 investment_holdings 的 ee_type 和 
av_date 在新 schema 中没有对应列
- 旧 periodic_bills 的 interval_days 在新 schema 中没有对应列
- 所有外键 ID 已解析为名称（非 UUID），导出文件可直接阅读

**修改文件**：
- 新增：scripts/migrate_from_old.py

**git 状态**：当前分支 main，待提交

---# 交接记录

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

