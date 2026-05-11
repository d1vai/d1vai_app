# d1vai_app 对齐 d1vai 最近 5 次提交（排除 admin）执行计划

## 最高优先设计原则（全阶段强约束）
- `macOS` 新增逻辑必须与 `iOS / Android` 逻辑隔离；凡是本地工作区、`.d1v`、Finder / Open With / CLI / 本地目录访问能力，都只能在 `macOS` 分支启用。
- 任何桌面端能力落地前，都要先确认“不改变 iOS / Android 现有用户路径、不改变现有移动端支付/聊天/订单逻辑、不引入移动端新权限”。
- 与本地文件系统、CLI、Finder 相关的代码，优先放在独立模型 / service / widget 中，避免渗透到通用业务层。
- 每完成一个阶段性 TODO，必须先做针对性 `flutter analyze` 或等价检查，通过后才能在计划中打勾。
- 如需真实接入 `d1v-cli`，先做骨架与协议，再接真实执行；在真实执行前，Flutter 端不得假设 CLI 一定存在。

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

---

## 第四阶段：App Store / Google Play 上线准备

### 审查结论（基于当前仓库）
- 当前仓库距离正式上架还有若干“审核阻塞项”，不是只补素材就能提审。
- iOS 侧最大风险是：外部 Stripe 支付引导、账户删除仍走联系客服、ATS 全量放开。
- Android / Google Play 侧最大风险是：仍使用外部 Stripe 支付、仍声明过宽的媒体读取权限、没有 Play 用的 AAB 与正式签名链路。
- 工程基础信息也还没收口：Android 包名仍是 `com.example.d1vai_app`，Android `release` 仍用 debug 签名，应用名称在 iOS / Android 间不一致。

### 优先级说明
- `P0`：会直接阻塞提审 / 审核 / 上架。
- `P1`：提审前强烈建议完成，否则大概率反复补件、延长审核。
- `P2`：不一定阻塞首发，但会影响质量、转化或后续版本维护。

### P0（硬阻塞，先做）
- [ ] S0.1：确定商店支付策略并改造代码。
  当前 App 内明确存在数字能力充值 / 订阅购买，并直接跳转外部 Stripe / Web 结算，不适合直接上 App Store / Google Play。
  代码位置：`lib/widgets/topup_dialog.dart`、`lib/services/wallet_service.dart`、`lib/screens/pricing_screen.dart`
  iOS 方案：如果继续在 iOS App 内售卖数字功能、订阅、额度或云服务能力，改为 StoreKit / In-App Purchase；否则在 iOS 构建中去掉这些购买入口，只保留已购使用和账号管理。
  Android 方案：如果上 Google Play，改为 Play Billing；如果坚持外部支付，需改成不在 Play 分发，或确认是否符合特定地区替代计费项目要求。
- [ ] S0.2：补齐“应用内发起账户删除”。
  当前删除账号仍是复制模板 / 联系客服，不符合 Apple 对支持创建账号 App 的常规要求。
  代码位置：`lib/screens/settings/account_data_screen.dart`
  当前进展：已把“先删除全部项目”前置到 App 内，并在项目未清空时阻止继续删除流程；真正的账户删除接口仍待后端提供。
  需要落地：应用内入口、二次确认、重新验证、删除进度提示、删除后登出；如后端是异步删除，也要在 App 内发起，而不是要求发邮件。
- [ ] S0.3：切换到正式发布身份。
  Android 还在使用示例包名和 debug 签名，不能作为商店正式包。
  代码位置：`android/app/build.gradle.kts`、`android/app/src/main/kotlin/ai/d1v/d1vaiapp/MainActivity.kt`
  当前进展：已完成 Android 正式包名/namespace 收口，并补了 `key.properties` 发布签名配置入口；正式 keystore 和商店上传 key 仍待接入。
  需要落地：正式 `applicationId` / package path、正式 keystore、版本号策略、AAB 构建产物。
- [ ] S0.4：把 Google Play 发布产物切到 AAB。
  当前仓库和 CI 都围绕 APK；Google Play 新应用要求使用 Android App Bundle，并启用 Play App Signing。
  需要落地：`flutter build appbundle`、Play 上传 key、内部测试轨道发布流程。

