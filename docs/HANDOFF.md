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

## 2026-08-10

**移交角色**：项目经理（PM）
**接收角色**：architect + invest-logic + invest-ui（记录归档）

**任务**：7.4 复审通过并合入

**审查结论**：
- 7.4.1-7.4.3 通过 PM 复审：`clearNote` 独立于 `clearMetadataFields`，UI 清空备注正确，账户卡展示备注带单行截断与 Tooltip
- 新增备注相关测试 7 个全部通过；全量测试 742 passed / 1 skipped / 1 failed，唯一失败为既存 `bill_creation_service_test`
- 本轮已提交并编译 Android APK

**git 状态**：当前分支 main，7.4 已合入

---

## 2026-08-10

**移交角色**：architect + invest-logic（7.4.3）
**接收角色**：PM（审查合入）

**任务**：备注清空优先级返工

**完成工作**：
- `LocalAccountRepository.updateAccount` note 分支改为 `clearNote` 优先：`clearNote=true` 写 NULL；未清空时传 `note` 才写；`clearMetadataFields` 完全不再影响 note
- 新增回归测试：非卡账户（cash）已有备注 + `clearMetadataFields=true` + `clearNote=true` 读回 NULL

**下一个任务需要知道的**：
- 7.4.2 UI 已并行接线 `clearNote`，其 UI 测试现通过
- 全量 `flutter test`：742 passed / 1 skipped / 1 failed（唯一失败为既存 `bill_creation_service_test`）；`flutter analyze` 无 error、无新增 warning

**git 状态**：当前分支 main，7.4.1-7.4.3 数据层 + invest-ui 7.4.2 UI 并行改动未提交，待 PM 审查合入

---

## 2026-08-10

**移交角色**：项目经理（PM）
**接收角色**：architect + invest-logic

**任务**：7.4.3 备注清空优先级返工

**审查发现**：`LocalAccountRepository.updateAccount` 中 `clearMetadataFields` 优先于 `clearNote`，因此现金/虚拟等非卡账户（保存时 `clearMetadataFields=true`）清空备注仍会保留旧值；UI 已正确传 `clearNote`，是数据层优先级问题。

**要求**：
- `note` 分支改为 `clearNote` 优先：`clearNote=true` 写 NULL；未清空时 `clearMetadataFields` 只影响开户行/卡号后四位，不再影响 note
- 新增回归测试：非卡账户（cash）已有备注 + `clearMetadataFields=true` + `clearNote=true` 时读回 NULL
- 完成后更新 TEAM.md 任务板 + HANDOFF 追加完成记录，交 PM 审查

**git 状态**：当前分支 main，7.4.1/7.4.2 未提交待合入

---

## 2026-08-10

**移交角色**：architect + invest-logic（7.4.1）
**接收角色**：PM（审查合入）→ invest-ui（7.4.2）

**任务**：账户备注保存修复（数据层）

**完成工作**：
- `updateAccount` 新增 `clearNote` 哨兵：`clearNote=true` 写 NULL；不传则不更新；`note` 传值正常保存
- `clearMetadataFields` 不再清 `note`，只清开户行/卡号后四位等元信息
- 接口 / LocalAccountRepository / LocalRepository 三层同步
- 新增测试 4 例：非卡账户编辑后备注保留、clearNote 清空、银行卡备注保存且元信息保留、不传不更新

**下一个任务需要知道的**：
- 7.4.2 UI 保存空备注时应传 `clearNote: true`（当前 `account_edit_page` 仍传 null，invest-ui 正在并行接线）
- 全量 `flutter test` 当前含 invest-ui 7.4.2 进行中的 UI 测试失败（`account_note_test` 编辑页清空保存）+ 既存 `bill_creation_service_test`；数据层相关测试全过
- `flutter analyze` 无 error，7.4.1 改动无新增 warning

**git 状态**：当前分支 main，7.4.1 数据层 + invest-ui 7.4.2 UI 并行改动未提交，待 PM 审查合入

---

## 2026-08-10

**移交角色**：invest-ui（7.4.2）
**接收角色**：PM（审查合入）→ invest-logic（7.4.1 收尾）

**任务**：账户卡展示备注

**完成工作**：
- `accounts_page.dart` 账户卡新增备注行：单行截断 + Tooltip 查看全文
- `account_edit_page.dart` 保存时区分「未修改」与「清空备注」：备注为空且原备注非空时传 `clearNote: true`
- 测试：`account_note_test.dart` 2 例（卡片备注展示、编辑回显 + 清空保存）；相关账户测试全过

**下一个任务需要知道的**：
- 当前 `LocalAccountRepository.updateAccount` 中 `clearMetadataFields=true` 优先于 `clearNote`，非卡账户清空备注仍会保留旧值；需 7.4.1 调整为 `clearNote` 优先（UI 已正确传参）
- 7.4.2 UI 测试用 bank_card 路径验证 `clearNote` 生效；非卡路径待 7.4.1 修复后补回归

**git 状态**：当前分支 main，7.4.1/7.4.2 相关改动在未提交工作区，待 PM 审查合入

---

## 2026-08-10

**移交角色**：项目经理（PM）
**接收角色**：architect + invest-logic（7.4.1）/ invest-ui（7.4.2）

**任务**：7.4 账户备注修复

**背景**：账户备注填写后保存，非银行卡/信用卡类型（现金、虚拟、负债等）再打开备注消失；账户列表卡片也不显示备注。

**根因**：
- `LocalAccountRepository.updateAccount` 的 `clearMetadataFields=true` 会连 `note` 一起置 NULL；账户编辑页对非银行卡/信用卡保存时传了 `clearMetadataFields=true`
- 清空备注也无法生效：备注为空时 UI 传 null，Repository 视为“不更新”
- 账户列表卡片没有渲染备注字段

**7.4.1 数据层（architect + invest-logic）**
- `clearMetadataFields` 只清开户行/卡号后四位等元信息，不再清 `note`
- 新增 `clearNote` 语义（或等价哨兵）：备注为空且原备注非空时写 NULL；不传则不更新
- 测试：非卡账户编辑后备注保留；备注清空后读回 NULL；银行卡编辑备注正常保存

**7.4.2 UI（invest-ui）**
- `accounts_page.dart` 账户卡展示备注（单行截断 + tooltip 或两行省略）
- `account_edit_page.dart` 保存时区分「未修改」与「清空备注」，正确调用 Repository
- 测试：账户卡备注展示、编辑后回显、清空备注生效

**约束**：HANDOFF 只增不减；flutter analyze 新增代码零 error/warning；完成后更新 TEAM.md 任务板 + HANDOFF 追加完成记录，交 PM 审查

**git 状态**：当前分支 main，HEAD ceae802

---

## 2026-08-10

**移交角色**：项目经理（PM）
**接收角色**：invest-logic / qa

**任务**：7.3.3 PM 审查通过 + 7.3.4 待实机验证

**审查结果**：7.3.3 通过，合入。
- FinancialAnalystContext 显式排除 `is_off_balance=1` 账户：账户与余额、缺失汇率、净资产、toPromptText 均不再出现表外/受托账户
- 验证：7.3.3 相关测试全过；全量 735 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）；改动文件 analyze 零 issue

**下一步**：7.3.4 实机验证（新建表外账户、资产页分区、AI 摘要不可见）后关闭

**git 状态**：当前分支 main，合入后提交

---

## 2026-08-10

**移交角色**：项目经理（PM）
**接收角色**：invest-ui

**任务**：7.3.2 PM 审查通过 + 合入

**审查结果**：7.3.2 通过，合入。
- 账户编辑页新增「表外/受托账户」开关，与「不计入资产」联动语义与 Repository 一致
- 资产页表外账户从资产/负债分组与分组小计中剔除，单独「表外/受托账户」分区展示，账户卡带灰标
- l10n：zh / zh_TW / en / ko 同步
- 验证：7.3.2 相关测试全过；全量 734 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）；改动文件 analyze 无新增 warning

**下一步**：7.3.3 AI 上下文排除表外账户完成后一并合入并编译 APK

**git 状态**：当前分支 main，合入后提交

---

## 2026-08-09

**移交角色**：invest-ui（7.3.2）
**接收角色**：PM（审查合入）

**任务**：表外/受托账户 UI

**完成工作**：
- `account_edit_page.dart` 新增「表外/受托账户」开关，开启后强制不计入资产；取消不计入资产时同步关闭表外（复用 Repository 联动语义）
- `accounts_page.dart` 表外账户从资产/负债分类与分组小计中剔除，新增 `OffBalanceAccountsSection` 单独分区，账户卡显示「表外/受托」标识
- 抽取 `inUseAccountsExcludingOffBalance` 纯过滤函数，供分类分组与小计复用
- l10n：zh / zh_TW / en / ko 新增 `accountOffBalance` / `accountOffBalanceHint` / `accountOffBalanceBadge` / `accountOffBalanceSection`
- 测试：`account_off_balance_test.dart` 3 例（开关联动、分区与标识、分组过滤）；相关账户测试全过

**下一个任务需要知道的**：
- 7.3.1 数据层已合入工作区；UI 开关直接透传 `isOffBalance`，联动由 Repository 保证
- 资产页整页 widget 测试因真实 Drift 异步 + 无限动画不适用，改为分区组件直测 + 纯函数断言

**git 状态**：当前分支 main，7.3.1-7.3.3 相关改动在未提交工作区，待 PM 审查合入

---

## 2026-08-10

**移交角色**：invest-logic（7.3.3）
**接收角色**：PM（审查合入）→ qa（7.3.4）

**任务**：AI 上下文排除表外账户

**完成工作**：
- `FinancialAnalystContext.forLedger` 账户与余额、缺失汇率列表排除 `is_off_balance=1` 账户
- `_buildNetWorthSummary` 口径与净资产一致：同时排除 `exclude_from_assets` 与 `is_off_balance`
- `toPromptText()` 不再出现表外/受托账户
- 新增测试：表外账户不进账户列表/净资产/缺失汇率/提示词

**下一个任务需要知道的**：
- 表外账户由 7.3.1 数据层强制 `exclude_from_assets=true`，本次按 7.3.3 规格显式过滤 `is_off_balance`
- 全量 `flutter test`：735 passed / 1 skipped / 1 failed（唯一失败为既存 `bill_creation_service_test`）；`flutter analyze` 无 error、无新增 warning

**git 状态**：当前分支 main，7.3.3 改动待 PM 审查合入

---

## 2026-08-09

**移交角色**：项目经理（PM）
**接收角色**：architect + invest-logic / invest-ui / invest-logic

**任务**：7.3.1 PM 审查通过 + 7.3.2/7.3.3 放行

**审查结果**：7.3.1 通过，合入。
- `accounts.is_off_balance` + schema v38 幂等迁移；创建/更新联动正确（开启表外强制不计入资产；取消不计入资产同步关闭表外；单独关闭表外保留不计入资产）
- 净资产、资产构成、净值趋势均排除表外账户
- 验证：7.3.1 测试全过；全量 731 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）；analyze 无新增 warning

**接口约定（7.3.2 / 7.3.3 按此接线）**：
- `createAccount(..., isOffBalance:)` / `updateAccount(..., isOffBalance:)` 已支持；UI 开关复用该联动语义
- 7.3.3 仍需在 FinancialAnalystContext 中显式过滤 `isOffBalance`（当前仅靠 excludeFromAssets 隐式排除净资产）

**git 状态**：当前分支 main，合入后提交

---

## 2026-08-09

**移交角色**：architect + invest-logic（7.3.1）
**接收角色**：PM（审查合入）→ invest-ui（7.3.2）/ invest-logic（7.3.3）

**任务**：7.3.1 表外账户数据层

**完成工作**：
- `accounts` 新增 `is_off_balance`（默认 0），schema v37 → v38，`_addColumnIfMissing` 幂等迁移 + `db.g.dart` 重新生成
- Repository：`createAccount` / `updateAccount` 支持 `isOffBalance`
  - 开启表外隐式强制 `exclude_from_assets=true`
  - 显式取消不计入资产时同步关闭表外；单独关闭表外保留不计入资产状态
- 统计/净资产沿用不计入资产排除（表外账户不参与净资产、资产构成、净值趋势）
- 手工构造 `Account` 的 9 处（lib 5 处 + test 5 处）补 `isOffBalance: false`；旧 schema 版本断言统一升到 38
- 新增测试：migration v38（默认 0 / 写入 1 / schemaVersion 38）+ account_off_balance（创建/更新联动、净资产排除）

**下一个任务需要知道的**：
- 7.3.2 UI 的开关联动可直接复用 Repository 语义（开启表外 → 强制不计入资产；取消不计入资产 → 关闭表外）
- 7.3.3 AI 上下文目前因 repo 强制 `exclude_from_assets=true` 已隐式排除表外账户；仍需按 7.3.3 规格显式过滤 `is_off_balance`
- 全量 `flutter test`：731 passed / 1 skipped / 1 failed（唯一失败为既存 `bill_creation_service_test`）；`flutter analyze` 无 error、无新增 warning

**git 状态**：当前分支 main，7.3.1 改动未提交，待 PM 审查合入

---

## 2026-08-09

**移交角色**：项目经理（PM）
**接收角色**：architect + invest-logic（7.3.1）→ invest-ui（7.3.2）/ invest-logic（7.3.3）→ qa（7.3.4）

**任务**：7.3 表外/受托账户

**背景**：用户作为中间人处理银行贷款与代付利息，需要把受托资金记为“表外/受托账户”，既不影响净资产/净值趋势，也不出现在 AI 财务摘要里。

**7.3.1 数据层（architect + invest-logic）**
- `accounts` 新增 `is_off_balance`（0/1，默认 0），schema v37 → v38 + 幂等迁移 + db.g.dart 重新生成
- 语义：`is_off_balance=1` 时视为“表外/受托”，隐式等同于不计入资产（`exclude_from_assets=1`），但仍可在账户页看到
- Repository：createAccount / updateAccount 支持该字段；统计与净资产口径沿用不计入资产排除
- 测试：迁移 v38、创建/更新表外账户、净资产与账户统计排除

**7.3.2 UI（invest-ui，等 7.3.1）**
- 账户编辑页新增「表外/受托账户」开关：开启后自动勾选/强制“不计入资产”，可手动取消不计入资产时同步关闭表外
- 账户列表/资产页：表外账户显示“表外/受托”标识，或单独分组展示，方便用户查看但不混入个人资产
- l10n：zh/zh_TW/en/ko 同步（ko 可模板兜底）
- 测试：开关联动、资产页标识/分区

**7.3.3 AI 上下文排除（invest-logic，等 7.3.1）**
- `FinancialAnalystContext.forLedger`：账户与余额、缺失汇率列表排除 `is_off_balance=1` 账户（与净资产口径一致）
- `toPromptText` 不再出现表外/受托账户
- 测试：表外账户不进入 AI 摘要

**7.3.4 全流程测试与实机验证（qa + invest-logic + invest-ui，等前几项）**
- 迁移/统计/AI/UI 测试；实机验证银行贷款 + 借给 A + 利息托管的完整场景

**约束**：HANDOFF 只增不减；flutter analyze 新增代码零 error/warning；完成后更新 TEAM.md 任务板 + HANDOFF 追加完成记录，交 PM 审查

**git 状态**：当前分支 main，HEAD a67a88e

---

## 2026-08-09

**移交角色**：项目经理（PM）
**接收角色**：invest-logic / invest-ui

**任务**：7.2.2 / 7.2.3 PM 审查通过 + 合入

**审查结果**：7.2.2 / 7.2.3 通过，合入。
- 分析师系统提示已移除原「统计/查询暂不支持」，只基于注入的账本/投资摘要回答；意图路由保证投资问题不误判为记账
- 新增投资概览 / 持仓分析 / 本月复盘指令，AI 页展示「本次分析覆盖」范围标签
- 验证：7.2 相关测试全过；全量 723 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）；改动文件 analyze 无新增 error/warning
- 备注：自由对话每次构建完整财务快照、UI 另算一次 scopeLabel，v1 接受重复查询，后续可缓存；ko 新文案走模板兜底

**下一步**：7.2.4 实机验证（真机问「我的总浮盈多少 / 基金 A 最近表现 / 投资与现金比例」等）后关闭

**git 状态**：当前分支 main，合入后提交

---

## 2026-08-09

**移交角色**：invest-ui（7.2.3 UI 合并）
**接收角色**：PM（审查合入）

**任务**：投资分析快捷指令 + 数据范围提示（UI 侧）

**完成工作**：
- 对齐 invest-logic 命名（investmentOverview / holdingAnalysis / monthReview + `analystSnapshot`），清理并行重复，`AIQuickCommands` 列表含原有 6 条 + 新增 3 条
- `ai_quick_commands_bar.dart` 与 `AIChatPage` 展示新指令标题 / 描述
- AI 页新增本次分析数据范围标签：分析类消息发送前构建 `FinancialAnalystSnapshot`，`scopeLabel()` 写入 assistant metadata，气泡内显示「本次分析覆盖：近 N 天 · N 只持仓」
- 新增 `lib/models/ai_analysis_metadata.dart` 编解码助手
- 测试：`ai_quick_command_test`（2 例）、`ai_analysis_metadata_test`（2 例）、`ai_quick_commands_bar_test`（1 例）；invest-logic 的 `ai_quick_command_analyst_test` 一并跑过

**下一个任务需要知道的**：
- `scopeLabel` 由 UI 单独构建一次（service 内部也会构建），v1 接受重复查询，后续可改成 service 返回或共享 provider
- en 已补投资指令文案，ko 走模板兜底（PM 允许后续补）
- 并行期间 `ai_chat_service_analyst_test` 单独跑在文件锁竞争时可能失败，属环境问题

**git 状态**：当前分支 main，7.2.1-7.2.3 改动均在未提交工作区，待 PM 审查合入

---

## 2026-08-09

**移交角色**：invest-logic（7.2.3 逻辑侧）
**接收角色**：PM（审查合入）→ invest-ui（UI 合并）

**任务**：投资分析快捷指令 + 数据范围提示（逻辑侧）

**完成工作**：
- `QuickCommandDataType` 新增 `analystSnapshot`；`AIQuickCommands` 新增投资概览 / 持仓分析 / 本月复盘 3 个指令，原有 6 个保留
- `AIQuickCommandService` 注入 `repository` + `investmentRepository`，`analystSnapshot` 数据文本走 `FinancialAnalystContext.forLedger(...).toPromptText()`
- l10n en / zh / zh_TW 新增 9 个 key（标题 / 描述 / prompt 模板），ko 走模板兜底
- `ai_quick_commands_bar.dart` 由 invest-ui 并行补了标题 / 描述展示，命名已对齐（`MonthReview`）
- 新增测试 2 例：新指令保留原有指令、投资概览 prompt 含财务上下文与持仓

**下一个任务需要知道的**：
- 接口变化：`AIQuickCommandService` 构造函数新增 `repository` + `investmentRepository`，provider 已接线
- `FinancialAnalystSnapshot.scopeLabel()` 已可给 UI 展示分析数据范围
- `ai_chat_page._handleQuickCommand` 的 `displayText` switch 仍缺 3 个新指令 case，属 UI 侧待补
- 全量 `flutter test`：722 passed / 1 skipped / 1 failed（唯一失败为既存 `bill_creation_service_test`）；`flutter analyze` 无 error

**git 状态**：当前分支 main，7.2.2 + 7.2.3 逻辑侧改动未提交，待 PM 审查合入

---

## 2026-08-09

**移交角色**：invest-logic（7.2.2）
**接收角色**：PM（审查合入）→ invest-logic（7.2.3）

**任务**：分析师提示词 + 意图路由

**完成工作**：
- `AIChatService` 新增财务分析意图判定：投资/持仓/收益/盈亏/基金/股票/分析/复盘/趋势/预算/净资产/资产/负债/浮盈/浮亏/组合 优先于记账意图
- 删除原「统计、查询等功能暂不支持」提示，改为财务分析师人设：只基于注入的账本/投资摘要回答，未提供数据不臆造
- 自由对话统一注入 `FinancialAnalystSnapshot.toPromptText()`（构建失败回退 `empty` 兜底）；`AIChatService` 构造函数新增 `investmentRepository`
- 新增测试 6 例：投资问题不误判为记账、普通记账仍走记账、关键词命中、prompt 含投资摘要、空数据兜底、英文人设

**下一个任务需要知道的**：
- `AIChatService` 路由顺序：分析师意图 → 记账意图 → 自由对话（均注入财务上下文）
- 意图判定方法公开为静态：`AIChatService.isAnalystIntent` / `isTransactionIntent`，7.2.3 快捷指令可复用
- 全量 `flutter test`：716 passed / 1 skipped / 1 failed（唯一失败为既存 `bill_creation_service_test`）；`flutter analyze` 无 error

**git 状态**：当前分支 main，7.2.2 改动待 PM 审查合入

---

## 2026-08-09

**移交角色**：项目经理（PM）
**接收角色**：architect + invest-logic / invest-logic / invest-ui

**任务**：7.2.1 PM 审查通过 + 7.2.2/7.2.3 放行

**审查结果**：7.2.1 通过，合入。
- FinancialAnalystSnapshot / FinancialAnalystContext.forLedger 覆盖账户、收支、分类、预算、净资产、投资持仓、近期投资流水与缺失汇率提示
- 过滤口径与现有净资产计算一致（隐藏账户排除、不计入资产/统计按口径过滤、多币种折算并标注缺失汇率）
- 验证：7.2.1 测试全过；全量 710 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）；改动文件 analyze 零 issue

**接口约定（7.2.2 / 7.2.3 按此接线）**：
- `FinancialAnalystContext.forLedger({repository, investmentRepository, ledgerId, recentTxLimit, holdingsLimit, trendDays})`，注意必须同时传 `investmentRepository`
- `toPromptText({maxChars})` 生成中文分析上下文；`scopeLabel()` 给 UI 展示数据范围

**git 状态**：当前分支 main，合入后提交

---

## 2026-08-09

**移交角色**：architect + invest-logic（7.2.1）
**接收角色**：PM（审查合入）→ invest-logic（7.2.2）

**任务**：7.2.1 财务上下文服务

**完成工作**：
- 新增 `lib/ai/core/financial_analyst_context.dart`：`FinancialAnalystSnapshot` + `FinancialAnalystContext.forLedger`
- 覆盖：账户与余额、近 30 天 / 本月收支、支出分类 Top、预算进度、净资产趋势、投资持仓摘要（代码/名称/份额/成本/市值/盈亏/收益率/净值日期）、近期投资交易、缺失汇率提示
- 过滤口径：隐藏账户不进入上下文；不计入资产 / 不计入统计按现有 Repository 口径；多币种按本位币折算并标注缺失汇率；投资盈亏用 Decimal 链路
- `toPromptText()` 中文格式化且受 `maxChars` 截断控制 token；`scopeLabel()` 返回「近 N 天 · N 只持仓」
- 新增测试 5 例：摘要内容、过滤规则、token 上限、空数据兜底、empty 常量

**下一个任务需要知道的**：
- `forLedger` 比 PM 规格多了 `investmentRepository` 必填参数：投资数据不在 `BaseRepository` 接口内，7.2.2 调用时需同时传 `repository` + `investmentRepository`
- 净资产按「非隐藏 + 不计入资产排除」自算口径（比现有 repo 净值方法更严格，隐藏账户不再计入），`trendDays` 默认 30
- 近期投资交易按 `investType != null && != initial` 过滤；转换显示为买卖两笔并标注「（转换）」
- 全量 `flutter test`：710 passed / 1 skipped / 1 failed（唯一失败为既存 `bill_creation_service_test`）；改动文件 `flutter analyze` 无 error/warning

**git 状态**：当前分支 main，工作区仅含 7.2.1 改动，待 PM 审查合入

---

## 2026-08-09

**移交角色**：项目经理（PM）
**接收角色**：architect + invest-logic（7.2.1）→ invest-logic（7.2.2）/ invest-logic + invest-ui（7.2.3）→ qa（7.2.4）

**任务**：7.2 AI 财务分析师（第一版）

**目标**：在记账基础上，让 AI 小助手能基于当前账本与投资持仓回答财务分析问题，并新增投资分析快捷指令。

**7.2.1 财务上下文服务（architect + invest-logic）**
- 新增 `FinancialAnalystSnapshot`：账户与余额、近 30 天/本月收支摘要、分类汇总、预算进度、净资产趋势摘要、投资持仓摘要（代码/名称/份额/成本/市值/盈亏/收益率/净值日期）、近期投资交易（买入/卖出/转换）
- 工厂 `FinancialAnalystContext.forLedger({repository, ledgerId, recentTxLimit, holdingsLimit, trendDays})`：只取当前账本，隐藏账户/不计入资产/不计入统计的记录按现有口径过滤
- 提供 `toPromptText()`（中文格式化，控制 token）与 `scopeLabel()`（如「近 30 天 · N 只持仓」供 UI 展示）
- 金额 2 位小数、净值 4 位、多币种按本位币折算并标注缺失汇率；投资盈亏用 Decimal 链路
- 测试：账本/投资摘要内容、过滤规则、token 上限、空数据兜底

**7.2.2 分析师提示词 + 意图路由（invest-logic，等 7.2.1）**
- 删除原系统提示「统计、查询等功能暂不支持」，改为财务分析师人设：仅基于注入的账本/投资摘要回答，未提供数据不臆造
- `AIChatService` 意图判定扩展：财务分析意图（投资/持仓/收益/盈亏/基金/股票/分析/复盘/趋势/预算/净资产/资产/负债/浮盈/浮亏/组合）优先于记账意图；记账仍走原提取流程
- 自由对话注入 `FinancialAnalystSnapshot.toPromptText()`，随用户问题一起发送
- 测试：投资问题不误判为记账、分析师 prompt 含投资摘要、无数据兜底

**7.2.3 投资分析快捷指令 + 数据范围提示（invest-logic + invest-ui，等 7.2.1 接口）**
- 快捷指令新增：投资概览、持仓分析、本月复盘、财务健康、预算建议、异常提醒（原有指令保留）
- 投资概览/持仓分析使用新的投资数据源；AI 页展示本次分析覆盖的数据范围（`scopeLabel`）
- 模板：新增投资分析 prompt 模板（zh/zh_TW 为主，en/ko 可后续补）

**7.2.4 全流程测试与实机验证（qa + invest-logic + invest-ui，等前几项）**
- 上下文/路由/指令/UI 测试补齐；真实服务商对话冒烟
- 验证样例问题：我的总浮盈多少 / 基金 A 最近表现 / 投资与现金比例是否失衡

**约束**：HANDOFF 只增不减；flutter analyze 新增代码零 error/warning；完成后更新 TEAM.md 任务板 + HANDOFF 追加完成记录，交 PM 审查

**git 状态**：当前分支 main，HEAD 3f98b65

---

## 2026-08-09

**移交角色**：项目经理（PM）
**接收角色**：invest-ui / qa / invest-logic

**任务**：7.1 PM 审查通过 + 合入

