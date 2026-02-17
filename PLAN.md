# d1vai_app Project Database/Data Tab 对齐与留存优化执行计划

## 设计思考与逻辑（先统一判断，再补齐关键路径）

### 1) d1vai（Web）与 d1vai_app（Flutter）当前差异
- **启用判断口径不一致（流程错误）**：Web 用 `project.project_database_id` 的存在性直接判断是否显示 `Enable Database`；App 当前用 `projectDatabaseId > 0`，会在 `project_database_id` 为非数字字符串时误判为“未启用”。
- **Schema → Data 主路径断裂**：Web 点击表会进入 Data 视图继续查数据；App 当前点击表是“发给 AI”，Data Tab 仍是占位文案，导致用户不能沿着“看结构 → 看数据”走通。
- **Data 功能缺失**：Web 有表切换、行浏览、分页、刷新与行级操作；App 缺少表数据浏览主流程（处于 Coming Soon）。
- **Migration 功能缺失**：Web 可查看迁移历史；App Migration Tab 仍是占位态，缺少“变更可追溯”。

### 2) 最小改动补齐策略（不重构页面架构）
- 保留 App 现有 Database 顶部结构（Schema / Data / Migration + Branch）。
- 先统一“是否启用数据库”的字段判断口径，避免错误入口。
- 在不拆大组件的前提下，把 Data Tab 从占位升级为可用路径（表选择 + 行数据浏览 + 基础行操作）。
- Migration Tab 先补“历史可见 + 刷新”基础能力，满足可追溯闭环。

### 3) 留存视角（交互 + 动效）
- **首个可行动作前置**：Schema 空间内点击表直接带入 Data，减少用户“看完结构后无下一步”的流失。
- **关键状态可见**：加载、刷新、执行中的按钮状态保持一致，降低不确定性焦虑。
- **轻量微动效强化掌控感**：延续已有 `AnimatedSwitcher` + 局部淡入滑入，不新增复杂手势学习成本。
- **闭环反馈**：每次增删改/刷新都有明确提示，让用户形成“我操作 → 系统响应 → 我继续下一步”的节奏。

## TODO（逐点完成、逐点检查、逐点打勾）
- [x] P0：统一数据库启用判断字段（与 Web 同口径：基于 `project_database_id` 存在性），修复 Enable Database/表视图误切换。
- [x] P1：修复 Schema 主路径（点击表默认进入 Data 并加载该表数据；AI 提问改为次级动作）。
- [x] P2：补齐 Data Tab 基础流程（表切换、行浏览、分页、刷新）。
- [x] P3：补齐 Data Tab 最小行级操作（新增、编辑、删除）。
- [x] P4：补齐 Migration Tab 历史视图（列表 + 状态 + 刷新）。
- [x] P5：补齐留存向交互细节（关键状态提示、轻动效过渡、下一步引导文案）。

## 执行约束
- 每完成一个 Px：先做一次代码检查（至少 `flutter analyze` 目标文件）再勾选。
- 以“最小改动 + 流程闭环 + 状态可见”为优先，避免重构级改造。
