# d1vai_app Analytics 对齐执行计划（P0-P3）

## 思想
- 先修稳定性，再补功能：先完成 P0，保证 enable 主链路可用，再做设置与多 Tab 扩展。
- 对齐以 web 为基准，但移动端保留简洁交互：优先对齐能力与数据口径，不盲目复制复杂 UI。
- 接口统一优先：逐步淘汰旧 `/api/projects/{id}/analytics/*` 路径，统一到 `/api/analytics/*` 与 `/api/analytics/data/*`。
- 每个阶段完成后先做格式/检查，确认无报错再打勾。

## TODO（按顺序执行）
- [x] P0：修复 enable/install 响应解析（移除 `['data']` 误用），并在 init 成功后刷新项目状态。
- [x] P1：在 app 端补齐 Setting 管理能力（Re-enable、Share Access、Copy Tracking Code）。
- [x] P2：将 app analytics 启用后页面升级为多 Tab 结构（Data/Events/Sessions/Realtime/Compare/Reports/Setting）。
- [x] P3：清理旧 `AnalyticsService` 端点并统一 analytics 状态判定逻辑（`analytics_id` 优先）。

## 共识（保留）
- 涉及前端 UI/交互：必须跑一次检查再打勾。
- 任何代码改动：必须跑一次检查并修到 0 error。
- 每个前端 task 需要完善用户反馈（toast / loading / 关键状态说明）。
