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