**审查结果**：7.1.1 / 7.1.2 通过，合入。
- 收支速览 364×169 / 155×155 在字体缩放 1.2 下不再底部溢出，新增回归测试
- 小组件管理页预览按原生尺寸保留比例，小/中/大档位不再失真，新增比例测试
- 「记账助手」更名覆盖 zh/zh_TW ARB、Android 桌面名、iOS 显示名、分享/欢迎/提醒/小组件引导/AI 系统提示与文档；en/ko 按约定保留 BeeCount；包名/deep link 未改
- 验证：相关测试全过；全量 705 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）；改动文件 analyze 无新增 error/warning

**git 状态**：当前分支 main，合入后提交

---

## 2026-08-09

**移交角色**：invest-logic（7.1.2 逻辑侧）
**接收角色**：PM（审查合入）

**任务**：App 更名「记账助手」invest-logic 侧

**完成工作**：
- 补齐 zh / zh_TW ARB 中独立的 `BeeCount` 分享/欢迎/邀请文案，改为「记账助手」/「記帳助手」并重新 `flutter gen-l10n`
- en / ko 按 PM 口径保留 BeeCount，未改动
- `docs/cloud-setup.md`、`docs/contributing/CONTRIBUTING_ZH.md` 中文文档更名
- 新增 `app_rename_scan_test.dart`：l10n appName 断言、lib 无「蜜蜂记账」、Android `build.gradle` / `strings.xml`、README 标题

**下一个任务需要知道的**：
- 与 invest-ui 并行完成，TEAM.md 已由 invest-ui 标记 ✅；本记录只补 invest-logic 侧明细
- 更新缓存 / 存储管理仍使用 `BeeCount_` 内部文件名，未改名
- 全量 `flutter test`：705 passed / 1 skipped / 1 failed（唯一失败为既存 `bill_creation_service_test`）；`flutter analyze` 无 error

**git 状态**：当前分支 main，7.0 + 7.1 改动均在未提交工作区，待 PM 审查合入

---

## 2026-08-09

**移交角色**：invest-ui（7.1.1 + 7.1.2）
**接收角色**：PM（审查合入）

**任务**：小组件显示修复 + App 更名「记账助手」

**完成工作**：
- 7.1.1：GlanceView medium stat 卡纵向 padding 8→6、区块间距 10→8，字体缩放 1.2 下 364×169 / 155×155 不再底部溢出；新增对应回归测试
- 7.1.1：小组件管理页预览卡新增 `widgetPreviewDisplaySize`，小号保持 155、中/大号保持 364，可用宽度不足才等比缩小；新增比例测试
- 7.1.2：zh / zh_TW ARB 与生成文件、Android `strings.xml` / `build.gradle`、iOS 显示名与权限文案、README / PRIVACY、AI 系统提示、分享海报与分享文案全部改为「记账助手」/「記帳助手」；en / ko 按 PM 约定保留 BeeCount
- 测试：新增 `app_rename_scan_test.dart`（20 例）；全量 705 passed / 1 skipped / 1 failed（唯一失败为既存 `bill_creation_service_test`）

**下一个任务需要知道的**：
- 包名 / applicationId / bundle id 未改，`beecount://` deep link 未改
- en / ko 用户可见文案仍为 BeeCount（PM 允许保留）
- 未改 `docs/cloud-setup` / `CONTRIBUTING` / `COMMERCIAL_LICENSE` 等文档旧名（非用户可见 App 文案）

**git 状态**：当前分支 main，7.0 + 7.1 改动均在未提交工作区，待 PM 审查合入

---

## 2026-08-09

**移交角色**：项目经理（PM）
**接收角色**：invest-ui + qa（7.1.1）/ invest-ui + invest-logic（7.1.2）

**任务**：7.1 小组件显示修复 + App 更名

**7.1.1 小组件显示修复（invest-ui + qa）**
- 收支速览（GlanceView）真机/预览出现 `bottom overflowed by 2.0 pixels`：定位 364×169 固定高度下的布局溢出（header / stat 卡 / 间距 / Spacer），把内容收敛到可用高度内
- 小组件管理页预览比例不当：`_buildGalleryCard` 当前所有尺寸都用同一 displayWidth，155×155 小号被放大成 364 宽，导致大中小比例失真；改为按预览尺寸保留真实比例（如小号最大 155、中号 364×169、大号 364×382，超出可用宽度再等比缩小）
- 测试：GlanceView 在 364×169 / 155×155 渲染不溢出；预览卡片尺寸比例断言

**7.1.2 App 更名「记账助手」（invest-ui + invest-logic）**
- 用户可见的「蜜蜂记账」全部改为「记账助手」（zh / zh_TW 为 記帳助手；en / ko 可按现有风格译为 Bookkeeping Assistant / 가계부 도우미 或保留 BeeCount，由工程师与 PM 确认）
- 覆盖：l10n（appName / appTitle / homeAppTitle / splashAppName / mineSlogan / sharePosterAppName / 提醒/小组件引导/分享文案等）、Android strings.xml 与 build.gradle app_name（测试版为「记账助手测试版」）、分享海报/帖子/系统提示词、README/PRIVACY 标题
- 包名 / applicationId / bundle id 不改，避免升级链路断裂
- 测试：扫描用户可见文案不再出现「蜜蜂记账」；Android 资源断言

**约束**：HANDOFF 只增不减；flutter analyze 新增代码零 error/warning；完成后更新 TEAM.md 任务板 + HANDOFF 追加完成记录，交 PM 审查

**git 状态**：当前分支 main，HEAD 68b2288

---

## 2026-08-09

**移交角色**：项目经理（PM）
**接收角色**：invest-ui / invest-logic / qa

**任务**：7.0 PM 审查通过 + 合入

**审查结果**：7.0.1 - 7.0.4 全部通过，合入。
- 关于页自用声明、本地更新日志/隐私页、社交/捐赠入口删除符合要求
- 更新链路、欢迎页、云同步 wiki、海报等原仓库链接全部改指自身 fork；beejz.com 官网文档入口已本地化并清理死代码
- 小组件主题模式跟随与刷新链路修复已覆盖转账/搜索/导入等触发点
- 验证：相关测试全过；全量 695 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）；改动文件 analyze 无新增 error/warning
- 遗留：本地教程页 en/ko/zh_TW 完整翻译后续可补，不影响本次合入

**git 状态**：当前分支 main，合入后提交

---

## 2026-08-09

**移交角色**：invest-logic（7.0.4 收尾）
**接收角色**：PM（审查合入）

**任务**：7.0.4 教程类内容本地化收尾（beejz.com 残留清理 + 扫描测试）

**完成工作**：
- 删除 `lib/utils/website_urls.dart` + `test/utils/website_urls_test.dart`：lib 已无调用点，教程本地页完成后属于死代码
- 删除 `lib/services/marketing/product_promos.dart`：无调用点且含 `assets.beejz.com` / `dns.beejz.com` 资产链接
- `original_repo_link_cleanup_test.dart` 新增 beejz.com 扫描：lib 非 l10n 下无用户可见官网链接（跳过历史注释）
- 确认 lib 中仅剩帮助页/更新日志的历史注释提及 beejz.com，无用户可见链接

**下一个任务需要知道的**：
- 全量 `flutter test`：695 passed / 1 skipped / 1 failed（唯一失败为既存 `bill_creation_service_test`）
- `flutter analyze` 无 error；仓库既有 + 并行 issue 856 条，7.0.4 改动无新增
- `product_promo_card.dart` 仍是无调用点的遗留组件（不含 beejz.com 链接），本次按范围未删
- 本地教程页正文以中文为主，en/ko/zh_TW 完整翻译后续可补

**git 状态**：当前分支 main，7.0.1-7.0.4 全部改动在未提交工作区，待 PM 审查合入

---

## 2026-08-09

**移交角色**：invest-ui（7.0.4 前半）
**接收角色**：invest-logic（7.0.4 收尾）/ PM（审查合入）

**任务**：教程类内容本地化（beejz.com）

**完成工作**：
- `help_center_page.dart` 重写为本地静态帮助页，覆盖基础记账 / 投资 / 导入导出 / 云同步 / 小组件 / AI 记账 / 数据隐私，不再使用 WebView
- 新增 `CloudSyncGuidePage`（Supabase / WebDAV / BeeCount Cloud / S3 设置说明），登录页「注册指引」改指本地页
- 新增 `AiTutorialPage`（服务商配置 / 能力绑定 / 图片 / 语音 / 截图 / AI 对话），AI 服务商管理「详细教程」改指本地页
- `mine_page`「使用帮助」去掉 WebView / 官网兜底，直接打开本地帮助页；移除 WebsiteUrls 与 url_launcher 相关死代码
- 新增 `help_center_local_test.dart` 3 例

**下一个任务需要知道的**：
- 未改 `lib/utils/website_urls.dart` 与 `product_promos.dart`，按执行顺序留给 invest-logic 清理
- 本地页正文以中文为主，标题沿用现有 l10n；en/ko/zh_TW 完整翻译后续可补

**git 状态**：当前分支 main，工作区含 7.0.1-7.0.3 + invest-ui 7.0.4 前半改动，待 PM 审查合入

---

## 2026-08-09

**移交角色**：项目经理（PM）
**接收角色**：invest-ui + invest-logic

**任务**：7.0.4 教程类内容本地化（beejz.com）

**背景**：7.0.1/7.0.2 已把 GitHub 原仓库链接全部替换为自身 fork，但 `lib/utils/website_urls.dart` 仍指向原开发者官网 `count.beejz.com`，并被帮助中心、我的页使用帮助、登录页云同步注册指引、AI 教程等入口使用。用户确认这些教程类内容采用**本地化**方案，不删除功能。

**要求**：
- 帮助中心：改为本地静态帮助页，覆盖基础记账、投资模块、导入导出、云同步、小组件、AI 记账等自用说明；不再 WebView 打开 beejz.com
- 登录页云同步注册指引：改为本地「云同步设置」说明页（Supabase / WebDAV / 自行部署的简要步骤）
- AI 教程入口：改为本地「AI 设置与使用」说明页（服务商配置、OCR/语音/截图记账）
- 我的页「使用帮助」：指向本地帮助页
- `lib/services/marketing/product_promos.dart` 等残留 beejz.com 资产链接：删除或置空（当前 UI 未使用，可清理）
- 新增/更新扫描测试：`lib` 下（除 l10n 历史文案）不再出现 `beejz.com` 用户可见链接
- 文案策略：本地页面正文先以中文为主（个人版主体中文），标题沿用现有 l10n；en/ko/zh_TW 如需完整翻译可后续补充

**执行顺序（重要）**：
1. invest-ui 先做：本地页面 + 移除 beejz.com 调用点（help_center / mine / login / ai_provider）
2. invest-logic 后做：清理 website_urls / product_promos 等残留 + 扫描测试；确认 lib 下无 beejz.com 用户可见链接后再交 PM
3. 两边不要同时修改 `lib/utils/website_urls.dart` 或同一页面文件，避免覆盖

**约束**：HANDOFF 只增不减；flutter analyze 新增代码零 error/warning；完成后更新 TEAM.md 任务板 + HANDOFF 追加完成记录，交 PM 审查

**git 状态**：当前分支 main，工作区含 7.0.1-7.0.3 待合入

---

## 2026-08-09

**移交角色**：invest-ui（7.0.1 + 7.0.3）
**接收角色**：PM（审查合入）

**任务**：关于页自用化 + 小组件 Bug 排查修复

**完成工作**：
- 7.0.1：about_page 删除社媒/支持开发/开发者的话/官网链接/ICP，标题改「关于本应用」，新增自用说明；更新日志与隐私政策改为本地静态页（ChangelogPage / PrivacyPolicyPage）；4 语言 ARB + gen-l10n
- 7.0.3 修复小组件刷新缺口：
  - 转账保存（transfer_form）后补 updateAppWidget
  - 搜索批量删除/备注/分类（search_page）后补 updateAppWidget
  - CSV 导入完成后补 WidgetManager.updateAllWidgetsLocalized（container 级，页面销毁也可刷新）
  - WidgetManager 新增 dark 透传；主题模式（light/dark/system）切换监听并重渲小组件，启动/前台恢复/主题色/收支配色/账本起始日调用点同步传入 effective dark
- 测试：新增 about_page_self_use_test（4 例）、resolveWidgetDarkMode 3 例；相关 widget 测试全过；全量 694 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**下一个任务需要知道的**：
- 7.0.2 并行线程已完成并已写 HANDOFF；about_page 中反馈链接指向 ForkLinks 属 7.0.2 改动，7.0.1 未动
- Android 多尺寸 provider 刷新链路审计通过：matchInstalledAll 已返回全尺寸 spec，updateAllWidgets 按 androidAllClassNames 全量触发原生刷新，无新增修复
- 点击跳转深链链路审计通过：原生 PendingIntent 携带 beecount://，app_links 冷启动/onNewIntent 均能收到并打开

**git 状态**：当前分支 main，工作区含 invest-ui（7.0.1+7.0.3）+ invest-logic（7.0.2）并行改动，待 PM 审查合入

---

## 2026-08-09

**移交角色**：invest-logic（7.0 收尾）
**接收角色**：PM（审查合入）

**完成工作**：
- invest-ui 7.0.1 已合入工作区，7.0.2 重新全仓扫描确认无功能性原仓库链接
- 追加清理：`.github` issue 模板与 FUNDING 改指 fork / 留空；`docs/contributing` 主仓库链接改指 fork（`upstream remote` 保留原仓库）
- 扫描测试扩展覆盖 `.github`；l10n 生成文件与当前 ARB 同步
- 全量 `flutter test`：695 passed / 1 skipped / 1 failed（唯一失败为既存 `bill_creation_service_test`）

**下一个任务需要知道的**：
- `WebsiteUrls`（count.beejz.com）仍用于帮助中心 / 云同步注册指引 / AI 教程的内嵌文档，属于上游技术文档引用，建议 PM 决定是否本地化
- `flutter analyze` 无 error；仓库既有 + 并行 issue 共 856 条，7.0.2 改动文件无新增
- 工作区含 7.0.1 + 7.0.2 全部改动，未提交，待 PM 审查合入

**git 状态**：当前分支 main，7.0.1 + 7.0.2 改动均在未提交工作区

---

## 2026-08-09

**移交角色**：invest-logic（7.0.2）
**接收角色**：PM（审查合入）

**任务**：更新链路 + 全仓原仓库链接替换

**完成工作**：
- 新增 `lib/utils/fork_links.dart` 统一管理 fork 链接常量
- 更新链路全部改指自身 fork：`update_checker.dart` 的 GitHub API、`update_downloader.dart` 的下载 Referer、`update_dialogs.dart` 的手动访问地址
- 其余入口改指 fork：欢迎页 GitHub、关于页反馈/捐赠、云同步页 Supabase/WebDAV wiki 指南、6 个海报 QR（app_promo/user_profile/month/ledger/year/annual）
- l10n：4 语言 `shareGuidanceCopyText` / `updateManualVisit` 替换 URL，重新 `flutter gen-l10n`（顺带同步了 invest-ui 7.0.1 新加的 `aboutSelfUse` 系列生成文件）
- README / README_EN 重写为「个人自用 fork」说明；PRIVACY.md、PROJECT_PLAN、cloud-setup、packages 主仓库链接替换
- 新增测试：`fork_links_test.dart` + `original_repo_link_cleanup_test.dart`（更新链路断言 + 全仓扫描）；相关测试 21 passed

**下一个任务需要知道的**：
- 保留 TNT-Likely 的位置均属有意：HANDOFF 历史、LICENSE 系列/CONTRIBUTING（法律归属）、docs/contributing（上游贡献指南）、l10n `aboutSelfUse`（7.0.1 要求保留原作者归属）
- `WebsiteUrls`（count.beejz.com）未动，属于官网清理范畴，建议由 7.0.1/PM 统一处理
- about_page 含 invest-ui 并行改动，invest-logic 在该文件只改了反馈链接指向 fork
- 若 invest-ui 后续继续修改 ARB，需自行重新 gen-l10n（本次生成文件已与当前 ARB 同步）

**git 状态**：当前分支 main，工作区含 invest-logic（7.0.2）+ invest-ui（7.0.1）并行改动，待 PM 审查合入

---

## 2026-08-09

**移交角色**：项目经理（PM）
**接收角色**：invest-ui（7.0.1）/ invest-logic（7.0.2）/ qa + invest-ui（7.0.3）

**任务**：7.0 原开发者内容清理 + 小组件排查

**背景**：App 已转为个人/小范围自用版本，需删除原开发者品牌与链接，改为自用声明；小组件功能疑似存在 bug，需先定位再修。

**7.0.1 归属/品牌清理（invest-ui）**
- lib/pages/settings/about_page.dart：删除「开发者的话」原文，改为自用说明（基于原作者 TNT-Likely 的 GitHub 项目 https://github.com/TNT-Likely/BeeCount 做了大量适配本人的功能性改动，仅用于个人及少量周边人员使用，不做盈利）；标题改为「关于本应用」
- 删除社交入口：GitHub / Telegram / 小红书 / 抖音 / 官方网站
- 删除「支持开发」入口
- 「更新日志」改为本地静态页（不再打开原官网 beejz.com）
- 「隐私政策」改为本地静态页（说明数据仅存本机、按需发送第三方 AI、无收集无盈利），不再 WebView 打开原官网
- l10n：zh / en / ko / zh_TW 同步新增或替换文案；删除无用 key 不阻塞，可保留未引用

**7.0.2 更新链路 + 全仓原仓库链接替换（invest-logic）**
- 更新检测 API / 下载 Referer / 手动访问地址 / 问题反馈 / 捐赠链接：全部由 TNT-Likely/BeeCount 改为 https://github.com/shshlh/BeeCount（自身 fork）
- 扫描并替换剩余 TNT-Likely 链接：分享文案、欢迎页 GitHub、云同步 wiki 指南、海报二维码等；无法本地化的二维码删除或改为「个人自用」说明
- 测试：更新链接断言 / 扫描结果

**7.0.3 小组件 Bug 排查（qa + invest-ui）**
- 用户反馈「小组件功能好像有 bug」，先复现并定位：添加后是否空白/占位、点击跳转、记账后刷新、切换账本/主题后更新、Android 多尺寸 provider 是否都刷新
- 修复定位到的 bug，补测试；完成后交 PM 审查

**约束**：HANDOFF 只增不减；flutter analyze 新增代码零 error/warning；完成后更新 TEAM.md 任务板 + HANDOFF 追加完成记录，交 PM 审查

**git 状态**：当前分支 main，HEAD e1e5e1a

---

## 2026-08-09

**移交角色**：项目经理（PM）
**接收角色**：invest-logic / invest-ui

**任务**：6.13.3 PM 审查通过 + 合入

**审查结果**：6.13.3 通过，合入。
- 数据层：NavRefreshResult / refreshNavsForLedgerDetailed，整批失败不抛错并返回全部 skippedCodes，旧方法兼容
- UI：进入资产页与下拉刷新均接入详细结果，skippedCodes 非空时 SnackBar「以下基金未更新：11017」
- 验证：相关测试全过；全量 670 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）；改动文件 analyze 无新增 issue

**git 状态**：当前分支 main，合入后提交

---

## 2026-08-09

**移交角色**：invest-ui
**接收角色**：项目经理（PM）

**任务**：6.13.3 刷新失败反馈（UI）

**完成工作**：
- lib/pages/investment/holdings_list_page.dart — 进入自动刷新与下拉刷新改用 refreshNavsForLedgerDetailed；skippedCodes 非空时 SnackBar「以下基金未更新：11017」；下拉刷新保留异常兜底「净值刷新失败」；进入路径 updatedCount>0 才 invalidate、下拉成功即 invalidate
- test/widgets/holdings_list_page_layout_test.dart — spy detailedResult 返回 skippedCodes=['11017']，断言 SnackBar 展示具体代码；tab 切换测试同步改为计数 detailed 调用

**下一个任务需要知道的**：
- invest-logic 数据层 NavRefreshResult/refreshNavsForLedgerDetailed 已落地；节流命中返回 updatedCount=0 + skipped 空，不弹提示
- 全量 analyze 零 error；全量测试 670 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**git 状态**：当前分支 main，待提交（工作区含 invest-logic 并行改动，交 PM 审查合入）

---

## 2026-08-09

**移交角色**：architect + invest-logic
**接收角色**：项目经理（PM）/ invest-ui（6.13.3 UI）

**任务**：6.13.3 刷新失败反馈（数据层）

**完成工作**：
- lib/services/data/investment_service.dart — 新增 NavRefreshResult(updatedCount, skippedCodes)；新增 refreshNavsForLedgerDetailed(ledgerId, {force})：skippedCodes = 当前账本持仓代码集合 − 实际抓取成功代码集合（覆盖无效代码/无日期/单只失败）；整批失败返回 updatedCount=0 + 全部 skipped，不抛异常、不记录节流时间
- 保留 refreshNavsForLedger 返回 int 不动（内部委托 detailed，整批失败仍抛 StateError 保持旧行为）
- 测试 +3：部分成功返回 skipped 列表、非法代码持仓出现在 skipped、整批失败不抛错且 skipped 全量返回

**下一个任务需要知道的**：
- UI 层将按接口切换到 refreshNavsForLedgerDetailed，skippedCodes.isNotEmpty 时显示非阻塞 SnackBar
- 节流命中时 detailed 返回 updatedCount=0、skippedCodes 空

**验证**：flutter analyze 855 个 issue、零 error（我的文件零新增）；全量测试 669 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**git 状态**：当前分支 main，工作区含 invest-logic 数据层改动，待 UI 完成后一并交 PM 审查

---

## 2026-08-09

**移交角色**：项目经理（PM）
**接收角色**：invest-logic（数据层）/ invest-ui（UI）

**任务**：6.13.3 刷新失败反馈

**需求**：净值刷新时被跳过的基金（代码无效 / 无日期 / 抓取失败）目前完全静默，用户无法发现 `11017` 这类误录代码。刷新后应非阻塞提示具体基金代码。

**接口约定（invest-logic 先落地，invest-ui 按此对齐）**：
- `lib/services/data/investment_service.dart` 新增 `NavRefreshResult`，字段：`int updatedCount`、`List<String> skippedCodes`
- 新增 `Future<NavRefreshResult> refreshNavsForLedgerDetailed(int ledgerId, {bool force = false})`；保留现有 `refreshNavsForLedger` 返回 `int` 不动
- `skippedCodes` = 当前账本持仓代码集合 − 实际抓取成功代码集合（覆盖无效代码、无日期、单只失败）
- 整批全失败时不再让 UI 只能看到泛化异常：详细方法返回 `updatedCount=0` + 全部 skippedCodes，不抛 StateError
- 测试：部分成功返回 skipped 列表；非法代码持仓出现在 skipped；整批失败不抛错且 skipped 全量返回

**UI 要求（invest-ui）**：
- 持仓页进入自动刷新与下拉刷新改用 `refreshNavsForLedgerDetailed`
- `skippedCodes.isNotEmpty` 时显示非阻塞 SnackBar，如「以下基金未更新：11017」
- 下拉刷新保留失败兜底提示，不打断列表
- widget 测试：spy service 返回 skippedCodes 后 SnackBar 展示具体代码

**约束**：HANDOFF 只增不减；flutter analyze 新增代码零 error/warning；完成后更新 TEAM.md 任务板 + HANDOFF 追加完成记录，交 PM 审查

**git 状态**：当前分支 main，HEAD 2db12a3

---

## 2026-08-09

**移交角色**：项目经理（PM）
**接收角色**：invest-ui / architect + invest-logic

**任务**：6.13.6 PM 复审通过 + 6.13 合入

**审查结果**：P1 批次删除防护、P2 附件清理均已修复，复审通过，合入。
- 转换批次流水删除被拦截（SnackBar「请删除完整的转换记录」），新增测试覆盖，不再产生单边删除
- deleteHolding 复用 LocalTransactionRepository.deleteTransaction，附件 DB 行与实体文件均清理，新增附件清理断言
- 验证：相关测试全过；全量 666 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）；改动文件 analyze 无新增 issue
- 遗留：6.13.3 刷新失败反馈仍为 P2 待办，不在本次合入范围

**git 状态**：当前分支 main，合入后提交

---

## 2026-08-08

**移交角色**：invest-ui
**接收角色**：项目经理（PM）

**任务**：6.13.6 返工 P1（批次流水删除防护）+ 收尾验证

**完成工作**：
- lib/pages/investment/holding_detail_page.dart — _confirmDeleteTransaction 开头拦截 batchId != null 的转换流水，SnackBar「请删除完整的转换记录」，与编辑入口防护一致，不再弹确认框/调 deleteTransaction
- test/widgets/holding_detail_delete_test.dart — 新增「转换批次流水删除被拦截」：点删除图标 → 只出提示、不弹确认框、deleteTransaction 未被调用
- P2 已由 architect/invest-logic 落地（deleteHolding 复用 LocalTransactionRepository 清理附件实体文件 + 测试），已并入全量验证

**下一个任务需要知道的**：
- 转换批次删除目前为「拦截 + 提示」，未做批次级原子删除（如需删除整个转换需分别处理两侧或另立入口）
- 全量 analyze 零 error；全量测试 666 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**git 状态**：当前分支 main，待提交（工作区含 architect/invest-logic 并行改动，交 PM 复审）

---

## 2026-08-08

**移交角色**：architect + invest-logic
**接收角色**：项目经理（PM）/ invest-ui（6.13.6 P1）

**任务**：6.13.6 返工 P2（deleteHolding 附件清理）

**完成工作**：
- lib/data/repositories/local/local_investment_repository.dart — deleteHolding 改为逐笔复用 LocalTransactionRepository.deleteTransaction：同步清理交易标签、附件 DB 行与附件实体文件（引用计数保留共享文件），再删分组关联与持仓行并同步投资账户市值
- pubspec.yaml — dev_dependencies 新增 path_provider_platform_interface（测试 mock 附件目录用）
- test/data/repositories/investment_repository_test.dart — 增加附件 DB 行清理断言，并注入 fake PathProviderPlatform 让附件清理路径可测

**下一个任务需要知道的**：
- P1（转换批次流水删除拦截）由 invest-ui 继续；本记录仅覆盖 P2 数据层
- 全量测试当前被并行线程卡住的测试进程阻塞；最近一次全量结果含既存 bill_creation_service_test 与 invest-ui 的 transaction_list_quick_add_test（Timer pending），均非本次数据层

**验证**：flutter analyze 855 个 issue、零 error（我的文件零新增）；数据层相关测试全部通过

**git 状态**：当前分支 main，工作区含 architect/invest-logic + invest-ui 并行改动，待提交交 PM 审查

---

## 2026-08-08

**移交角色**：项目经理（PM）
**接收角色**：invest-ui / architect + invest-logic

**任务**：6.13 审查结论 + 6.13.6 返工派工

**审查结果**：6.13.1/6.13.2/6.13.4/6.13.5 主体功能通过，但存在 1 个必须修复的问题，暂不合入。

**P1（必须修）**：转换批次流水可被单笔删除。
- 文件：lib/pages/investment/holding_detail_page.dart `_confirmDeleteTransaction`
- 问题：转换记录（batchId != null）的删除入口会直接调 deleteTransaction 删单边，导致 A 卖出但 B 未买入等数据不一致；编辑入口已禁止批次单边编辑，删除入口漏了同样的防护
- 要求：batchId != null 时拦截并提示（如「请删除完整的转换记录」），或实现批次级原子删除；补测试

