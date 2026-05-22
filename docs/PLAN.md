# 项目 PLAN - Desktop Project Editor

## 当前状态
- 当前阶段：`M1`
- 当前里程碑状态：`[IN-PROGRESS]`
- 当前工作方向：统一桌面项目窗口入口，复用现有本地工作区编辑器链路

## 里程碑列表

### [IN-PROGRESS] M1. 跨平台多窗口基础架构
- [x] 建立桌面窗口启动参数模型
- [x] 抽象 Windows 新进程打开项目窗口服务
- [x] 让独立项目窗口支持欢迎页和最近工作区
- [x] 让 `/local-workspace` 基础链路支持 macOS + Windows
- [x] 完成当前改动范围分析与测试
- [x] 完成 macOS 构建验证
- [ ] 完成 Windows 构建验证
- [ ] 评估并补齐第一轮缺口后再决定是否标记完成

### [TODO] M2. 原生拖拽支持（macOS + Windows）
- macOS：Dock / open-document / AppDelegate 稳定打开独立窗口
- Windows：图标 / 任务栏拖拽 + runner 参数链路
- 平台层统一路径事件结构

### [TODO] M3. 高密度文件浏览器
- 优化树形结构与大目录性能
- 提升桌面端信息密度
- 增加更明确的最近项目 / 快速切换入口

### [TODO] M4. 轻量代码编辑器集成与交互完善
- 编辑器标签、多缓冲区、保存状态继续打磨
- 查找、折叠、快捷键等轻量特性补齐
- 避免 IDE 化膨胀

## M1 实施说明
- 主应用仍保留现有入口，不强制推翻现有产品壳。
- 新增“本地项目窗口”轻量入口：
  - macOS：继续复用现有原生窗口链路
  - Windows：通过命令行参数和新进程直接进入本地项目窗口
- 新窗口默认先进入欢迎页；收到路径时直接打开 `/local-workspace`
- 本地工作区服务从“仅 macOS”扩展为“macOS + Windows”

## 验证清单
- [ ] `flutter analyze`
- [x] `flutter analyze lib/main.dart lib/screens/desktop_workspace_welcome_screen.dart lib/screens/local_workspace_screen.dart lib/services/desktop_window_service.dart lib/models/desktop_window_launch_configuration.dart lib/services/local_workspace_service.dart lib/services/workspace_local_service.dart lib/widgets/chat/project_chat/code_tab/project_chat_code_tab.dart test/desktop_window_launch_configuration_test.dart`
- [x] `flutter test test/desktop_window_launch_configuration_test.dart`
- [x] `flutter build macos`
- [ ] `flutter build windows`

## BLOCKERS
- `flutter build windows` 需要 Windows 主机；在当前 macOS 环境中只能记录失败/不可执行情况，不能作为 Windows 构建通过证据。
- 仓库级 `flutter analyze` 当前会被 `third_party/nativeapi-flutter` 下既有 example/test 错误拦住；这些错误与本次桌面项目窗口改动无关，但会阻止“全仓绿”的结论。
