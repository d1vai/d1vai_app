# iOS 和 Android 权限配置完整版

## ✅ 已配置的权限

### iOS 配置 (ios/Runner/Info.plist)

#### 1. 网络访问权限
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```
- **用途**：允许 HTTP/HTTPS 网络请求
- **适用范围**：所有 iOS 版本
- **构建版本**：Debug 和 Release 都适用

#### 2. 存储访问权限
```xml
<key>NSUserTrackingUsageDescription</key>
<string>此应用需要访问设备存储以保存用户数据和缓存</string>
```
- **用途**：访问设备存储空间
- **适用范围**：iOS 11+
- **说明**：iOS 使用沙盒机制，应用只能访问自己的存储空间

#### 3. 摄像头权限 (新增)
```xml
<key>NSCameraUsageDescription</key>
<string>此应用需要访问相机以拍摄头像照片</string>
```
- **用途**：拍照修改头像
- **适用范围**：所有 iOS 版本
- **触发时机**：用户首次尝试拍照时

#### 4. 相册访问权限 (新增)
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>此应用需要访问相册以选择头像照片</string>
```
- **用途**：从相册选择头像
- **适用范围**：所有 iOS 版本
- **触发时机**：用户首次尝试访问相册时

### Android 配置 (android/app/src/main/AndroidManifest.xml)

#### 1. 网络权限
```xml
<uses-permission android:name="android.permission.INTERNET" />
```
- **用途**：允许应用访问互联网
- **适用范围**：所有 Android 版本
- **构建版本**：Debug、Profile、Release 都适用

#### 2. 网络状态权限
```xml
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```
- **用途**：检查网络连接状态
- **适用范围**：所有 Android 版本

#### 3. 存储权限 (按 Android 版本区分)

**Android 6.0 - 9.x (API 23-28)**：
```xml
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="28" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```
- **用途**：读写外部存储
- **特殊说明**：`WRITE_EXTERNAL_STORAGE` 在 Android 10+ 已废弃，使用 `maxSdkVersion="28"` 限制

**Android 10+ (API 29+)**：
```xml
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
```
- **用途**：访问媒体文件（使用分区存储）
- **说明**：Android 10 引入分区存储，应用需要请求特定媒体权限

#### 4. 摄像头权限 (新增)
```xml
<uses-permission android:name="android.permission.CAMERA" />
```
- **用途**：拍照修改头像
- **适用范围**：所有 Android 版本
- **权限类型**：危险权限，需要运行时请求

## 🔐 权限类型说明

### iOS 权限类型

| 权限类型 | 描述 | 提示时机 |
|----------|------|----------|
| NSAppTransportSecurity | 网络访问 | 应用启动时自动生效 |
| NSUserTrackingUsageDescription | 存储访问 | iOS 11+ 系统使用 |
| NSCameraUsageDescription | 相机访问 | 首次尝试使用相机时 |
| NSPhotoLibraryUsageDescription | 相册访问 | 首次尝试访问相册时 |

### Android 权限类型

| 权限类型 | 描述 | 请求时机 | Android 版本 |
|----------|------|----------|-------------|
| INTERNET | 网络访问 | 安装时自动授予 | 全部 |
| ACCESS_NETWORK_STATE | 网络状态 | 安装时自动授予 | 全部 |
| WRITE_EXTERNAL_STORAGE | 外部存储写入 | 运行时请求 | API 23-28 |
| READ_EXTERNAL_STORAGE | 外部存储读取 | 运行时请求 | 23+ |
| READ_MEDIA_IMAGES | 媒体图片读取 | 运行时请求 | API 33+ |
| READ_MEDIA_VIDEO | 媒体视频读取 | 运行时请求 | API 33+ |
| READ_MEDIA_AUDIO | 媒体音频读取 | 运行时请求 | API 33+ |
| CAMERA | 摄像头 | 运行时请求 | 全部 |

## 📱 运行时权限处理

### 摄像头权限 (Android)

从 Android 6.0 (API 23) 开始，`CAMERA` 权限需要运行时请求。