### P1（提审前高优）
- [x] S1.1：收紧 iOS ATS 配置，移除 `NSAllowsArbitraryLoads = true`。
  当前 iOS 对所有网络请求放开非安全连接，会触发额外审查，也和正式上架的最小权限原则相冲突。
  代码位置：`ios/Runner/Info.plist`
  建议：生产构建只允许 `https`，如确需特殊域名或本地网络，改为最小范围 exception，不要全局放开。
- [x] S1.2：精简 Android 媒体权限。
  当前声明了 `READ_EXTERNAL_STORAGE`、`READ_MEDIA_IMAGES`、`READ_MEDIA_VIDEO`、`READ_MEDIA_AUDIO`，但现有场景看起来主要只是头像拍照 / 选图。
  代码位置：`android/app/src/main/AndroidManifest.xml`
  建议：优先改用 Android Photo Picker；至少去掉 `READ_MEDIA_VIDEO`、`READ_MEDIA_AUDIO` 和不必要的旧存储权限，减少 Play 权限审核风险。
- [ ] S1.3：完成隐私与数据申报素材。
  当前代码里有邮箱、头像、订单、支付、分析、WebView、共享链接等数据接触面，上架前必须把 App Store Privacy 和 Play Data Safety 填完整。
  需要输出：数据类型清单、用途、是否追踪、是否与第三方共享、保留策略、删除策略、第三方 SDK 清单。
- [x] S1.4：复核 ATT 与跟踪声明是否真的需要。
  当前 iOS 带有 `NSUserTrackingUsageDescription`，但仓库里没有明显广告 SDK / ATT 调起逻辑。
  代码位置：`ios/Runner/Info.plist`
  建议：如果不做跨 App / 跨站追踪，删除 ATT 文案和相关商店声明；如果要保留，补完整的授权流程与隐私说明，确保和 App Privacy 一致。
- [ ] S1.5：补全商店元数据与审核材料。
  需要准备：隐私政策 URL、支持 URL、营销文案、副标题、关键词、截图、App Review 测试账号、审核备注、账号删除说明、付费能力说明。
  现状：仓库内已有支持邮箱和部分法律/帮助页面入口，但还看不到可直接用于商店后台的结构化提交流程。
- [x] S1.6：统一品牌与版本信息。
  当前名称存在 `d1vai_app` / `D1vai App` / `D1V` 混用；iOS 工程里的 `MARKETING_VERSION` 仍是 `0.0.1`；Android 标签还是 `d1vai_app`。
  代码位置：`ios/Runner/Info.plist`、`ios/Runner.xcodeproj/project.pbxproj`、`android/app/src/main/AndroidManifest.xml`、`pubspec.yaml`
  需要落地：统一商店名称、包内显示名、版本号、构建号、截图品牌文案。
- [ ] S1.7：移除仓库中的签名资产并改用安全分发。
  当前仓库内直接存在 `ios/diven-distribustion.p12`，不适合继续作为正式发布方案。
  需要落地：证书 / profile / keystore 全部迁入本地钥匙串、CI secrets 或专用签名仓库，不再明文跟代码同仓。

### P2（并行优化）
- [ ] S2.1：补一套“商店发布验证矩阵”。
  包含：iOS 真机回归、TestFlight 内测、Google Play Internal Testing、登录/下单/删除账号/上传头像/外链/多语言检查。
- [x] S2.2：修复 `flutter analyze` 现有信息级问题。
  目前主要是 `withOpacity` 废弃和个别字符串插值提示，不阻塞上架，但建议在首发前清零，减少后续升级成本。
- [ ] S2.3：把商店分发和 GitHub APK 分发拆开。
  现有 GitHub Action 已适合 GitHub Release 分发 APK；后续建议另补 `android-aab-release` 和 `ios-testflight` 工作流，避免把“侧载包”和“商店包”混在一起。
- [ ] S2.4：整理审核辅助文档。
  需要沉淀一页内部文档，固定记录：测试账号、演示路径、付费说明、删除账号路径、隐私数据流、客服联系方式、已知限制。

