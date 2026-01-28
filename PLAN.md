# d1vai_app 产品对齐与提升计划（对比 d1vai Web）

目标：围绕「用户最可能高频使用」的 5 个核心功能，对齐 d1vai（Web）的体验与能力，优先补齐 d1vai_app（移动端）在关键链路上的缺口，并给出 10 个“明显可提升”的改进点（按优先级）。

## 1) 用户最可能用的五个功能：d1vai vs d1vai_app 对比

| 功能（Top 5） | d1vai（Web）现状 | d1vai_app（当前）现状 | 差距 / 明显机会 |
| --- | --- | --- | --- |
| 1. 项目创建与项目管理（Projects） | Dashboard/Projects 入口明确；项目分区导航（overview/chat/db/api/git/pay/deploy/analytics）完整 | Dashboard 有项目列表/搜索 + CreateProjectDialog（AI 新建/导入仓库）；项目详情 Tab 已搭好 | 移动端更需要“快速继续工作”：最近项目/最近会话/一键继续；搜索/筛选（状态、更新时间、是否可部署）仍偏弱 |
| 2. 项目内 AI 对话（Chat） | `/chat` Playground + 项目内 Chat；Web 的工作流更像“IDE + 任务流” | 项目内 Chat（ProjectChatTab + ChatScreen）实现较完整（含 WS、队列、workspace 状态） | 入口不如 Web 显性（不在底部 Tab）；缺少“全局 Chat Playground”（不绑定项目的问答/引导）与“从其他 Tab 一键带上下文提问”的更强联动 |
| 3. 文档/上手学习（Docs） | `/docs` 站内阅读 + slug 路由；与产品内部信息架构一致 | Docs 列表 + 搜索，但点击后外跳到 `docs.d1v.ai`（外部浏览器） | 外跳导致流失与上下文断裂；缺少站内 Markdown/WebView 阅读、目录/搜索、高亮复制代码、离线缓存与深链 |
| 4. GitHub 集成与导入（GitHub） | 有“快速导入/连接/验证/导入”导向流程（组件层面较完善） | Settings/集成页具备 token 方式连接与拉取 repo；但项目详情 GitHub Tab 仍以“占位/说明”为主 | 关键缺口在“项目级”联动：展示当前项目关联仓库、导入/同步状态、权限检查与导入闭环；应复用现有 GitHubService 能力补齐 |
| 5. 计费/用量/订单（Billing/Orders/Usage） | Pricing/Order/Orders 页面完整；与使用统计联动 | Orders Tab 聚合 Balance/Orders/Usage/Pricing（结构清晰） | 移动端仍缺少更强的“因果解释”：用量→扣费→余额变化；以及订单/账单导出、失败原因与自助修复路径（支付失败、额度不足等） |

## 2) d1vai_app 可以明显提升和改进的 10 个点（按优先级）

### P0：补齐关键闭环（优先做）

1. 补齐 Project API Tab 的“可用性”（把占位变为可操作）
   - 现状：Env Var 的 Add/Edit/Delete、API Keys、API Documentation、Import/Export 多为提示/占位。
   - 改进：实现 Env Var CRUD（含 environment/加密标记/校验/回滚）、支持 `.env` 导入与导出；实现 API Keys 列表/创建/撤销；提供 API 文档入口（至少 WebView 打开项目 spec / OpenAPI）。
   - 验收：不出现 “coming soon / add... / exporting...” 的纯提示；用户可在手机上完成 80% 的 API 配置与自助排障。
   - 实施清单：
     - [x] Env Var：Add/Edit/Delete（对齐后端 `is_sensitive` + `show_values`）
     - [x] Env Var：Import/Export（.env 粘贴导入 + 导出复制/分享）
     - [x] Env Var：Sync to Vercel（手动触发）
     - [ ] API Keys：列表/创建/撤销
     - [x] API Documentation：站内查看（OpenAPI/WebView）

2. 项目级 GitHub Tab 对齐 Web 的“导入/连接/验证”闭环（复用现有 GitHubIntegrationScreen/GitHubService）
   - 现状：项目详情 GitHub Tab 偏展示/说明，Connected Repositories 为 0 的占位；而 Settings 的 GitHub 集成已具备连接与拉取 repo 能力。
   - 改进：在项目内提供：选择仓库→验证权限→导入/绑定→展示绑定信息（仓库、分支、最近同步/导入状态、错误提示与修复建议）。
   - 验收：新用户在移动端可独立完成“导入 GitHub repo → 生成/更新项目 → 进入 Deploy/Preview”的完整流程。
   - 实施清单：
     - [x] GitHub Tab：拉取 bot username + 一键复制
     - [x] GitHub Tab：Accept invitation / Verify access / Import（复用后端 github-import 接口）
     - [x] GitHub Tab：展示当前项目绑定仓库/分支/最近同步（需后端字段或新接口）

