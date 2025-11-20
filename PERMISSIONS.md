# 网络请求和存储权限配置

## ✅ 已配置的权限

### iOS (ios/Runner/Info.plist)

#### 网络访问权限
```xml
<!-- 允许 HTTP/HTTPS 请求 -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

#### 存储访问权限
```xml
<!-- 存储访问说明，iOS 会在首次请求时向用户显示 -->
<key>NSUserTrackingUsageDescription</key>
<string>此应用需要访问设备存储以保存用户数据和缓存</string>
```

### Android (android/app/src/main/AndroidManifest.xml)

#### 网络权限
```xml
<!-- 允许应用访问互联网 -->
<uses-permission android:name="android.permission.INTERNET" />

<!-- 允许应用检查网络状态 -->
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

#### 存储权限
```xml
<!-- 读取外部存储（所有 Android 版本都需要） -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />

<!-- 写入外部存储（Android 6.0 - 9.x） -->
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="28" />

<!-- Android 10+ 媒体文件权限 -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
```

## 📱 Android 运行时权限处理

从 Android 6.0 (API 23) 开始，`WRITE_EXTERNAL_STORAGE` 和 `READ_EXTERNAL_STORAGE` 权限需要**运行时请求**。

### 1. 添加依赖

在 `pubspec.yaml` 中添加：

```yaml
dependencies:
  permission_handler: ^11.3.1
```

然后运行：
```bash
flutter pub get
```

### 2. 在代码中请求权限

创建权限工具类 `lib/utils/permissions.dart`：

```dart
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// 请求存储权限
  static Future<bool> requestStoragePermission() async {
    // 检查当前权限状态
    final status = await Permission.storage.status;

    if (status.isGranted) {
      return true;
    }

    // 请求权限
    final result = await Permission.storage.request();

    if (result.isGranted) {
      return true;
    }

    // 权限被拒绝，打开设置页面
    if (result.isDenied || result.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }

    return false;
  }

  /// 请求图片/媒体权限 (Android 13+)
  static Future<bool> requestMediaPermission() async {
    final statuses = await [
      Permission.mediaLibrary,
      Permission.photos,
      Permission.sensors,
    ].request();

    return statuses.values.every((status) =>
        status == PermissionStatus.granted ||
        status == PermissionStatus.limited);
  }

  /// 检查网络权限（通常不需要请求，系统会自动允许）
  static Future<bool> checkNetworkPermission() async {
    final status = await Permission.network.status;
    return status.isGranted;
  }

  /// 统一请求所有必要权限
  static Future<Map<Permission, PermissionStatus>> requestAllPermissions() async {
    return await [
      Permission.storage,
      Permission.mediaLibrary,
      Permission.photos,
    ].request();
  }
}
```

### 3. 在应用启动时请求权限

在 `lib/main.dart` 或 `lib/app.dart` 中添加：

```dart
import 'utils/permissions.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 请求权限
  await PermissionService.requestStoragePermission();

  runApp(MyApp());
}
```

### 4. 在需要时动态请求权限

```dart
import 'package:permission_handler/permission_handler.dart';

Future<void> saveFile() async {
  // 检查权限
  final status = await Permission.storage.status;

  if (status.isDenied) {
    // 请求权限
    final result = await Permission.storage.request();

    if (!result.isGranted) {
      // 显示错误信息
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('需要存储权限才能保存文件')),
      );
      return;
    }
  }

  // 执行保存操作
  await _performSave();
}
```

## 🔍 权限说明

### iOS
- **网络权限**：默认允许，无需特殊处理
- **存储权限**：iOS 使用沙盒机制，应用只能访问自己的存储空间，权限已在 Info.plist 中配置

### Android
- **网络权限 (INTERNET)**：所有版本都需要，调试和发布版本都适用
- **存储权限**：
  - **Android < 6.0 (API 23)**：安装时自动授予
  - **Android 6.0-9.x (API 23-28)**：需要运行时请求 `WRITE_EXTERNAL_STORAGE`
  - **Android 10+ (API 29+)**：使用 `READ_MEDIA_*` 权限，支持分区存储
  - **Android 13+ (API 33+)**：使用 `READ_MEDIA_IMAGES/VIDEO/AUDIO` 权限

## 🚀 验证权限配置

### iOS
1. 在模拟器或真机上运行应用
2. 打开设置 > 隐私与安全性 > 存储
3. 确认应用有存储权限

### Android
1. 运行 `adb shell pm list permissions`
2. 确认权限列表包含：
   - `android.permission.INTERNET`
   - `android.permission.READ_EXTERNAL_STORAGE`
   - `android.permission.WRITE_EXTERNAL_STORAGE` (Android < 10)
   - `android.permission.READ_MEDIA_*` (Android >= 10)

## 📝 注意事项

1. **权限最小化**：只请求应用实际需要的权限
2. **用户体验**：在请求权限前，向用户说明为什么需要这个权限
3. **权限被拒绝**：如果权限被拒绝，提供替代方案或引导用户到设置页面
4. **测试**：在 Android 6.0+ 的设备上测试运行时权限功能
5. **文档**：在 Google Play 和 App Store 的隐私政策中说明权限用途

## 🔗 参考链接

- [Flutter Permission Handler](https://pub.dev/packages/permission_handler)
- [Android 权限指南](https://developer.android.com/guide/topics/permissions/overview)
- [iOS 权限描述](https://developer.apple.com/documentation/uikit)