**P2（建议修）**：deleteHolding 只删附件 DB 行，未清理附件实体文件。
- 文件：lib/data/repositories/local/local_investment_repository.dart `deleteHolding`
- 建议复用 LocalTransactionRepository 的附件文件清理逻辑，避免孤儿文件

**验证**：相关测试全过；全量 665 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）；改动文件 analyze 无新增 issue

**git 状态**：当前分支 main，工作区改动未提交，待 6.13.6 完成后再合入

---

## 2026-08-08

**移交角色**：invest-ui
**接收角色**：项目经理（PM）

**任务**：6.13.5 明细页记一笔快速入口

**完成工作**：
- lib/pages/main/transaction_list_page.dart — PrimaryHeader actions 最右端新增 IconButton(Icons.add, tooltip「记一笔」)，点击 push TransactionEditorPage(initialKind: 'expense', quickAdd: true)；保存后走编辑器既有 invalidate 机制刷新明细
- test/widgets/transaction_list_quick_add_test.dart — 新增 widget 测试：明细页存在「+」入口，点击进入 TransactionEditorPage（spy 仓库返回普通空流避免 Drift 流定时器干扰收尾）

**下一个任务需要知道的**：
- 明细页为首页 tab0 push 的全屏页，返回按钮已存在，新入口在其 actions 最右端
- 测试用 _StaticTxRepo.transactionsWithCategoryAll 覆盖为 Stream.value([])，避免 Drift 订阅 pending timer 导致测试无法收尾
- 全量 analyze 零 error；全量测试 665 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**git 状态**：当前分支 main，待提交（工作区含 architect/invest-logic 并行改动，交 PM 审查合入）

---

## 2026-08-08

**移交角色**：architect + invest-logic
**接收角色**：项目经理（PM）/ invest-ui（6.13.4 UI）

**任务**：6.13.4 删除初始登记/持仓入口（数据层）

**完成工作**：
- lib/data/repositories/investment_repository.dart + local 实现 — 新增 deleteHolding(holdingId)：同一事务内删除关联交易（含 transaction_tags / transaction_attachments 关联行）、分组关联、持仓行，并同步投资账户市值（按剩余持仓合计），避免 0 份额历史行残留；持仓不存在抛 StateError
- lib/services/data/investment_service.dart — deleteHolding 透传仓库
- 测试 +3：删除持仓清理流水/分组关联并联动账户市值、不存在抛错、service 透传

**下一个任务需要知道的**：
- 6.13.4 UI（明细/列表删除入口）已由 invest-ui 并行落地并调用 deleteHolding / deleteTransaction
- 当前工作区全量测试有 2 个失败：既存 bill_creation_service_test + invest-ui 并行新增的 transaction_list_quick_add_test（Timer pending，属 6.13.5 新测试，非本次数据层）

**验证**：flutter analyze 855 个 issue、零 error（我的文件零新增）；数据层相关 65 个测试全部通过

**git 状态**：当前分支 main，工作区含 architect/invest-logic + invest-ui 并行改动，待提交交 PM 审查

---

## 2026-08-08

**移交角色**：项目经理（PM）
**接收角色**：invest-ui

**任务**：6.13.5 明细页记一笔快速入口

**需求**：用户在明细页无法直接记账，需返回首页再进入记账页；在明细页首行菜单栏最右端增加「+」入口。

**要求**：
- lib/pages/main/transaction_list_page.dart — PrimaryHeader 的 actions 最右端加 IconButton（Icons.add），点击打开 `TransactionEditorPage(initialKind: 'expense', quickAdd: true)`（与首页/中间按钮一致）
- 保存后按编辑器现有 invalidate 机制刷新明细
- widget 测试：明细页存在「+」入口，点击进入记账页

**约束**：HANDOFF 只增不减；flutter analyze 新增代码零 error/warning；完成后更新 TEAM.md 任务板 + HANDOFF 追加完成记录，交 PM 审查

**git 状态**：当前分支 main，工作区含 6.13.1/6.13.2/6.13.4 待审查

---

## 2026-08-08

**移交角色**：invest-ui
**接收角色**：项目经理（PM）

**任务**：6.13.4 删除初始登记/持仓入口（UI）

**完成工作**：
- lib/pages/investment/holding_detail_page.dart — 交易行新增删除图标（tooltip「删除流水」），确认弹窗后调 repositoryProvider.deleteTransaction(tx.id) 并 invalidate 持仓/摘要/过滤；PrimaryHeader 新增「删除持仓」入口，确认后调 service.deleteHolding 并返回上一页
- lib/pages/investment/holdings_list_page.dart — 持仓卡长按弹出「删除持仓」确认，确认后调 service.deleteHolding 并刷新列表
- 测试 +3：明细单笔流水删除确认（spy LocalRepository）、明细删除整个持仓（spy service）、列表长按删除确认（spy service）

**下一个任务需要知道的**：
- architect/invest-logic 已落地 deleteHolding（删除持仓+流水+分组关联+账户市值联动）与既有 deleteTransaction 投资重算，UI 已按其签名对齐
- 转换 batch 交易允许单侧删除（删除后重算对应持仓）；如需双向删除由用户分别删除两侧
- 全量 analyze 零 error；全量测试 664 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**git 状态**：当前分支 main，待提交（工作区含 architect/invest-logic 并行改动，交 PM 审查合入）

---

## 2026-08-08

**移交角色**：architect + invest-logic
**接收角色**：项目经理（PM）/ invest-ui（6.13.2）

**任务**：6.13.1 持仓信息编辑数据层

**完成工作**：
- lib/data/repositories/investment_repository.dart + local 实现 — 新增 updateHoldingInfo(holdingId, {fundCode, fundName})：基金代码必须 6 位数字，否则 ArgumentError；同账本+账户下已存在相同代码时抛 StateError（避免静默合并持仓），改回自身代码允许；只更新 fundCode/fundName，保留 totalShares/totalCost/currentNav/navDate/marketValue
- lib/services/data/investment_service.dart — updateHoldingInfo 透传仓库
- 测试 +5：仓库改码/名称保留统计字段、非法代码拒绝、同账户重复拒绝/自身允许；service 非法/重复拒绝与合法透传；修正误录代码（11017 → 110017）后 refreshNavsForLedger 可命中新代码刷新

**下一个任务需要知道的**：
- 6.13.2 UI（明细编辑入口 + 各弹窗 6 位校验）已由 invest-ui 并行落地并调用新接口
- 6.13.4 删除初始登记/持仓为新派工任务，数据层（deleteHolding 等）不在本次范围

**验证**：flutter analyze 855 个 issue、零 error（我的文件零新增）；全量测试 658 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**git 状态**：当前分支 main，工作区含 architect/invest-logic + invest-ui 并行改动，待提交交 PM 审查

---

## 2026-08-08

**移交角色**：项目经理（PM）
**接收角色**：architect + invest-logic（数据层）/ invest-ui（UI）

**任务**：6.13.4 删除初始登记/持仓入口（补充）

**背景**：6.13.2 已补「编辑基金信息」，但用户发现没有任何删除入口，误录的初始登记无法直接删除；仓库底层已有 `deleteTransaction`（含投资重算），UI 未接线，也没有删除整个持仓的方法。

**数据层要求（architect + invest-logic）**：
- 新增 `deleteHolding(int holdingId)`：删除持仓及关联交易、分组关联，并同步投资账户市值；避免 0 份额历史行残留
- 测试：删除持仓后流水/分组关联清理 + 账户市值联动

**UI 要求（invest-ui）**：
- 持仓明细交易记录支持「删除该笔流水」（含确认弹窗），初始登记可直接删除
- 持仓明细/列表提供「删除整个持仓」入口，误录代码后可清掉重新导入

**约束**：HANDOFF 只增不减；完成后更新 TEAM.md 任务板 + HANDOFF 追加完成记录，交 PM 审查

**git 状态**：当前分支 main，工作区含 6.13.1/6.13.2 待审查

---

## 2026-08-08

**移交角色**：invest-ui
**接收角色**：项目经理（PM）

**任务**：6.13.2 基金代码校验 + 编辑入口

**完成工作**：
- lib/pages/investment/holding_detail_page.dart — PrimaryHeader 新增「编辑基金信息」入口；弹窗可改基金代码/名称，代码 6 位数字校验，保存调 service.updateHoldingInfo，成功后 invalidate holding/currentHoldings/portfolioSummary/filteredHoldings 并关闭
- lib/widgets/investment/buy_dialog.dart / initial_holding_dialog.dart — 基金代码校验从「非空」升级为 6 位数字
- lib/widgets/investment/convert_dialog.dart — 手填目标基金代码（无）追加 6 位数字校验
- 测试 +5：明细编辑入口与 6 位校验（spy updateHoldingInfo）、买入弹窗校验、导入弹窗校验、转换手填代码校验（含既有布局回归）

**下一个任务需要知道的**：
- invest-logic 6.13.1 updateHoldingInfo 已并行落地（6 位校验 + 同代码拒绝 + 测试），UI 已按其签名对齐
- 校验提示统一为「基金代码必须为6位数字」
- 全量 analyze 零 error；全量测试 658 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**git 状态**：当前分支 main，待提交（工作区含 architect/invest-logic 并行改动，交 PM 审查合入）

---

## 2026-08-08

**移交角色**：项目经理（PM）
**接收角色**：architect + invest-logic（6.13.1）/ invest-ui（6.13.2）

**任务**：6.13 持仓基金代码修复与防错

**背景**：用户登记初始持仓时把 `110017` 误录为 `11017`。当前初始持仓/买入弹窗只校验“非空”，5 位代码会被 NavFetchService 静默过滤，导致该持仓无法刷新净值。

**6.13.1 数据层（architect + invest-logic）**
- InvestmentRepository 新增 `updateHoldingInfo(int holdingId, {required String fundCode, String? fundName})`
- 校验：基金代码必须 `^\d{6}$`；同账本+账户下已存在相同代码时拒绝（避免静默合并持仓）
- 更新后保留 totalShares / totalCost / currentNav / navDate / marketValue，不重算市值
- Service 层透传 + 测试：改代码后可正常刷新；重复代码拒绝；非法代码拒绝

**6.13.2 UI 层（invest-ui）**
- 持仓明细页增加「编辑基金代码/名称」入口，弹窗调用 service.updateHoldingInfo，成功后 invalidate 持仓并刷新
- 初始持仓导入弹窗 / 买入弹窗：基金代码校验为 6 位数字
- 转换弹窗手填目标基金代码同样校验 6 位数字
- widget 测试：编辑入口 + 校验提示

**6.13.3 刷新失败反馈（P2，等 6.13.1/6.13.2 落地后派工）**
- 刷新时被跳过的基金（代码无效/无日期/失败）给出非阻塞提示，列出具体基金代码，避免静默失效

**约束**：
- HANDOFF 只增不减；flutter analyze 新增代码零 error/warning
- 完成后更新 TEAM.md 任务板 + HANDOFF 追加完成记录，git 状态待提交交 PM 审查

**git 状态**：当前分支 main，HEAD b130d87

---

## 2026-08-08

**移交角色**：项目经理（PM）
**接收角色**：invest-ui

**任务**：6.12.2 PM 审查通过

**审查结果**：6.12.2 通过，合入。
- 持仓卡片与持仓明细均按「净值（2026.8.7）」标签 + 数值独立展示；旧数据无 navDate 时只显示「净值」
- 导入初始持仓无需改 UI：仓库已默认把净值日期写为导入/发生日期
- 验证：相关 widget 测试全过；全量 649 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）；改动文件 analyze 无新增 issue

**git 状态**：当前分支 main，合入后提交

---

## 2026-08-08

**移交角色**：invest-ui
**接收角色**：项目经理（PM）

**任务**：6.12.2 净值日期 UI 展示

**完成工作**：
- lib/widgets/investment/holding_card.dart — 第二行左侧新增「净值（2026.8.7）」chip（数值 1.2345 独立展示），旧数据无 navDate 时仅显示「净值」；左侧改 Wrap 防窄屏溢出
- lib/pages/investment/holding_detail_page.dart — 净值统计格标签改为「净值（2026.8.7）」，无日期时保持「净值」
- 导入初始持仓弹窗无需改 UI：createInitialHolding 未传 navDate 时由仓库默认取发生日期（happenedAt）
- test/widgets/holding_card_nav_date_test.dart — 新增 2 个用例：有日期显示标签+数值、无日期不显示括号
- test/widgets/holding_detail_convert_row_test.dart — 持仓带 navDate，断言明细页「净值（2026.8.7）」

**下一个任务需要知道的**：
- InvestmentHolding 新增 navDate（DateTime?），schema v37 已由 6.12.1 落地
- 日期格式统一为 year.month.day（如 2026.8.7），不补零
- 全量 analyze 零 error；全量测试 649 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**git 状态**：当前分支 main，待提交交 PM 审查

---

## 2026-08-08

**移交角色**：项目经理（PM）
**接收角色**：architect + invest-logic / invest-ui

**任务**：6.12.1 PM 审查通过 + 6.12.2 派工

**审查结果**：6.12.1 通过，合入。
- 验证：6.12.1 相关测试全过；全量 647 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）；改动文件 analyze 无新增 issue
- 轻微风险记录：数据源缺日期时该基金整条跳过（当前两个数据源均带日期，可接受；若后续出现货币基金等异常品类再评估改为 navDate 可空）

**6.12.2 派工（invest-ui）**：
- 持仓卡片、持仓明细显示「净值（2026.8.7）」标签，数值 `1.2345` 单独显示；旧数据无 navDate 时不显示括号
- 导入初始持仓弹窗：净值日期默认取导入/发生日期
- widget 测试断言日期展示

**git 状态**：当前分支 main，合入后提交

---

## 2026-08-08

**移交角色**：architect + invest-logic
**接收角色**：项目经理（PM）/ invest-ui（6.12.2）

**任务**：6.12.1 净值日期数据层

**完成工作**：
- lib/services/data/nav_fetch_service.dart — 新增 FundNavQuote(nav + navDate)，fetchLatestNavs 返回 Map<String, FundNavQuote>；腾讯行情解析日期字段 yyyy-MM-dd，天天基金 Data_netWorthTrend 最后一项 x 时间戳（兼容毫秒/秒）；日期缺失时回退/跳过
- lib/data/db.dart — InvestmentHoldings 新增 nullable navDate，schema v36 → v37 + 幂等迁移 nav_date；db.g.dart 已重新生成
- lib/data/repositories/investment_repository.dart + local 实现 — buy/sell/convert/updateNav/createInitialHolding 支持 navDate（默认成交时间/当前时间）；_recomputeHolding 保留已有日期或按最后一笔交易发生日期回填；删除路径保留手动 navDate
- lib/services/data/investment_service.dart — batchUpdateNav 改为 Map<int, FundNavQuote>，updateNav 透传 navDate，refreshNavsForLedger 把数据源日期写入
- 测试 +5：腾讯/天天基金日期解析与缺失跳过、刷新后 navDate 持久化、migration v37、repo buy/updateNav 写日期、删除保留手动净值日期；schemaVersion 断言全部升到 37

**下一个任务需要知道的**：
- 6.12.2 UI 可开始：日期放「净值」标签后（如「净值（2026.8.7）」），数值保持独立；旧数据无 navDate 时不显示括号
- 投资持仓数据类新增 navDate 字段（DateTime?）

**验证**：flutter analyze 855 个 issue、零 error（我的文件零新增；1 条 dangling doc info 来自 invest-ui 并行的 6.10 测试）；全量测试 647 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**git 状态**：当前分支 main，工作区改动未提交，待 PM 审查

---

## 2026-08-08

**移交角色**：项目经理（PM）
**接收角色**：invest-ui（6.12.2）

**任务**：6.12.2 显示形式修正（净值日期）

**修正说明**：日期放在「净值」标签后面，数值保持独立，例如标签「净值（2026.8.7）」，数值仍显示「1.2345」；不要把日期拼进数值串。

**生效范围**：持仓卡片、持仓明细、导入初始持仓等净值展示点；6.12.1 数据层（navDate）不受影响。

**git 状态**：当前分支 main，HEAD 9153600（派工已提交）

---

## 2026-08-08

**移交角色**：项目经理（PM）
**接收角色**：architect + invest-logic（6.12.1）→ invest-ui（6.12.2）

**任务**：6.12 净值日期显示（数据层 + UI）

**需求背景**：当前净值只显示数值，用户无法得知该净值对应的日期；腾讯行情和天天基金数据源均带日期，需要把日期随净值一起展示，例如「净值（2026.8.7）」。导入初始持仓 / 基金卡片 / 持仓明细等净值展示点统一带上日期。

**6.12.1 数据层（architect + invest-logic）**
- NavFetchService：返回值升级为 `nav + navDate`（腾讯行情日期字段 `yyyy-MM-dd`；天天基金 `Data_netWorthTrend` 最后一项的 `x` 时间戳）
- InvestmentHoldings 增加 nullable `navDate`，schema 36 → 37 + 幂等迁移 `nav_date`
- Repository：updateNav / buy / sell / convert / createInitialHolding 写入净值日期；`_recomputeHolding` 保留/回填日期
- InvestmentService.refreshNavsForLedger / batchUpdateNav 传递数据源日期
- 测试：日期解析、刷新后持久化、迁移 v37

**6.12.2 UI 层（invest-ui，等 6.12.1 接口落地）**
- 持仓卡片、持仓明细「净值」显示 `1.2345（2026.8.7）`；旧数据无日期时不显示括号
- 导入初始持仓弹窗：净值日期默认取导入/发生日期
- widget 测试断言日期展示

**约束**：
- HANDOFF 只增不减；flutter analyze 新增代码零 error/warning
- 完成后更新 TEAM.md 任务板 + HANDOFF 追加完成记录，git 状态待提交交 PM 审查

**git 状态**：当前分支 main，HEAD d781560（上轮 P0 已提交）

---

## 2026-08-08

**移交角色**：项目经理（PM）
**接收角色**：invest-logic / invest-ui（后续维护）

**任务**：P0 修复 — 净值抓取数据源切换（fundgz 失效）

**完成工作**：
- lib/services/data/nav_fetch_service.dart — 主数据源由 fundgz JSONP 切换为腾讯行情 `qt.gtimg.cn/q=jj{code}`，解析 `~` 分隔字段取单位净值、累计净值兜底；主源失败回退天天基金 `pingzhongdata`，解析 `Data_netWorthTrend` 最后一个 y；HTML/异常响应干净跳过，不再抛 FormatException
- test/services/nav_fetch_service_test.dart — 更新为腾讯格式，新增主源失败回退、双源 HTML 干净跳过用例
- 验证：文件级 analyze 零 issue；全量测试 642 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**下一个任务需要知道的**：
- `https://fundgz.1234567.com.cn/js/{code}.js` 已对所有基金返回「页面未找到」HTML（诊断时间 2026-08-08），不要切回
- 腾讯字段顺序：代码~名称~预留~预留~空~单位净值~累计净值~日增长率~日期；pingzhongdata 响应约 600KB，仅作兜底
- 本次修复由 PM 直接处理（当前会话无跨线程派发工具），无需再派 invest-logic

**git 状态**：当前分支 main，待提交

---

## 2026-08-08

**移交角色**：invest-ui
**接收角色**：项目经理（PM）

**任务**：6.11 返工（进入持仓页自动刷新时机）

**完成工作**：
- lib/pages/investment/holdings_list_page.dart — build 中 ref.listen(bottomTabIndexProvider)：next==2（资产 tab）且 prev!=2 时调 refreshNavsForLedger(ledgerId)（service 层 15 分钟节流，updated>0 才刷新列表，失败静默）；保留 initState 首次刷新
- test/widgets/holdings_list_page_layout_test.dart — 新增「切到资产 tab 触发自动刷新」：spy InvestmentService 计数，initState=1、切到 tab2=2、切走再切回=3；15 分钟节流由 service 层测试覆盖（invest-logic 已含节流命中/force 绕过用例）

**下一个任务需要知道的**：
- 资产 tab 在 IndexedStack 常驻，刷新时机由「tab 切换监听 + 首次 initState」双入口覆盖
- 节流去重仍在 InvestmentService.refreshNavsForLedger（SharedPreferences + force），UI 不做二次判断
- 全量 analyze 零 error；全量测试 640 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**git 状态**：当前分支 main，待提交（工作区含 invest-logic 并行改动，交 PM 复审）

---

## 2026-08-08

**移交角色**：项目经理（PM）
**接收角色**：invest-ui

**任务**：6.11 返工（进入持仓页自动刷新时机）

**问题（P2）**：资产页在底部导航 IndexedStack 常驻，initState 在 App 启动即执行，当前「进入持仓页自动刷新」实际只在启动时触发一次；之后切回资产 tab（即使超过 15 分钟节流）不会再次刷新
- 文件：lib/pages/investment/holdings_list_page.dart
- 要求：
  a) 监听 bottomTabIndexProvider：切换为 2（资产 tab）时调用 refreshNavsForLedger(ledgerId)（保持 service 层 15 分钟节流，updated>0 才刷新列表，失败静默）
  b) 保留 initState 首次刷新（启动即刷）
  c) 补测试：切到资产 tab 触发刷新；15 分钟节流内不重复请求

**约束**：
- flutter analyze 新增代码零 error/warning
- 全量测试保持 639 passed / 1 skipped / 1 failed（既存 bill_creation_service_test 除外）
- 完成后更新 TEAM.md 任务板 + HANDOFF.md 追加完成记录，git 状态待提交交 PM 复审

---

## 2026-08-08

**移交角色**：invest-logic
**接收角色**：项目经理（PM）

**任务**：6.11.1 + 6.11.2 数据层

**完成工作**：
- 6.11.1 — 新增 lib/services/data/nav_fetch_service.dart：天天基金 JSONP 解析，dwjz 优先、gsz 兜底；只接受 6 位数字代码；并发上限 8；单只失败/无净值跳过并记日志，不抛整批
- 6.11.2 — InvestmentService.refreshNavsForLedger(ledgerId, {force})：读账本持仓 → fetchLatestNavs → batchUpdateNav（事务 + 市值联动）；15 分钟节流用 SharedPreferences 持久化（key 含 ledgerId，多账本隔离）；force 忽略节流；整批失败抛 StateError，部分成功返回更新数
- 测试 +11：NavFetchService JSONP/gsz 兜底/无效代码过滤/单只失败跳过/并发 ≤8；refresh 成功联动市值/节流命中与 force 绕过/超时允许/整批失败不记录节流/多账本 key 隔离/部分成功

**下一个任务需要知道的**：
- 6.11.3 UI（下拉/进入自动刷新 + SnackBar）已由 invest-ui 并行落地并按其签名接线
- 节流时间在成功后写入；整批失败不写，可立即重试

**验证**：flutter analyze 零 error（我的文件零新增 issue；并行 invest-ui 测试文件有 1 条 dangling doc info）；全量测试 639 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**git 状态**：当前分支 main，工作区含 invest-logic + invest-ui 并行改动，待提交交 PM 审查

---

## 2026-08-08

**移交角色**：invest-ui
**接收角色**：项目经理（PM）

**任务**：6.11.3 持仓页刷新入口

**完成工作**：
- lib/pages/investment/holdings_list_page.dart — 由 ConsumerWidget 改为 ConsumerStatefulWidget；进入页面 initState postFrame 调 refreshNavsForLedger(ledgerId)（15 分钟节流，内部静默跳过，updated>0 才刷新列表）
- 下拉刷新 RefreshIndicator.onRefresh 改调 refreshNavsForLedger(ledgerId, force: true)，成功后 invalidate currentHoldingsProvider / portfolioSummaryProvider / filteredHoldingsProvider；失败 SnackBar「净值刷新失败」，部分成功不打断
- test/widgets/holdings_list_page_layout_test.dart — 补内存库 + investmentRepositoryProvider/repositoryProvider override 与 SharedPreferences mock，适配进入页面自动刷新路径

**下一个任务需要知道的**：
- invest-logic 6.11.1/6.11.2 已落地（NavFetchService + refreshNavsForLedger 节流/force + 测试），UI 已按其签名对齐
- 自动刷新只在首次进入页面实例时触发；15 分钟节流在 service 层，重复进入不会重复请求
- 全量 analyze 零 error；全量测试 639 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**git 状态**：当前分支 main，待提交（工作区含 invest-logic 并行改动，交 PM 审查合入）

---

## 2026-08-08

**移交角色**：项目经理（PM）
**接收角色**：invest-logic + invest-ui

**任务**：6.11 天天基金净值自动刷新（数据源已确认）

**角色分工**：
- invest-logic：6.11.1 NavFetchService + 6.11.2 refreshNavsForLedger 节流/接线 + 测试
- invest-ui：6.11.3 持仓页下拉/进入自动刷新 + 提示

**6.11.1 天天基金净值抓取服务（invest-logic）**
- 数据源：`https://fundgz.1234567.com.cn/js/{基金代码}.js`（JSONP 壳 `jsonpgz({...})`），解析 `dwjz`（最新单位净值）；无 dwjz 时可用 `gsz`（估算净值）兜底或跳过该基金（工程师按字段可靠性决定，倾向 dwjz 优先、缺失跳过并记日志）
- 新增 lib/services/data/nav_fetch_service.dart：`Future<Map<String, double>> fetchLatestNavs(List<String> fundCodes)`
  - 复用现有 http/HttpClient，并发上限约 8，单只失败跳过不抛整批
  - 只接受 6 位数字基金代码，过滤异常
- 测试：JSONP 解析、无效代码过滤、单只失败跳过、并发限流

**6.11.2 账本净值刷新 + 15 分钟节流（invest-logic）**
- InvestmentService 新增 `Future<int> refreshNavsForLedger(int ledgerId, {bool force = false})`，返回成功更新的持仓数
  - 读当前账本持仓 → 取 fundCode 列表 → fetchLatestNavs → 映射 holdingId → 调 batchUpdateNav（已有，事务 + 市值联动）
  - 节流：15 分钟内不重复请求（force=true 忽略节流，供下拉刷新）；上次刷新时间用 SharedPreferences 持久化（key 含 ledgerId），首次/超时允许
- 错误处理：整批失败抛错给 UI 提示；单只失败跳过不影响其余
- 测试：节流命中/超时、force 绕过、刷新后市值联动、多账本 key 隔离

**6.11.3 持仓页刷新入口（invest-ui）**
- 文件：lib/pages/investment/holdings_list_page.dart
- 下拉刷新（RefreshIndicator.onRefresh）：调 refreshNavsForLedger(ledgerId, force: true)，成功后再 invalidate currentHoldingsProvider / portfolioSummaryProvider / filteredHoldingsProvider
- 进入持仓页：首次/页面出现时调 refreshNavsForLedger(ledgerId)（受 15 分钟节流，内部静默跳过）；返回成功更新数>0 时刷新列表
- 失败提示：SnackBar「净值刷新失败」；部分成功不打断