### 建议执行顺序
- 第 1 周：S0.1 / S0.2 / S0.3 定方案并开始改代码。
- 第 2 周：S0.4 / S1.1 / S1.2 / S1.6 完成工程收口，跑首轮商店构建。
- 第 3 周：S1.3 / S1.4 / S1.5 / S1.7 补后台与合规材料，进 TestFlight / Play Internal Testing。
- 第 4 周：S2.1 / S2.2 / S2.3 / S2.4 完成提审前联调，准备正式提交。

### 已确认的正向项
- Android Target API 不是当前阻塞项：项目跟随 Flutter 默认 `targetSdkVersion`，按现状应高于 Google Play 对 2025 年提交的最低要求。
- iOS / Android 都已有基础图标资源，可继续用于内测和素材迭代。
- App 内已经有帮助与支持入口，也有账号数据导出 / 删除说明页，可在此基础上继续补“正式删除流程”和“隐私说明承接页”。

### 参考要求（官方）
- Apple：账户删除要求、App Privacy、ATS、App Review 元数据与支付规则
  `https://developer.apple.com/support/offering-account-deletion-in-your-app`
  `https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy`
  `https://developer.apple.com/documentation/Security/preventing-insecure-network-connections`
  `https://developer.apple.com/help/app-store-connect/reference/required-localizable-and-editable-properties`
  `https://developer.apple.com/app-store/review/guidelines/`
- Google Play：Payments、Target API、Data Safety、Photo/Video 权限、AAB / Play App Signing
  `https://support.google.com/googleplay/android-developer/answer/9858738`
  `https://support.google.com/googleplay/android-developer/answer/11926878`
  `https://developer.android.com/privacy-and-security/declare-data-use`
  `https://support.google.com/googleplay/android-developer/answer/16558241`
  `https://developer.android.com/studio/publish/`
  `https://developer.android.com/studio/publish/upload-bundle`

---

## 第五阶段：macOS 本地工作区（`.d1v`）与云端绑定基础

### 设计思考（严格限制在 macOS，不影响 iOS / Android）
- 目标不是立即做完整 IDE，而是先把“本地文件夹 -> d1v 工作区”这条链路打通。
- 第一阶段只做本地工作区元数据层：识别目录、检查 `.d1v`、读取绑定状态、返回统一模型；不改动现有聊天、订单、支付、iOS IAP、Android 流程。
- 所有新逻辑默认只在 `macOS` 分支启用；其它平台只保留现有行为。
- 优先做可验证的小步：每完成一个小点立即 `flutter analyze`，通过后再勾选。

### TODO（逐项检查后勾选）
- [x] M1：定义本地工作区数据模型（`.d1v/project.toml` 对应模型、工作区状态模型），并补 `WorkspaceLocalService` 的只读检测能力。
- [x] M2：实现 macOS 专用 `.d1v` 检查逻辑：给定目录后返回“未绑定 / 已绑定 / 配置损坏 / 非 macOS”状态，不接入其它平台。
- [x] M3：补一个最小 CLI 桥接层设计占位（先不依赖真实 `d1v-cli` 执行），统一后续 `workspace status/init/scan` 调用入口。
- [x] M4：补一个 macOS 专用入口状态卡/调试入口，用于在 App 内验证本地目录的 `.d1v` 检查结果。
- [x] M5：把当前已完成的 macOS 文档外跳、网络权限、图标、工作区检测一并联检，确认不影响 iOS / Android 代码路径。

### 第五阶段代码检查记录
- M1：`flutter analyze lib/models/local_workspace.dart lib/services/workspace_local_service.dart` ✅
- M2：`flutter analyze lib/models/local_workspace.dart lib/models/workspace_cli_result.dart lib/services/workspace_local_service.dart lib/services/workspace_cli_service.dart` ✅
- M3：`flutter analyze lib/models/local_workspace.dart lib/models/workspace_cli_result.dart lib/services/workspace_local_service.dart lib/services/workspace_cli_service.dart` ✅
- M4：`flutter analyze lib/models/local_workspace.dart lib/models/workspace_cli_result.dart lib/services/workspace_local_service.dart lib/services/workspace_cli_service.dart lib/widgets/macos_workspace_inspector_card.dart lib/screens/settings/api_settings_screen.dart` ✅
- M5：联检确认
  1) 新增工作区能力仅挂在 `macOS` 分支与 `API Settings` 调试入口；
  2) 文档外跳逻辑仍仅在 `TargetPlatform.macOS` 生效；
  3) 网络权限与图标改动仅位于 `macos/` 宿主工程；
  4) 本轮未改动任何 iOS / Android 运行分支逻辑。✅

