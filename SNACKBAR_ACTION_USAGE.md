# SnackBarHelper 动作按钮使用示例

## 基本用法（不推荐动作按钮）

```dart
SnackBarHelper.showSuccess(
  context,
  title: 'Success',
  message: '操作已成功完成',
);
```

## 推荐用法（使用动作按钮）

```dart
// 1. 成功提示 + 重试按钮
SnackBarHelper.showSuccess(
  context,
  title: 'Upload Complete',
  message: '文件上传成功',
  actionLabel: 'View',
  onActionPressed: () {
    Navigator.pushNamed(context, '/files');
  },
);

// 2. 错误提示 + 重试按钮
SnackBarHelper.showError(
  context,
  title: 'Upload Failed',
  message: '文件上传失败，请检查网络连接',
  actionLabel: 'Retry',
  onActionPressed: () {
    // 重新执行上传操作
    _retryUpload();
  },
);

// 3. 警告提示 + 设置按钮
SnackBarHelper.showWarning(
  context,
  title: 'Permission Required',
  message: '需要相机权限才能继续',
  actionLabel: 'Settings',
  onActionPressed: () {
    // 打开应用设置
    openAppSettings();
  },
);

// 4. 信息提示 + 查看详情按钮
SnackBarHelper.showInfo(
  context,
  title: 'New Update',
  message: '应用有新版本可用',
  actionLabel: 'Update',
  onActionPressed: () {
    // 打开应用商店
    openAppStore();
  },
);
```

## 在现有代码中使用

### 替换前（无动作按钮）
```dart
SnackBarHelper.showError(
  context,
  title: 'Error',
  message: 'Network connection failed',
);
```

### 替换后（带动作按钮）
```dart
SnackBarHelper.showError(
  context,
  title: 'Error',
  message: 'Network connection failed',
  actionLabel: 'Retry',
  onActionPressed: () {
    _refreshData();
  },
);
```

## 使用场景

1. **网络错误** - 提供"重试"按钮
2. **操作成功** - 提供"查看"或"详情"按钮
3. **权限问题** - 提供"设置"按钮
4. **更新提示** - 提供"更新"按钮
5. **需要用户确认** - 提供"确认"或"取消"按钮

## 注意事项

- 动作按钮参数是可选的，不会破坏现有代码
- 只有同时提供 `actionLabel` 和 `onActionPressed` 时，动作按钮才会显示
- 建议动作按钮的文本简洁明了，通常 1-2 个词