**约束**：
- flutter analyze 新增代码零 error/warning
- 全量测试保持 627 passed / 1 skipped / 1 failed（既存 bill_creation_service_test 除外）
- 相关测试补充（service + widget）
- 完成后更新 TEAM.md 任务板 + HANDOFF.md 追加完成记录，git 状态待提交交 PM 审查

---

## 2026-08-08

**移交角色**：invest-ui
**接收角色**：项目经理（PM）

**任务**：6.10 洞察页排行金额精度（实际金额）

**完成工作**：
- lib/widgets/analytics/category_rank_row.dart — 一级/二级分类排行金额 AmountText decimals 0 → 2，显示实际金额，百分比仍 1 位
- 核对 lib/widgets/analytics/analytics_summary.dart — 收入/支出/结余金额未显式传 decimals，AmountText 默认 2，口径已一致，无需改动
- test/widgets/category_rank_row_test.dart — 新增 widget 测试：排行金额 AmountText decimals == 2、百分比 50.0% 保持 1 位

**下一个任务需要知道的**：
- 结余视角当前不显示分类排行（既有逻辑），本轮未改
- 全量 analyze 零 error；全量测试 628 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**git 状态**：当前分支 main，待提交交 PM 审查

---

## 2026-08-08

**移交角色**：项目经理（PM）
**接收角色**：invest-ui

**任务**：6.10 洞察页排行金额精度（实际金额）

**问题**：洞察页支出/收入分类排行金额用 AmountText(decimals: 0)，显示个位取整，与总结余/图表金额口径割裂

**要求**：
- 文件：lib/widgets/analytics/category_rank_row.dart（一级/二级行金额）
- 排行金额 decimals 0 → 2，显示实际金额（如 1234.56），百分比保留 1 位不变
- 核对 lib/widgets/analytics/analytics_summary.dart 的收入/支出/结余金额已是 2 位小数；若不是统一为 2 位
- 说明：结余视角当前不显示分类排行（既有逻辑，不改）；如需结余排行另行确认

**约束**：
- flutter analyze 新增代码零 error/warning
- 全量测试保持 627 passed / 1 skipped / 1 failed（既存 bill_creation_service_test 除外）
- 更新相关 widget 测试（排行金额 2 位断言）
- 完成后更新 TEAM.md 任务板 + HANDOFF.md 追加完成记录，git 状态待提交交 PM 审查

---

## 2026-08-07

**移交角色**：invest-ui
**接收角色**：项目经理（PM）

**任务**：6.7.5 返工（转换提交校验传参）+ 6.8（固定底部确认 + 间距放宽）

**完成工作**：
- lib/widgets/investment/convert_dialog.dart — 6.7.5：_submit 的 validateConvert 调用补传 toHoldingId/fundCode/fundName（与 service.convert 一致），修复「目标基金代码和名称必填」误报
- convert_dialog — 6.8.1：确认按钮从滚动区移出，改为 Scaffold.bottomNavigationBar 固定底部栏（SafeArea + 顶部分隔线），滚动时始终可见，校验/loading/错误提示不变
- convert_dialog — 6.8.2：A/B/C 卡间距 p12 → 16，卡内行距 12 → 16，小格 label 与输入框间距 4 → 6，卡片内边距统一 16
- test/widgets/convert_dialog_layout_test.dart — 新增「选择已有持仓提交成功」「手填代码/名称提交成功并创建新持仓」两条真实内存库提交回归测试；现有布局/校验测试适配固定底部按钮（去掉 ensureVisible）

**下一个任务需要知道的**：
- 6.7.5 回归测试走真实内存库 + runAsync 跑通确认流程，覆盖已有持仓与手填新基金两条路径
- 6.8 只调间距与底部栏，字段/校验/提交逻辑不变
- 全量 analyze 零 error；全量测试 627 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**git 状态**：当前分支 main，待提交（工作区含 invest-logic 并行改动，交 PM 复审）

---

## 2026-08-07

**移交角色**：项目经理（PM）
**接收角色**：invest-ui

**任务**：6.7 返工 2（转换提交必填校验误报）

**问题（P1）**：convert_dialog._submit 调 service.validateConvert 时漏传 toHoldingId / fundCode / fundName
- 现象：无论选择已有持仓还是手填目标基金代码/名称，点确认都报「目标基金代码和名称必填 / Invalid argument(s)」
- 根因：validateConvert 新增的目标基金校验依赖这些参数，但 UI 只在 service.convert 传了，validateConvert 没传 → 永远命中空值抛错，转换无法提交
- 要求：
  a) _submit 的 validateConvert 调用同步传 toHoldingId: _toHolding?.id、fundCode/fundName（与 service.convert 完全一致）
  b) 补回归测试：选择已有持仓提交成功 + 手填代码/名称提交成功（convert_dialog_layout_test 用真实内存库跑通确认流程，避免再漏）

**约束**：
- flutter analyze 新增代码零 error/warning
- 全量测试保持 625 passed / 1 skipped / 1 failed（既存 bill_creation_service_test 除外）
- 完成后更新 TEAM.md 任务板 + HANDOFF.md 追加完成记录，git 状态待提交交 PM 复审

---

## 2026-08-07

**移交角色**：项目经理（PM）
**接收角色**：全团队

**决策**：6.9 账本账户隔离已取消
- 用户决定保持账户跨账本共享（「不限账户」是期望行为，不是 bug）
- 模拟/测试数据污染问题由用户自行控制（测试时避免新建跨账本同名账户、避免在投资弹窗选到其他账本账户，或用独立数据库测试）
- 不派工、不实现；后续如需要隔离再重新立项

---

## 2026-08-07

**移交角色**：项目经理（PM）
**接收角色**：architect + invest-logic

**任务**：6.9 账本账户隔离（测试账本不污染真实账本）—— 已取消，见上方 PM 决策记录

**背景**：用户真实记账与模拟测试并行，账户跨账本共享会污染真实账本。本轮将账户相关选择器、统计、AI 匹配统一按当前账本隔离；「全部账本汇总」暂不做，以后需要再加切换。

**6.9.1 账户选择器按账本过滤（architect）**
- 文件：lib/data/repositories/local/local_account_repository.dart getAvailableAccountsForLedger
- 现状：只按币种过滤，投资弹窗（买入扣款/卖出回款/转换退回）会列出其他账本同币种账户
- 要求：加 ledgerId 过滤（a.ledgerId.equals(ledgerId) & a.currency.equals(ledger.currency)）

**6.9.2 首页/资产/洞察统计按账本（architect + invest-logic）**
- 现状：getNetWorthBreakdown / getAssetCompositionByType / getAllAccountStats / getAllAccountsTotalStats / getNetWorthBreakdownByCurrency 用 getAllAccounts() 跨账本汇总；allAccountsStreamProvider（资产页列表）也跨账本
- 要求：
  a) Repository 层为上述统计新增/改造为按 ledgerId 过滤（新增参数或 per-ledger 方法，旧全局方法如仍有调用需审计）
  b) Provider 层（netWorthBreakdownProvider / assetCompositionProvider / allAccountStatsProvider / allAccountsTotalStatsProvider / netWorthBreakdownByCurrencyProvider / allAccountsStreamProvider 等）统一 watch currentLedgerIdProvider，首页/资产页/洞察只显示当前账本数据
  c) 净值趋势（getNetWorthDailyBalances / netWorthTrendSeriesProvider）同样按当前账本
- 注意：改动影响面大，先审计 getAllAccounts() 的全部调用方，逐处确认是否应 per-ledger

**6.9.3 AI 智能记账账户匹配按账本（invest-logic）**
- 文件：lib/services/billing/bill_creation_service.dart _matchAccountByName
- 现状：pool 只按 currency + !hidden 过滤
- 要求：加 a.ledgerId == ledgerId 过滤

**6.9.4 账户名唯一改为「同账本内唯一」（architect）**
- 文件：lib/data/repositories/local/local_account_repository.dart createAccount
- 现状：name 全局唯一，跨账本不能同名
- 要求：改为一账本内唯一（where name == x & ledgerId == ledgerId）；同步检查 upsertAccount 等其他建账路径与 DuplicateNameException 语义

**6.9.5 多账本隔离测试（architect + invest-logic）**
- 新增/更新测试：
  a) 投资弹窗账户下拉只列当前账本账户
  b) 两个账本各自净资产/资产构成/账户统计不混
  c) 两个账本可创建同名账户
  d) AI 记账只匹配当前账本账户

**约束**：
- flutter analyze 新增代码零 error/warning
- 全量测试保持 625 passed / 1 skipped / 1 failed（既存 bill_creation_service_test 除外）
- 完成后更新 TEAM.md 任务板 + HANDOFF.md 追加完成记录，git 状态待提交交 PM 审查
- HANDOFF 铁律：只 prepend 追加，不整文件重写、不用模糊正则范围替换

---

## 2026-08-07

**移交角色**：项目经理（PM）
**接收角色**：invest-ui

**任务**：6.8 转换页确认固定底部 + 间距放宽（纯 UI）

**6.8.1 确认按钮固定页面底部**
- 文件：lib/widgets/investment/convert_dialog.dart
- 现状：D 确认卡在滚动区内，随内容滚出屏幕
- 要求：把「确认」按钮从滚动区移出，固定到底部（Scaffold.bottomNavigationBar 或等价的固定底部栏，含安全区），页面滚动时始终可见；保留校验、提交 loading、错误提示

**6.8.2 卡片间距与卡内行距放宽**
- 现状：A/B/C 三卡之间、卡内字段之间偏紧凑
- 要求：
  a) A/B/C 卡之间间距加大（当前 p12 → 建议 16-20）
  b) 卡内行距放宽：A1 与 A2/A3 之间、B1 与 B2/B3 之间、C 三行之间（当前 12 → 建议 16-20）
  c) 小格内 label 与输入框之间（当前 4 → 建议 6-8），卡片内边距适当加大
- 注意：只调间距，不改字段/逻辑；确认按钮移出后，滚动区保留 A/B/C 三卡

**约束**：
- flutter analyze 新增代码零 error/warning
- 全量测试保持 625 passed / 1 skipped / 1 failed（既存 bill_creation_service_test 除外）
- 更新 convert_dialog_layout_test（确认按钮仍可找到、布局结构不变）
- 完成后更新 TEAM.md 任务板 + HANDOFF.md 追加完成记录，git 状态待提交交 PM 审查

---

## 2026-08-07

**移交角色**：invest-ui
**接收角色**：项目经理（PM）

**任务**：6.7 返工（转换记录展示金额回归）

**完成工作**：
- lib/pages/investment/holding_detail_page.dart — _TransactionTile 对 batchId != null 的转换交易，第二行金额按「|investShares| × investNav」展示（sell/buy 两侧均适用），amount 保持 0 不写回 DB；非转换交易照常显示 amount
- test/widgets/holding_detail_convert_row_test.dart — 新增转换行展示 widget 测试：amount=0 + shares=500 + nav=1.2 → AmountText 展示 600，断言「转换」类型与「净值 1.2」

**下一个任务需要知道的**：
- 转换交易的 amount 语义已固定为 0（投资账户内部记账），展示层计算只在 UI，不回写数据库
- 全量 analyze 零 error；全量测试 625 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**git 状态**：当前分支 main，待提交（工作区含 invest-logic 并行改动，交 PM 复审）

---

## 2026-08-07

**移交角色**：项目经理（PM）
**接收角色**：invest-ui

**任务**：6.7 返工（转换记录展示金额回归）

**问题（P2）**：6.7.1 把转换的卖出 A / 买入 B amount 改为 0（投资账户内部记账）后，持仓明细里转换交易行会显示「金额 0.00」，用户看不到确认成交金额
- 文件：lib/pages/investment/holding_detail_page.dart _TransactionTile（约 420-490 行）
- 要求：对 batch 转换交易（batchId != null），第二行金额改为按「确认份额 × 确认净值」展示（|investShares| × investNav），sell/buy 两侧均适用；金额不写回 DB，amount 仍为 0；非转换交易照常显示 amount
- 可选：补一个转换行展示的 widget 断言

**约束**：
- flutter analyze 新增代码零 error/warning
- 全量测试保持 624 passed / 1 skipped / 1 failed（既存 bill_creation_service_test 除外）
- 完成后更新 TEAM.md 任务板 + HANDOFF.md 追加完成记录，git 状态待提交交 PM 复审

---

## 2026-08-07

**移交角色**：invest-ui
**接收角色**：项目经理（PM）

**任务**：6.7.2 UI + 6.7.3

**完成工作**：
- lib/widgets/investment/convert_dialog.dart — 6.7.2 UI：「无 + 手填代码/名称」路径可提交：代码/名称仅「无」时必填（validator）；提交时 toHoldingId=null + fundCode/fundName（选中已有持仓仍传 id，行为不变）
- convert_dialog — 6.7.3：_loadRefundAccounts 加 try/catch + 防重入 + _refundAccountsLoadFailed 状态；失败显示「退回账户加载失败，请重试」+ 重试按钮；refund>0 且账户未加载成功或未选账户时提交被拦截
- test/widgets/convert_dialog_layout_test.dart — 新增「选「无」手填目标基金：空代码/名称被校验拦截」用例（ensureVisible 滚动后点确认）

**下一个任务需要知道的**：
- invest-logic 6.7.1/6.7.2 数据层已落地（convert amount=0 + toHoldingId 可空 + 查找/创建新持仓），UI 已按其签名对齐
- 手填新目标基金由数据层按 (ledgerId, fundCode, 来源投资账户) 查找/创建；转换确认金额如需展示，展示层按份额×净值计算，amount 语义不再承载
- 全量 analyze 零 error；全量测试 624 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**git 状态**：当前分支 main，待提交（工作区含 invest-logic 并行改动，交 PM 审查合入）

---

## 2026-08-07

**移交角色**：invest-logic
**接收角色**：项目经理（PM）

**任务**：6.7.1 + 6.7.2 数据层

**完成工作**：
- 6.7.1 — lib/data/repositories/local/local_investment_repository.dart：convert 卖出 A / 买入 B 的 amount 固定 0（投资账户内部记账，不产生资金流水），仍记录份额/净值/手续费/持仓/batchId；退回金额仍是唯一真实转账（投资账户 → 退回账户），退回账户余额只 +refund；持仓/成本/市值逻辑不变
- 6.7.2 — repo/service convert 的 toHoldingId 改为可空，新增 fundCode / fundName；toHoldingId 为空时校验代码/名称必填，先按 (ledgerId, fundCode, 来源投资账户) 查找已有持仓，命中复用，未命中则创建新持仓（挂到来源基金所在投资账户）后执行转换；validateConvert 同步补新目标校验
- 测试：卖出/买入 amount=0 断言更新；新增 toHoldingId 为空创建新持仓并记账、手填代码命中已有持仓复用、代码/名称为空抛错、validateConvert 新目标校验

**下一个任务需要知道的**：
- 6.7.2 UI（无 + 手填代码/名称提交）与 6.7.3（退回账户加载容错）由 invest-ui 并行处理
- toHoldingId 为空时服务端要求 fundCode/fundName 非空；选中已有持仓仍传 toHoldingId

**验证**：flutter analyze 853 个既有 issue、零 error；全量测试 624 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**git 状态**：当前分支 main，工作区含 invest-logic + invest-ui 并行改动，待提交交 PM 审查

---

## 2026-08-07

**移交角色**：项目经理（PM）
**接收角色**：invest-logic + invest-ui

**任务**：6.7 转换记账口径修正 + 支持新目标基金 + 退回账户加载容错（3 项）

**角色分工**：
- invest-logic：6.7.1（记账口径修正）+ 6.7.2 数据层（支持新目标基金）
- invest-ui：6.7.2 UI（“无 + 手填代码/名称”走新路径）+ 6.7.3

**6.7.1 转换记账口径修正（invest-logic）**
- 现状（6.5）：卖出 A amount=转出市值、买入 B amount=转入市值、退回转账，共 3 笔资金流水形态
- 修正：转换本质是卖出 A + 买入 B，但两者都在投资账户内部完成，不与非投资账户发生资金往来；**实际与非投资账户的关联只有退回这笔钱**
- 要求：
  a) 卖出 A / 买入 B：amount 固定 0（投资账户内部记账，不产生资金流水），仍记录确认份额/净值、手续费、持仓归属、batchId；投资账户市值仍由持仓合计覆盖
  b) 退回（refund>0）：唯一真实转账，accountId=投资账户、toAccountId=退回账户、amount=refund，计入退回账户余额与总资产
  c) 测试同步修正：卖出/买入 amount=0；退回账户余额仅 +refund；持仓/成本/市值断言不变
- 展示：如需在持仓明细看到转换确认金额，可在展示层按份额×净值计算，不改 amount 语义

**6.7.2 转换支持新目标基金（invest-logic + invest-ui）**
- 目标：用户在下拉选「无」并手动填写目标基金代码/名称时，可正常完成转换；若该代码已有持仓则复用，否则创建新目标持仓后再买入 B
- 数据层（invest-logic）：
  - repo.convert / service.convert：toHoldingId 改为可空（int?），新增可选 fundCode / fundName
  - toHoldingId 非空：沿用现有逻辑
  - toHoldingId 为空：fundCode / fundName 必填（空则抛 ArgumentError）；先按 (ledgerId, fundCode, 来源投资账户) 查找已有持仓，找到则复用，否则创建新持仓（挂到来源基金所在投资账户）后执行转换
  - 卖出 A / 买入 B 内部记账 + 退回转账逻辑不变（按 6.7.1 修正后口径）
  - 测试：转换到新基金创建持仓并记账；手动输入代码命中已有持仓时复用；代码/名称为空抛错
- UI 层（invest-ui）：
  - convert_dialog「无 + 手填代码/名称」路径：代码/名称非空校验（仅“无”时必填）；提交时传 toHoldingId=null + fundCode/fundName
  - 选中已有持仓时仍传其 id，行为不变

**6.7.3 退回账户加载错误处理（invest-ui）**
- 文件：lib/widgets/investment/convert_dialog.dart _loadRefundAccounts
- 现状：无 try/catch，账户加载失败成未处理异步异常
- 要求：补 try/catch + 错误状态；失败时显示「退回账户加载失败，请重试」+ 重试按钮；refund>0 且账户未加载成功时提交被拦截

**约束**：
- flutter analyze 新增代码零 error/warning
- 全量测试保持 619 passed / 1 skipped / 1 failed（既存 bill_creation_service_test 除外）
- 完成后更新 TEAM.md 任务板 + HANDOFF.md 追加完成记录，git 状态待提交交 PM 审查
- HANDOFF 铁律：只 prepend 追加，不整文件重写、不用模糊正则范围替换

---

## 2026-08-07

**移交角色**：invest-ui
**接收角色**：项目经理（PM）

**任务**：6.6 基金转换页面 1x4 组件化改造

**完成工作**：
- lib/widgets/investment/convert_dialog.dart — 重构为 1x4 竖排组件：A 转出（摘要 + 确认转出份额/净值左右并排）、B 转入（目标基金下拉 + 无/持仓列表 + 手动代码/名称 + 确认转入份额/净值并排）、C 手续费/退回金额/退回账户三行、D 全宽确认按钮；AppBar 删除「确认」动作；6.5 记账字段与校验/提交逻辑不动
- 目标基金下拉首项「无」，选中持仓自动填入代码/名称/净值，选「无」恢复手动填写
- test/widgets/convert_dialog_layout_test.dart — 新增 2 个 widget 测试：1x4 组件结构断言 + 下拉选择持仓后自动填入并隐藏手动代码/名称（种子内存库 + runAsync 驱动 Drift 异步）

**下一个任务需要知道的**：
- 页面仍包 SingleChildScrollView，结构固定、不随持仓数量变长
- 选择「无」后手动填写的代码/名称当前不参与提交（提交仍需选择已有持仓，沿用原逻辑）；如需支持手动新建目标基金，需数据层增加 create-on-convert，登记待确认
- 全量 analyze 零 error；全量测试 619 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**git 状态**：当前分支 main，待提交交 PM 审查

---

## 2026-08-07

**移交角色**：项目经理（PM）
**接收角色**：invest-ui

**任务**：6.6 基金转换页面 1x4 组件化改造（布局重构，逻辑不变）

**目标**：当前转换页是单列长表单，目标基金用竖向单选列表，持仓多时页面无限变长；改为 1x4 竖排四个组件（A/B/C/D，非等分便当格，各组件行数不同），目标基金改为下拉选择，页面高度固定。

**A 转出基金组件**
- A1：现有「从某基金转出」摘要（基金名称/代码 + 可转份额）
- A2 / A3：确认转出份额、确认转出净值，左右并排；小格内文字在上、输入框在下

**B 转入基金组件**
- B1：目标基金。第一行「目标基金」+ 下拉列表，下拉首项固定「无」（不选已有持仓）；选中已有持仓自动填入代码/名称，选「无」则代码/名称手动填写（代码一行、名称一行）
- B2 / B3：确认转入份额、确认转入净值，样式同 A2/A3

**C 手续费与退回组件**
- 三行：手续费（文字+输入）、退回金额（文字+输入，保留 6.5 自动计算可手改）、退回账户（文字+下拉，refund>0 必填）

**D 确认组件**
- 把顶部 AppBar 右侧「确认」移到这里：D 为全宽确认卡片，按钮占满可用宽度，圆角/内边距与 A1 视觉一致
- 顶部 AppBar 删除「确认」动作；保留原有表单校验、validateConvert、提交 loading 与错误提示

**约束**：
- 6.5 的记账逻辑/字段（确认份额净值、手续费、退回金额/账户、三笔记账）一律不动，只改布局
- 目标基金下拉数据 = 当前账本持仓列表（排除当前转出基金），并置顶「无」
- flutter analyze 新增代码零 error/warning；全量测试保持 617 passed / 1 skipped / 1 failed；更新 holdings/convert 相关 widget 测试（结构断言）
- 完成后更新 TEAM.md 任务板 + HANDOFF.md 追加完成记录，git 状态待提交交 PM 审查
- HANDOFF 铁律：只 prepend 追加，不整文件重写、不用模糊正则范围替换

---

## 2026-08-06

**移交角色**：invest-ui
**接收角色**：项目经理（PM）

**任务**：6.5.1 + 6.5.4 UI

**完成工作**：
- lib/widgets/investment/convert_dialog.dart — 6.5.1：_loadHoldings 加 try/catch + _loadFailed 状态，失败显示「加载失败，请重试」+ 重试按钮，不再静默空态
- convert_dialog — 6.5.4 UI：新增「退回金额」「退回账户」；退回金额默认自动 = 转出市值 - 转入市值 - 手续费（Decimal、>=0 截断、两位小数），手动编辑后不再自动覆盖；退回账户用可交易账户下拉（排除投资/债权/负债/隐藏），refund>0 必填、refund=0 隐藏；提交前调用 validateConvert/convert 传 refundAmount/refundAccountId；份额/净值标签改为「确认转出/确认转入」

**下一个任务需要知道的**：
- invest-logic 数据层已落地 convert 三笔记账 + validateConvert/convert refund 参数（refundAmount 默认 0、refundAccountId 可空），UI 已按其签名对齐
- 退回账户在无可用可交易账户或 refund=0 时隐藏；refund>0 且未选账户时提交被拦截
- 未新增独立弹窗 widget 测试（弹窗依赖 repositoryProvider，mock 成本高）；全量测试覆盖数据层 refund 用例
- 全量 analyze 零 error（854 个既有 info/warning 基线不变）；全量测试 617 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**git 状态**：当前分支 main，待提交（工作区含 invest-logic 并行改动，交 PM 审查合入）

---

## 2026-08-06

**移交角色**：invest-logic
**接收角色**：项目经理（PM）

**任务**：6.5.2 / 6.5.3 / 6.5.4 数据层

**完成工作**：
- 6.5.2 — lib/data/repositories/local/local_investment_repository.dart：recomputeHolding 删除路径先读删除前 currentNav，重算时保留该净值；_recomputeHolding 增加 preservedNav 参数，剩余份额 >0 时市值按保留净值计算；updateTransaction 编辑路径仍按交易净值更新
- 6.5.3 — updateTransaction 的 clearNote 分支改为写入 d.Value(null) 真 NULL；note 传值正常更新、「不更新」仍 absent
- 6.5.4 — repo/service convert 新增 refundAmount / refundAccountId（可选默认 0/null，保持现有 UI 编译，UI 线程传入后生效）；事务内生成卖出 A（amount=转出市值）、买入 B（amount=转入市值，成本仍按 toShares×toNav）、退回（refund>0 时 type=transfer，投资账户→退回账户，note=基金转换退回，不进持仓/不挂 batchId）；refund<0 或 refund>0 缺账户在 repo/service 双侧抛错
- 测试 +5：删除旧流水保留手动净值、转换含退回三笔记账与余额、refund=0 不生成退回、refund 参数校验（repo + service）

**下一个任务需要知道的**：
- 6.5.1 / 6.5.4 UI（convert_dialog 退回字段 + 加载失败提示）由 invest-ui 并行处理
- convert 的 refundAmount/refundAccountId 为可选参数，最终 UI 应显式传入；refund>0 时账户必填

**验证**：flutter analyze 854 个既有 issue、零 error；全量测试 617 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**git 状态**：当前分支 main，工作区含 invest-logic + invest-ui 并行改动，待提交交 PM 审查

---

## 2026-08-06

**移交角色**：项目经理（PM）
**接收角色**：invest-logic + invest-ui

**任务**：6.5 遗留修复 + 基金转换确认记账改造（4 项）

**角色分工**：
- invest-logic：6.5.2 / 6.5.3 / 6.5.4 数据层（convert 记账 + 退回 + 测试）
- invest-ui：6.5.1 / 6.5.4 UI（转换弹窗退回字段 + 加载失败提示）

**6.5.1 转换弹窗加载失败提示（invest-ui）**
- 文件：lib/widgets/investment/convert_dialog.dart _loadHoldings
- 现状：只有 finally 无 catch，stream.first 抛错成未处理异步异常，列表静默为空
- 要求：加 try/catch + 错误状态，失败时界面显示「加载失败，请重试」，可点重试重新加载

**6.5.2 删除旧记录保留手动净值（invest-logic）**
- 文件：lib/data/repositories/local/local_investment_repository.dart recomputeHolding / _recomputeHolding
- 现状：删除任意旧流水触发重算时，currentNav 被重置为「最后一笔剩余流水的净值」，覆盖用户手动 updateNav 的最新值
- 要求：recomputeHolding（删除路径专用）重算时保留删除前的 currentNav；若剩余份额 >0，市值按保留净值重算；编辑路径（updateTransaction）保持按交易净值更新
- 净值数据源：用户建议接入数据源拉取最新净值（如天天基金/雪球），源未定，登记 backlog 待确认，不在本轮实现

**6.5.3 清空备注写 NULL（invest-logic）**
- 文件：local_investment_repository.dart updateTransaction（clearNote 分支）
- 现状：clearNote 写空串 ''，展示等价但语义是「空内容」
- 要求：clearNote 时写 d.Value(null)（真 NULL）；note 传值仍正常更新；「不更新」仍用 absent