---

## 第六阶段：`.d1v` 协议与真实 CLI 桥接准备

### 设计思考（先协议，后执行）
- 先固定 `.d1v/project.toml` 的字段结构和 App 侧模型，避免后续 CLI / backend / Flutter 三边各自发散。
- 先做“真实 CLI 调用骨架 + 回退策略”，但默认不改变现有 App 主流程，不要求用户机器已经安装 `d1v`。
- 所有真实 CLI 执行入口都必须是 `macOS` 限定，并提供“CLI 不存在 / 命令失败 / JSON 无效”的显式结果。

### TODO（逐项检查后勾选）
- [x] N1：补 `.d1v/project.toml` 正式字段草案与示例文件模型，统一 App 端字段定义。
- [x] N2：在 Flutter 端新增真实 CLI 执行器骨架（`d1v workspace status`），但先不接入用户主流程。
- [x] N3：为 CLI 执行器补“命令不存在 / 非 macOS / JSON 解析失败”回退结果，保证不会影响移动端。
- [x] N4：让 macOS 调试卡支持切换“本地解析模式 / CLI 模式”，用于本地验证真实桥接。
- [x] N5：完成本阶段联检，并确认新增 CLI 骨架未影响现有 iOS / Android 编译路径。

### 第六阶段代码检查记录
- N1：`flutter analyze lib/models/d1v_project_file.dart lib/models/local_workspace.dart lib/models/workspace_cli_result.dart lib/services/workspace_local_service.dart lib/services/workspace_cli_service.dart lib/services/workspace_cli_executor.dart` ✅
- N2：`flutter analyze lib/models/d1v_project_file.dart lib/models/local_workspace.dart lib/models/workspace_cli_result.dart lib/services/workspace_local_service.dart lib/services/workspace_cli_service.dart lib/services/workspace_cli_executor.dart` ✅
- N3：`flutter analyze lib/models/d1v_project_file.dart lib/models/local_workspace.dart lib/models/workspace_cli_result.dart lib/services/workspace_local_service.dart lib/services/workspace_cli_service.dart lib/services/workspace_cli_executor.dart` ✅
- N4：`flutter analyze lib/models/d1v_project_file.dart lib/models/local_workspace.dart lib/models/workspace_cli_result.dart lib/services/workspace_local_service.dart lib/services/workspace_cli_service.dart lib/services/workspace_cli_executor.dart lib/widgets/macos_workspace_inspector_card.dart lib/screens/settings/api_settings_screen.dart` ✅
- N5：联检确认
  1) 真实 CLI 骨架仅位于独立 service，不会被 iOS / Android 主流程主动调用；
  2) 调试卡仅在 `macOS` 下显示，并支持 Local Parse / CLI 双模式验证；
  3) CLI 缺失、JSON 解析失败、非 macOS 都有显式回退结果；
  4) 本轮新增代码未改动任何移动端既有业务逻辑。✅

---

## 第七阶段：真实 `d1v-cli workspace` MVP

### 设计思考（先打通链路，再接云端）
- 本阶段先做最小可用闭环：`d1v workspace status` 和 `d1v workspace init`。
- `init` 只负责在本地目录生成 `.d1v/project.toml`，不在 CLI 内耦合云端绑定；云端绑定后续单独接。
- Flutter 端只在 macOS 调试入口暴露 `init`，不把未完成的本地工作区流程带进 iOS / Android 或现有主路径。

