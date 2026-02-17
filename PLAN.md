# d1vai_app Project Deploy Tab 对齐与留存优化执行计划

## 设计思考与逻辑（先找差异，再做最小补齐）

### 1) d1vai（Web）与 d1vai_app（Flutter）Deploy 流程差异
- **发布主流程差异（流程错误）**：Web 的「Release → Merge to Main」是 `先比对 dev/main -> 必要时 merge -> 再触发 production deploy`；App 现状是直接调 production deploy，存在发布语义与结果不一致风险。
- **回滚闭环缺失**：Web 支持在时间线里对非最新提交执行 `git revert` 并自动触发 preview redeploy；App 没有 deploy 侧一键回滚，失败后恢复路径断裂。
- **发布可追溯差异**：Web 有 Releases 视图（main 分支发布分组 + 生产站点入口）；App 只有 deployment history，缺少“这次发布包含哪些变更”的认知锚点。
- **部署数据兼容性差异**：Web 端对 deploy 接口结构容错更完整；App 的历史解析偏窄，容易出现“有数据但列表空”的弱感知问题。

### 2) 最小改动补齐策略（不重构页面架构）
- 保留 App 现有四块卡片（Actions/Troubleshooting/Current/History）结构，不改全局路由。
- 在 **Actions** 内修正 production 主流程（merge + deploy）并补阶段反馈，不重做大弹窗体系。
- 在 **History 行为** 内补“Revert + Preview Redeploy”，复用现有 bottom sheet 与日志入口。
- 新增一个轻量 **Releases 卡片**（基于 main commits 分组），补齐 Web 关键信息而不复制完整 Dev Timeline UI。
- 同步补 deploy 数据解析兼容，确保“最小改动但可见可用”。

### 3) 留存视角（顶级交互 + 动效）
- **低摩擦主路径**：把“发布到生产”从黑盒按钮变成阶段化反馈（checking/merging/deploying），降低用户不确定性焦虑。
- **失败可恢复**：给失败 deployment 直接提供“回滚并预览重部署”，缩短从失败到恢复的路径。
- **发布记忆点**：Releases 卡片持续展示“每次上线带来了什么”，帮助用户形成可复盘的交付节奏。
- **微动效增强掌控感**：沿用 App 现有轻动效体系（AnimatedSwitcher / loading state），只在关键节点强化反馈，不增加学习成本。

## TODO（逐点完成、逐点检查、逐点打勾）
- [x] P0：修复 Deploy 数据解析兼容（history / deploy 返回结构容错 + URL 规范化）。
- [x] P1：修复 Production 发布流程错误（对齐 Web：dev/main 比对、必要 merge、再 deploy，并展示阶段状态）。
- [x] P2：补齐回滚闭环（Deployment 行内支持 Revert commit + 自动 Preview Redeploy）。
- [x] P3：补齐 Releases 视图（main 分支发布分组 + 生产链接入口 + 手动刷新）。
- [x] P4：补齐留存向交互反馈（关键动作统一状态提示与下一步引导文案）。

## 执行约束
- 每完成一个 Px：先做一次代码检查（至少 `flutter analyze` 目标文件）再勾选。
- 以“最小改动 + 流程闭环 + 可回滚”为优先，避免大规模 UI 重构。
