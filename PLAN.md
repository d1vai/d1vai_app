# d1vai_app 对齐 d1vai 最近 5 次提交（排除 admin）执行计划

## 设计思考与逻辑（最小改动 + 高体验 + 国际化优先）

### 1) 本轮基线：d1vai 最近 5 次提交（仅看非 admin）
- `febdee9`：新增余额不足弹窗，并将订单/计费相关文案国际化；聊天发送与创建项目流程接入余额不足提示。
- `9dafbd3`：钱包流水支持 `direction`，新增 Usage（debit）视图（admin 广播本身不做 App 端功能复制）。
- `b5428fa`：Builder Time 增加费用估算、费率展示和说明。
- `ab4587f`：订单页新增 Builder Time 视图与接口类型。
- `3c26f6c`：Analytics 口径统一为 `path/hostname`，并支持 realtime timezone（App 端相关实现需复核是否已对齐）。

### 2) App 端当前差异判断
- 订单页有 Balance / Orders / Usage / Price，但 Orders 子页仅有 Purchases/Credit，缺少 debit Usage 流水。
- Usage 页目前只有 DB + LLM 聚合，没有 Builder Time（总时长/费用/项目分布/费率）。
- 聊天发送失败、创建项目失败对“余额不足”无专门引导，用户只能看到通用报错。
- 订单与计费区域存在较多硬编码英文，国际化覆盖不足。
- Analytics `path/hostname` 与 timezone 逻辑在 `d1vai_service` 已存在，需要做差异复核并记录，不做重复改造。

### 3) 改造策略（尽量不重构）
- **先补齐关键闭环**：余额不足 → 友好弹窗 → 一键去充值页。
- **最小范围扩展现有结构**：不重做订单页架构，只在现有 tab 中新增 Usage 子 tab 和 Builder 卡片区。
- **体验优先**：每个新增区块必须有加载态、空态、失败提示、可刷新。
- **国际化优先**：本次新增/改造文案全部走 `l10n`；避免继续引入硬编码。
- **逐点验收**：每完成一个小点立即 `flutter analyze` 做代码检查，再勾选 TODO。

## TODO（逐项完成 + 逐项检查 + 逐项勾选）
- [x] T0：完成 5 个提交的非 admin 差异映射，并在 App 代码中标注对应逻辑位置（含“已对齐无需改造”的项）。
- [x] T1：补齐订单侧钱包 Usage（debit）历史视图（接口 `direction`、source 解析、加载/空态/刷新、国际化文案）。
- [x] T2：在 Usage 页补齐 Builder Time（总时长、预估费用、费率说明、项目分布、加载/空态/失败提示、国际化文案）。
- [x] T3：新增“余额不足”统一识别与友好弹窗（聊天发送 + 创建项目），支持一键跳转充值页。
- [x] T4：补齐本次涉及页面的国际化键值（多语言 ARB + 生成文件），并完成路由落点体验（`/orders?tab=price`）。
- [x] T5：逐差异点复核补齐（对照 5 次提交），完成最终代码检查并关闭全部 TODO。

## 差异复核结果（commit → App 逻辑位置）
- `febdee9`（余额不足弹窗 + 计费国际化）：已补齐到 `lib/widgets/insufficient_balance_dialog.dart`、`lib/utils/billing_errors.dart`、`lib/screens/chat_screen.dart`、`lib/widgets/chat/project_chat/project_chat_tab_logic.dart`、`lib/widgets/create_project_dialog/create_project_dialog.dart`。
- `9dafbd3`（wallet usage/debit）：已补齐到 `lib/services/wallet_service.dart`（`direction` 参数）、`lib/models/balance.dart`（`direction` 字段）、`lib/widgets/wallet_usage_history.dart`、`lib/screens/order_screen.dart`（新增 Usage 子 tab）。
- `ab4587f` + `b5428fa`（Builder Time + 预估费用/费率）：已补齐到 `lib/models/builder_usage.dart`、`lib/services/usage_service.dart`、`lib/widgets/usage_stats.dart`。
- `3c26f6c`（analytics path/hostname + realtime timezone）：复核 `lib/services/d1vai_service.dart` 与 `lib/widgets/project_analytics/project_analytics_tab.dart` 已具备别名归一与 timezone 参数，判定本轮无需重复改造。
- 国际化落地：新增键值已同步到 `lib/l10n/arb/*.arb` 并生成 `lib/l10n/generated_localizations.dart`，订单/用量/余额不足流程不再依赖新增硬编码文案。

## 执行约束
- 每完成一个 Tx：
  1) 先执行代码检查（至少 `flutter analyze` 覆盖改动文件）；
  2) 再在该 TODO 前打勾；
  3) 记录“本点差异是否完全补齐”。
- 优先保证用户感知：明确加载态、友好提示、减少无效点击、避免生硬报错。

