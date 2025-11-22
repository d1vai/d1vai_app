# SnackBarHelper 自定义持续时间和持久化使用指南

## 新增功能

### 自定义持续时间
所有 SnackBar 方法现在都支持 `duration` 参数，允许您控制 toast 的显示时间。

### 持久化 Toast
通过设置 `duration` 为 `Duration.zero`，可以创建需要用户手动关闭的持久化 toast。

## 使用示例

### 1. 默认持续时间（4秒）
```dart
SnackBarHelper.showSuccess(
  context,
  title: 'Success',
  message: '操作已成功完成',
);
```

### 2. 短时间提示（2秒）
```dart
SnackBarHelper.showInfo(
  context,
  title: 'Tip',
  message: '这是一个快速提示',
  duration: const Duration(seconds: 2),
);
```

### 3. 长时间显示（10秒）
```dart
SnackBarHelper.showWarning(
  context,
  title: 'Important',
  message: '这是一个重要的警告信息，需要更长时间阅读',
  duration: const Duration(seconds: 10),
);
```

### 4. 持久化 Toast（用户手动关闭）
```dart
SnackBarHelper.showError(
  context,
  title: 'Critical Error',
  message: '发生了严重错误，需要您立即处理',
  duration: Duration.zero, // 持久化显示
  actionLabel: 'Fix Now',
  onActionPressed: () {
    // 修复错误的操作
  },
);
```

### 5. 与动作按钮结合使用
```dart
SnackBarHelper.showSuccess(
  context,
  title: 'Upload Complete',
  message: '文件上传成功，点击查看文件列表',
  actionLabel: 'View Files',
  onActionPressed: () {
    Navigator.pushNamed(context, '/files');
  },
  duration: const Duration(seconds: 8),
);
```

## 使用场景

### 短时间 (1-3秒)
- ✅ 轻微的成功提示
- ✅ 简单的操作确认
- ✅ 非关键信息

### 默认时间 (4秒)
- ✅ 一般信息提示
- ✅ 常规操作反馈

### 长时间 (5-10秒)
- ⚠️ 重要警告信息
- ⚠️ 需要用户阅读的详细说明
- ⚠️ 错误详情提示

### 持久化 (Duration.zero)
- 🚫 严重错误需要用户立即处理
- 🚫 关键系统状态变化
- 🚫 需要用户确认的操作

## 常见用例

### 替换前（无自定义持续时间）
```dart
SnackBarHelper.showError(
  context,
  title: 'Network Error',
  message: '无法连接到服务器，请检查网络设置',
);
```

### 替换后（带自定义持续时间）
```dart
SnackBarHelper.showError(
  context,
  title: 'Network Error',
  message: '无法连接到服务器，请检查网络设置',
  duration: const Duration(seconds: 6),
  actionLabel: 'Retry',
  onActionPressed: () => _retryConnection(),
);
```

## 注意事项

1. **向后兼容** - `duration` 参数是可选的，不指定时默认为 4 秒
2. **持久化建议** - 持久化 toast 建议搭配动作按钮使用
3. **用户体验** - 避免使用过多持久化 toast，会干扰用户体验
4. **时长选择** - 根据信息重要性和内容长度选择合适的持续时间

## 最佳实践

- ✅ 轻微信息：2-3秒
- ✅ 一般信息：4秒（默认）
- ✅ 重要警告：6-8秒
- ✅ 严重错误：持久化 + 动作按钮
- ✅ 避免使用超过 10 秒的持续时间