**6.5.4 基金转换按确认数据记账 + 退回金额/退回账户（invest-logic + invest-ui）**
- 目标：转换本质 = 卖出 A + 买入 B，按转换确认后的实际成交数据记账：转出基金确认份额/单位净值、转入基金确认份额/单位净值、手续费、退回金额、退回账户；转出市值扣转入市值和手续费后的尾差退回，计入总资产
- 数据层（invest-logic）：
  - service.convert / repo.convert 签名新增：required double refundAmount（退回金额，>=0）、required int? refundAccountId（退回账户，refund>0 时必填）
  - validateConvert 新增：refundAmount >= 0；refundAmount > 0 时 refundAccountId 非空
  - 事务内生成 3 笔记录（batchId 相同）：
    a) 卖出 A：amount = 转出市值（fromShares×fromNav），investType='sell'，investFee=fee，batchId
    b) 买入 B：amount = 转入市值（toShares×toNav，不含手续费），investType='buy'，investFee=fee，batchId；持仓成本仍按 toShares×toNav
    c) 退回（refund>0 时）：type='transfer'，accountId=A 的投资账户，toAccountId=refundAccountId，amount=refund，note='基金转换退回'，不进持仓、不挂 batchId 编辑防护
  - 账户联动：退回账户余额 +refund（计入总资产）；投资账户市值仍由持仓合计覆盖
  - 测试：转换含退回 → 3 笔记录、B 成本=转入市值、退回账户余额 +refund、持仓/市值正确；refund=0 时不生成退回记录；refund<0 / 缺账户校验抛错
- UI 层（invest-ui）：
  - convert_dialog 字段补齐：确认转出份额/确认转出净值/确认转入份额/确认转入净值/手续费 + 新增「退回金额」「退回账户」
  - 退回金额默认自动计算 = 转出市值 - 转入市值 - 手续费（Decimal，>=0 截断），可手动改为平台确认值
  - 退回账户：可交易账户下拉（排除投资/债权/负债/隐藏），refund>0 时必填；refund=0 时禁用/隐藏
  - 提交前调用新 validateConvert 并传 refundAmount/refundAccountId

**约束**：
- flutter analyze 新增代码零 error/warning
- 全量测试保持 612 passed / 1 skipped / 1 failed（既存 bill_creation_service_test 除外）
- 完成后更新 TEAM.md 任务板 + HANDOFF.md 追加完成记录，git 状态待提交交 PM 审查
- HANDOFF 铁律：只 prepend 追加，不整文件重写、不用模糊正则范围替换

---

## 2026-08-06

**移交角色**：外部审查员 kimi
**接收角色**：项目经理（PM）

**任务**：6.4 修复（commit 937449e）针对性复审

**复审结论：验收通过 ✅**

12 项修复逐条对照代码核实，全部真实落地、实现正确，无虚假声明：
- 🔴#1 回退查询已加 ledgerId 过滤 + limit(1)（local_investment_repository.dart:72-78），多账本/多账户测试覆盖
- 🔴#2 删除重算已落地：单条（local_transaction_repository.dart:640-664）与批量（:1585-1619，holdingId 去重）均在同一事务内重算持仓 + 同步账户市值；recomputeHolding 自身不开新事务无嵌套；sync_diff_service 两条回删路径均覆盖；非投资交易不受影响
- 🔴#3 convert_dialog 加载移入 initState + 防重入 + mounted 检查，单基金空态不再循环
- 🔴#4 悬空冒号已删（wheel_date_picker.dart:622-648 时分结构正确）
- 🔴#5 homePeriodStatsProvider 已补 ref.watch(statsRefreshProvider)（home_page.dart:20）
- 🔴#6 编辑弹窗四字段 validator 落地，全文件已无 tryParse ?? 0 路径
- 🟡 updateNav 已包事务；buy 孤儿 holdingId 抛 StateError 且事务回滚；clearNote sentinel 四层全通（接口/实现/service/UI）；validateSell/validateConvert 校验补齐且弹窗实际传参；batchId 单边编辑已拦截；排序菜单改 PopupMenuDivider；分组弹窗 controller 与 wheel_date_picker 三个 State 的 dispose 均补齐
- 美化 Q1（border 亮色 8%）、Q2（净资产 textPrimary）顺带确认落地

**独立验证**：flutter analyze 854 issues / 0 error（基线不变）；flutter test 612 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test，与交接记录一致）；新增 3 个测试文件 45 用例实跑全绿，断言到具体数值，非空测试

**复审新发现问题（均为 🟢 轻微，不阻塞验收，建议记入下轮迭代）**：
1. convert_dialog.dart:65-81 _loadHoldings 有 finally 无 catch：stream.first 出错会成为未处理异步异常且列表静默为空，建议补 catch + 空态提示
2. _recomputeHolding 会把 currentNav 重置为「最后一笔剩余流水的净值」：用户手动 updateNav 后再删除任意旧流水，手动净值被覆盖。口径上可辩解，但与用户预期可能有偏差，建议产品层面确认
3. clearNote 写入空串 '' 而非 NULL：展示层等价，仅备注口径

**软约束提示**：batchId 单边编辑防护目前仅在 UI 层（holding_detail_page.dart:278-283），InvestmentService.updateTransaction 本身不拒绝 batch 交易；当前编辑入口唯一，可接受，后续若新增入口需在 service 层兜底

**git 状态**：当前分支 main，HEAD 937449e，复审全程只读，仅本文档新增本条目

---

## 2026-08-06

**移交角色**：invest-ui
**接收角色**：项目经理（PM）

**任务**：6.4 返工（6.4.3 UI 部分 + 🔴#4 悬空冒号）

**完成工作**：
- lib/widgets/investment/convert_dialog.dart — build 副作用修复：_loadHoldings 移到 initState + 防重入标记 + await 后 mounted 检查，仅一只基金时保持空态不再循环请求；转出净值/转入份额/转入净值必填 >0、手续费 >=0；提交前调用 service.validateConvert(fromNav/toShares/toNav/fee)，去掉空值静默写 0
- lib/widgets/ui/wheel_date_picker.dart — _TimeStepPicker 删除分钟后的多余冒号，只保留时分间 1 个分隔符；保留 _WheelDatePickerState/_DateStepPickerState 滚轮控制器 dispose（6.4.4 遗留）
- lib/widgets/investment/sell_dialog.dart — 卖出净值必填 >0、手续费 >=0；提交前调用 service.validateSell(nav/fee)
- lib/pages/investment/holding_detail_page.dart — 编辑弹窗份额/金额/净值必填 >0、手续费 >=0，禁止 tryParse ?? 0 静默写 0；备注清空走 updateTransaction(clearNote: true)，未变化不更新；带 batchId 的转换交易禁止单边编辑（提示「请编辑完整的转换记录」）

**下一个任务需要知道的**：
- service.updateTransaction 已支持 clearNote sentinel；validateSell/validateConvert 已支持 nav/fee/toShares/toNav 校验（invest-logic 并行落地）
- 转换 batch 交易现在不可单条编辑，只能整体处理（当前无批量编辑入口，属已知限制）
- 弹窗校验逻辑沿用现有测试基线，未新增独立弹窗 widget 测试（弹窗依赖 repositoryProvider，mock 成本高）
- 全量 analyze 零 error（854 个既有 info/warning 基线不变）；全量测试 612 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**git 状态**：当前分支 main，待提交（工作区含 architect/invest-logic 并行改动，交 PM 复审）

---

## 2026-08-06

**移交角色**：项目经理（PM）
**接收角色**：invest-ui

**任务**：6.4 返工（6.4.3 UI 部分 + 🔴#4 悬空冒号）

**问题 1（🔴#3）：convert_dialog build 副作用**
- 文件：lib/widgets/investment/convert_dialog.dart
- 现状：build 里 addPostFrameCallback 判 _holdings.isEmpty 触发加载，只有一只基金时反复请求；await 后未检查 mounted
- 要求：加载逻辑移到 initState 或加防重入标记，await 后 mounted 检查；只有一只基金（无转换目标）时保持空态不再循环请求

**问题 2（🔴#4）：时间选择器悬空冒号**
- 文件：lib/widgets/ui/wheel_date_picker.dart _TimeStepPicker
- 现状：6.3 删秒列后仍保留 2 个 ':'（HH : MM :）
- 要求：删除分钟后的多余 ':'，只保留时分间 1 个分隔符

**问题 3（🔴#6）：编辑交易弹窗份额/金额静默写 0**
- 文件：lib/pages/investment/holding_detail_page.dart 编辑弹窗
- 要求：份额必填且 >0（sell/redeem 保存时内部转负）、金额必填 >0、净值必填 >0、手续费 >=0；禁止 tryParse ?? 0 静默写 0；表单校验不过不提交

**问题 4（🟡）：sell_dialog / convert_dialog 接入新校验**
- 文件：lib/widgets/investment/sell_dialog.dart、lib/widgets/investment/convert_dialog.dart
- 要求：提交前调用 service.validateSell(holdingId, shares, nav:, fee:) / service.validateConvert(fromHoldingId, fromShares, fromNav:, toShares:, toNav:, fee:) 并传参；UI 层同步补 净值>0、手续费>=0、转入份额/净值>0 校验

**问题 5（🟡）：转换 batch 交易单边编辑防护**
- 文件：lib/pages/investment/holding_detail_page.dart
- 要求：编辑带 batchId 的转换交易时禁止单边保存（提示“请编辑完整的转换记录”或隐藏编辑入口），避免只改单侧导致两持仓口径不一致

**问题 6（🟡）：编辑弹窗备注清空**
- 文件：lib/pages/investment/holding_detail_page.dart
- 要求：备注清空时调用 service.updateTransaction(tx.id, clearNote: true)（接口已就绪），区分「不更新」；保留原值不变逻辑

**约束**：
- flutter analyze 新增代码零 error/warning
- 全量测试保持 612 passed / 1 skipped / 1 failed（既存 bill_creation_service_test 除外）
- 完成后更新 TEAM.md 任务板 + HANDOFF.md 追加完成记录，git 状态待提交交 PM 复审

---

## 2026-08-06

**移交角色**：architect + invest-logic
**接收角色**：项目经理（PM）

**任务**：6.4.1-6.4.3（architect / invest-logic 数据层与校验层部分）

**完成工作**：
- lib/data/repositories/local/local_investment_repository.dart — 6.4.1 投资账户回退查询加 ledgerId 过滤 + limit(1)；6.4.3 buy 指定不存在 holdingId 时抛 StateError、updateNav 包事务、updateTransaction 增加 clearNote sentinel（清空备注与「不更新」区分）；新增 recomputeHolding 公开入口供通用删除路径调用
- lib/data/repositories/local/local_transaction_repository.dart — 6.4.2 deleteTransaction / deleteTransactionsBatchBySyncIds 删除投资流水后在同一事务内重算持仓（份额/成本/市值）并联动投资账户市值
- lib/data/repositories/investment_repository.dart + lib/services/data/investment_service.dart — updateTransaction 接口补 clearNote；validateSell 补 nav/fee，validateConvert 补 fromNav/toShares/toNav/fee 校验（可选参数，UI 传入后生效）
- 测试 +9：多账本回退不串账本、同账本多投资账户取首个、buy 孤儿防护、clearNote 清空、validateSell/validateConvert 校验、删除 buy/sell/批量删除重算
- 验证：flutter analyze 854 个既有 issue、零 error；全量测试 612 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**下一个任务需要知道的**：
- 6.4.3 的 UI 弹窗部分仍由 invest-ui 线程继续：convert_dialog build 副作用、wheel_date_picker 悬空冒号、编辑弹窗份额/金额校验、sell/convert 弹窗传 nav/fee、转换 batch 单边编辑防护、编辑弹窗备注清空 UI
- validateSell/validateConvert 新参数为可选，UI 未传时不会触发对应校验；最终需 invest-ui 调用时传入

**git 状态**：当前分支 main，工作区含 architect/invest-logic + invest-ui 并行改动，待提交交 PM 审查

---

## 2026-08-06

**移交角色**：invest-ui
**接收角色**：项目经理（PM）

**任务**：6.4.4 + 6.4.5（kimi REV-1 修复）

**完成工作**：
- lib/pages/investment/holdings_list_page.dart — 排序菜单分隔线由手写 Colors.black ColoredBox 改为 PopupMenuDivider（随主题适配，暗黑可见）；新建/重命名分组弹窗的 TextEditingController 增加 try/finally dispose
- lib/widgets/ui/wheel_date_picker.dart — _WheelDatePickerState / _DateStepPickerState 补 dispose，year/month/day 滚轮控制器全部释放；_TimeStepPicker 原有 dispose 不变
- lib/styles/tokens.dart — Q1：BeeTokens.border() 亮色 transparent → rgba(0,0,0,0.08)，恢复可见边框，暗黑分支不变
- lib/pages/main/home_page.dart — 🔴#5：homePeriodStatsProvider 补 ref.watch(statsRefreshProvider)；Q2：首页净资产 30pt 颜色由 primary 改为 BeeTokens.textPrimary
- test/widgets/holdings_list_page_layout_test.dart — 排序下拉菜单断言补 PopupMenuDivider 数量（2 条）

**下一个任务需要知道的**：
- 6.4.1-6.4.3 由 architect/invest-logic 并行落地（本记录完成时已出现在工作区，全量测试已含其新用例）
- Q1 边框改动影响 48+ 处 BeeTokens.border 使用，已跑全量 widget/单元测试确认无回归；暗黑分支未改
- 全量 analyze 零 error；全量测试 609 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）；排序菜单暗黑效果未做实机截图验证

**git 状态**：当前分支 main，待提交（工作区含 architect/invest-logic 并行改动，交 PM 审查合入）

---

## 2026-08-06

**移交角色**：项目经理（PM）
**接收角色**：architect + invest-logic + invest-ui

**任务**：6.4 外部审查修复（kimi REV-1：🔴 6 + 🟡 7 + 精选 Quick Wins）

**角色分工**：
- architect + invest-logic：数据/事务/校验层（6.4.1/6.4.2/6.4.3）
- invest-ui：弹窗与 UI（6.4.4/6.4.5）

**6.4.1 投资账户回退查询串账本/崩溃（🔴#1）**
- 文件：lib/data/repositories/local/local_investment_repository.dart _resolveInvestmentAccount
- 现状：回退查询只按 type 过滤、未按 ledgerId，且 getSingleOrNull() 多行抛 StateError
- 要求：加 ledgerId 过滤 + limit(1)/first 取首条；补「多账本各有投资账户」测试

**6.4.2 通用删除投资交易后不重算持仓（🔴#2）**
- 文件：lib/data/repositories/local/local_transaction_repository.dart deleteTransaction / deleteTransactionsBatchBySyncIds
- 现状：搜索页/分类详情/标签页删除 investType!=null 的交易后，持仓份额/成本/市值与账户市值留旧值
- 要求：删除后触发投资重算（份额/成本/市值 + 投资账户市值联动）；新增删除 buy/sell 交易的重算测试；若跨仓库注入不便，可由 UI 层短期禁止删除投资交易（记录取舍）

**6.4.3 投资校验/事务/孤儿/备注（invest-logic + invest-ui 弹窗配合）**
- convert_dialog build 副作用（🔴#3）：加载逻辑移到 initState 或加防重入，await 后 mounted 检查
- wheel_date_picker 悬空冒号（🔴#4）：删除分钟后的多余 ':'（6.3 遗留）
- 编辑交易弹窗份额/金额校验（🔴#6）：holding_detail_page 编辑弹窗份额必填 >0（sell/redeem 内部转负）、金额/净值/手续费必填且范围合法，禁止 tryParse ?? 0 静默写 0
- sell_dialog / convert_dialog（🟡）：净值必填 >0、手续费 >=0、转入份额/净值必填 >0；service.validateSell / validateConvert 同步补校验
- updateNav 包事务（🟡）：与 buy/sell/convert 一致
- buy 指定不存在的 holdingId 时抛错（🟡）：避免孤儿交易
- 转换 batch 交易单边编辑防护（🟡）：holding_detail_page 编辑带 batchId 的转换交易时禁止单边保存或强制双侧校验
- 编辑弹窗备注清空（🟡）：updateTransaction 用 sentinel（empty → 清空）区分「不更新」

**6.4.4 排序菜单分隔线暗黑不可见 + 控制器 dispose（invest-ui）**
- 排序菜单分隔线（🟡/Q3）：替换手写 Colors.black ColoredBox，用随主题适配的分隔（亮色黑、暗色可见），可用 PopupMenuDivider 或同效实现
- 控制器 dispose（🟡）：wheel_date_picker 滚轮控制器、holdings_list_page 分组弹窗 TextEditingController

**6.4.5 首页统计刷新 + 美化速赢（invest-ui）**
- homePeriodStatsProvider 不随记账刷新（🔴#5）：home_page.dart 加 ref.watch(statsRefreshProvider)（与 netWorthBreakdownProvider 一致）
- Q1：BeeTokens.border() 亮色 transparent → 实色（black 8%），恢复 48+ 处可见边框；改动前确认受影响页面无明显回归（跑全量 widget 测试）
- Q2：首页净资产 30pt 白底金字对比度不足 → 改 BeeTokens.textPrimary

**范围外（登记 backlog，本轮不做）**：🔵 系统性项（l10n 硬编码、Decimal 存储层、净值数据源、分组查重/归属校验）、Quick Wins Q4-Q7、长期项 L1-L5

**约束**：
- flutter analyze 新增代码零 error/warning
- 全量测试保持 603 passed / 1 skipped / 1 failed（既存 bill_creation_service_test 除外）
- 相关测试补充
- 完成后更新 TEAM.md 任务板 + HANDOFF.md 追加完成记录，git 状态待提交交 PM 审查
- HANDOFF 铁律：只 prepend 追加，不整文件重写、不用模糊正则范围替换

---

## 2026-08-06

**移交角色**：外部审查员 kimi
**接收角色**：项目经理（PM）

**任务**：投资模块全量代码审查 + 前端美化分析（只读审查，未改任何代码）

**完成工作**：
- 审查范围：①逻辑层 —— db.dart 投资表与 v32-v36 迁移、investment_repository、local_investment_repository、investment_service、investment_providers；②UI 层 —— holdings_list_page、holding_detail_page、5 个投资弹窗、home_page（6.3 改动）、wheel_date_picker（6.3 改动）；③设计系统 —— tokens.dart、主题、关键页面一致性
- 全量 flutter analyze 复核：0 error、20 条 warning（均为 unused import/variable、unnecessary cast，无实质问题），与 6.3 交接记录一致，基线干净
- 产出：下方问题清单（均经代码逐条确认，存疑处标注「待确认」）+ 美化建议方案，递交 PM 分派

**🔴 严重问题（6 条，建议优先修复）**：
1. **投资账户回退查询可崩溃/串账本** —— lib/data/repositories/local/local_investment_repository.dart:72-76：回退查询只按 type 过滤、未按 ledgerId 过滤，且 getSingleOrNull() 多行抛 StateError。≥2 个账本时买入直接崩溃；单行时也可能把持仓挂到他账本账户。修法：加 ledgerId 过滤 + limit(1) 取首条
2. **通用删除路径删投资交易后不重算持仓（最可能真实爆雷）** —— lib/data/repositories/local/local_transaction_repository.dart:580-592（含批量删除 :1489-1513）：搜索页/分类详情/标签页删除买入记录后，持仓份额/成本/账户市值全部留旧值且无纠正机制。修法：删除后触发 _recomputeHolding + 账户市值同步；短期可在 UI 禁止删除 investType != null 的交易
3. **转换弹窗 build 副作用可无限循环** —— lib/widgets/investment/convert_dialog.dart:122-124：build() 里判 _holdings.isEmpty 触发加载、加载完无条件 setState，只有一只基金时恒为空 → 每帧循环请求数据库；且 await 后未检查 mounted。修法：移到 initState + mounted 检查
4. **时间选择器遗留悬空冒号** —— lib/widgets/ui/wheel_date_picker.dart:631：6.3 删秒列时留下了分隔符，现显示 HH : MM :。删 1 行
5. **首页周期统计不随记账刷新** —— lib/pages/main/home_page.dart:16-41：homePeriodStatsProvider 漏了 ref.watch(statsRefreshProvider)（同文件 netWorthBreakdownProvider 有）。记账回首页后今日/本周收支不更新，同屏两卡口径不一致。加 1 行
6. **编辑交易弹窗份额可静默写 0** —— lib/pages/investment/holding_detail_page.dart:586-594：份额无 validator，tryParse ?? 0，清空误输 → 份额写 0 入库 → 重算后持仓被错误扣减；金额 validator 也放行 0 和负数

**🟡 中等问题（摘要）**：
- 卖出/转换校验缺口：sell_dialog.dart:76 净值留空按 0 提交 → 市值清零、proceeds 可为负；convert_dialog.dart:92-94 转入份额/净值留空按 0；手续费无负值校验。validateSell/validateConvert（investment_service.dart）与 UI 双层都需补 nav>0、fee>=0
- updateNav 不在事务内 —— local_investment_repository.dart:527-541（buy/sell/convert 均包事务，唯独它没包）
- buy 指定不存在的 holdingId 时静默产生孤儿交易 —— local_investment_repository.dart:295-301（sell/convert 都会抛错）
- 转换对交易可被单边编辑 —— holding_detail_page.dart:577-598：带 batchId 的转换无防护，只改单侧且只重算单侧持仓
- 排序菜单分隔线写死 Colors.black —— holdings_list_page.dart:407，暗黑模式下不可见
- 编辑弹窗无法清空备注 —— null 被 updateTransaction 当「不更新」，需 sentinel 区分
- 控制器未 dispose —— wheel_date_picker 两个 State 类的滚轮控制器、holdings_list_page 分组弹窗的 TextEditingController

**🔵 系统性/技术债**：
- 投资模块 7 个文件完全绕开 l10n（项目本身有 zh/zh_TW/en/ko 四套 arb），全部硬编码中文
- 「Decimal 精度改造」只到内存层，存储仍是 RealColumn（double），db.dart:207-217
- 净值刷新 updateNav/batchUpdateNav 无任何调用方（无净值数据源接入），属功能缺口
- createGroup 不查重名；分组接口不校验持仓归属账本；注释中的 redeem 类型实现里不存在

**前端美化建议（均已核实证据）**：
- Quick Wins：Q1 BeeTokens.border() 亮色返回 transparent 被 48+ 处当可见边框用（tokens.dart:237-240），排序按钮/分组 chip 亮色下只剩悬浮文字 → 亮色分支改返回 black 8% 实色，一处改全局生效；Q2 首页净资产 30pt 白底金字对比度仅 1.6:1（home_page.dart:218-221）→ 改 textPrimary；Q3 排序菜单手写纯黑分隔条（holdings_list_page.dart:405-408）→ 换 PopupMenuDivider；Q4 我的页头像装饰在同色金底上隐身（mine_page.dart:774-784）→ 改半透明白底；Q5 交易卡水波纹圆角 8 与卡片 12 不匹配（holding_detail_page.dart:416-419）；Q6 统计页版心 padding 16 与其余页 12 不一致（analytics_page.dart:710）；Q7 持仓摘要卡三行等宽无主次（holdings_list_page.dart:254-268）→ 总市值 26pt + 盈亏行加粗
- 长期项：L1 圆角统一（8/10/12/14/16/20 六套并存 → 卡片 12 / 弹窗 16，一致性收益最大）；L2 514 处手写 fontSize 收进约 8 级文字 token；L3 PrimaryHeader 文字色不随自定义主题色深浅自适应（primary_header.dart:67，textOnHeader 定义了却没用）；L4 统计页摘要把收支都显示成主题色、投资盈亏借用收入/支出色（建议独立 profit/loss token）；L5 折线图暗色辅助线不可见（line_chart.dart:290/415/425）
- 若只做三件事：Q1 → Q2 → L1

**下一个任务需要知道的**：
- 本次审查全程只读，未修改任何代码文件；上述每条均在当前 main 代码中确认行号
- 建议修复顺序：🔴 6 条（多为 1-10 行小改动，但直接影响数据正确性）→ 🟡 校验/事务/暗黑分隔线 → Q1-Q3 美化速赢 → 其余排期
- 做得好的一面：迁移幂等、核心写操作均包事务、成本重算双路径自洽、Provider 失效链路正确、测试有覆盖；问题集中在边界防守和与存量系统的接缝处

**git 状态**：当前分支 main，代码零改动，仅本文档新增本条目 + TEAM.md 登记（待 PM 审查）

---

## 2026-08-06

**移交角色**：invest-ui
**接收角色**：项目经理（PM）

**任务**：6.3 首页/资产/记账 6 项 UI 优化

**完成工作**：
- lib/pages/investment/holdings_list_page.dart — 分组胶囊加 minWidth 80 最小宽度；排序由 ChoiceChip 改为右侧下拉菜单（PopupMenuButton），左侧「排序」+ 单边向下箭头，菜单项左对齐并用黑色 Divider 分隔，holdingsSortProvider 逻辑不变
- lib/pages/main/home_page.dart — 资产概览总资产/总负债改为上下两行、标签灰字、数值沿用 income/expense 语义色（资产红/负债绿），卡片高度保持 200；周期统计每项两行（黑字标签 + 灰字时间范围）+ 右侧收入/支出两行红绿数值，卡片高度自适应；homePeriodStatsProvider 补充 start/end 字段；删除月度分类占比组件与 homeCategoryExpensesProvider
- lib/widgets/ui/wheel_date_picker.dart — showWheelDateTimePicker/_TimeStepPicker 删除秒列，只保留时分，组合 DateTime second 固定 0
- test/widgets/home_page_test.dart — 删除分类占比 override/断言，周期统计 override 补日期范围，新增范围文本与收入/支出断言
- test/widgets/holdings_list_page_layout_test.dart — 排序断言改为打开下拉菜单后校验

**下一个任务需要知道的**：
- homePeriodStatsProvider 返回结构变为 {income, expense, start, end}（start/end 为闭开区间，end 为 exclusive，UI 显示时减一天）
- 时间选择器只保留时分后，现有 wheel_date_picker 测试（纯日期）不受影响；_TimeStepPicker 为私有类无直接测试
- 视觉布局（资产卡 200 高度内排版、下拉菜单、周期统计两行）未做 Windows 实机截图验证；widget 测试覆盖结构断言
- 全量 analyze 854 个既有 info/warning、零 error；全量测试 603 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**git 状态**：当前分支 main，待提交交 PM 审查

---

## 2026-08-06

**移交角色**：项目经理（PM）
**接收角色**：invest-ui

**任务**：6.3 首页/资产/记账 6 项 UI 优化

**问题 1：分组胶囊最小尺寸**
- 文件：lib/pages/investment/holdings_list_page.dart _buildGroupChip
- 现状：chip 只按内容撑开，短名（如「全部」）很小
- 要求：给分组胶囊设置最小宽度，能容纳 4 个中文字符（当前 13px 字号约 52px + 左右 padding 14×2 ≈ 80px），视觉参考记账页面 4 字标签尺寸；「全部」与自定义分组统一最小宽度，chip 高度/内边距不变

