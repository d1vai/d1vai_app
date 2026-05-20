# macOS App Store Review Assets

这个目录放 `d1v` 提交 macOS App Store 审核时需要的本地审核资产方案。

已纳入 Git 的内容：

- `metadata.zh-CN.md`
- `review-notes.en-US.md`
- `screenshots-plan.zh-CN.md`
- `../../../tool/generate_macos_review_assets.sh`

只保留本地、不提交 Git 的内容：

- `local-assets/screenshots/1440x900/*.png`
- `local-assets/screenshots/2880x1800/*.png`

生成命令：

```bash
bash tool/generate_macos_review_assets.sh
```

默认会使用仓库里已有的页面截图源图，生成符合 macOS App Store 上传尺寸的审核截图。

推荐上传：

- 截图：优先使用 `1440x900`
- 数量：6 张
- App Preview：macOS 版本本轮先不提交，先用截图完成审核资产