## 代码检查记录（逐点）
- T1：`flutter analyze lib/screens/order_screen.dart lib/widgets/wallet_usage_history.dart lib/services/wallet_service.dart lib/models/balance.dart` ✅
- T2：`flutter analyze lib/widgets/usage_stats.dart lib/services/usage_service.dart lib/models/builder_usage.dart` ✅
- T3：`flutter analyze lib/utils/billing_errors.dart lib/widgets/insufficient_balance_dialog.dart lib/core/api_client.dart lib/services/chat_service.dart lib/widgets/create_project_dialog/create_project_dialog.dart lib/screens/chat_screen.dart lib/widgets/project_chat/project_chat_tab.dart lib/widgets/chat/project_chat/project_chat_tab_logic.dart` ✅
- T4：`flutter analyze lib/router/app_router.dart lib/screens/main_screen.dart lib/screens/order_screen.dart lib/l10n/generated_localizations.dart lib/widgets/usage_stats.dart lib/widgets/wallet_usage_history.dart lib/widgets/insufficient_balance_dialog.dart` ✅
- T5：`flutter analyze lib/core/api_client.dart lib/router/app_router.dart lib/screens/chat_screen.dart lib/screens/main_screen.dart lib/screens/order_screen.dart lib/services/chat_service.dart lib/services/usage_service.dart lib/services/wallet_service.dart lib/widgets/chat/project_chat/project_chat_tab_logic.dart lib/widgets/create_project_dialog/create_project_dialog.dart lib/widgets/project_chat/project_chat_tab.dart lib/widgets/usage_stats.dart lib/models/balance.dart lib/models/builder_usage.dart lib/utils/billing_errors.dart lib/widgets/insufficient_balance_dialog.dart lib/widgets/wallet_usage_history.dart lib/l10n/generated_localizations.dart` ✅

---

## 第二阶段：用户体验优化 + 多语言（Dashboard / Project Detail）

### 设计思考（最小改动，但体验必须可感知）
- 优先改“用户最常见路径”：Dashboard → Project Detail → Overview，先把高频页面的硬编码文案清掉。
- 保持低风险：沿用页面内 `_t(key, fallback)`，避免大规模状态/组件重构，缺词时也不会展示 raw key。
- 体验先行：发布、删除、转移等高风险交互统一补齐加载态、进度提示、失败反馈；时间文案与日期格式按 locale 展示。
- 国际化策略：`en/zh/zh_Hant` 给出可读翻译，其它语种先落英文兜底，保证多语言不破 UI。

### TODO（逐项检查后勾选）
- [x] P1：Dashboard 页面核心状态/提示/空态/错误文案国际化（含搜索与 workspace 状态）。
- [x] P2：Project Detail 主页面（tab/share/error/not found）国际化。
- [x] P3：Project Overview 全量国际化（Header/Stats/Links/Recent Deployments/Health Metrics/Community/Danger Zone），并补齐关键流程加载与提示文案。
- [x] P4：Project Deploy 页面国际化 + 加载态/空态/失败提示优化。
- [x] P5：Project API / Env / Database / Analytics 页面继续国际化补齐。

### P3 差异复核（本次）
- 已清理 Project Overview 下仍残留的硬编码英文，覆盖发布流程弹窗、进度文本、危险操作确认、链接错误提示、状态标签与时间文案。
- `formatTimeAgo` 改为按当前 locale 展示日期格式，减少跨语言阅读负担。
- 新增 `project_overview_*` 多语言键并重新生成 `generated_localizations.dart`。

### P4 差异复核（本次）
- 已完成 Deploy 主页面国际化：Actions / Troubleshooting / Current Deployments / Releases / Deployment History / BottomSheet 操作项。
- 关键流程体验对齐：预览/生产部署、回滚、重试、下一步建议、日志打开失败等提示均已本地化并保持原加载态交互。
- 部署日志页（`DeploymentLogScreen` + `DeploymentLogViewer`）完成菜单、复制、分享、错误态、统计标签国际化。
- 时间文案与空态文案统一本地化，避免中英文混杂。

### P5 差异复核（本次）
- 已完成 `Database / Analytics` 国际化补齐：`project_database_tab.dart` + `project_analytics_tab.dart`。
- Analytics 新增完整交互文案覆盖：安装引导、分享访问、筛选器、对比维度、状态卡片、摘要复制、失败重试、按钮反馈；并按 locale 格式化时间范围显示。
- Database 补齐 AI 说明提示词的中文/繁中文案，避免中英文混杂。
- 已将 `project_analytics_*` 新增键同步到 `lib/l10n/arb/*.arb`，并重新生成 `generated_localizations.dart`，保证多语言 key 一致。