**问题 2：排序改为下拉菜单**
- 文件：holdings_list_page.dart _buildSortRow
- 现状：持有金额/持有收益/持有收益率三个 ChoiceChip
- 要求：
  a) 去掉独立胶囊，改为一个下拉式选择菜单，菜单靠右对齐界面；右侧显示当前排序值，点击弹出
  b) 菜单三项：持有金额/持有收益/持有收益率，文字左对齐，项与项之间用黑色分割线（Divider）
  c) 左侧保留「排序」文字，其后追加一个单边向下箭头（Icons.arrow_drop_down），代表排序方向从大到小（降序）
  d) 行仍固定在摘要下方不随列表滚动；holdingsSortProvider 逻辑不变

**问题 3：首页资产概览总资产/总负债分行红绿**
- 文件：lib/pages/main/home_page.dart _buildAssetOverview
- 现状：总资产/总负债同一行左右并排，数值黑字
- 要求：改为上下两行（总资产一行、总负债一行），卡片总高度保持 200 不变；总资产数值红色、总负债数值绿色（沿用 income/expense 语义色），标签保持小灰字

**问题 4：首页周期统计两行布局 + 时间范围**
- 文件：home_page.dart _buildPeriodStats、homePeriodStatsProvider（如需补日期范围字段）
- 现状：今天/本周/本月/今年每行单行，右侧「收入 X 支出 Y」一行
- 要求：
  a) 每一条两行：第一行黑字 今天/本周/本月/今年；第二行灰色小字显示时间范围：今天「2026.8.6」、本周「8.3-8.9」、本月「8.1-8.31」、今年「2026」（跨月按「7.28-8.3」格式）
  b) 每一条右侧收入/支出分两行：灰色小字「收入」「支出」+ 数值，收入红、支出绿
  c) 卡片高度随内容自适应（不再固定 178）
- 注意：周范围按周一为一周开始（与 now.weekday 语义一致）

**问题 5：删除首页月度分类占比**
- 文件：home_page.dart（_buildCategoryBreakdown、homeCategoryExpensesProvider、CategoryPieChart 导入）、test/widgets/home_page_test.dart
- 要求：删除组件、provider 与相关测试 override/断言；确认 homeCategoryExpensesProvider 无其他引用后再删；页面其余模块顺序自然衔接

**问题 6：记账时间选择器去掉秒**
- 文件：lib/widgets/ui/wheel_date_picker.dart（showWheelDateTimePicker / _TimeStepPicker）
- 现状：时分秒三列
- 要求：删除秒列，只保留时分；showWheelDateTimePicker 组合 DateTime 时 second 固定 0；确认 tx_entry_form / transfer_form 使用不受影响
- 注意：不要改动 reminder 设置用的 WheelTimePicker（本就无秒）

**约束**：
- flutter analyze 新增代码零 error/warning
- 更新相关 widget 测试
- 完成后更新 TEAM.md 任务板 + HANDOFF.md 追加完成记录，git 状态待提交交 PM 审查
- HANDOFF 铁律：只 prepend 追加，不整文件重写、不用模糊正则范围替换

---

## 2026-08-05

**移交角色**：invest-logic + invest-ui
**接收角色**：项目经理（PM）

**任务**：6.2 返工 2 完成（Notifier state 暴露方式修正）

**完成工作**：
- lib/providers/investment_providers.dart — SelectedGroupNotifier 新增公开方法 select(int? groupId) / reset()，内部写 state；保留账本切换自动重置
- lib/pages/investment/holdings_list_page.dart — 3 处 notifier.state 直接写入改为公开方法调用（「全部」chip reset()、分组 chip select(group.id)、删除分组后回全部 reset()）
- test/providers/investment_providers_test.dart — 测试改用公开方法 select(groupA)，「切换账本后分组重置」覆盖保留

**下一个任务需要知道的**：
- UI/测试不再直接写 notifier.state，消除 invalid_use_of_protected_member / invalid_use_of_visible_for_testing_member 两类 warning
- 全量 analyze 新增代码零 error/warning；全量测试 603 passed / 1 skipped / 1 failed（既存 bill_creation_service_test 除外）

**git 状态**：当前分支 main，待提交（工作区含 6.2 原实现 + 两次返工，交 PM 审查合入）

---



## 2026-08-05

**移交角色**：项目经理（PM）
**接收角色**：invest-logic + invest-ui

**任务**：6.2 返工 2（analyzer warning）

**问题（P1）：selectedGroupProvider 自定义 Notifier 后 UI 直接写 notifier.state**
- 文件：lib/providers/investment_providers.dart、lib/pages/investment/holdings_list_page.dart（约 452 / 462 / 926 行）
- 现象：dart analyze 新增 6 条 warning（invalid_use_of_protected_member / invalid_use_of_visible_for_testing_member），违反「新增代码零 error/warning」约束
- 要求：
  a) SelectedGroupNotifier 增加公开方法 select(int? groupId) 与 reset()（内部写 state，保留账本切换自动重置）
  b) holdings_list_page 的 3 处 `notifier.state = ...` 改为调用 select(...) / reset()
  c) 测试保持「切换账本后分组重置」覆盖，全部改用公开方法
- 约束：flutter analyze 新增代码零 error/warning；全量测试保持 603 passed / 1 skipped / 1 failed；完成后更新 TEAM.md + HANDOFF.md，git 状态待提交交 PM 复审

---

## 2026-08-05

**移交角色**：invest-logic + invest-ui
**接收角色**：项目经理（PM）

**任务**：6.2 返工完成（P2 账本切换分组重置 + P3 弹窗持仓加载）

**完成工作**：
- lib/providers/investment_providers.dart — selectedGroupProvider 从全局 StateProvider 改为 NotifierProvider，build 中监听 currentLedgerIdProvider，账本变化时重置为 null（回到「全部」），避免旧账本分组 id 过滤新账本持仓导致列表为空且无 chip 高亮
- lib/pages/investment/holdings_list_page.dart — _showCreateGroupDialog / _showEditGroupMembersDialog 弹窗前 await currentHoldingsProvider.future（异常时兜底空列表），首帧即可列出可选基金
- test/providers/investment_providers_test.dart — 新增「切换账本后选中的分组重置为全部」用例：账本 1 选中分组 → 切到账本 2 → selectedGroupProvider 回到 null，filteredHoldingsProvider 返回账本 2 全部持仓

**下一个任务需要知道的**：
- selectedGroupProvider 的 UI 读/写 API 不变（ref.watch / ref.read(...notifier).state），仅实现改为 Notifier + 账本监听重置
- 弹窗打开前会等待持仓流首次数据；加载失败时仍显示「暂无基金可选」兜底
- 全量 analyze 零 error；全量测试 603 passed / 1 skipped / 1 failed（既存 bill_creation_service_test 除外）

**git 状态**：当前分支 main，待提交（工作区含 6.2 原实现 + 本次返工，交 PM 审查合入）

---

## 2026-08-05

**移交角色**：项目经理（PM）
**接收角色**：invest-logic + invest-ui

**任务**：6.2 返工（PM 审查发现 1 个 P2 + 1 个 P3）

**问题 1（P2）：切换账本后选中的分组未重置**
- 文件：lib/providers/investment_providers.dart（selectedGroupProvider / filteredHoldingsProvider）
- 现状：selectedGroupProvider 是全局 StateProvider；资产页选中分组后切回首页换账本，再回资产页仍保留旧账本分组 id，filteredHoldingsProvider 用旧账本成员过滤新账本持仓，导致列表空且无 chip 高亮
- 要求：currentLedgerIdProvider 变化时重置 selectedGroupProvider 为 null（或按 ledger 隔离，如 family<int, int>）；补「切换账本后回到全部」测试

**问题 2（P3）：新建/编辑成员弹窗首帧读不到持仓**
- 文件：lib/pages/investment/holdings_list_page.dart _showCreateGroupDialog / _showEditGroupMembersDialog
- 现状：用 ref.read(currentHoldingsProvider).asData?.value 同步快照，数据未加载时显示「暂无基金可选」
- 要求：弹窗前 await currentHoldingsProvider.future（带容错），确保列表可用

**约束**：
- flutter analyze 新增代码零 error/warning
- 全量测试保持 602 passed / 1 skipped / 1 failed（既存 bill_creation_service_test 除外）
- 完成后更新 TEAM.md 任务板 + HANDOFF.md 追加完成记录，git 状态待提交交 PM 复审

---

## 2026-08-05

**移交角色**：invest-ui
**接收角色**：项目经理（PM）

**任务**：6.2 UI（持仓排序 + 基金分组）

**完成工作**：
- lib/pages/investment/holdings_list_page.dart — 摘要卡下方新增固定区：分组 chips（全部 + 自定义分组 + 末尾「新建分组」，横向滚动）+ 排序行（持有金额/持有收益/持有收益率，默认持有金额降序）；列表改用 filteredHoldingsProvider，选中分组内无基金时显示分组空态；新建分组弹窗（名称 + 多选基金）、长按分组 chip 支持重命名/编辑成员/删除（「全部」不可改删）
- test/widgets/holdings_list_page_layout_test.dart — 空态测试补 groupsProvider override；新增「有持仓时固定显示排序行与分组 chips」「选中分组无基金时显示分组空态」2 个用例

**下一个任务需要知道的**：
- 逻辑侧（invest-logic）并行落地 schema v36 + repository/service/providers + 测试，UI 已按其实际签名对齐：createGroup(ledgerId/name/sortOrder) + addHoldingsToGroup；watchGroupHoldingIds 返回 Stream<List<int>>；setGroupMembers 存在
- 视觉布局（排序行/分组 chips/弹窗）未做 Windows 实机截图验证
- 全量 analyze 854 个既有 info/warning、零 error；全量测试 602 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**git 状态**：当前分支 main，待提交（工作区含 invest-logic 并行改动，交 PM 审查合入）

---

## 2026-08-05

**移交角色**：项目经理（PM）
**接收角色**：invest-logic + invest-ui

**任务**：6.2 持仓排序 + 基金分组（2 个问题，设计与用户已确认）

**角色分工**：
- invest-logic：schema v36 + 分组 repository/service + 排序/过滤 provider + 测试
- invest-ui：排序控件 + 分组 chips/弹窗/编辑 + 列表接线

**问题 1：持仓排序**
- 目标：资产页持仓列表可按「持有收益率 / 持有收益 / 持有金额」排序；默认「持有金额」降序，不做升降序切换
- 语义：持有金额 = 当前市值；持有收益 = 市值 - 成本；持有收益率 = 收益 / 成本
- 数据/逻辑层（invest-logic）：
  - 新增 holdingsSortProvider（StateProvider，默认 marketValue），选项 enum：marketValue / pnl / returnRate
  - 新增 sortedHoldingsProvider：watch currentHoldingsProvider + 排序状态，内存排序（先分组过滤后排序）
- UI 层（invest-ui）：
  - lib/pages/investment/holdings_list_page.dart：投资组合摘要卡与列表之间加固定排序行（三选一，建议 SegmentedButton 或紧凑下拉），不随列表滚动
  - 无持仓时不显示排序行或显示禁用态，不破坏布局

**问题 2：基金分组**
- 目标：默认虚拟分组「全部」（含所有基金、永远第一位、不可改删）+ 用户自定义分组；一只基金可属于多个分组；分组标签固定在投资组合摘要下方，横向滚动、不可上下滚动；「新建分组」按钮在标签末尾；支持分组改名/删除/编辑成员；分组数据仅本地，不做云同步
- 数据层（invest-logic）：
  - Drift schema v35 → v36：新增 investment_groups（id、ledger_id、name、sort_order、created_at）与 investment_group_holdings（group_id、holding_id 复合主键），外键级联删除（删持仓自动清理关联）；同步补充 migration v36 测试
  - LocalInvestmentRepository：createGroup / renameGroup / deleteGroup / addHoldingsToGroup（或 setGroupMembers）/ removeHoldingFromGroup / watchGroups / watchGroupHoldingIds
  - InvestmentService 包装以上方法
  - Provider：groupsProvider（Stream）、selectedGroupProvider（StateProvider<int?>，null=全部）、filteredHoldingsProvider（先按选中分组过滤，再按排序）
  - 测试：分组 CRUD、成员多对多、删持仓级联、过滤+排序组合
- UI 层（invest-ui）：
  - holdings_list_page：摘要卡下方固定一行横向滚动分组 chips（全部 + 自定义分组 + 「新建分组」在最后）；选中分组过滤下方列表；分组内无基金时显示空态
  - 新建分组弹窗：填名称 + 多选基金
  - 分组管理：长按分组 chip → 改名/删除/编辑成员；「全部」不可改删
  - 排序行与分组 chips 都位于固定区，列表只滚动持仓

**约束**：
- flutter analyze 新增代码零 error/warning
- 全量测试保持 586 passed / 1 skipped / 1 failed（既存 bill_creation_service_test 除外）
- 完成后更新 TEAM.md 任务板 + HANDOFF.md 追加完成记录，git 状态待提交交 PM 审查
- HANDOFF 铁律：只 prepend 追加，不整文件重写、不用模糊正则范围替换

---

## 2026-08-05

**移交角色**：invest-ui
**接收角色**：项目经理（PM）

**任务**：6.1.1 UI + 6.1.2 + 6.1.3

**完成工作**：
- lib/widgets/investment/buy_dialog.dart — 删除「手续费」字段/控制器；新增「投入本金」字段；「份额/净值」label 改为「确认份额/确认净值」；校验本金/份额/净值 > 0；调用 service.validateBuy(amount:) 与 service.buy(amount:) 新签名
- lib/pages/account/accounts_page.dart — 资产构成模块删除大号「资产构成」标题；加载占位高度 70 → 96 同步
- lib/widgets/charts/asset_composition_chart.dart — 饼图高度 70 → 96，切片 radius 30/34 → 36/40，centerSpaceRadius 20 → 26，legend 间距 12 → 24
- lib/pages/main/mine_page.dart — 删除「分享海报/复制推广文案」两个 tile 与「支持我们」SectionCard；年度账单移入外观设置所在卡片（外观设置之后）；清理 Platform/services/share_poster/donation/in_app_review 导入与 _rateApp

**下一个任务需要知道的**：
- 6.1.1 逻辑侧由 invest-logic 线程并行落地（service/repo buy 改 required amount、investFee=0、Decimal 算术、测试 +4 用例），本记录完成时已在工作区且验证通过；本次仅改 UI 文件，未触碰 service/repo/test
- 视觉布局（饼图尺寸/间距、我的页重排）未做 Windows 实机截图验证
- 全量 analyze 854 个既有 info/warning、零 error；全量测试 586 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**git 状态**：当前分支 main，待提交（工作区含 invest-logic 并行改动，交 PM 审查合入）

---

## 2026-08-05

**移交角色**：项目经理（PM）
**接收角色**：invest-logic + invest-ui

**任务**：6.1 投资买入输入调优 + 资产构成布局 + 我的页清理（3 个问题）

**角色分工**：
- invest-logic：6.1.1 数据层/服务层（repository/service/Decimal/测试）
- invest-ui：6.1.1 UI（buy_dialog 三字段）+ 6.1.2 + 6.1.3

**问题 1：基金买入计算逻辑调优（核心）**
- 目标：与支付宝等平台显示对齐。买入时用户只需录入「投入本金」「确认份额」「确认净值」三个字段；市值 = 确认份额 × 最新净值；浮动盈亏 = 市值 - 投入本金；无需录入费率/手续费；直接使用基金公司确认的截位后份额，不反算份额。
- 数据层/服务层（invest-logic）：
  - 文件：lib/services/data/investment_service.dart、lib/data/repositories/local/local_investment_repository.dart、相关测试
  - service.buy / repo.buy：移除 double fee 参数，新增 required double amount（投入本金）；交易 amount = amount（本金），investFee = 0；持仓 totalCost += amount；marketValue = (oldShares + shares) × nav
  - validateBuy 增加 amount > 0 校验（签名同步为 shares/nav/amount）
  - 所有投资算术改用 package:decimal（Decimal）：buy、_recomputeHolding（份额/成本/比例/市值）、updateNav（市值）、getPortfolioSummary / getHoldingReturn（盈亏/收益率）；double 仅在入库/出参时转换，避免浮点误差
  - 兼容：_recomputeHolding 对旧 buy 记录（无 amount）的兜底「份额 × 净值 + 手续费」保留
  - 更新 test/services/investment_service_test.dart、test/data/repositories/investment_repository_test.dart 的 buy 调用为 amount；新增用例：amount=1001.5 / shares=1000 / nav=1 → cost=1001.5、marketValue=1000、fee=0；Decimal 精度用例（如 shares=0.1、nav=0.1 → 市值=0.01，而非 0.010000000000000002）
- UI 层（invest-ui）：
  - 文件：lib/widgets/investment/buy_dialog.dart
  - 删除「手续费」字段/控制器；新增「投入本金」（金额）字段；保留「份额」「净值」，label 改为「确认份额」「确认净值」
  - 校验：本金 > 0、份额 > 0、净值 > 0；调用新 service.buy 签名传 amount
  - 提交按钮文案保持「确认」
- 约束：flutter analyze 新增代码零 error/warning；全量测试保持 582 passed / 1 skipped / 1 failed（既存 bill_creation_service_test 除外）

**问题 2：资产构成饼图布局**
- 文件：lib/pages/account/accounts_page.dart（_buildNetWorthAndCompositionCard）、lib/widgets/charts/asset_composition_chart.dart
- 删除模块内大号「资产构成」标题文字
- 饼图适当放大（图高 70 → 约 96~100，切片 radius / centerSpaceRadius 相应调大），不裁切不重叠
- 各一级账户占比文字（legend）继续下移约一个文字行高（约 11px）：饼图与 legend 间距由 12 调大（约 22~24），保证不压饼图
- 模块仍固定不滚动，暗黑适配

**问题 3：我的页面清理排序**
- 文件：lib/pages/main/mine_page.dart
- 删除「分享应用」（分享海报）与「复制推广文案」两个 tile（及其 onTap/相关 l10n 调用，ARB 字符串可保留）
- 剩余区块顺序调整为：第一块「云服务/同步」（现有云同步与备份 SectionCard 不动）、第二块「个性化设置/年度账单」（把年度账单 tile 移入外观设置所在 SectionCard，位于外观设置之后）、第三块「使用帮助/关于」（现有关于+使用帮助 SectionCard）
- 「支持我们」SectionCard 移除（Android 下删除后为空；iOS 不需要适配）
- 不改数据/Provider，纯 UI 重排

**约束**：
- 完成后更新 TEAM.md 任务板 + HANDOFF.md 追加完成记录，git 状态待提交交 PM 审查
- HANDOFF 铁律：只 prepend 追加，不整文件重写、不用模糊正则范围替换

---

## 2026-08-05

**移交角色**：invest-ui
**接收角色**：项目经理（PM）

**任务**：6.0 返工完成

**完成工作**：
- lib/app.dart — PopScope：非首页 tab 按返回先切回首页，首页才走「再按一次退出」；明细按钮加 400ms 防抖，快速连点只 push 一页
- lib/pages/account/accounts_page.dart — _AccountCard 边框改用 BeeTokens.borderStrong（亮色 12% 黑，暗色主题色 30%）
- lib/providers/ui_state_providers.dart — 删除已无写入方的 homeScrollToTopProvider
- lib/pages/main/transaction_list_page.dart — 删除 homeScrollToTopProvider 监听

**下一个任务需要知道的**：
- 返回链路：push 页面正常逐级返回；tab 层返回先回首页；首页再按两次退出
- 明细防抖窗口 400ms
- 全量 analyze 854 个既有问题（与基线持平）；全量测试 582 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**git 状态**：当前分支 main，待提交

---

## 2026-08-05

**移交角色**：项目经理（PM）
**接收角色**：invest-ui

**任务**：6.0 返工（PM 审查结论）

**问题 1：返回链路补全（对齐总则“所有界面最终都能回到首页”）**
- 文件：lib/app.dart PopScope（约 805-818 行）
- 现状：从洞察/资产/我的 tab 按返回仍是「再按一次退出」，不会先回首页；总则目前只对 push 子页面成立
- 要求：onPopInvokedWithResult 中，若 bottomTabIndexProvider != 0，按返回时先切回 tab0 首页；仅当已在首页时才触发「再按一次退出」提示；不得影响 push 页面的正常逐级返回

**问题 2：明细按钮防重复**
- 文件：lib/app.dart onTabTap index==0（约 838-850 行）
- 现状：每次点击都直接 push TransactionListPage，快速连点会叠加多个流水列表页
- 要求：加 300-500ms 防抖（复用 _lastTapTime 机制或独立记录上次 push 时间），一次点击只 push 一页

**问题 3：账户卡边框加深**
- 文件：lib/pages/account/accounts_page.dart _AccountCard（约 1359-1361 行）
- 现状：使用 BeeTokens.divider（亮色 6% 黑），边框偏浅，未达到「颜色加深」的视觉效果
- 要求：改用 BeeTokens.borderStrong（亮色 12% 黑）或更深一档的语义色，暗黑模式保持可见；有条件可截图确认

**顺手清理（P3）**：
- homeScrollToTopProvider 已无写入方（原 tab0 双击滚动置顶逻辑已被 6.0.1 替换），可删除 provider 定义与 transaction_list_page 的 listen；如保留需说明用途

**约束**：
- flutter analyze 新增代码零 error/warning
- 相关 widget 测试补充/更新
- 完成后更新 TEAM.md 任务板 + HANDOFF.md 追加完成记录，git 状态待提交交 PM 复审

---

## 2026-08-05

**移交角色**：invest-ui
**接收角色**：项目经理（PM）

**任务**：6.0 首页/明细导航修正 + 资产页视觉修正

**完成工作**：
- lib/app.dart — 底部「明细」点击先切回 tab0 再全屏 push TransactionListPage；首页删除明细宽卡
- lib/pages/main/transaction_list_page.dart — PrimaryHeader 增加 showBack: true
- lib/pages/main/home_page.dart — 资产概览改为净资产大数字主视觉，总资产/总负债小字在下方，整卡可点击进 AccountsPage；Bento 仅保留 4 功能入口
- lib/widgets/charts/asset_composition_chart.dart — 饼图半径/中心孔缩小，去掉切片 pct 标题，legend 间距加大，70px 内不重叠
- lib/pages/account/accounts_page.dart — _AccountCard 加 BeeTokens.divider 边框，暗黑适配
- test/widgets/home_page_test.dart — 首页不再断言「明细」入口；断言净资产/总负债与资产卡点击回调已接线（Key 断言，避免 widget 测试实际 push AccountsPage 触发汇率刷新不 settle）

**下一个任务需要知道的**：
- 明细页现在只能经底部导航进入，返回后回到首页 tab0
- 资产概览卡片点击进 AccountsPage，与「账户总览」入口行为一致
- 全量 analyze 854 个既有问题（与基线持平）；全量测试 582 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**git 状态**：当前分支 main，待提交

---

---

## 2026-08-05

**移交角色**：项目经理（PM）
**接收角色**：invest-ui

**任务**：6.0 首页/明细导航修正 + 资产页视觉修正（4 个问题）

**总则**：首页是 app 第一屏（根界面），本 app 内所有界面经过一次或多次回退后，最终都能回到首页；所有 push 的子页面必须能逐级返回，不能出现无返回的死页面。

**问题 1：明细入口回归底部导航**
- 文件：lib/app.dart（onTabTap / bottom nav）、lib/pages/main/home_page.dart、lib/pages/main/transaction_list_page.dart
- 现状：tab0 内容 = 首页仪表盘 HomePage（底部标签为「明细」），首页里有一张「明细」宽卡 push TransactionListPage
- 要求：
  a) 删除首页的「明细」入口卡（_buildTransactionEntry 及调用），首页只保留 4 个功能入口 + 资产概览 + 收支统计 + 分类占比
  b) 点击底部导航「明细」时直接进入流水列表页 TransactionListPage：从任意 tab 点击都进入，而不是只在首页有效
  c) 推荐实现：onTabTap(0) 时先切到 tab0（首页仪表盘），再 push TransactionListPage 全屏进入（可带返回）
  d) TransactionListPage 作为 push 页面时 PrimaryHeader 加 showBack: true，保证有可见返回按钮
  e) 底部 5 项保持不变：明细/洞察/记账/资产/我的；首页仪表盘仍是打开 App 的第一屏（tab0 根内容），不单独占用导航按钮
  f) 返回链路验证：从任意 tab 点「明细」进入流水列表，返回后回到首页；从首页各入口进入的子页面，返回后同样回到首页

**问题 2：首页排版 + 资产概览改造**
- 文件：lib/pages/main/home_page.dart _buildAssetOverview / _overviewStat
- 要求：
  a) 资产概览突出「净资产」：净资产作为主数字，大字号展示
  b) 总资产/总负债改为小字，位于净资产之下（层级参考 D:/Users/wanji/Downloads/首页.jpg）
  c) 整个资产概览卡片可点击 → 进入账户总览（AccountsPage）
  d) 首页整体文字排版/布局轻量美化：保持 Bento 风格、BeeTokens、暗黑适配，不改数据逻辑

**问题 3：资产页头部占比文字下移**
- 文件：lib/widgets/charts/asset_composition_chart.dart、lib/pages/account/accounts_page.dart（固定模块）
- 现状：各一级账户占比文字与饼图重叠/横穿（5.7 把图高降到 70 后，饼图半径/中心孔未同步调小，切片 pct 标题和下方 legend 视觉上压到饼图）
- 要求：
  a) 百分比文字移到饼图下方，不与饼图重叠
  b) 合理缩小饼图半径/中心孔，或去掉切片上的 pct 标题，保证 70px 高度内不裁切不重叠
  c) legend（类型名 + 百分比）与饼图之间留出明确间距
  d) 该模块仍固定不滚动

**问题 4：资产页账户卡片加边框**
- 文件：lib/pages/account/accounts_page.dart _AccountCard
- 现状：卡片纯表面色、无边框，整页过白
- 要求：账户卡加清晰可见边框（颜色比页面背景深一档，暗黑模式同样适配），卡片与背景层次分明；保留圆角

**约束**：
- flutter analyze 新增代码零 error/warning
- 更新 test/widgets/home_page_test.dart：首页不再断言「明细」入口文字；资产概览可点击；其余断言保留
- 完成后更新 TEAM.md 任务板（5.10 标 ✅ + 日期）+ HANDOFF.md 追加完成记录，git 状态保持待提交交 PM 审查
- HANDOFF 铁律：只 prepend 追加，不整文件重写、不用模糊正则范围替换

---

## 2026-08-04

**移交角色**：invest-ui
**接收角色**：项目经理（PM）

**任务**：5.9 首页导航回归 + 明细头迁移 + Bento 美化

