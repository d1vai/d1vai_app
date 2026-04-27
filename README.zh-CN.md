# d1vai_app

<p align="center">
  <strong>面向构建者、运营者和现代产品团队的 AI 原生移动工作台。</strong>
</p>

<p align="center">
  <code>d1v.ai</code> 官方 Flutter 客户端。你可以在手机上创建项目、导入仓库、与 AI 协作、查看文件、监控部署，并处理账户和运营事项。
</p>

<p align="center">
  <a href="https://www.d1v.ai">官网</a> ·
  <a href="https://github.com/d1vai/d1vai_app/releases">下载发布版</a> ·
  <a href="https://www.d1v.ai/docs/overview">文档</a> ·
  <a href="./docs/DEVELOPER_GUIDE.md">开发者指南</a> ·
  <a href="./README.md">English</a>
</p>

<p align="center">
  <a href="https://github.com/d1vai/d1vai_app/blob/main/LICENSE"><img alt="License" src="https://img.shields.io/badge/license-MIT-black.svg"></a>
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white">
  <img alt="Dart" src="https://img.shields.io/badge/Dart-3.10+-0175C2?logo=dart&logoColor=white">
  <img alt="Platforms" src="https://img.shields.io/badge/platform-iOS%20%7C%20Android-111827">
  <img alt="Status" src="https://img.shields.io/badge/status-open%20source-16a34a">
</p>

<p align="center">
  <img src="./docs/readme-assets/app-overview.png" alt="d1v.ai mobile app overview" width="360">
</p>

---

## 它是什么

`d1vai_app` 不是一个只负责通知的配套 App，也不是简单把 AI 聊天塞进手机里的外壳。它是一个面向真实项目工作流的移动控制面板。

它把 `d1v.ai` 的核心能力带到移动端：

- 用 AI 创建新项目
- 导入 GitHub 仓库或本地压缩包
- 在手机上继续项目会话和 AI 协作
- 查看代码、文件、预览状态和部署上下文
- 管理账户、计费、使用量、设置、文档和社区入口

## 为什么它不一样

- 不是“聊天优先”，而是“工作流优先”
  从 prompt 到项目、文件、部署和运营状态，链路是连续的。
- 离开电脑仍然有用
  不是只能看消息，而是真能在手机上看项目、看预览、看部署、看分析。
- 直接连到真实项目表面
  GitHub 导入、工作区状态、账单能力、项目详情都在同一个产品里。
- 按正式产品来做
  认证、引导、诊断、主题、多语言和设置不是附属功能，而是完整产品的一部分。

## 产品预览

<table>
  <tr>
    <td align="center" width="33%">
      <img src="./docs/readme-assets/projects-screen.png" alt="d1v.ai projects screen" width="220"><br>
      <strong>项目列表</strong><br>
      导入仓库、管理活跃项目，并快速进入项目聊天。
    </td>
    <td align="center" width="33%">
      <img src="./docs/readme-assets/community-screen.png" alt="d1v.ai community screen" width="220"><br>
      <strong>社区</strong><br>
      浏览公开作品、分享项目，并查看创作者动态。
    </td>
    <td align="center" width="33%">
      <img src="./docs/readme-assets/docs-screen.png" alt="d1v.ai docs screen" width="220"><br>
      <strong>文档</strong><br>
      在应用内搜索产品说明、工作流和实现参考。
    </td>
  </tr>
</table>

## 你可以用它做什么

### 构建

用 prompt 新建项目，导入已有代码库，或在移动端继续 AI 项目会话，不必把流程切碎到多个工具里。

### 查看

打开项目文件，检查结构化结果，阅读生成代码，并在离开桌面环境时保持对工作区状态的感知。

### 运营

从一个移动控制面板里查看部署状态、预览可用性、分析数据、使用量、钱包活动和项目健康度。

### 协作

把 AI 放进真实工作会话里，而不是孤立的聊天窗口。项目上下文、模型切换、会话连续性和操作流都在同一个应用中。

### 管理

统一处理登录认证、引导流程、邀请、GitHub 集成、账户设置、文档和社区参与。

## 使用场景

- 创业者在路上查看预览部署是否完成，并立即进入项目聊天继续推进工作。
- 产品工程师在手机上快速审阅 AI 生成的代码和项目文件，再回到桌面完成后续动作。
- 运营或负责人查看使用量、计费和部署状态，而不需要切换多个内部后台。
- AI 原生团队把它当作远程工作区和活跃项目的移动控制面板。

## 3 分钟理解产品

1. 登录并连接工作区或 GitHub 集成。
2. 用 prompt 创建项目，或导入现有仓库。
3. 打开项目聊天，继续和 AI 协作构建。
4. 查看文件、代码、预览状态和部署上下文。
5. 在同一个应用里查看分析、使用量、计费和账户设置。

## 为什么把它开源

这个仓库不仅是产品客户端，也是一份可参考的实现样本。

- 它展示了 AI 原生工作流在 Flutter 移动端里该如何组织，而不是只做一个聊天入口。
- 它展示了远程工作区、项目操作和部署可视化在移动端控制面的组织方式。
- 它提供了认证、引导、GitHub 导入、诊断和多功能产品架构的实用参考。

如果你关注 Flutter 架构、AI 产品体验或移动端运营工具，这个仓库应该是可读、可扩展、可借鉴的。

## 适合谁

- 希望随时推进产品的创业者
- 需要移动端快速感知项目状态的产品工程师
- 基于远程工作区协作的 AI 原生团队
- 希望拥有完整移动控制台而不是临时内部工具的构建者

## 当前状态

- 活跃维护中的代码库
- 以 MIT License 开源
- 面向 iOS 和 Android
- 从一开始就支持多语言和主题能力

## 路线方向

当前最重要的方向包括：

- 更强的移动端项目工作流和导入流程
- 更深入的 AI 会话连续性与代码 / 文件处理
- 更完整的部署、分析和运营可见性
- 持续优化计费、设置、文档和社区相关体验

## 快速链接

- [官网](https://www.d1v.ai)
- [最新发布版](https://github.com/d1vai/d1vai_app/releases)
- [开发者指南](./docs/DEVELOPER_GUIDE.md)
- [English README](./README.md)
- [许可证](./LICENSE)