### TODO（逐项检查后勾选）
- [x] W1：在 `d1v-cli` 中新增 `workspace status` 子命令，输出标准 JSON / text 状态。
- [x] W2：在 `d1v-cli` 中新增 `workspace init` 子命令，生成最小 `.d1v/project.toml`。
- [x] W3：在 Flutter 端新增 `workspace init` CLI 执行器，并接入 macOS 调试卡。
- [x] W4：让调试卡支持“选目录 -> inspect -> init -> re-inspect”的最小闭环。
- [x] W5：完成 `cargo check`、Flutter analyze 联检，并确认仍未影响 iOS / Android 逻辑。

### 第七阶段代码检查记录
- W1：`cargo check -p d1v-cli` ✅
- W2：`cargo check -p d1v-cli` ✅
- W3：`flutter analyze lib/models/d1v_project_file.dart lib/models/local_workspace.dart lib/models/workspace_cli_result.dart lib/services/workspace_local_service.dart lib/services/workspace_cli_service.dart lib/services/workspace_cli_executor.dart lib/widgets/macos_workspace_inspector_card.dart lib/screens/settings/api_settings_screen.dart` ✅
- W4：`cargo check -p d1v-cli` + `flutter analyze lib/models/d1v_project_file.dart lib/models/local_workspace.dart lib/models/workspace_cli_result.dart lib/services/workspace_local_service.dart lib/services/workspace_cli_service.dart lib/services/workspace_cli_executor.dart lib/widgets/macos_workspace_inspector_card.dart lib/screens/settings/api_settings_screen.dart` ✅
- W5：联检确认
  1) `workspace status/init` 已在 `d1v-cli` 中具备最小可用实现；
  2) Flutter 调试卡已支持 `CLI` 模式和 `Init .d1v` 闭环；
  3) 当前闭环仍只暴露在 macOS 调试入口，不进入 iOS / Android 主路径；
  4) Rust 与 Flutter 两侧检查均通过。✅

---

## 第八阶段：macOS 文件夹打开 / 拖拽导入最小闭环

### 设计原则（醒目约束，继续生效）
- `macOS` 新增“Open With / 文件夹拖拽 / 本地打包上传 / 自动跳转项目页”逻辑，必须继续严格隔离在桌面宿主与独立 service 中，不能影响 `iOS / Android` 主流程。
- 不新增移动端文件系统权限，不修改既有 iOS / Android 项目创建、聊天、支付、订单链路。
- 优先复用现有后端成熟能力：当前后端已有“导入本地 zip”为项目，因此 `macOS` 侧采用“文件夹 -> 本地 zip -> 复用 import API”的最小改动方案，而不是新造一条云端协议。

### TODO（逐项检查后勾选）
- [x] D1：把 macOS 收到的目录打开事件从“跳转设置页”升级为独立处理入口，不再依赖调试卡触发。
- [x] D2：新增 macOS 专用导入协调器，收到文件夹后显示处理中弹窗，并执行“本地压缩 -> 上传导入 -> 刷新项目列表”。
- [x] D3：导入成功后直接跳转到项目详情页 `tab=chat&chatTab=code`，对齐用户期望路径。
- [x] D4：保持 native 拖拽层改动最小，仅补目录拖入转发，不改动 Flutter 主窗口控制器结构，避免再次引入黑屏 / dead channel。
- [ ] D5：在真实运行中的 macOS App 上完成手工 e2e：拖入文件夹后确认弹窗出现、导入成功并跳转 chat code。

### 第八阶段代码检查记录
- D1-D4：`flutter analyze lib/main.dart lib/services/macos_open_service.dart lib/services/macos_folder_import_service.dart lib/widgets/macos_workspace_inspector_card.dart` ✅
- D5：待在真实 macOS 运行态手工验证。当前未自动化完成，因为本地已有 `flutter run -d macos` 调试会话占用 Flutter startup lock，且拖拽/Finder 打开属于宿主级交互，无法在当前无头命令环境内完整模拟。⏳

---

## 第九阶段：macOS 桌面自适应布局（高频 10 点）

### 设计原则（继续严格限制影响面）
- 桌面布局增强优先发生在 `macOS` 大屏断点；手机端与 iOS / Android 现有交互保持原样。
- 优先改“信息架构”，不是只加 `maxWidth`：左侧主导航、左侧页内导航、主内容双栏/三栏、右侧常驻工作区/聊天侧栏。
- 先覆盖高频主路径，再处理长尾页面；每完成一组页面都先做 `flutter analyze`。

