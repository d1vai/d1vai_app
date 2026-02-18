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