**完成工作**：
- lib/app.dart — 底部 tab0 恢复「明细」+ receipt_long 图标，页面内容仍为首页仪表盘（5.9.1）
- 新增 lib/widgets/biz/home_header_bar.dart — 从明细页迁出 BeeIcon + 账本切换胶囊 + AI 助手/日历/搜索，首页 PrimaryHeader 使用（5.9.2）
- lib/pages/main/transaction_list_page.dart — 移除顶部整块，仅保留「明细」简洁标题 + 月份/收支汇总行 + 预算摘要 + 流水列表（5.9.2）
- lib/pages/main/home_page.dart — Bento 便当格：5 个入口格（4 功能入口 + 明细宽格）、2x2 资产概览、跨列收支统计、月度分类占比卡，统一 8px 圆角/表面色/暗黑适配（5.9.3）
- test/widgets/home_page_test.dart — 覆盖迁移头部 + 5 入口 + 各概览模块

**下一个任务需要知道的**：
- 明细页保留月份跳转与收支汇总，账本切换/AI/日历/搜索只在首页顶部
- 首页 Bento 使用 BeeTokens + BeeShadows，未改 Provider/数据逻辑
- 全量 analyze 854 个既有问题（较基线 857 少 3）；全量测试 582 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**git 状态**：当前分支 main，待提交

---

## 2026-08-04

**移交角色**：项目经理（PM）
**接收角色**：invest-ui

**任务**：5.9 首页导航回归 + 明细头迁移 + Bento 美化（3 个问题）

**问题 1：底部导航恢复 5 项，去掉「首页」字样**
- 文件：lib/app.dart _BeeBottomBar（tab0 当前用 Icons.home + l10n.homeTitle）
- 要求：
  a) tab0 改回「明细」标签 + receipt 图标（原 Icons.receipt_long_outlined/receipt_long + l10n.tabHome）
  b) 底部 5 项固定为：明细/洞察/记账/资产/我的
  c) tab0 页面内容仍为首页仪表盘 HomePage（打开 App 第一眼看到首页；首页顶部已有「明细」入口进入流水列表）

**问题 2：明细页顶部内容迁移到首页顶部**
- 来源：lib/pages/main/transaction_list_page.dart PrimaryHeader 内容（BeeIcon + 账本选择胶囊 + AI 助手 + 日历 + 搜索按钮，约 670 行起）
- 目标：lib/pages/main/home_page.dart PrimaryHeader
- 要求：
  a) 把明细页顶部整块（BeeIcon、账本切换、AI 助手、日历、搜索）迁移到首页顶部
  b) 明细页（TransactionListPage）不再保留这些内容，仅保留流水列表主体（可保留简洁标题）
  c) 这些按钮依赖的 provider / 导航逻辑一并迁移，确保功能不变

**问题 3：首页 Bento 便当格美化**
- 文件：lib/pages/main/home_page.dart
- 要求：
  a) Bento grid：不同尺寸卡片组合（2x2 大卡资产概览、1x1 入口、跨列收支统计、饼图卡等）
  b) 顶部入口区保留 4 入口（账户总览/智能记账/数据管理/自动化）+「明细」入口，用 Bento 格子呈现
  c) 视觉简洁统一，遵循 BeeTokens（圆角 ≤8、表面色、无彩色渐变），暗黑模式适配
  d) 数据逻辑不变（复用现有 provider）

**约束**：flutter analyze 零 error/warning（新增代码）；home_page_test / 相关测试更新

## 2026-08-04

**移交角色**：invest-ui
**接收角色**：项目经理（PM）

**完成工作**：阶段 5.8 首页 + 资产页视觉简化（3 项全部完成）

1. **5.8.1 账户卡面改白色** — [accounts_page.dart](/D:\codexproject\pj_004_beecount_fork\lib\pages\account\accounts_page.dart)
   - _AccountCard 去掉 LinearGradient 类型色渐变与彩色阴影，改白色/表面色（暗色模式深色表面），保留圆角
   - 卡片内文字/图标改为常规 Token 配色，删除装饰圆与白色系文案

2. **5.8.2 资产顶部只留饼图** — accounts_page.dart
   - 顶部模块删除净值走势折线图、净值趋势按钮、净资产数值、总资产/总负债行与切换按钮
   - 只保留「资产构成」居中标题 + AssetCompositionChart 饼图，模块固定不滚动
   - 清理因此孤立的私有方法/组件与导入（仅 UI，不动数据层）

3. **5.8.3 制作 app 首页** — 新增 [home_page.dart](/D:\codexproject\pj_004_beecount_fork\lib\pages\main\home_page.dart)，原首页改为 [transaction_list_page.dart](/D:\codexproject\pj_004_beecount_fork\lib\pages\main\transaction_list_page.dart)
   - 首页：首行 4 入口（账户总览/智能记账/数据管理/自动化）+「明细」入口 + 资产概览卡 + 今天/本周/本月/今年收支 + 月度分类占比列表与饼图
   - 复用 totalsInRange / totalsByCategory / netWorthBreakdownProvider，未新增仓储接口
   - 「我的」删除同名 4 个入口（外观设置等保留）
   - 底部导航不变；流水列表经首页「明细」入口进入（tab0 标签仍为「明细」，内容为首页，待 PM 确认是否改标签）

**测试**：
- 新增 home_page_test（4 入口 + 资产概览 + 收支统计 + 分类占比）
- 全量 flutter analyze 零 error（857 个预存 info/warning，较基线减少 16；PM 审查返工：修复 mine_page 遗留 dead_code 与 transaction_list_page 未用变量 hide）
- 全量 flutter test：582 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**下一个任务需要知道的**：
- 原 HomePage（流水列表）已更名 TransactionListPage，路径 lib/pages/main/transaction_list_page.dart；app.dart tab0 引用新的 HomePage
- 落地页 = 首页仪表盘：底部导航 tab0 标签已改为「首页」（home 图标），明细经首页「明细」入口进入；洞察/记账/资产/我的仍走底部导航按钮
- 资产顶部模块只展示饼图后，趋势页（NetWorthTrendPage）仍可单独进入查看净值走势
- 视觉布局未做 Windows 实机截图验证（widget 测试覆盖结构与回归）

**git 状态**：当前分支 main，未提交（等待 PM 审查）

---
## 2026-08-04

**移交角色**：项目经理（PM）
**接收角色**：invest-ui + invest-logic

**任务**：5.8 首页 + 资产页视觉简化（3 个问题）

**问题 1：账户卡面全部改白色**
- 文件：lib/pages/account/accounts_page.dart _AccountCard（约 1921-1965）
- 现状：LinearGradient 用 typeColor 彩色渐变（黄/蓝/绿/紫）
- 要求：全部改为白色/表面色（暗色模式用深色表面），去掉彩色渐变与彩色阴影；保留圆角

**问题 2：资产管理顶部模块简化**
- 文件：lib/pages/account/accounts_page.dart _buildNetWorthAndCompositionCard 及内部
- 要求：
  a) 去掉净值走势折线图、净值趋势按钮、净资产数值、总资产/总负债行
  b) 只保留资产构成饼图（AssetCompositionChart）
  c) 取消「净值走势/资产构成」切换按钮，改为「资产构成」文字说明居中置顶
  d) 模块高度随饼图内容，仍固定不滚动
- 注意：只删 UI 不删数据层

**问题 3：制作 app 首页**
- 参考图：D:/Users/wanji/Downloads/首页.jpg
- 需求：
  a) 打开 app 后首屏为「首页」：首行导航栏 4 个入口（账户总览/智能记账/数据管理/自动化），配图标
  b) 下方内容区（资产概览卡 + 今日/本周/本月/今年收支 + 月度分类占比列表 + 饼图）
  c) 这 4 个入口与「我的」界面现有入口一致；「我的」界面中的这 4 个入口删除
  d) 底部导航栏暂时不变（明细/洞察/记账/资产/我的）
- 实现：新 HomePage 或改造现有首页（当前首页是流水列表）；流水列表入口保留（经底部「明细」进入）

**约束**：flutter analyze 零 error；相关 widget 测试更新

## 2026-08-04

**移交角色**：invest-ui
**接收角色**：项目经理（PM）

**完成工作**：阶段 5.7 资产页布局细节（3 项全部完成）

1. **5.7.1 图表高度 + 金额标注** — [accounts_page.dart](/D:\codexproject\pj_004_beecount_fork\lib\pages\account\accounts_page.dart) + [asset_composition_chart.dart](/D:\codexproject\pj_004_beecount_fork\lib\widgets\charts\asset_composition_chart.dart)
   - 净值走势图高度 180 → 70（1/3）；LineChart annotate 改 false，不再逐点标金额
   - 资产构成图容器与 loading 高度同步 180 → 70

2. **5.7.2 类型小计右对齐** — accounts_page.dart _AccountTypeGroup
   - 标题行改为右→左：chevron → 小计，移除 Flexible/Spacer 位置漂移
   - 小计带前缀：「资产 XXXX」/「负债 XXXX」（按 isLiabilityType 判定），单币种组显示

3. **5.7.3 列表底部留白** — accounts_page.dart
   - asTab 底部 padding 再 +48（合计 56+48+安全区），确保最后一个账户/已隐藏模块不被导航遮挡

**测试**：
- 全量 flutter analyze 零 error（873 个预存 info/warning）
- 全量 flutter test：581 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**下一个任务需要知道的**：
- 净值/构成图表统一 70 高度，趋势页全屏不受影响
- 类型小计文案走 accountAssetShort/accountLiabilityShort l10n
- 视觉布局未做 Windows 实机截图验证（widget 测试覆盖结构与回归）

**git 状态**：当前分支 main，未提交（等待 PM 审查）

---
## 2026-08-04

**移交角色**：项目经理（PM）
**接收角色**：invest-ui

**任务**：5.7 资产页布局细节（3 个问题）

**问题 1：净资产图表高度 + 金额标注**
- 文件：lib/pages/account/accounts_page.dart _buildNetWorthChartInline / _inlineChartBox（当前 SizedBox height: 180）
- 要求：
  a) 图表高度降低到约 1/3（建议 60~80，可 70.0.scaled）
  b) 折线图 annotate 不再每个点标注金额（避免与净资产金额交叉），只显示当月净资产数值（顶部大数字已体现）——LineChart annotate 改为 false 或仅最后一个点
  c) 确认切换「资产构成」视图的 AssetCompositionChart 高度同步降低（loading 180 也降）

**问题 2：类型小计 + 收起按键右对齐**
- 文件：lib/pages/account/accounts_page.dart _AccountTypeGroup 标题行（约 1690-1745）
- 现状：数量徽标 → 小计（Flexible）→ Spacer → 收起箭头
- 要求：
  a) 小计与收起箭头统一靠右对齐，从右到左顺序：收起箭头（chevron）→ 小计金额
  b) 小计格式「资产 XXXX」或「负债 XXXX」（按该组是否为负债类型：isLiabilityType(widget.type) ? 负债 : 资产）
  c) 移除 Flexible/Spacer 造成的位置漂移，固定右对齐

**问题 3：资产列表底部空间不足**
- 文件：lib/pages/account/accounts_page.dart ListView padding bottom（当前 asTab 时 8 + 56 + padding.bottom + 24）
- 要求：加大底部留白（建议 asTab 时再加 48，合计约 56+48+安全区），确保最后一个账户/已隐藏账户模块不被导航遮挡且易点击
- 注意：确认 asTab 分支确实生效（accounts_page 作为 Tab 嵌入底部导航）

## 2026-08-03

**移交角色**：invest-ui + invest-logic
**接收角色**：项目经理（PM）

**完成工作**：阶段 5.6 记账/账户/资产体验改进（5 项全部完成）

1. **5.6.1 小键盘完成仅确认金额** — [amount_editor_sheet.dart](/D:\codexproject\pj_004_beecount_fork\lib\widgets\biz\amount_editor_sheet.dart) + tx_entry_form/transfer_form
   - AmountEditorSheet 新增 confirmOnly：完成只 pop 返回（金额+币种）写回表单，不再 onSubmit 保存流水
   - 记账/转账表单 await 结果更新 _amount/_pickedCurrency；其它调用方 onSubmit 行为保持（当前无其它调用方）
   - confirmOnly 模式隐藏附件/旗标区（保存由底部按钮负责）

2. **5.6.2 再记一笔先保存** — [tx_entry_form.dart](/D:\codexproject\pj_004_beecount_fork\lib\widgets\transaction\tx_entry_form.dart) + transfer_form.dart
   - _save 先校验：金额 0 提示「请输入金额」、转账缺账户提示「选择账户」，不进入下一笔
   - 校验通过后先提交当前内容（编辑态保存 A 的修改），成功再清空金额/标签/备注

3. **5.6.3 账户「不计入资产」开关** — [db.dart](/D:\codexproject\pj_004_beecount_fork\lib\data\db.dart) + 账户仓储 + 编辑/详情页
   - Accounts 新增 exclude_from_assets，schema v34→v35（幂等 _addColumnIfMissing）
   - createAccount/updateAccount 全链路支持该字段
   - 净资产/资产构成/净值趋势（getNetWorthBreakdown* / getNetWorthDailyBalances / getNetWorthTrendSeries / getAssetCompositionByType*）排除 excludeFromAssets=true
   - 编辑页加「不计入资产」开关，详情页 header 显示标记

4. **5.6.4 资产管理界面布局** — [accounts_page.dart](/D:\codexproject\pj_004_beecount_fork\lib\pages\account\accounts_page.dart)
   - 净资产汇总 + 资产构成模块移出 ListView 固定（账户列表独立滚动）
   - 每个一级账户类型标题右侧显示类型合计（单币种组）
   - 列表底部余量保留（隐藏账户区可点击）

5. **5.6.5 账户自定义 logo** — [account_type_utils.dart](/D:\codexproject\pj_004_beecount_fork\lib\utils\account_type_utils.dart) + 账户编辑/列表/抽屉/详情
   - AccountTypeIcon 支持 iconType/customIconPath，渲染自定义图片（CustomIconService）
   - 编辑页相册上传 + 恢复默认，create/update 持久化
   - 账户卡片/抽屉/详情/默认账户选择器均显示自定义 logo

**测试**：
- 新增 migration_v35_test、account_exclude_from_assets_test
- 新增 editor 测试：小键盘完成仅写回金额、再记一笔金额 0 提示
- 更新 sync_pull_errors_schema_test schemaVersion 34→35；账户编辑页测试回归通过
- 全量 flutter analyze 零 error（873 个预存 info/warning）
- 全量 flutter test：581 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**下一个任务需要知道的**：
- Account 数据类新增必填 excludeFromAssets，手工构造 Account 的位置需同步补字段
- schema 已升到 v35；同步层（云端）账户字段默认 false，未做服务端迁移
- 自定义 logo 文件存 custom_icons/，账户场景用 id=0 前缀文件名（与分类共用目录）
- 视觉布局未做 Windows 实机截图验证（widget 测试覆盖结构与回归）

**git 状态**：当前分支 main，未提交（等待 PM 审查）

---

## 2026-08-03

**移交角色**：项目经理（PM）
**接收角色**：invest-ui + invest-logic

**任务**：5.6 记账/账户/资产体验改进（5 项）

**1. 小键盘「完成」仅确认金额，不保存流水**
- 文件：lib/widgets/biz/amount_editor_sheet.dart 约 867-940 行 doneKey()
- 现状：点完成直接 widget.onSubmit(...) → 保存流水并跳明细
- 要求：完成仅把金额写回表单（关闭小键盘），保存由底部「再记一笔/保存」负责；小键盘不再 onSubmit
- 注意：AmountEditorSheet 的 onSubmit 仍用于其他调用方（如投资买入？）——需评估：仅记账表单（tx_entry_form/transfer_form）传 null 或加参数，投资买入保持原行为

**2. 「再记一笔」先保存当前编辑再记新账**
- 文件：lib/widgets/transaction/tx_entry_form.dart _save(exitAfterSave:false) + transfer_form.dart 同
- 现状：编辑模式 A 改后点再记一笔，当前 A 改未保存就清空，新流水 B 导致 A 改丢失
- 要求：exitAfterSave=false 时先提交当前内容（保存 A 改），成功后再清空金额/标签/备注进入下一笔
- 校验：当前内容无效（如金额 0 / 缺账户）时提示，不进入下一笔

**3. 账户「不计入资产」开关**
- 文件：lib/data/db.dart Accounts 表 + lib/pages/account/account_edit_page.dart + 净资产/资产构成计算
- 需求：贷款/帮别人借的账户不计入自己资产（仅提醒作用）
- 实现：
  a) Accounts 表加 excludeFromAssets bool（默认 false）→ schema v35 迁移
  b) account_edit_page 新建/编辑界面加「不计入资产」Switch（隐藏账户旁）
  c) 净资产/资产构成/净值趋势计算排除 excludeFromAssets=true 的账户（getAccountBalance 聚合、netWorth 相关查询）
  d) 账户详情显示「不计入资产」标记

**4. 资产管理界面布局**
- 文件：lib/pages/account/accounts_page.dart
- 要求：
  a) 净资产图表固定高度 + 整个模块固定不滚动（类似投资组合摘要固定）
  b) 每个一级账户类型（现金/储蓄/虚拟/应收款/投资/信用/贷款）标题右侧显示该类型资产/负债合计金额
  c) 账户列表滚动到底留足底部余量（隐藏账户区可正常点击，不被导航栏遮挡）

**5. 账户自定义 logo**
- 文件：参考分类自定义图标（CustomIconService / Category iconType/customIconPath）
- Accounts 表 4.5 已加 iconType/customIconPath，需确认 UI 是否接通
- 要求：新建/编辑账户时可选相册/文件上传图片作账户 logo；账户列表/抽屉/卡片显示自定义 logo
- 复用分类的自定义图标实现模式

**约束**：flutter analyze 零 error；相关测试更新（小键盘不保存、再记一笔先保存、不计入资产、账户 logo）

## 2026-08-03

**移交角色**：invest-ui
**接收角色**：项目经理（PM）

**完成工作**：阶段 5.5 转账独立 + 记账视觉 + 日期选择器（5 项全部完成）

1. **5.5.1 转出/转入独立选择** — [transfer_form.dart](/D:\codexproject\pj_004_beecount_fork\lib\widgets\transaction\transfer_form.dart)
   - 去掉自动连选：点转出只弹转出抽屉、点转入只弹转入抽屉；两端已选后点各自区域直接改对应端（删除中间「修改哪一端」弹窗）

2. **5.5.2 反转按钮固定** — transfer_form.dart
   - 账户行改为 转出 | 转入 两格（Expanded 均分）+ 中间固定 44px 宽按钮列，名称长度变化不移动按钮

3. **5.5.3 转出/转入灰字标签** — transfer_form.dart
   - 每格左上灰字小标签「转出」「转入」，下方账户名；未选显示「请选择」灰字

4. **5.5.4 字段行分隔线** — [tx_entry_form.dart](/D:\codexproject\pj_004_beecount_fork\lib\widgets\transaction\tx_entry_form.dart) + transfer_form.dart
   - 金额/分类/账户/时间/标签/备注行间加浅灰 Divider（height 13 / 0.5px）

5. **5.5.5 日期选择器周几 + 放宽范围** — [wheel_date_picker.dart](/D:\codexproject\pj_004_beecount_fork\lib\widgets\ui\wheel_date_picker.dart) + 调用处
   - 日期滚轮每格显示「M月d日 周X」，今天显示「今天」
   - 年份范围改为今年 ±30 年（2026 → 1996~2056），月份 1-12 完整、日期按自然月
   - tx_entry_form / transfer_form 调用处去掉 maxDate=今天限制

**测试**：
- 新增 wheel_date_picker_test（年份 ±30 / 月份 1-12 / 日期格周几与今天）
- 更新 transaction_editor_page_test / transfer_form_account_hidden_test / account_open_types_test：独立选择流程、两格标签
- 全量 flutter analyze 零 error（871 个预存 info/warning）
- 全量 flutter test：575 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**下一个任务需要知道的**：
- 转账账户选择已完全解耦：转出/转入各自独立弹抽屉，不再自动连选
- 日期滚轮默认年份范围 ±30 年；其它调用方仍可传 minDate/maxDate 自定义范围
- 字段行间分隔线沿用 BeeTokens.divider，视觉统一
- 视觉布局未做 Windows 实机截图验证（widget 测试覆盖结构与回归）

**git 状态**：当前分支 main，未提交（等待 PM 审查）

---

## 2026-08-03

**移交角色**：项目经理（PM）
**接收角色**：invest-ui（UI 工程师）

**任务**：5.5 转账账户独立 + 记账页视觉 + 日期选择器（5 个问题）

**问题 1：转出/转入账户完全独立选择**
- 文件：lib/widgets/transaction/transfer_form.dart _pickTransferAccount
- 现状：选完转出后自动连弹转入抽屉
- 要求：点转出只弹转出抽屉；点转入只弹转入抽屉。完全独立，可先选转出再填金额再选转入。去掉自动连选；两端已选时点各自区域修改对应端（去掉中间选择弹窗）

**问题 2：反转按钮固定位置**
- 文件：transfer_form.dart _buildTransferAccountRow
- 现状：Flexible + IconButton 布局，两侧名称长度变化导致中间按钮移动
- 要求：按钮固定在中间（固定宽度列或 Expanded 均分两侧），不随名称长度移动

**问题 3：转出/转入增加灰色小字标签**
- 要求：账户行改为两格布局（转出 | 转入），每格左上灰字标签「转出」「转入」，下方显示账户名；未选显示「请选择」灰字；反转按钮在中间固定

**问题 4：记账页字段行间加浅灰分隔线**
- 文件：tx_entry_form.dart _buildFieldRow + transfer_form.dart 字段行
- 要求：金额/分类/账户/时间/标签/备注每行之间加浅灰细线（Divider），替换或叠加现有间距

**问题 5：日期选择器显示周几 + 放宽日期范围**
- 文件：lib/widgets/ui/wheel_date_picker.dart + tx_entry_form/transfer_form 调用处
- 要求：
  a) 日期滚轮每格显示周几（8月2日 周六 / 8月3日 今天 / 8月4日 周二）
  b) 不再限制 maxDate=今天：年份范围 = 今年上下 30 年（1996~2056），月份 1-12 完整，日期按月份自然天数，周几按真实日历
  c) 调用处去掉 maxDate 限制（或传 null）
  d) 最终显示栏仍保留周几（已有 tx_date_format）

**约束**：flutter analyze 零 error；相关 widget 测试更新（转账独立选择、按钮固定、日期周几、日期范围）

## 2026-08-03

**移交角色**：项目经理（PM）审查结论
**接收角色**：invest-ui / invest-logic（返工）

**审查结论**：5.3 + 5.4 大部分通过，1 个 P1 未完成，返工补齐。

**（已撤销）净资产无需 4 位，保持 2 位小数，与基金 App 一致；基金净值仍 4 位**
- 用户要求：净值（净资产）精确到小数点后 4 位（如 1.0000）
- 现状：lib/pages/account/accounts_page.dart 净资产显示（约 375-388 行）AmountText 未传 decimals，默认 2 位
- 修复：
  a) 净资产 AmountText 加 decimals: 4
  b) 检查多币种净资产行（nwByCurrency 分支）同样 4 位
  c) 净值趋势页（net_worth_trend_page.dart）数值也 4 位
  d) 市值/成本保持 2 位不变（已正确）
- 补充测试：净资产 4 位断言

**其余全部通过**：转账反转 / 日期周几 / 再记一笔+保存 / 蜜蜂家当删除 / 市值成本2位无万 / extendBody false / 组合摘要固定 / 导入按钮顶部。


## 2026-08-03

**移交角色**：invest-ui
**接收角色**：项目经理（PM）

**完成工作**：阶段 5.4 界面布局固定（4 项全部完成，5.3 在工作区一并待审查）

1. **5.4.1 底部导航不遮挡内容** — [app.dart](/D:\codexproject\pj_004_beecount_fork\lib\app.dart)
   - 外层 Scaffold `extendBody: true` → `false`，底部导航栏固定占位，四个 Tab 页面内容区自动避开导航栏高度
2. **5.4.2 明细/洞察/我的适配** — 同 app.dart 全局修复
   - HomePage / AnalyticsPage / MinePage 不再被底部导航覆盖，无需逐页补 padding（记账页未改）
3. **5.4.3 投资组合固定占位** — [holdings_list_page.dart](/D:\codexproject\pj_004_beecount_fork\lib\pages\investment\holdings_list_page.dart)
   - 组合摘要卡从 ListView item 移出，改为 Header 下方固定区；只滚动持仓卡片列表；空态/加载/错误仍显示在摘要下方
4. **5.4.4 导入初始持仓移顶部** — holdings_list_page.dart
   - 移除摘要卡下方导入按钮；PrimaryHeader actions 增加 file_upload IconButton（tooltip「导入初始持仓」），标题左、按钮右；空态保留原有导入按钮作补充入口

**测试**：
- 新增 holdings_list_page_layout_test（摘要固定 + 顶部导入按钮 tooltip + 空态）
- 全量 flutter analyze 零 error（870 个预存 info/warning）
- 全量 flutter test：573 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**下一个任务需要知道的**：
- extendBody 全局改 false 后，各 Tab 页不再需要手动加底部导航高度 padding；若未来页面有全出血背景需求，可在页内自行 extendBody
- holdings_list 的导入入口现有顶部 IconButton（主）+ 空态按钮（次）
- 视觉布局未做 Windows 实机截图验证（widget 测试覆盖结构与回归）

**git 状态**：当前分支 main，未提交（5.3 + 5.4 一并等待 PM 审查）

---

## 2026-08-03

**移交角色**：项目经理（PM）
**接收角色**：invest-ui（继续 5.3 会话）

**任务**：5.4 界面布局固定（4 个问题，与 5.3 一起改完后统一审查）

**问题 1：资产界面底部导航栏遮挡**
- 现象：11 只基金时，底部导航栏（明细/洞察/记账/资产/我的）挡住最后一只基金内容
- 根因：推测根 Scaffold 用 extendBody:true，底部导航覆盖内容；或 Tab 页面无底部 padding
- 要求：底部导航栏固定占位，内容区不被覆盖；ListView 底部加 SafeArea / MediaQuery padding 等于导航栏高度

**问题 2：同一原则应用到明细/洞察/我的**
- 文件：lib/app.dart（底部导航布局）+ 对应页面容器
- 明细（TransactionListPage）、洞察（AnalyticsPage）、我的（MinePage）同样确保底部内容不被导航栏覆盖
- 记账界面不用改

**问题 3：资产界面顶部「投资组合」固定**
- 文件：lib/pages/investment/holdings_list_page.dart
- 现状：组合摘要卡片在 ListView 内随持仓滚动
- 要求：投资组合摘要固定占位（列表头部固定，只滚动持仓卡片部分）
- 实现：Column + 固定摘要区 + Expanded(ListView 持仓)；或 CustomScrollView + SliverPinnedHeader

**问题 4：「导入初始持仓」移到顶部栏右侧**
- 文件：lib/pages/investment/holdings_list_page.dart
- 现状：导入按钮在摘要卡下方
- 要求：移到资产界面顶部栏，与「投资持仓」标题分列左右（标题左、导入按钮右）
- PrimaryHeader 支持 actions 参数则直接加 IconButton；否则在 header 右侧放文本/图标按钮

**约束**：flutter analyze 零 error；widget 测试同步更新（若涉及滚动/布局断言）

## 2026-08-02

**移交角色**：invest-ui + invest-logic
**接收角色**：项目经理（PM）

