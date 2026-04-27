# d1vai_app

<p align="center">
  <strong>AI-native mobile workspace for builders, operators, and modern product teams.</strong>
</p>

<p align="center">
  <strong>面向下一代构建者与产品团队的 AI 原生移动工作台。</strong>
</p>

<p align="center">
  <a href="https://github.com/d1vai/d1vai_app/blob/main/LICENSE"><img alt="License" src="https://img.shields.io/badge/license-MIT-black.svg"></a>
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white">
  <img alt="Dart" src="https://img.shields.io/badge/Dart-3.10+-0175C2?logo=dart&logoColor=white">
  <img alt="Platforms" src="https://img.shields.io/badge/platform-iOS%20%7C%20Android-111827">
  <img alt="Status" src="https://img.shields.io/badge/status-open%20source-16a34a">
</p>

---

## English

### What It Is

`d1vai_app` is the official Flutter mobile client for `d1v.ai`.

It turns the core d1v workflow into a portable mobile experience: create projects, connect workspaces, chat with AI, inspect files, monitor deployments, review analytics, and manage your account from a single app.

This is not a lightweight companion shell. It is designed as a serious mobile surface for AI-assisted building and operational control.

### Why It Matters

- AI workflow, not just chat: move from prompt to project, deployment, and iteration inside one mobile product.
- Mobile-first control plane: review code, inspect files, monitor status, and act fast when you are away from desktop.
- Production-aware UX: account flows, project management, deployment visibility, analytics surfaces, and community/docs access are all integrated.
- International by default: multilingual support is built in from the start.

### Core Capabilities

- Authentication
  Email verification login, password login, Solana login, Sui login, onboarding, invitation flows.
- Project operations
  Create AI projects, import repositories, import local zip archives, browse projects, inspect project details.
- AI collaboration
  Execute project sessions, continue chats, manage mobile chat state, switch models, and keep workspace status visible.
- File and code workflows
  Read project files, preview structured content, edit supported files, and sync changes back to GitHub.
- Deployment and analytics
  Track preview state, deployment context, operational metrics, and activity surfaces.
- Platform experience
  Theme support, runtime API override, diagnostics, docs, community, orders, and settings.

### Designed For

- Founders shipping from anywhere
- Product engineers who want fast operational visibility on mobile
- AI-native teams building with remote workspaces
- Builders who need a polished control surface instead of raw internal tooling

### Open Source

This repository is now published as an open-source Flutter client under the MIT License.

If you are evaluating mobile architecture, AI product UX, or workspace-driven app patterns, this codebase is meant to be readable, practical, and extensible.

### Developer Docs

The previous README content is preserved and expanded as developer-facing documentation:

- [Developer Guide](./docs/DEVELOPER_GUIDE.md)

---

## 中文

### 项目定位

`d1vai_app` 是 `d1v.ai` 的官方 Flutter 移动客户端。

它把 d1v 的核心工作流真正带到移动端：创建项目、连接工作区、与 AI 协作、查看文件、关注部署状态、追踪分析数据，并在同一个应用中完成账户与项目管理。

这不是一个只负责“消息通知”的配套 App，而是一个面向真实构建场景的移动工作台。

### 为什么值得关注

- 不只是 AI 聊天，而是完整工作流：从 prompt 到项目、部署、迭代，形成闭环。
- 真正的移动控制面板：在离开电脑时，依然可以快速查看代码、读文件、看状态、做决策。
- 面向生产环境的产品设计：认证、项目管理、部署视图、分析数据、社区与文档能力都已打通。
- 天然国际化：从一开始就支持多语言与全球化使用场景。

### 主要能力

- 认证体系
  邮箱验证码登录、密码登录、Solana 登录、Sui 登录、邀请与 onboarding 流程。
- 项目工作流
  AI 创建项目、仓库导入、本地 ZIP 导入、项目浏览与详情管理。
- AI 协作体验
  执行项目会话、持续聊天、移动端会话管理、模型切换、工作区状态可视化。
- 文件与代码能力
  浏览项目文件、预览结构化内容、编辑可编辑文件，并同步到 GitHub。
- 部署与分析
  查看预览状态、部署上下文、运行数据与项目活跃度。
- 平台级体验
  支持主题切换、运行时 API 覆盖、诊断信息导出，以及文档、社区、订单、设置等完整入口。

### 适合谁

- 希望随时随地推进产品的创业者
- 需要移动端快速掌控项目状态的产品工程师
- 基于远程工作区与 AI 协作构建产品的团队
- 希望拥有完整移动控制台，而不是临时内部工具的构建者

### 开源说明

本仓库现以 MIT License 开源。

如果你关注 Flutter 移动架构、AI 产品交互、远程工作区驱动的应用形态，`d1vai_app` 会是一个兼顾工程实用性与产品表达力的参考项目。

### 开发者文档

原有 README 中偏开发者导向的内容已迁移为独立文档：

- [开发者指南 / Developer Guide](./docs/DEVELOPER_GUIDE.md)

---

## Quick Links

- [Developer Guide](./docs/DEVELOPER_GUIDE.md)
- [License](./LICENSE)

## Local Stripe Debug Setup

For local `flutter run` / debug builds, keep Stripe compile-time values in a local file:

1. Copy `.env/dev.example.json` to `.env/dev.json`
2. Replace `STRIPE_PUBLISHABLE_KEY` with your real key
3. Run from VS Code using the included launch config, or run manually:

```bash
flutter run --dart-define-from-file=.env/dev.json
```

The `.env/` folder is gitignored by default, so local keys stay out of the repo.