### 第二阶段代码检查记录
- P3：`flutter analyze lib/widgets/project_overview/project_overview_tab.dart lib/widgets/project_overview/components/project_overview_utils.dart lib/widgets/project_overview/components/project_overview_header_card.dart lib/widgets/project_overview/components/project_overview_health_metrics_card.dart lib/widgets/project_overview/components/project_overview_recent_deployments_card.dart lib/widgets/project_overview/components/project_overview_links_card.dart lib/widgets/project_overview/components/project_overview_stats_card.dart lib/widgets/project_overview/components/project_overview_danger_zone_card.dart lib/l10n/generated_localizations.dart` ✅
- P4：`flutter analyze lib/widgets/project_deploy/project_deploy_tab.dart lib/widgets/project_deploy/deployment_log_screen.dart lib/widgets/project_deploy/deployment_log_viewer.dart lib/l10n/generated_localizations.dart` ✅
- P5（API/Env 子批次）：`flutter analyze lib/widgets/project_api/project_api_tab.dart lib/widgets/project_api/env_var_editor_dialog.dart lib/l10n/generated_localizations.dart` ✅
- P4+P5（联检）：`flutter analyze lib/widgets/project_deploy/project_deploy_tab.dart lib/widgets/project_deploy/deployment_log_screen.dart lib/widgets/project_deploy/deployment_log_viewer.dart lib/widgets/project_api/project_api_tab.dart lib/widgets/project_api/env_var_editor_dialog.dart lib/l10n/generated_localizations.dart` ✅
- P5（Database/Analytics 子批次）：`flutter analyze lib/widgets/project_analytics/project_analytics_tab.dart lib/widgets/project_database/project_database_tab.dart lib/l10n/generated_localizations.dart` ✅
- P5（全量联检）：`flutter analyze lib/widgets/project_deploy/project_deploy_tab.dart lib/widgets/project_deploy/deployment_log_screen.dart lib/widgets/project_deploy/deployment_log_viewer.dart lib/widgets/project_api/project_api_tab.dart lib/widgets/project_api/env_var_editor_dialog.dart lib/widgets/project_database/project_database_tab.dart lib/widgets/project_analytics/project_analytics_tab.dart lib/l10n/generated_localizations.dart` ✅

---

## 第三阶段：Project Detail 深化（GitHub / Payment）

### 设计思考（继续最小改动 + 强化操作可感知）
- GitHub Tab 是“高风险操作路径”（邀请、验权、导入），优先补齐步骤反馈文案，避免用户不知道当前卡在哪一步。
- Payment Tab 是“经营类信息页”，优先保证空态/错误态/编辑弹窗文案清晰，减少新增/编辑失败时的理解成本。
- 仍采用页面内 `_t(key, fallback)`，只替换可见文案和提示，不改动原接口与流程，降低回归风险。
- 新增 key 同步到多语言 ARB，保持 `en/zh/zh_Hant` 可读，其它语种走英文兜底。

### TODO（逐项检查后勾选）
- [x] P6.1：Project GitHub 页面国际化补齐（连接仓库、邀请验权、导入流程、复制提示、错误提示）。
- [x] P6.2：Project Payment 页面国际化补齐（概览指标、商品区、交易区、新增/编辑弹窗、失败提示、AI 提示词）。
- [x] P6.3：补齐 `project_github_*` / `project_payment_*` ARB 键并重新生成本地化文件。
- [x] P6.4：做联检并确认新旧页面无分析错误。

### P6 差异复核（本次）
- `project_github_tab.dart`：已覆盖连接仓库卡片、GitHub Import 流程、邀请/验权/导入反馈、复制与失败提示，并保留原交互顺序与按钮禁用逻辑。
- `project_payment_tab.dart`：已覆盖 Payment Overview / Products / Transactions 以及新增/编辑商品弹窗的全部关键文案，补齐字段校验错误、加载态按钮文本与 AI 提示词国际化。
- 新增键值已同步到 `lib/l10n/arb/*.arb` 并重新生成 `lib/l10n/generated_localizations.dart`，保证多语言 key 集合一致。

### 第三阶段代码检查记录
- P6.1：`flutter analyze lib/widgets/project_github/project_github_tab.dart` ✅
- P6.2：`flutter analyze lib/widgets/project_github/project_github_tab.dart lib/widgets/project_payment/project_payment_tab.dart` ✅
- P6.3：`flutter analyze lib/widgets/project_github/project_github_tab.dart lib/widgets/project_payment/project_payment_tab.dart lib/l10n/generated_localizations.dart` ✅
- P6.4（联检）：`flutter analyze lib/widgets/project_github/project_github_tab.dart lib/widgets/project_payment/project_payment_tab.dart lib/widgets/project_analytics/project_analytics_tab.dart lib/widgets/project_database/project_database_tab.dart lib/l10n/generated_localizations.dart` ✅