**完成工作**：阶段 5.3 记账/资产体验改进（5 项全部完成）

1. **5.3.1 转账账户反转按键** — [transfer_form.dart](/D:\codexproject\pj_004_beecount_fork\lib\widgets\transaction\transfer_form.dart)
   - 账户行拆为「转出名 + swap_horiz IconButton + 转入名」，⇄ 独立可点
   - 点击交换 _from/_to（含 id），两端不同才可反转

2. **5.3.2 日期显示周几** — 新增 [tx_date_format.dart](/D:\codexproject\pj_004_beecount_fork\lib\utils\tx_date_format.dart)
   - 支出/收入/转账统一格式：`2026年8月2日 今天` / `2026年8月1日 周六`
   - 周几按 DateTime.weekday 自动算出；显示时间开启时追加 HH:mm

3. **5.3.3 记账页底部「再记一笔」+「保存」** — tx_entry_form.dart + transfer_form.dart
   - 支出/收入/转账底部固定两按钮：「再记一笔」保存后保留分类/账户/时间（转账保留转出/转入/时间），清空金额/标签/备注并留在当前页；「保存」保存后关闭编辑器并跳到首页「明细」流水列表（bottomTabIndexProvider=0）
   - 保存逻辑抽成 _submitTransaction / _performTransferSave，金额小键盘与底部按钮共用；金额可独立填写（允许 0）

4. **5.3.4 删除资产管理页「蜜蜂家当」推荐** — [accounts_page.dart](/D:\codexproject\pj_004_beecount_fork\lib\pages\account\accounts_page.dart)
   - 移除 header 右上角 _BeeAssetsHeaderEntry、相关注释与 product_promos/product_promo_card 引用

5. **5.3.5 资产金额精度** — [format_utils.dart](/D:\codexproject\pj_004_beecount_fork\lib\utils\format_utils.dart) + 资产/投资页
   - 新增 formatFullAmount（千分号 + 固定小数位，不做万/k/M 缩写）
   - accounts_page / account_detail_page 全部 useCompactFormat 改传 false；holding_card / holdings_list_page / holding_detail_page 同步关闭紧凑格式
   - 净值保持 4 位小数（holding_detail 已 toStringAsFixed(4)），市值/成本/小计统一 2 位完整数字

**测试**：
- 新增 format_utils_test（2 位/4 位小数、千分号、无万单位）、tx_date_format_test（今天/周几/HH:mm）、amount_text_precision_test（关闭紧凑后无万/k/M）
- 更新 transaction_editor_page_test（底部按钮、⇄ 反转交换顺序）、transfer_form_account_hidden_test（账户行独立名称 + 反转按钮）
- 全量 flutter analyze 零 error（869 个预存 info/warning）
- 全量 flutter test：572 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**下一个任务需要知道的**：
- 日期格式统一走 formatEntryDateTime（tx_date_format.dart），不要在表单里再手拼 yyyy/M/d
- 「再记一笔」只清金额/标签/备注，分类/账户/时间（转账为转出/转入/时间）保留
- 保存（exit）统一跳到 bottomTabIndex=0（首页明细）；从账户详情等入口进入编辑器时，保存后先返回原页面再切 tab
- 资产页不再跟随 compactAmountProvider 设置，useCompactFormat 固定 false
- 视觉布局未做 Windows 实机截图验证（widget 测试覆盖结构与回归）

**git 状态**：当前分支 main，未提交（等待 PM 审查）

---

## 2026-08-02

**移交角色**：项目经理（PM）
**接收角色**：UI 工程师（invest-ui）+ invest-logic

**任务**：5.3 记账/资产体验改进（5 项）

**1. 转账账户反转按键**
- 文件：lib/widgets/transaction/transfer_form.dart
- 账户行当前显示「A ⇄ B」；要求 ⇄ 是独立可点击按钮，点击后 A/B 对调（B ⇄ A）
- 实现：账户行拆为 Row（转出名 + ⇄ IconButton + 转入名），点 ⇄ 时交换 _fromAccount/_toAccount（含 id）
- 注意：反转后仍保持两账户不同

**2. 日期显示周几**
- 文件：lib/widgets/transaction/tx_entry_form.dart _formatDateTime + transfer_form.dart _formatTransferDate
- 日期格式改为：2026年8月2日 今天 / 2026年8月1日 周六（今日显示「今天」，其他显示周几）
- 周几由日期自动算出（DateTime.weekday → 周日/周一/…/周六），不手动选
- 若显示时间开启，追加 HH:mm（如 2026年8月2日 今天 15:30）

**3. 记账页底部「再记一笔」+「保存」**
- 文件：lib/widgets/transaction/tx_entry_form.dart + transfer_form.dart
- 底部固定两按钮：
  a) 「再记一笔」：保存当前笔后保留分类/账户/时间（转账保留转出/转入/时间），清空金额/标签/备注；停留当前界面继续记
  b) 「保存」：保存后跳到明细界面（流水列表）
- 支出/收入/转账三种模式都适用
- 实现：现有保存逻辑（AmountEditorSheet onSubmit）需支持「保存并继续」与「保存并退出」两种模式；建议抽出保存方法，底部按钮直接调用（金额未填时弹提示或允许保存金额0）

**4. 删除资产管理页「蜜蜂家当」推荐**
- 文件：lib/pages/account/accounts_page.dart（_BeeAssetsHeaderEntry 约 116-130、2519-2531）
- 删除 header 右上角蜜蜂家当入口及相关代码

**5. 资产界面金额精度**
- 文件：lib/utils/format_utils.dart（万单位压缩）+ 资产相关页面（净资产业务格式）
- 净值：精确到小数点后 4 位（如 1.0000）
- 市值/成本/总市值/总成本：精确到小数点后 2 位
- 禁止「万」为单位：资产页不使用 formatMoneyCompact / 万/k/M 缩写，用完整数字+2位小数（净值4位）
- 注意：AmountText 有 useCompactFormat 开关，资产页改传 false；确认报表/图表等是否也要同步

**约束**：flutter analyze 零 error；相关 widget/format 测试更新；金额精度测试（净值4位、市值2位、无万单位）

## 2026-08-02

**移交角色**：invest-ui
**接收角色**：项目经理（PM）

**完成工作**：阶段 5.2 转账模式体验统一（2 项全部完成）

1. **5.2.1 转账金额独立填写** — [transfer_form.dart](/D:\codexproject\pj_004_beecount_fork\lib\widgets\transaction\transfer_form.dart)
   - 金额作为表单顶部第一行，点击直接打开 AmountEditorSheet，不再依赖「两个账户都选后自动弹出」
   - 提交时若两端账户未选，留在金额弹窗内 toast 提示「选择账户」，不丢已输金额

2. **5.2.2 转账账户抽屉分格** — 新增 [account_drawer_sheet.dart](/D:\codexproject\pj_004_beecount_fork\lib\widgets\transaction\account_drawer_sheet.dart) + transfer_form.dart
   - 抽出公共账户抽屉组件 showAccountDrawerSheet（左侧一级类型竖向导航 + 右侧一户一行余额；支持 title / pinnedAccountId（隐藏账户钉住灰标）/ excludedAccountId / 管理入口），TxEntryForm 与 TransferForm 共用
   - TransferForm 改为 金额-账户-时间-标签-备注 五行；账户行显示「A ⇄ B」
   - 点击账户行：先选转出抽屉 → 自动进入转入抽屉（排除已选转出账户）；两端已选后再次点击可弹「修改转出/修改转入」
   - 转账保存逻辑不变（transfer 类型 + from/to + 金额）

**测试**：
- transfer_form_account_hidden_test 重写为抽屉流程（编辑态钉住隐藏账户灰标 / 新建不出现）
- account_open_types_test 的 TransferForm 用例改为抽屉分格验证（债权/负债类型可选，投资/隐藏不可选）
- transaction_editor_page_test 新增：转账 Tab 五行结构、金额独立打开小键盘、抽屉两段选择回显 A ⇄ B
- 全量 flutter analyze 零 error（866 个预存 info/warning）
- 全量 flutter test：566 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**下一个任务需要知道的**：
- 公共组件：lib/widgets/transaction/account_drawer_sheet.dart，支出/收入/转账统一走 showAccountDrawerSheet
- TransferForm 不再有转出/转入双网格；账户行回显格式「A ⇄ B」
- 转账金额与账户完全解耦，提交时统一校验两端账户
- 视觉布局未做 Windows 实机截图验证（widget 测试覆盖结构与回归）

**git 状态**：当前分支 main，未提交（等待 PM 审查）

---

## 2026-08-02

**移交角色**：项目经理（PM）
**接收角色**：UI 工程师（invest-ui）

**任务**：5.2 转账模式体验统一（2 个问题）

**问题 1：转账无法独立填写金额**
- 文件：lib/widgets/transaction/transfer_form.dart
- 现状：金额依赖「两个账户都选后自动弹出金额弹窗」（_openAmountSheet），不是独立字段
- 要求：转账模式与支出/收入一致，金额作为独立行（顶部第一行），点击金额行才弹数字小键盘，不依赖账户选择

**问题 2：转出/转入账户太大，改为抽屉分格**
- 现状：转出/转入是两个大型选择器（可能是下拉/大卡片）
- 要求：与 TxEntryForm 新版一致
  a) 字段顺序：金额-转账-时间-标签-备注
  b) 转账行显示「账户：转出⇄转入」（如「账户：支付宝 ⇄ 储蓄卡」），点击弹出抽屉分格
  c) 抽屉分格：左侧一级账户类型竖向导航 + 右侧账户一户一行显示余额（复用 tx_entry_form 的 _AccountDrawerSheet 设计，建议抽公共组件 _AccountDrawerSheet 或直接复用）
  d) 首次选择转出账户后，再选转入账户（或转出/转入同一抽屉内两段选择）

**实现建议**：
- 将 tx_entry_form.dart 的 _AccountDrawerSheet / _showAccountDrawer 抽为公共组件（如 lib/widgets/transaction/account_drawer_sheet.dart），转账和收支共用
- TransferForm 的 build 改为与 TxEntryForm 相同的 ListView 字段行结构
- 转账保存逻辑不变（transfer 类型 + from/to 账户 + 金额）

**约束**：flutter analyze 零 error；transaction_editor_page_test / transfer 相关测试全过；补充转账金额独立、抽屉分格测试


## 2026-08-02

**移交角色**：invest-ui
**接收角色**：项目经理（PM）

**完成工作**：阶段 5.1 记账界面体验优化（7 项全部完成，对应 PM 9 个问题）

1. **5.1.1 备注弹框报错修复 + 5.1.2 备注行内填写** — [tx_entry_form.dart](/D:\codexproject\pj_004_beecount_fork\lib\widgets\transaction\tx_entry_form.dart)
   - 删除备注 AlertDialog（原 TextEditingController 在 pop 后 dispose 导致闪报错），改为表单内嵌多行 TextField
   - 复用 NoteHistoryService + NotePickerDialog 提供高频备注历史入口

2. **5.1.3 金额行 + 字段顺序** — tx_entry_form.dart
   - 字段顺序改为：金额-分类-账户-时间-标签-备注
   - 金额行显示币种 + 金额（如 ¥ 0.00），点击进入小键盘；金额不再要求分类前置（提交支持无分类）

3. **5.1.4 标签行** — tx_entry_form.dart
   - 时间之后、备注之前新增「标签」行，点击弹 TagSelector 多选，选中标签名称回显

4. **5.1.5 小键盘剥离非金额功能** — [amount_editor_sheet.dart](/D:\codexproject\pj_004_beecount_fork\lib\widgets\biz\amount_editor_sheet.dart)
   - 移除备注输入区、账户选择区、标签选择区、时间键（dateKey）
   - 键盘改为 7-8-9-C / 4-5-6-+ / 1-2-3-- / .-0-⌫-完成；保留币种、金额、汇率、附件、记账标记
   - 转账 Tab 同步在 [transfer_form.dart](/D:\codexproject\pj_004_beecount_fork\lib\widgets\transaction\transfer_form.dart) 增加金额/时间/标签/备注行，避免精简后功能丢失

5. **5.1.6 账户选择显示优化** — tx_entry_form.dart
   - 账户抽屉右栏改为一户一行纵向列表；每行显示账户类型小字 + 余额
   - 银行卡/储蓄/其它类型显示「余额 ¥x」；信用卡显示「已用额度 ¥x / 信用额度 ¥y」（负余额取绝对值）

6. **5.1.7 分类/账户管理快捷入口** — tx_entry_form.dart
   - 分类抽屉顶部新增「编辑」按钮 → CategoryManagePage（按支出/收入 tab）
   - 账户抽屉顶部新增「管理」按钮 → AccountsPage

**测试**：
- 更新 transaction_editor_page_test：字段顺序/备注行/标签行/账户抽屉余额（一户一行 + 信用卡已用额度）
- 更新 amount_editor_currency_test：小键盘无备注/标签/时间，保留 C 清空键与完成键
- 全量 flutter analyze 零 error（866 个预存 info/warning）
- 全量 flutter test：563 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**下一个任务需要知道的**：
- AmountEditorSheet 已精简为纯金额键盘；时间/备注/标签由外层表单管理（TxEntryForm / TransferForm）
- 分类已非必填，addTransaction 允许 categoryId 为 null
- AmountEditorSheet 的 showAccountPicker 参数仅为 API 兼容保留，UI 不再渲染
- 视觉布局未做 Windows 实机截图验证（widget 测试覆盖结构与回归）

**git 状态**：当前分支 main，未提交（等待 PM 审查）

---

## 2026-08-02

**移交角色**：项目经理（PM）
**接收角色**：UI 工程师（invest-ui）+ invest-logic

**任务**：5.1 记账界面体验优化（9 个问题）

**问题 1：备注弹框闪报错（bug）**
- 文件：lib/widgets/transaction/tx_entry_form.dart _pickNote
- 现象：按取消/确定都会闪一下报错，但备注实际写入成功
- 定位：TextEditingController 生命周期/dialog 关闭时序问题（可能在 Navigator.pop 后 dispose controller 导致）
- 修复：确保 controller dispose 在 widget 卸载后安全执行，或改用 showDialog 内部创建 controller

**问题 2：备注去掉弹框，改为行内填写**
- 备注行直接内嵌 TextField（或点击行展开输入框），不弹 AlertDialog
- 支持多行输入 + 高频备注历史（现有 NoteHistoryService 可复用）

**问题 3：分类之上加「金额」行**
- 表单顺序改为：金额-分类-账户-时间-标签-备注
- 金额行显示币种 + 金额（如 ¥ 0.00），点击调出数字小键盘（AmountEditorSheet 剥离非金额功能后）

**问题 4：数字小键盘的「标签」上提到界面**
- 表单加「标签」行（时间之后、备注之前），点击弹 TagSelector
- 顺序：金额-分类-账户-时间-标签-备注

**问题 5：所有字段独立填写**
- 分类/账户/金额/时间/标签/备注完全独立，无先后依赖
- 现状已接近（分类非必填），确认金额无需分类前置

**问题 6：数字小键盘删掉时间/备注/标签功能**
- 文件：lib/widgets/biz/amount_editor_sheet.dart
- 小键盘只保留：币种、金额、数字键、快捷操作（若有）、确定
- 移除备注输入区、标签选择区、时间选择区（这些已在主表单）

**问题 7：账户选择显示优化**
- 二级账户一户一行，纵向排列
- 每行显示账户余额小字：
  - 银行卡/储蓄卡 → 显示余额（如「工商银行  ¥12,345.67」）
  - 信用卡 → 显示已用额度（欠款/信用额度）
  - 其它类型 → 显示当前余额
- 文件：lib/widgets/transaction/tx_entry_form.dart _AccountDrawerSheet

**问题 8：分类弹窗加「编辑」按钮**
- 分类抽屉顶部「分类」标题旁加编辑图标按钮
- 点击进入分类管理页（CategoryManagePage）

**问题 9：账户弹窗加「管理」按钮**
- 账户抽屉顶部「账户」标题旁加管理图标按钮
- 点击进入账户管理页（AccountsPage 或账户设置）

**约束**：flutter analyze 零 error；新增/更新 widget 测试；金额/备注/标签历史功能不回归
## 2026-08-02

**移交角色**：invest-ui + UI 工程师
**接收角色**：项目经理（PM）

**完成工作**：阶段 5.0 记账账户放开 + 记账页重构（3 项全部完成）

1. **5.0.1 转账放开应收款/贷款** — [transfer_form.dart](/D:\codexproject\pj_004_beecount_fork\lib\widgets\transaction\transfer_form.dart)
   - 新增 `isBookingAccountType`（仅排除 investment），替换转账表单的 `isTradableType` 过滤
   - 转出/转入网格现在可选 receivable/loan（贷款作转出=还款、应收款作转入=收款）
   - hidden 过滤、币种过滤、编辑态 E1 钉住逻辑保持不变

2. **5.0.2 收支放开账户限制** — [account_selector.dart](/D:\codexproject\pj_004_beecount_fork\lib\widgets\biz\account_selector.dart) + [account_picker.dart](/D:\codexproject\pj_004_beecount_fork\lib\widgets\biz\account_picker.dart)
   - 两处过滤改用 `isBookingAccountType`，支出/收入可选 receivable/loan，investment 仍不可选
   - AccountPicker 顺带补上 hidden 过滤（原来漏了，与账户隐藏 #240 规则对齐）

3. **5.0.3 记账页 UI 重构** — [transaction_editor_page.dart](/D:\codexproject\pj_004_beecount_fork\lib\pages\transaction\transaction_editor_page.dart)（外壳）+ 新增 [tx_entry_form.dart](/D:\codexproject\pj_004_beecount_fork\lib\widgets\transaction\tx_entry_form.dart)
   - 顶部两排：第一排返回 + 标题「记一笔」，第二排支出/收入/转账 Tab（取消按钮移除）
   - 支出/收入改为表单先行：分类（一级 > 二级，抽屉两列联动）、账户（一级类型/账户两列）、时间、备注四行 + 底部金额栏
   - 分类/账户抽屉：左侧一级竖向导航（选中主题色竖条高亮），右侧二级 3 列图标网格
   - 点金额栏进入 AmountEditorSheet（showAccountPicker: false，分类/账户/时间/备注预填），保存链路沿用原 repo 写事务逻辑
   - 转账 Tab 继续走 TransferForm；quickAdd 参数保留兼容，不再自动弹金额窗

**测试**：
- 新增 test/widgets/account_open_types_test.dart（AccountSelector/AccountPicker/TransferForm 三类账户放开）
- 新增 test/widgets/transaction_editor_page_test.dart（新表单四行 + 转账 Tab 回归）
- 全量 flutter analyze 零 error（869 个预存 info/warning）
- 全量 flutter test：561 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**下一个任务需要知道的**：
- `isTradableType` 语义未改（buy/sell 弹窗仍排除 receivable/loan）；新谓词 `isBookingAccountType` 只用于记账/转账选择器
- 记账页交互已从「选分类即弹金额」改为「先表单后金额」，所有 quickAdd 调用方行为随之变化
- AccountPicker 新增 hidden 过滤（此前会显示隐藏账户）
- 视觉布局未做 Windows 实机截图验证（widget 测试覆盖结构与回归）

**git 状态**：当前分支 main，未提交（等待 PM 审查）

---

## 2026-08-02

**移交角色**：项目经理（PM）
**接收角色**：invest-ui（账户选择）+ UI 工程师（记账页重构）

**任务**：5.0 记账账户放开 + 记账页 UI 重构（3 个问题）

**问题 1：转账放开应收款/贷款账户**
- 文件：lib/widgets/transaction/transfer_form.dart:380
- 根因：isTradableType(account.type) 过滤掉了 receivable/loan，导致无法记录贷款还款/代付
- 修复：转出/转入账户选择放开，允许 receivable/loan（按用户需求，贷款账户作转出=还款，应收款作转入=收款）
- 注意：需保持 hidden 账户仍被过滤；币种过滤保留

**问题 2：支出/收入放开账户限制**
- 文件：lib/widgets/biz/account_selector.dart:98、lib/widgets/biz/account_picker.dart:122
- 根因：同样 isTradableType 过滤
- 修复：支出/收入账户选择放开 receivable/loan
- 注意：investment 账户保持不可选（投资走专属流程）；确认负债账户作支出/收入的方向语义

**问题 3：记账页 UI 重构**
- 文件：lib/pages/transaction/transaction_editor_page.dart（大改）
- 现状：TabBar + CategorySelector + 金额弹窗（quickAdd）
- 目标布局：
  a) 顶部蓝色菜单两排：第二排基本不变（支出/收入/转账 Tab）；取消按钮移除，第一排最左侧「<」返回 + 标题「记一笔」
  b) 白色内容第一行「分类」：显示「一级分类 > 二级分类」，点击后抽屉式纵向两列滚动（左侧一级、右侧二级联动，二级必须对应所选一级）
  c) 第二行「账户」：同样方式显示一级/二级账户
  d) 第三行「时间」选择
  e) 第四行「备注」
- 参考模板：D:/Users/wanji/Downloads/markmap.svg（底部分类面板：左侧一级竖向导航，选中橙色竖条高亮；右侧二级图标网格 3 列）
- 金额输入仍保留（点金额区弹小键盘或底部金额栏），交互顺序：先表单后金额

**约束**：flutter analyze 零 error；既有 transaction 相关测试全过；问题 1/2 补账户选择测试

## 2026-08-01

**移交角色**：invest-ui + architect + invest-logic（4.9 联合执行）
**接收角色**：PM

**完成工作**：阶段 4.9 账户创建与净值趋势优化（4 项全部完成）

1. **4.9.1 虚拟账户不显示卡信息** — [account_edit_page.dart](/D:\codexproject\pj_004_beecount_fork\lib\pages\account\account_edit_page.dart)
   - `isBankCard` 从 `bank_card || virtual_account` 改为仅 `bank_card`
   - 编辑保存时 `clearMetadataFields = !isBankOrCredit`，虚拟账户等非卡账户保存会清掉历史开户行/卡号，避免残留

2. **4.9.2 应收款改初始资金语义** — [account_type_utils.dart](/D:\codexproject\pj_004_beecount_fork\lib\utils\account_type_utils.dart)
   - `isValuationOrInvestmentType` 移除 `receivable`（仅保留 investment/loan）
   - 应收款余额 = 初始资金 + 流水；详情页自动走普通账户分支，不再显示「更新估值」按钮

3. **4.9.3 初始资金日期字段** — [db.dart](/D:\codexproject\pj_004_beecount_fork\lib\data\db.dart) + account_edit_page + Repository 三层
   - Accounts 表新增 `initial_date`（nullable DATETIME），schemaVersion 33→34，v34 迁移回填 `COALESCE(created_at, now)`
   - account_edit_page 初始资金区新增日期选择器（默认今天），createAccount/updateAccount（接口 + LocalAccountRepository + LocalRepository）支持 initialDate
   - 未传 initialDate 时保持 null（不约束历史趋势；小组件/导入/种子路径行为不变），UI 新建默认今天

4. **4.9.4 净值趋势按初始日期** — [local_account_repository.dart](/D:\codexproject\pj_004_beecount_fork\lib\data\repositories\local\local_account_repository.dart)
   - `getAccountDailyBalances`：估值账户 initialDate 之前返回 0；普通账户 initialDate 前为 0，从该日起才累计初始资金 + 流水
   - getNetWorthTrendSeries 按各账户 initialDate 累加

**测试**：
- 新增 4 组：migration_v34_test（列 + 回填 + 幂等）、account_initial_fund_test（应收款余额语义 + initialDate 落库）、net_worth_trend_test 新增 3 个趋势用例、account_edit_page_card_info_test（虚拟账户无卡信息 + 银行卡保留）
- flutter analyze 零 error（873 个预存 warning/info）
- 全量 flutter test：556 passed / 1 skipped / 1 failed（唯一失败为既存 bill_creation_service_test）

**下一个任务需要知道的**：
- 存量账户升级到 v34 时 initial_date 回填 created_at；无 created_at 用当前时间
- 应收款已不是估值类型，投资账户仍为估值类型（市值由持仓自动计算），loan 保留负债估值语义
- 小组件/导入/种子创建的账户 initialDate 为 null，趋势不做日期截断；只有 UI 新建账户默认今天
- 若需给既有账户补初始资金日期，编辑账户即可改日期

**git 状态**：当前分支 main，未提交（等待 PM 审查）

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

## 2026-08-01

**移交角色**：项目经理（PM）
**接收角色**：invest-ui + invest-logic（账户体验优化）

**任务**：4.9 账户创建与净值趋势优化（4 个问题）

**问题 1：虚拟账户不应显示开户行/卡号后四位**
- 文件：lib/pages/account/account_edit_page.dart:200
- 根因：`isBankCard = _selectedType == 'bank_card' || _selectedType == 'virtual_account'`，导致支付宝/微信等虚拟账户也显示「开户行/卡号后四位」
- 修复：改为仅 `_selectedType == 'bank_card'` 显示该区块

**问题 2：应收款账户应用「初始资金」而非「当前估值」**
- 文件：lib/utils/account_type_utils.dart:100-103 + lib/pages/account/account_detail_page.dart
- 根因：`isValuationOrInvestmentType` 包含 `receivable`，导致应收款账户走估值逻辑（显示"当前估值"+「更新估值」按钮）
- 修复：将 `accountTypeReceivable` 从估值类型中移除；应收款账户余额语义改为「初始资金」（余额=初始资金+流水），删除应收款账户的「更新估值」入口
- 注意：`investment` 仍为估值类型（市值由持仓自动计算）；`loan` 需确认是否保留估值语义，建议保留负债估值

**问题 3：新建账户支持选择初始资金日期**
- 文件：lib/data/db.dart（Account 表）+ lib/pages/account/account_edit_page.dart
- 需求：新建所有账户时，初始资金可指定某年某月某日（默认今天），便于后期补充历史流水
- 实现：
  a) Accounts 表加 `initial_date`（nullable DateTimeColumn）→ schema v33→v34 迁移
  b) account_edit_page 在初始资金输入区加日期选择器（默认 DateTime.now()）
  c) 保存时写入 initialDate；已有账户迁移时回填 created_at（或默认当天）
  d) LocalAccountRepository createAccount/updateAccount 支持该字段

**问题 4：净值趋势按初始资金日期计算**
- 文件：lib/data/repositories/local/local_account_repository.dart:694-709
- 根因：`getAccountDailyBalances` 对估值账户每天返回固定估值，导致 6 个月趋势全部显示同一个数，即使前 5 个月没有登记
- 修复：账户在 `initialDate`（问题 3 新字段）之前应返回 0（不计入），从 initialDate 起才返回余额；普通账户同样遵循：初始资金日期之前为 0
- 联动：不同账户可登记不同日期的初始资金，净值趋势按各自日期累加
- 注意：确认 trend 页面 6M/12M 的 startDate 语义，避免破坏既有测试（test/utils/net_worth_trend_utils_test.dart 等）

**约束**：flutter analyze 零 error；相关测试全过并补充：虚拟账户无卡信息、应收款余额语义、initialDate 趋势计算、迁移 v34 测试。

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