### 目标 10 点
- [x] R1：主框架从底部 Tab 升级为桌面左侧主导航（Dashboard / Community / Docs / Settings）。
- [x] R2：Settings 页面桌面左侧标签导航（Profile / GitHub / Invites）。
- [x] R3：Projects 页面桌面搜索 + 摘要区 + 网格化项目卡片。
- [x] R4：Docs 页面桌面双栏布局（左侧 Hero / Search / Recent，右侧文档目录）。
- [x] R5：Orders 页面桌面左侧 Billing rail。
- [x] R6：Dashboard 页面桌面双栏布局（左侧 welcome / stats / workspace，右侧 heatmap / recent projects）。
- [x] R7：Community 页面桌面左侧过滤 rail + 右侧 feed。
- [x] R8：Project Detail 页面桌面左侧项目级导航 rail。
- [x] R9：Project Chat 页面宽屏右侧常驻聊天侧栏，预览 / 代码留在主工作区。
- [x] R10：补统一桌面断点与内容容器工具，避免后续继续散落写死宽度。

### 第九阶段代码检查记录
- R1-R10：`flutter analyze lib/utils/desktop_layout.dart lib/screens/main_screen.dart lib/screens/settings_screen.dart lib/screens/projects_screen.dart lib/screens/docs_screen.dart lib/screens/order_screen.dart lib/screens/dashboard_screen.dart lib/screens/community_screen.dart lib/screens/project_detail_screen.dart lib/widgets/chat/project_chat/project_chat_tab_ui.dart` ✅

### 当前验证结论
- 以上 10 个高频桌面适配点已完成首轮落地，且静态检查通过。
- 本轮重点是桌面信息架构调整，不涉及移动端路由、支付、聊天协议、本地工作区协议变更。
- 下一轮如果继续优化，优先建议补：Docs detail 桌面目录、Project Overview 更强三栏、Project API / Payment / Analytics 子页宽屏细化。 

---

## 第十阶段：高价值 UX 优化（当前基础上最值得做的 10 点）

### 设计原则
- 优先修“已经有功能但不好用”的点，不为凑功能堆新入口。
- 桌面优化优先关注效率、可发现性、减少误解与减少多余点击。
- 继续保证 `macOS` / 桌面增强不破坏 iOS / Android 既有路径。

### 完成项
- [x] U1：通用搜索框支持 `Esc` 清空或退出焦点，降低桌面搜索摩擦。
- [x] U2：搜索清空按钮 Tooltip 明确为 `Clear (Esc)`，提高快捷键可发现性。
- [x] U3：桌面主导航支持 `Cmd+1..4` 快速切页。
- [x] U4：主导航底部明确展示 `Desktop mode · Cmd+1-4`，减少隐藏能力。
- [x] U5：修复 Orders 桌面 rail 点击不切页的问题（之前 controller 没接入桌面内容区）。
- [x] U6：Dashboard 桌面 workspace 卡新增明确 CTA：`Wake workspace / Refresh workspace`。
- [x] U7：Projects 与 Dashboard 的创建入口补 Tooltip，提升桌面可发现性。
- [x] U8：Docs 桌面左栏新增明确 CTA：`Browse all docs`，减少用户被“近期/搜索”困住。
- [x] U9：Community 桌面左栏新增 `New post` CTA 和 filter 使用说明，减少操作路径绕行。
- [x] U10：Project Detail / Chat / Settings / Orders 左侧栏补说明文字，让桌面侧栏不再只是“能点但不解释”。

### 第十阶段代码检查记录
- U1-U10：`flutter analyze lib/widgets/search_field.dart lib/screens/main_screen.dart lib/screens/projects_screen.dart lib/screens/order_screen.dart lib/screens/dashboard_screen.dart lib/screens/docs_screen.dart lib/screens/community_screen.dart lib/screens/settings_screen.dart lib/screens/project_detail_screen.dart lib/widgets/chat/project_chat/project_chat_tab_ui.dart` ✅

