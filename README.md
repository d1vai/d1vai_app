# d1vai_app

`d1vai_app` 是 d1v.ai 的 Flutter 客户端，面向移动端使用场景，提供登录、项目管理、AI 聊天、部署与实时分析、文档与社区、订单与账户设置等能力。

## 功能概览

- 认证与账号：
  - 邮箱验证码登录 / 密码登录
  - Solana / Sui 钱包登录
  - Onboarding 流程、邀请码、资料维护
- 主导航模块：
  - Dashboard（工作区状态、项目总览、活跃度热力图）
  - Community（社区内容）
  - Docs（文档）
  - Orders（订单与账单）
  - Settings（语言、API、通知、账号数据、GitHub 等）
- 项目能力：
  - 项目列表与搜索、项目详情多标签页
  - 项目聊天与代码视图
  - 实时分析与部署信息展示
- 国际化与主题：
  - 内置多语言（如 `en/zh/zh_Hant/ja/fr/es/ru/ar`）
  - 明暗主题切换

## 技术栈

- Flutter / Dart（`sdk: ^3.10.0`）
- 状态管理：`provider`
- 路由：`go_router`
- 网络层：`http`
- 本地存储：`shared_preferences`
- 图表：`fl_chart`

## 项目结构

```text
lib/
  core/        # API 客户端、主题、全局事件总线
  models/      # 数据模型
  providers/   # 状态管理（鉴权、主题、语言、项目等）
  services/    # 业务服务（用户、项目、分析、钱包、工作区等）
  screens/     # 页面
  widgets/     # 组件
  l10n/        # 国际化资源与生成代码
tool/
  gen_l10n.dart  # l10n 运行时映射生成脚本
test/
```

## 环境要求

- Flutter SDK（建议与项目 Dart 版本匹配）
- Xcode（iOS）
- Android Studio / Android SDK（Android）

## 快速开始

1. 安装依赖

```bash
flutter pub get
```

2. 运行项目（示例）

```bash
flutter run
```

3. （可选）构建时覆盖 API 地址

```bash
flutter run --dart-define=API_BASE_URL=https://api.d1v.ai
```

## API 配置

- 默认 API Base URL：`https://api.d1v.ai`
- 支持在应用内覆盖：`Settings → Profile → API`
- `Copy diagnostics` 会导出关键诊断信息，包括：
  - 生效中的 Base URL
  - Token 是否存在与后缀
  - JWT Claims（如 `sub/type/exp`，可用时）
  - 最近一次工作区状态与最近 API 错误

## 常见排查：创建项目返回 500

如果 `d1vai_app` 创建项目失败，但 Web 端正常：

1. 进入 `Settings → Profile → API`，点击 `Copy diagnostics`
2. 确认 `effective_base_url` 为 `https://api.d1v.ai`
3. 确认 `auth_token_present=true`
4. 对比 App 与 Web/curl 的 `jwt_sub` / `jwt_type`（或 token 后缀）

## 国际化（l10n）工作流

- 事实来源：`lib/l10n/arb/app_*.arb`
- 修改 ARB 后生成运行时映射：

```bash
dart run tool/gen_l10n.dart
```

- 一致性校验：
  - `test/l10n_arb_consistency_test.dart` 会检查各语种 key 是否与 `app_en.arb` 对齐

## 测试

```bash
flutter test
```

## Android 发布签名

- 仓库已支持从 `android/key.properties` 读取正式签名配置。
- 可先复制 `android/key.properties.example` 为 `android/key.properties`，再填入真实 keystore 信息。
- 若未提供 `android/key.properties`，当前仍会回退为 debug 签名，方便本地侧载和 GitHub APK 分发；商店发布前请务必切换到正式签名。