3. Docs 站内化（减少外跳流失）
   - 现状：DocsScreen 点击外跳浏览器。
   - 改进：提供站内文档阅读（InAppWebView 或 Markdown 渲染）；支持目录/站内搜索、复制代码块、最近阅读、深链接（`/docs/:slug`）。
   - 验收：用户从 app 内阅读文档不离开应用；返回时状态可恢复（滚动位置、搜索词）。
   - 实施清单：
     - [x] Docs 列表点击后站内打开（新增 `DocDetailScreen` + 路由 `/docs/:slug`）
     - [x] 代码块复制/优化阅读（后续可做 Markdown 渲染或 WebView 注入）
     - [x] 最近阅读/滚动位置恢复

4. 增加“Schema 可视化/结构化理解”能力（对齐 Web 的 scheme 可视化价值）
   - 现状：Database Tab 以表列表为主，缺少整体关系视图。
   - 改进：提供 ERD/Schema Graph（节点=表/视图，边=外键/关联）；支持从 schema 一键生成“Ask AI”的上下文提问（例如：为订单表增加优惠券关系）。
   - 验收：用户可在手机上快速理解数据结构；能从图上定位表并跳转详情。
   - 实施清单：
     - [x] 修复 schema 解析：支持后端 `{tables:[...]}` 返回（含 foreign_keys）
     - [x] Database Tab 增加 Relations 视图（外键关系列表 + 一键 Ask AI）
     - [ ] ERD/Graph 可视化（节点/边布局）

### P1：提升高频体验与转化（次优先）

5. 强化 Chat 入口与“继续工作”的主路径
   - 现状：Chat 不在底部主导航；用户需进入项目详情后再切到 Chat。
   - 改进：在 Dashboard/ProjectCard 增加“继续聊天/继续上次任务”按钮；提供全局浮动入口（可选）并支持带 `autoprompt` 快速提问。
   - 验收：从打开 app 到发出第一条有效 prompt 的步骤减少（可量化：点击次数/耗时）。
   - 实施清单：
     - [x] Dashboard/Projects：ProjectCard 提供直达 Chat 的快捷入口
     - [ ] 全局 Chat Playground（不绑定项目）

6. API 文档与 OpenAPI Viewer 对齐（移动端快速查阅/调试）
   - 现状：Web 有 `/openapi` viewer；移动端 API 文档仍占位。
   - 改进：在 Project API Tab 内集成 OpenAPI viewer（WebView + spec url 参数），并提供常见示例请求的“复制 curl/复制 token”。
   - 验收：移动端可完成“查看接口→复制请求→快速调试”。

7. 文案与国际化（i18n）一次性补齐（减少“半中文半英文”的割裂）
   - 现状：部分页面/Tab 文案硬编码英文（如 Orders/Documentation/Balance 等），与已有 AppLocalizations 不一致。
   - 改进：统一抽取到 l10n；补齐中文/英文；同时规范日期、货币、数量格式化。
   - 验收：切换语言后无明显漏翻；核心流程文本一致且可读。

8. 更强的“用量→费用→余额”解释与导出
   - 现状：Orders 聚合 Balance/Orders/Usage，但解释链路偏弱。
   - 改进：把 Usage 指标与 Billing 事件关联展示（某天/某项目/某模型用量→扣费→余额变化）；支持导出（CSV/复制摘要）。
   - 验收：用户能在移动端自助回答“为什么今天扣费变多/哪个项目在烧钱”。

### P2：长期护城河（可并行）

9. 深链接与分享（把 Web 的链接生态带到 App）
   - 现状：路由已覆盖 projects/:id、posts、apps/:slug 等，但缺少统一深链策略。
   - 改进：支持从外部链接打开到指定页面/Tab（项目/部署日志/社区帖子/文档）；支持“分享项目/分享帖子/分享预览链接”。
   - 验收：从 Web/社交平台点击链接可直达 app 对应页面（或兜底到 Web）。

10. 通知与后台状态同步（提升留存与闭环效率）
   - 现状：关键异步事件（部署完成、导入完成、支付成功/失败、社区互动）缺少推送/站内通知中心。
   - 改进：引入站内通知列表 +（可选）APNs/FCM；提供事件直达入口（点通知→对应 Project Tab/Log/Post）。
   - 验收：用户能“离开 app 也能收敛任务”，回到 app 可一键定位到结果页面。