### 本轮结论
- 本轮 UX 改动主要解决了桌面端效率与可发现性问题，而不是继续堆布局花样。
- 当前最有价值的下一步不再是全局大改，而是深挖 3 条高频路径：
  1) Docs detail 的目录与返回链路；
  2) Project Chat 的消息筛选 / 锚点 / 跳转；
  3) Project Overview / Deploy / Analytics 子页的桌面流程指引。 

---

## 第十一阶段：桌面列表多列化（最值得先做的 3 个地方）

### 目标选择依据
- 优先处理当前在 macOS 上仍然“单列长条往下滚”的高频列表。
- 只在桌面断点下切换为网格，多列化后提升浏览密度，不改变移动端阅读节奏。

### 完成项
- [x] G1：Docs 文档卡片列表改为桌面网格卡片，减少长列表滚动。
- [x] G2：Community 帖子流改为桌面双列卡片流，提升内容浏览效率。
- [x] G3：Orders 购买记录改为桌面双列卡片流，减少账单页纵向拖拽。

### 代码位置
- G1：[`lib/screens/docs_screen.dart`](/Users/apple/project/d1v_sever/d1vai_app/lib/screens/docs_screen.dart)
- G2：[`lib/screens/community_screen.dart`](/Users/apple/project/d1v_sever/d1vai_app/lib/screens/community_screen.dart)
- G3：[`lib/widgets/order_history.dart`](/Users/apple/project/d1v_sever/d1vai_app/lib/widgets/order_history.dart)

### 第十一阶段代码检查记录
- G1-G3：`flutter analyze lib/screens/docs_screen.dart lib/screens/community_screen.dart lib/widgets/order_history.dart` ✅

---

## 第十二阶段：macOS Chat Code 可拖拽分栏

### 目标
- 在 `chat code` 桌面布局下，让左侧文件列表栏和右侧文件预览栏之间有可拖拽分隔条。
- 仅在 `macOS` 桌面分支启用，不影响移动端与其它平台已有布局。

### 完成项
- [x] C1：把桌面 code tab 从固定 `320px + Expanded` 改为可调宽 split view。
- [x] C2：新增中间拖拽 handle，支持用户水平拖动调整左右视图宽度。
- [x] C3：限制最小/最大宽度，避免拖拽后把文件树或预览挤坏。

### 代码位置
- [`lib/widgets/chat/project_chat/code_tab/project_chat_code_tab.dart`](/Users/apple/project/d1v_sever/d1vai_app/lib/widgets/chat/project_chat/code_tab/project_chat_code_tab.dart)

### 第十二阶段代码检查记录
- C1-C3：`flutter analyze lib/widgets/chat/project_chat/code_tab/project_chat_code_tab.dart` ✅

---

## 第十三阶段：Chat Code 高亮增强

### 目标
- 让 `chat code` 里的文件预览对更多常见代码/配置文件类型启用语法高亮。
- 复用现有高亮组件，不引入新渲染链路。

### 完成项
- [x] H1：确认 `FilePreview` 已走 `CodeTabCodeBlock`，不重复造轮子。
- [x] H2：补齐常见文件类型语言识别：`kotlin/swift/java/go/c/cpp/toml/ini/less/xml/vue/svg/env/zsh`。
- [x] H3：保持大文件保护逻辑不变，避免高亮导致滚动卡顿。

### 代码位置
- [`lib/widgets/chat/project_chat/code_tab/code_tab_code_block.dart`](/Users/apple/project/d1v_sever/d1vai_app/lib/widgets/chat/project_chat/code_tab/code_tab_code_block.dart)
- [`lib/widgets/chat/file_preview.dart`](/Users/apple/project/d1v_sever/d1vai_app/lib/widgets/chat/file_preview.dart)

### 第十三阶段代码检查记录
- H1-H3：`flutter analyze lib/widgets/chat/project_chat/code_tab/code_tab_code_block.dart lib/widgets/chat/file_preview.dart lib/widgets/chat/project_chat/code_tab/code_tab_file_viewer.dart lib/widgets/chat/project_chat/code_tab/code_tab_file_viewer_page.dart` ✅
