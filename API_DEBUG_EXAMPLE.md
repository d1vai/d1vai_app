# API 错误调试功能使用说明

## 功能概述

当 d1vai_app 的 API 请求发生错误时，系统会自动打印详细的调试信息，包括：
- 📍 请求的 API 路径 (endpoint)
- 🔢 HTTP 状态码 (403, 502, 500 等)
- 📥 完整的响应详情
- 📤 请求体内容 (如果有)
- 💥 错误详情和堆栈信息

## 调试信息示例

### 1. HTTP 错误 (如 403, 502, 500)

```
═══════════════════════════════════════
API HTTP Error Detected
═══════════════════════════════════════
📍 API Path: /api/users/profile
🔢 HTTP Status Code: 403
📥 Response Body: {"code":403,"msg":"Forbidden","data":null}
📦 Parsed JSON: {"code":403,"msg":"Forbidden","data":null}
═══════════════════════════════════════
```

### 2. 业务逻辑错误

```
═══════════════════════════════════════
API Business Error Detected
═══════════════════════════════════════
📍 API Path: /api/projects/create
🔢 Status Code: 200
📝 Error Message: Project name already exists
📤 Request Body: {"name":"My Project","description":"A test project"}
📥 Response Body: {"code":-1,"msg":"Project name already exists","data":null}
═══════════════════════════════════════
```

### 3. 网络错误

```
🔄 Network error on attempt 1/3, retrying in 1000ms: SocketException: Connection failed (OS Error: Connection refused)
📍 API Path: /api/projects/list
═══════════════════════════════════════
Network Error - Max Retries Exceeded
═══════════════════════════════════════
📍 API Path: /api/projects/list
🔢 Retry Count: 3
💥 SocketException: Connection failed (OS Error: Connection refused)
═══════════════════════════════════════
```

### 4. 服务器错误 (5xx)

```
🔄 Server error on attempt 1/3, retrying in 1000ms: HTTP Error: 502 Bad Gateway
📍 API Path: /api/chat/send
═══════════════════════════════════════
Server Error - Max Retries Exceeded
═══════════════════════════════════════
📍 API Path: /api/chat/send
🔢 Retry Count: 3
💥 HTTP Error: 502 Bad Gateway
═══════════════════════════════════════
```

### 5. 文件上传错误

```
🌐 API Request: POST /upload
📁 File Name: avatar.png
📏 File Size: 245760 bytes
═══════════════════════════════════════
API Upload Error Detected
═══════════════════════════════════════
📍 API Path: /upload
🔢 HTTP Status Code: 413
📥 Response Body: {"code":413,"msg":"File too large","data":null}
═══════════════════════════════════════
```

### 6. 流式请求错误

```
🌐 API Request: POST (Stream) /api/chat/stream
📤 Request Body: {"message":"Hello","sessionId":"abc123"}
═══════════════════════════════════════
API Stream Error Detected
═══════════════════════════════════════
📍 API Path: /api/chat/stream
🔢 HTTP Status Code: 500
📥 Response Body: {"code":500,"msg":"Internal server error","data":null}
═══════════════════════════════════════
```

## 支持的 HTTP 方法

所有 HTTP 方法都会记录请求信息：
- `GET` - 打印 API 路径
- `POST` - 打印 API 路径和请求体
- `PUT` - 打印 API 路径和请求体
- `PATCH` - 打印 API 路径和请求体
- `DELETE` - 打印 API 路径
- `POST (Stream)` - 打印 API 路径和请求体
- `POST /upload` - 打印文件信息和大小

## 重试机制日志

当启用重试机制时 (retries > 0)，系统会记录每次重试的详细信息：
- 当前尝试次数 / 总次数
- 延迟时间 (指数退避)
- 错误详情

## 查看日志

在 Flutter 应用中，这些调试信息会通过 `debugPrint` 输出，可以在：
- 控制台中查看
- Flutter Inspector 的 Logs 面板中查看
- 集成开发环境 (IDE) 的调试控制台中查看

## 注意事项

1. 这些调试信息只在 Debug 模式下输出，Release 模式不会输出
2. 调试信息使用 `debugPrint`，不会影响应用性能
3. 敏感信息 (如密码) 请确保不会在请求体中打印
4. 调试信息中的 emoji 图标有助于快速识别不同类型的日志

## 文件位置

调试功能实现在：`lib/core/api_client.dart`