**image_picker 插件自动处理**：
项目中使用的 `image_picker` 插件会自动处理以下权限请求：
- Android：自动请求 `CAMERA` 和存储权限
- iOS：根据 Info.plist 中的描述自动处理权限提示

**权限流程**：
1. 用户点击拍照按钮
2. 系统检查权限状态
3. 如果未授权，显示权限请求对话框
4. 用户授权后，启动相机

### 存储权限 (Android)

不同 Android 版本的存储权限处理方式不同：

**Android 6.0 - 9.x**：
- 需要请求 `WRITE_EXTERNAL_STORAGE` 和 `READ_EXTERNAL_STORAGE`
- 权限在应用设置中可以手动撤销

**Android 10 - 12**：
- 使用分区存储，应用不需要 `WRITE_EXTERNAL_STORAGE` 权限即可写入自己的目录
- 需要 `READ_EXTERNAL_STORAGE` 访问其他应用的文件
- 可以通过 `android:requestLegacyExternalStorage="true"` 使用旧版存储模型

**Android 13+ (API 33+)**：
- 使用细粒度权限 `READ_MEDIA_IMAGES/VIDEO/AUDIO`
- `READ_EXTERNAL_STORAGE` 已被废弃

## 🎯 头像修改功能权限流程

### iOS 流程
1. 用户点击头像
2. 选择"拍照"选项
3. 系统显示权限提示（首次使用时）
4. 用户授权后，启动相机
5. 拍照后保存并上传

### Android 流程
1. 用户点击头像
2. 选择"拍照"选项
3. 系统检查权限
4. 如果未授权，显示权限请求对话框
5. 用户授权后，启动相机
6. 拍照后保存并上传

## 🔧 配置验证

### iOS 验证
在模拟器或真机上运行应用：
1. 进入 Profile 页面
2. 点击头像
3. 选择"拍照"
4. 查看是否出现权限提示
5. 在设置 > 隐私与安全性 > 相机中确认权限已授予

### Android 验证
1. 进入 Profile 页面
2. 点击头像
3. 选择"拍照"
4. 查看是否出现权限请求对话框
5. 授权后检查相机是否正常启动
6. 权限可在设置 > 应用 > d1vai_app > 权限中查看和管理

## 📊 权限覆盖矩阵

| 权限 | iOS Debug | iOS Release | Android Debug | Android Release |
|------|-----------|-------------|---------------|-----------------|
| 网络访问 | ✅ | ✅ | ✅ | ✅ |
| 存储访问 | ✅ | ✅ | ✅ | ✅ |
| 摄像头 | ✅ | ✅ | ✅ | ✅ |
| 相册访问 | ✅ | ✅ | ✅ | ✅ |

## ⚠️ 注意事项

### iOS 注意事项
1. **Info.plist 描述文本**：必须用中文或英文清晰描述权限用途
2. **权限最小化**：只请求实际需要的权限
3. **审核指南**：确保权限描述符合 Apple 审核指南

### Android 注意事项
1. **运行时权限**：`CAMERA` 和存储权限需要在运行时请求
2. **权限拒绝**：用户拒绝权限后，应提供清晰的提示和引导
3. **版本兼容性**：不同 Android 版本的权限模型有差异
4. **最小组件**：在 AndroidManifest.xml 中确保权限声明正确

## 🎉 总结

### 已配置的权限
✅ 网络请求权限 (iOS + Android)
✅ 存储权限 (iOS + Android，涵盖所有版本)
✅ 摄像头权限 (iOS + Android，新增)
✅ 相册访问权限 (iOS + Android，新增)

### 适用版本
✅ iOS：所有版本 (Debug + Release)
✅ Android：所有版本 (API 16+，Debug + Release)

### 自动处理
✅ image_picker 插件自动处理相机权限
✅ image_picker 插件自动处理存储权限
✅ 系统自动处理权限提示和管理

现在应用具备完整的权限配置，可以在 iOS 和 Android 上正常进行头像拍照和选择操作！🚀