## 3) 建议的迭代拆分（可选）

- Sprint A（P0）：API Tab 可用化 + GitHub 项目级闭环
- Sprint B（P0）：Docs 站内化 + Schema 可视化（先只读）
- Sprint C（P1）：Chat 入口与继续工作 + OpenAPI viewer
- Sprint D（P1/P2）：i18n 补齐 + Billing 解释/导出 + 深链/通知（按依赖拆分）

### 6. 公共页面与分享（用户/项目/应用）

- [x] 在 `AppDetailScreen` / `PostDetailScreen` / `ProjectDetailScreen` 加统一“分享”入口（右上角 Share icon）
- [x] 统一生成分享链接策略（优先：现有 Web URL；后续：App Deep Link），并把“复制链接 / 系统分享”做成通用组件（例如 `widgets/share_sheet.dart`）
- [x] 为分享内容补齐可读摘要（标题、短描述、预览链接），避免只分享裸 URL
- [ ] 增加“从分享链接打开 app”的深链方案（先只做：识别 `https://...` 路由 → `go_router` 跳转；未命中则落到对应 WebView/外部浏览器）
- [x] 为 `/apps/:slug` 增加“打开官网 / 打开预览 / 复制”三联动作（减少用户找入口成本）

### 7. 社区内容生产与互动（Community）

- [x] 给 `PostDetailScreen` 增加“评论列表 + 发表评论”入口（先仅 UI + 占位数据也可，但要把 API/Model 结构预留）
- [x] 给 `PostCard` 增加轻量互动按钮（like/comment/share），并在未登录时统一走 `LoginRequiredDialog`
- [ ] 增加“我的帖子 / 我的草稿”列表入口（可挂在 Profile 或 Community 顶部筛选）
- [ ] 支持“发布失败重试 + 本地草稿保存”（复用 `models/outbox.dart` 的队列思想或新增轻量 Draft 存储）
- [ ] 增加“举报/屏蔽”入口（先只走前端 UI + 提示；后续接后端）

### 8. 用户资料与账号安全（Profile/Auth/2FA/Wallet）

- [ ] 把 `TwoFactorAuthSettingsScreen` 从“设置项”升级为可用闭环：开启/关闭 2FA、展示备份码（至少复制/保存提示）
- [ ] 增加“会话过期与多端登录提示”统一处理（目前各处有 `isAuthExpiredText` 分散处理，补一个全局拦截/提示策略）
- [ ] 在 `ApiSettingsScreen` 的 diagnostics 基础上，新增“一键复制更完整诊断”（设备/版本/locale/baseUrl/token 后 6 位/最后一次 API 错误）
- [ ] 钱包登录链路补齐一致性校验（签名消息展示、失败原因可读化、重试/切换钱包入口）
- [ ] 增加“账号注销/数据导出”入口占位（至少有清晰预期与跳转到 docs/legal）



### 9. 监控与分析（Analytics / Realtime）

- [ ] 在 `ProjectAnalyticsTab` 增加筛选：时间范围（7/30/90）、环境（dev/prod）、关键指标切换（errors/requests/latency…按现有 API 能力逐步打开）
- [ ] 在 Realtime 页增加“异常提示卡”：当错误率/延迟飙升时，提供快捷跳转（Deploy Logs / Ask AI / Env Vars）
- [x] 增加“导出/分享报表摘要”（复制文本或 CSV；优先做复制摘要）
- [ ] 把 Dashboard 的 prompt heatmap 增加“按项目过滤/跳转到项目详情”入口（减少孤立指标）

### 10. 部署日志与排障（Deploy Logs / Debug）

- [x] `DeploymentLogScreen` 增加：复制全部日志 / 复制错误片段 / 系统分享（用于发给同事或支持）
- [x] 日志关键字高亮（error/warn/failed/traceback/http 4xx/5xx），并提供“仅看错误”过滤
- [x] Deploy Tab 增加“一键重试上次部署”（复用现有 preview/prod deploy action，并带确认弹窗）
- [x] 增加“排障向导”入口（FAQ 卡片）：检查 GitHub 权限 → 检查 env var → 检查 workspace → 重试部署（每步给可执行按钮/跳转）
- [x] 当部署失败时，把错误与“下一步建议”写入 SnackBar/对话框（避免只给 raw message）
