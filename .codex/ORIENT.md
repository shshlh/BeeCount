# 项目方向文档

欢迎加入 Fork & Invest 团队。

## 你进入了一个有明确分工的项目

在开始工作之前，请阅读以下文件，按顺序：

1. **`.codex/TEAM.md`** — 团队章程，包含任务板、角色分工、工作流程。**必读，找到你的任务**
2. **`docs/PROJECT_PLAN.md`** — 总体规划书，包含 6 个阶段、22 天、功能范围。**必读，了解全局**
3. **`docs/HANDOFF.md`** — 交接记录。如果上一位成员留下了交接信息，这里有。**选读，有助于衔接**

## 自检清单

进入项目后：

- [ ] 我读了 TEAM.md，找到了当前我的任务
- [ ] 我读了 PROJECT_PLAN.md，理解了项目全局
- [ ] 我确认了当前 git 状态（git status）
- [ ] 我在开工前跑了一遍 flutter analyze + flutter test
- [ ] 我明确了我的工作范围（不碰不属于我角色的文件）

## 边界规则

- 不属于你角色任务的文件，不要修改
- 如有必要跨越边界，先在任务里说明理由
- 每次 git 提交前确保 flutter analyze 无 error
- 完成工作后更新 TEAM.md 的任务状态
- 如果需要交接给下一个人，在 docs/HANDOFF.md 写交接记录
- **HANDOFF 编辑铁律**（详见 TEAM.md）：只增不减、禁止整文件重写、禁止模糊正则范围替换；改完跑 git diff -- docs/HANDOFF.md 自检，不允许出现 - 开头的内容行
- **看图必用 skill**：任务涉及图片/截图/本地图片文件/UI 参考图时，先读 C:/Users/wanji/.codex/skills/deepseek-vision-skill/SKILL.md 并用其脚本读图，再继续工作（详见 TEAM.md「图像识别规范」）
