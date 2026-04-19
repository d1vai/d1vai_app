import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart';
import '../utils/image_compressor.dart';
import 'auth_expiry_bus.dart';

class ApiResponse<T> {
  final int code;
  final String msg;
  final T? data;

  ApiResponse({required this.code, required this.msg, this.data});

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    // Backend has two styles of responses:
    // 1) Wrapped in { code, msg, data } (legacy BaseResponse)
    // 2) Raw JSON payload (e.g. /api/billing/usage)
    if (json.containsKey('code') && json.containsKey('msg')) {
      return ApiResponse(
        code: json['code'] ?? -1,
        msg: json['msg'] ?? 'Unknown error',
        data: json['data'] != null && fromJsonT != null
            ? fromJsonT(json['data'])
            : json['data'],
      );
    }

    // Treat raw payloads as successful responses and decode directly.
    return ApiResponse(
      code: 0,
      msg: 'success',
      data: fromJsonT != null ? fromJsonT(json) : json as T,
    );
  }

  bool get isSuccess => code == 0;
}

class ApiClientException implements Exception {
  final String message;
  final int? statusCode;
  final int? code;
  final dynamic data;

  const ApiClientException(
    this.message, {
    this.statusCode,
    this.code,
    this.data,
  });

  @override
  String toString() {
    if (statusCode != null) {
      return 'HTTP Error: $statusCode $message';
    }
    return 'ApiClientException: $message';
  }
}

class ApiClient {
  static const String _envBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // Override via `--dart-define=API_BASE_URL=...` or in-app settings.
    defaultValue: 'https://api.d1v.ai',
  );

  static const String _prefsBaseUrlKey = 'api_base_url_override';
  static const String _prefsLastErrorKey = 'api_last_error';
  static String? _runtimeBaseUrl;
  static bool _configLoaded = false;

  static String get envBaseUrl => _envBaseUrl;
  static String? get runtimeBaseUrl => _runtimeBaseUrl;

  /// Effective API base URL (runtime override > build-time env).
  static String get baseUrl {
    final raw = (_runtimeBaseUrl ?? _envBaseUrl).trim();
    if (raw.endsWith('/')) return raw.substring(0, raw.length - 1);
    return raw;
  }

  final http.Client client;

  // 缓存 SharedPreferences 实例以避免重复调用
  static SharedPreferences? _sharedPreferences;

  ApiClient({http.Client? client}) : client = client ?? http.Client() {
    _init();
  }

  void _noteLastApiError({String? endpoint, int? statusCode, String? message}) {
    final ep = (endpoint ?? '').trim();
    if (ep.isEmpty) return;
    final msg = (message ?? '').trim();
    final payload = <String, dynamic>{
      'at': DateTime.now().toIso8601String(),
      'endpoint': ep,
      if (statusCode != null) 'status': statusCode,
      if (msg.isNotEmpty)
        'message': msg.length > 800 ? msg.substring(0, 800) : msg,
    };
    unawaited(() async {
      try {
        _sharedPreferences ??= await SharedPreferences.getInstance();
        await _sharedPreferences!.setString(
          _prefsLastErrorKey,
          jsonEncode(payload),
        );
      } catch (_) {
        // Best-effort only.
      }
    }());
  }

  /// Build a request URI from the configured baseUrl and a relative endpoint.
  ///
  /// The app historically used endpoints that include `/api/...`, but some builds
  /// or runtime overrides may set a base URL that already ends with `/api`.
  /// This helper prevents accidental double prefixes like `/api/api/...`.
  Uri _buildUri(String endpoint, {Map<String, String>? queryParams}) {
    final base = Uri.parse(baseUrl);
    final endpointUri = Uri.parse(endpoint);

    // Path normalize
    var basePath = base.path;
    if (basePath.endsWith('/')) {
      basePath = basePath.substring(0, basePath.length - 1);
    }

    var epPath = endpointUri.path;
    if (!epPath.startsWith('/')) epPath = '/$epPath';

    // Avoid double `/api` when baseUrl already includes it.
    if (basePath.endsWith('/api') && epPath.startsWith('/api/')) {
      epPath = epPath.substring('/api'.length);
    } else if (basePath == '/api' && epPath == '/api') {
      epPath = '';
    }

    final combinedPath = (basePath.isEmpty ? '' : basePath) + epPath;

    // Merge queries from baseUrl, endpoint string, and explicit params.
    final mergedQuery = <String, String>{
      ...base.queryParameters,
      ...endpointUri.queryParameters,
      if (queryParams != null) ...queryParams,
    };

    return base.replace(
      path: combinedPath.isEmpty ? '/' : combinedPath,
      queryParameters: mergedQuery.isEmpty ? null : mergedQuery,
    );
  }

  bool _isPublicEndpoint(String? endpoint) {
    if (endpoint == null) return false;
    return endpoint.startsWith('/api/user/login') ||
        endpoint == '/api/user/verify-code' ||
        endpoint.startsWith('/api/user/password/') ||
        endpoint.startsWith('/api/user/public/') ||
        endpoint.startsWith('/api/user/activity/prompt-daily/slug/') ||
        endpoint.startsWith('/api/upload/pic') ||
        endpoint.startsWith('/api/solana/login') ||
        endpoint.startsWith('/api/sui/login');
  }

  Future<void> _init() async {
    _sharedPreferences ??= await SharedPreferences.getInstance();
    await _ensureConfigLoaded();
  }

  static Future<void> ensureInitialized() async {
    await _ensureConfigLoaded();
  }

  static Future<void> setRuntimeBaseUrlOverride(String? value) async {
    _sharedPreferences ??= await SharedPreferences.getInstance();
    final v = (value ?? '').trim();
    if (v.isEmpty) {
      await _sharedPreferences!.remove(_prefsBaseUrlKey);
      _runtimeBaseUrl = null;
    } else {
      await _sharedPreferences!.setString(_prefsBaseUrlKey, v);
      _runtimeBaseUrl = v;
    }
    _configLoaded = true;
  }

  static Future<void> _ensureConfigLoaded() async {
    if (_configLoaded) return;
    _sharedPreferences ??= await SharedPreferences.getInstance();
    _runtimeBaseUrl = _sharedPreferences!.getString(_prefsBaseUrlKey);
    _configLoaded = true;
  }

  Future<Map<String, String>> _getHeaders() async {
    _sharedPreferences ??= await SharedPreferences.getInstance();
    await _ensureConfigLoaded();

    final tokenRaw = _sharedPreferences!.getString('auth_token');
    final tokenTrimmed = tokenRaw?.trim();
    // Some callers might accidentally persist "Bearer <token>" or include whitespace.
    final token =
        (tokenTrimmed != null &&
            tokenTrimmed.toLowerCase().startsWith('bearer '))
        ? tokenTrimmed.substring('bearer '.length).trim()
        : tokenTrimmed;

    if (kDebugMode) {
      final t = (token ?? '').trim();
      if (t.isEmpty) {
        debugPrint('🔐 Auth: missing');
      } else {
        final suffix = t.length <= 6 ? t : t.substring(t.length - 6);
        final kind = t.startsWith('eyJ') ? 'jwt' : 'opaque';
        debugPrint(
          '🔐 Auth: present kind=$kind len=${t.length} suffix=$suffix',
        );
      }
    }

    final apiHost = Uri.tryParse(baseUrl)?.host ?? '';
    final isD1vDomain = apiHost.endsWith('d1v.ai');

    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      // Align with d1vai web request headers for stricter gateways/WAF.
      if (isD1vDomain) 'Origin': 'https://www.d1v.ai',
      if (isD1vDomain) 'Referer': 'https://www.d1v.ai/',
      'User-Agent': 'd1vai_app',
      'X-D1V-Client': 'd1vai_app',
    };
  }

  Future<T> get<T>(
    String endpoint, {
    T Function(dynamic)? fromJsonT,
    Map<String, String>? queryParams,
    int retries = 3,
    Duration? timeout,
  }) async {
    final headers = await _getHeaders();
    final hasAuthToken = headers.containsKey('Authorization');
    final uri = _buildUri(endpoint, queryParams: queryParams);

    debugPrint('🌐 API Request: GET $uri');

    return executeWithRetry<T>(
      () {
        final fut = client.get(uri, headers: headers);
        return timeout != null ? fut.timeout(timeout) : fut;
      },
      fromJsonT,
      retries: retries,
      endpoint: endpoint,
      hasAuthToken: hasAuthToken,
      requestBody: null,
    );
  }

  Future<T> postWithQuery<T>(
    String endpoint,
    Map<String, String> queryParams,
    dynamic body, {
    T Function(dynamic)? fromJsonT,
    int retries = 3,
    Duration? timeout,
  }) async {
    final headers = await _getHeaders();
    final hasAuthToken = headers.containsKey('Authorization');
    final uri = _buildUri(endpoint, queryParams: queryParams);

    debugPrint('🌐 API Request: POST $uri');
    debugPrint('📤 Request Body: ${jsonEncode(body)}');

    return executeWithRetry<T>(
      () {
        final fut = client.post(uri, headers: headers, body: jsonEncode(body));
        return timeout != null ? fut.timeout(timeout) : fut;
      },
      fromJsonT,
      retries: retries,
      endpoint: endpoint,
      hasAuthToken: hasAuthToken,
      requestBody: body,
    );
  }

  Future<T> post<T>(
    String endpoint,
    dynamic body, {
    T Function(dynamic)? fromJsonT,
    int retries = 3,
    Duration? timeout,
  }) async {
    final headers = await _getHeaders();
    final hasAuthToken = headers.containsKey('Authorization');
    final uri = _buildUri(endpoint);

    debugPrint('🌐 API Request: POST $uri');
    debugPrint('📤 Request Body: ${jsonEncode(body)}');

    return executeWithRetry<T>(
      () {
        final fut = client.post(uri, headers: headers, body: jsonEncode(body));
        return timeout != null ? fut.timeout(timeout) : fut;
      },
      fromJsonT,
      retries: retries,
      endpoint: endpoint,
      hasAuthToken: hasAuthToken,
      requestBody: body,
    );
  }

  Future<T> put<T>(
    String endpoint,
    dynamic body, {
    T Function(dynamic)? fromJsonT,
    int retries = 3,
    Duration? timeout,
  }) async {
    final headers = await _getHeaders();
    final hasAuthToken = headers.containsKey('Authorization');
    final uri = _buildUri(endpoint);

    debugPrint('🌐 API Request: PUT $uri');
    debugPrint('📤 Request Body: ${jsonEncode(body)}');

    return executeWithRetry<T>(
      () {
        final fut = client.put(uri, headers: headers, body: jsonEncode(body));
        return timeout != null ? fut.timeout(timeout) : fut;
      },
      fromJsonT,
      retries: retries,
      endpoint: endpoint,
      hasAuthToken: hasAuthToken,
      requestBody: body,
    );
  }

  // PATCH request method
  Future<T> patch<T>(
    String endpoint,
    dynamic body, {
    T Function(dynamic)? fromJsonT,
    int retries = 3,
    Duration? timeout,
  }) async {
    final headers = await _getHeaders();
    final hasAuthToken = headers.containsKey('Authorization');
    final uri = _buildUri(endpoint);

    debugPrint('🌐 API Request: PATCH $uri');
    debugPrint('📤 Request Body: ${jsonEncode(body)}');

    return executeWithRetry<T>(
      () {
        final fut = client.patch(uri, headers: headers, body: jsonEncode(body));
        return timeout != null ? fut.timeout(timeout) : fut;
      },
      fromJsonT,
      retries: retries,
      endpoint: endpoint,
      hasAuthToken: hasAuthToken,
      requestBody: body,
    );
  }

  Future<T> delete<T>(
    String endpoint, {
    T Function(dynamic)? fromJsonT,
    int retries = 3,
    Duration? timeout,
  }) async {
    final headers = await _getHeaders();
    final hasAuthToken = headers.containsKey('Authorization');
    final uri = _buildUri(endpoint);

    debugPrint('🌐 API Request: DELETE $uri');

    return executeWithRetry<T>(
      () {
        final fut = client.delete(uri, headers: headers);
        return timeout != null ? fut.timeout(timeout) : fut;
      },
      fromJsonT,
      retries: retries,
      endpoint: endpoint,
      hasAuthToken: hasAuthToken,
      requestBody: null,
    );
  }

  /// 上传文件（支持图片压缩）
  /// [fileBytes] 文件字节数据
  /// [fileName] 文件名
  /// [compress] 是否压缩图片（仅对图片文件有效）
  Future<String> uploadFile(
    Uint8List fileBytes,
    String fileName, {
    bool compress = true,
  }) async {
    final originalSize = fileBytes.length;

    Uint8List finalBytes = fileBytes;

    // 如果是图片文件且需要压缩
    if (compress && _isImageFile(fileName)) {
      try {
        finalBytes = await ImageCompressor.compress(
          imageBytes: fileBytes,
          quality: 0.75, // 75% 质量
          maxWidth: 800,
          maxHeight: 800,
        );
        final compressedSize = finalBytes.length;
        final ratio = ImageCompressor.getCompressionRatio(
          originalSize,
          compressedSize,
        );

        debugPrint(
          'Image compressed: ${(ratio * 100).toStringAsFixed(1)}% reduction',
        );
      } catch (e) {
        debugPrint('Compression failed, using original file: $e');
        finalBytes = fileBytes;
      }
    }

    final headers = await _getHeaders();
    final hasAuthToken = headers.containsKey('Authorization');
    headers.remove('Content-Type');

    const endpoint = '/api/upload/pic';
    final uri = _buildUri(endpoint);

    debugPrint('🌐 API Request: POST $uri');
    debugPrint('📁 File Name: $fileName');
    debugPrint('📏 File Size: ${finalBytes.length} bytes');

    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(headers);
    final contentType = _getContentType(fileName);

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        finalBytes,
        filename: fileName,
        contentType: contentType,
      ),
    );

    final streamed = await request.send();
    final responseBody = await streamed.stream.bytesToString();
    final httpResponse = http.Response(responseBody, streamed.statusCode);

    if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
      final Map<String, dynamic> json = jsonDecode(httpResponse.body);
      return json['data'] ?? '';
    } else {
      if (httpResponse.statusCode == 401 &&
          hasAuthToken &&
          !_isPublicEndpoint(endpoint)) {
        AuthExpiryBus.trigger(endpoint: endpoint);
      }
      // 打印上传错误
      debugPrint('═══════════════════════════════════════');
      debugPrint('API Upload Error Detected');
      debugPrint('═══════════════════════════════════════');
      debugPrint('📍 API Path: $endpoint');
      debugPrint('🔢 HTTP Status Code: ${httpResponse.statusCode}');
      debugPrint('📥 Response Body: $responseBody');
      debugPrint('═══════════════════════════════════════');
      throw Exception(
        'Upload failed: ${httpResponse.statusCode} ${httpResponse.body}',
      );
    }
  }

  Future<T> postMultipart<T>(
    String endpoint, {
    required Map<String, String> fields,
    required String fileField,
    required Uint8List fileBytes,
    required String fileName,
    String? contentType,
    T Function(dynamic)? fromJsonT,
    Duration? timeout,
  }) async {
    final headers = await _getHeaders();
    final hasAuthToken = headers.containsKey('Authorization');
    headers.remove('Content-Type');

    final uri = _buildUri(endpoint);
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(headers);
    request.fields.addAll(fields);

    final mediaType = contentType != null && contentType.trim().isNotEmpty
        ? MediaType.parse(contentType)
        : _getContentType(fileName);

    request.files.add(
      http.MultipartFile.fromBytes(
        fileField,
        fileBytes,
        filename: fileName,
        contentType: mediaType,
      ),
    );

    debugPrint('🌐 API Request: POST $uri');
    debugPrint('📁 Multipart File: $fileName (${fileBytes.length} bytes)');

    final sendFuture = request.send();
    final streamed = timeout != null
        ? await sendFuture.timeout(timeout)
        : await sendFuture;
    final responseBody = await streamed.stream.bytesToString();
    final httpResponse = http.Response(responseBody, streamed.statusCode);

    if (httpResponse.statusCode == 401 &&
        hasAuthToken &&
        !_isPublicEndpoint(endpoint)) {
      AuthExpiryBus.trigger(endpoint: endpoint);
    }

    final dynamic decoded = responseBody.isEmpty
        ? null
        : jsonDecode(responseBody);

    if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
      if (decoded is Map<String, dynamic>) {
        final apiResponse = ApiResponse<T>.fromJson(decoded, fromJsonT);
        if (apiResponse.isSuccess) {
          return apiResponse.data as T;
        }
        throw ApiClientException(
          apiResponse.msg,
          statusCode: httpResponse.statusCode,
          code: apiResponse.code,
          data: decoded,
        );
      }
      if (fromJsonT != null) {
        return fromJsonT(decoded);
      }
      return decoded as T;
    }

    _noteLastApiError(
      endpoint: endpoint,
      statusCode: httpResponse.statusCode,
      message: responseBody,
    );
    throw ApiClientException(
      responseBody.isEmpty ? 'Request failed' : responseBody,
      statusCode: httpResponse.statusCode,
      data: decoded,
    );
  }

  /// 检查是否为图片文件
  bool _isImageFile(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'webp'].contains(extension);
  }

  MediaType _getContentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return MediaType.parse('image/jpeg');
      case 'png':
        return MediaType.parse('image/png');
      case 'webp':
        return MediaType.parse('image/webp');
      default:
        return MediaType.parse('application/octet-stream');
    }
  }

  /// POST request with streaming response
  /// Returns a stream of bytes for streaming responses
  Future<Stream<Uint8List>> postStream(String endpoint, dynamic body) async {
    final headers = await _getHeaders();
    final hasAuthToken = headers.containsKey('Authorization');
    final uri = _buildUri(endpoint);
    final request = http.Request('POST', uri);
    request.headers.addAll(headers);
    request.body = jsonEncode(body);

    debugPrint('🌐 API Request: POST (Stream) $uri');
    debugPrint('📤 Request Body: ${jsonEncode(body)}');

    final streamedResponse = await client.send(request);

    if (streamedResponse.statusCode >= 200 &&
        streamedResponse.statusCode < 300) {
      return streamedResponse.stream.map((bytes) => Uint8List.fromList(bytes));
    } else {
      final responseBody = await streamedResponse.stream.bytesToString();
      if (streamedResponse.statusCode == 401 &&
          hasAuthToken &&
          !_isPublicEndpoint(endpoint)) {
        AuthExpiryBus.trigger(endpoint: endpoint);
      }

      // 打印流式请求错误
      debugPrint('═══════════════════════════════════════');
      debugPrint('API Stream Error Detected');
      debugPrint('═══════════════════════════════════════');
      debugPrint('📍 API Path: $endpoint');
      debugPrint('🔢 HTTP Status Code: ${streamedResponse.statusCode}');
      debugPrint('📥 Response Body: $responseBody');
      debugPrint('═══════════════════════════════════════');

      throw Exception(
        'HTTP Error: ${streamedResponse.statusCode} $responseBody',
      );
    }
  }

  /// 执行可重试的 HTTP 请求
  /// [requestBuilder] 请求构建器函数
  /// [retries] 重试次数，默认 3
  Future<T> executeWithRetry<T>(
    Future<http.Response> Function() requestBuilder,
    T Function(dynamic)? fromJsonT, {
    int retries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    String? endpoint,
    bool hasAuthToken = false,
    dynamic requestBody,
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (attempt <= retries) {
      try {
        if (AuthExpiryBus.isTriggered && !_isPublicEndpoint(endpoint)) {
          throw AuthExpiredException();
        }
        final response = await requestBuilder();
        return _handleResponse<T>(
          response,
          fromJsonT,
          endpoint: endpoint,
          hasAuthToken: hasAuthToken,
          requestBody: requestBody,
        );
      } on SocketException catch (e) {
        // 网络错误，可以重试
        if (attempt == retries) {
          debugPrint('═══════════════════════════════════════');
          debugPrint('Network Error - Max Retries Exceeded');
          debugPrint('═══════════════════════════════════════');
          if (endpoint != null) {
            debugPrint('📍 API Path: $endpoint');
          }
          debugPrint('🔢 Retry Count: $retries');
          debugPrint('💥 Error: $e');
          debugPrint('═══════════════════════════════════════');
          throw Exception('Network error after $retries retries: $e');
        }
        debugPrint(
          '🔄 Network error on attempt ${attempt + 1}/$retries, retrying in ${delay.inMilliseconds}ms: $e',
        );
        if (endpoint != null) {
          debugPrint('📍 API Path: $endpoint');
        }
        await Future.delayed(delay);
        delay *= 2; // 指数退避
        attempt++;
      } on HttpException catch (e) {
        // HTTP 错误，通常不重试
        debugPrint('═══════════════════════════════════════');
        debugPrint('HTTP Exception');
        debugPrint('═══════════════════════════════════════');
        if (endpoint != null) {
          debugPrint('📍 API Path: $endpoint');
        }
        debugPrint('💥 Error: $e');
        if (requestBody != null) {
          debugPrint('📤 Request Body: ${jsonEncode(requestBody)}');
        }
        debugPrint('═══════════════════════════════════════');
        rethrow;
      } on http.ClientException catch (e) {
        final retryable = _isTransientClientException(e);
        if (retryable && attempt < retries) {
          debugPrint(
            '🔄 Transient client error on attempt ${attempt + 1}/$retries, retrying in ${delay.inMilliseconds}ms: $e',
          );
          if (endpoint != null) {
            debugPrint('📍 API Path: $endpoint');
          }
          await Future.delayed(delay);
          delay *= 2;
          attempt++;
          continue;
        }
        debugPrint('═══════════════════════════════════════');
        debugPrint('Client Exception');
        debugPrint('═══════════════════════════════════════');
        if (endpoint != null) {
          debugPrint('📍 API Path: $endpoint');
        }
        debugPrint('🔢 Retry Count: $attempt/$retries');
        debugPrint('💥 Error: $e');
        if (requestBody != null) {
          debugPrint('📤 Request Body: ${jsonEncode(requestBody)}');
        }
        debugPrint('═══════════════════════════════════════');
        rethrow;
      } catch (e) {
        // 其他错误，检查是否包含可重试的状态码
        if (e.toString().contains('HTTP Error: 5')) {
          // 服务器错误，可以重试
          if (attempt == retries) {
            debugPrint('═══════════════════════════════════════');
            debugPrint('Server Error - Max Retries Exceeded');
            debugPrint('═══════════════════════════════════════');
            if (endpoint != null) {
              debugPrint('📍 API Path: $endpoint');
            }
            debugPrint('🔢 Retry Count: $retries');
            debugPrint('💥 Error: $e');
            debugPrint('═══════════════════════════════════════');
            rethrow;
          }
          debugPrint(
            '🔄 Server error on attempt ${attempt + 1}/$retries, retrying in ${delay.inMilliseconds}ms: $e',
          );
          if (endpoint != null) {
            debugPrint('📍 API Path: $endpoint');
          }
          await Future.delayed(delay);
          delay *= 2;
          attempt++;
        } else {
          // 客户端错误或其他错误，不重试
          debugPrint('═══════════════════════════════════════');
          debugPrint('Client Error or Other Exception');
          debugPrint('═══════════════════════════════════════');
          if (endpoint != null) {
            debugPrint('📍 API Path: $endpoint');
          }
          debugPrint('💥 Error: $e');
          if (requestBody != null) {
            debugPrint('📤 Request Body: ${jsonEncode(requestBody)}');
          }
          debugPrint('═══════════════════════════════════════');
          rethrow;
        }
      }
    }

    throw Exception('Max retries exceeded');
  }

  bool _isTransientClientException(http.ClientException e) {
    final msg = e.message.toLowerCase();
    return msg.contains('connection closed before full header') ||
        msg.contains('connection reset') ||
        msg.contains('connection terminated') ||
        msg.contains('broken pipe') ||
        msg.contains('http2') ||
        msg.contains('temporarily unavailable');
  }

  T _handleResponse<T>(
    http.Response response,
    T Function(dynamic)? fromJsonT, {
    String? endpoint,
    bool hasAuthToken = false,
    dynamic requestBody,
  }) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final Map<String, dynamic> json = jsonDecode(
        utf8.decode(response.bodyBytes),
      );
      final apiResponse = ApiResponse<T>.fromJson(json, fromJsonT);

      if (apiResponse.isSuccess) {
        return apiResponse.data as T;
      } else {
        if (apiResponse.code == 401 &&
            hasAuthToken &&
            !_isPublicEndpoint(endpoint)) {
          AuthExpiryBus.trigger(endpoint: endpoint);
          _noteLastApiError(
            endpoint: endpoint,
            statusCode: response.statusCode,
            message: apiResponse.msg,
          );
          throw AuthExpiredException(apiResponse.msg);
        }
        // 打印业务逻辑错误
        debugPrint('═══════════════════════════════════════');
        debugPrint('API Business Error Detected');
        debugPrint('═══════════════════════════════════════');
        if (endpoint != null) {
          debugPrint('📍 API Path: $endpoint');
        }
        debugPrint('🔢 Status Code: ${response.statusCode}');
        debugPrint('📝 Error Message: ${apiResponse.msg}');
        if (requestBody != null) {
          debugPrint('📤 Request Body: ${jsonEncode(requestBody)}');
        }
        debugPrint('📥 Response Body: ${jsonEncode(json)}');
        debugPrint('═══════════════════════════════════════');
        _noteLastApiError(
          endpoint: endpoint,
          statusCode: response.statusCode,
          message: apiResponse.msg,
        );
        throw ApiClientException(
          apiResponse.msg,
          statusCode: response.statusCode,
          code: apiResponse.code,
          data: json,
        );
      }
    } else {
      // 打印 HTTP 错误
      debugPrint('═══════════════════════════════════════');
      debugPrint('API HTTP Error Detected');
      debugPrint('═══════════════════════════════════════');
      if (endpoint != null) {
        debugPrint('📍 API Path: $endpoint');
      }
      debugPrint('🌍 API Base: $baseUrl');
      debugPrint('🔢 HTTP Status Code: ${response.statusCode}');

      // 解析响应体
      String responseBodyForException = '';
      int? parsedCode;
      Map<String, dynamic>? parsedErrorData;
      try {
        final responseBody = utf8.decode(response.bodyBytes);
        responseBodyForException = responseBody;
        debugPrint('📥 Response Body: $responseBody');

        // 尝试解析为 JSON
        try {
          final json = jsonDecode(responseBody);
          debugPrint(
            '📦 Parsed JSON: ${jsonEncode(json, toEncodable: (obj) => obj)}',
          );

          // Prefer backend error message fields when present.
          if (json is Map<String, dynamic>) {
            parsedErrorData = json;
            final msg =
                json['msg'] ??
                json['detail'] ??
                json['message'] ??
                json['error'];
            if (msg is String && msg.trim().isNotEmpty) {
              responseBodyForException = msg.trim();
            }
            final rawCode = json['code'];
            if (rawCode is num) {
              parsedCode = rawCode.toInt();
            } else if (rawCode is String) {
              parsedCode = int.tryParse(rawCode.trim());
            }
            if (json['code'] == 401 && !_isPublicEndpoint(endpoint)) {
              if (!hasAuthToken) {
                throw Exception('Unauthenticated');
              }
              AuthExpiryBus.trigger(endpoint: endpoint);
              // Token removal is best-effort; redirect flow also clears it.
              final prefs = _sharedPreferences;
              if (prefs != null) {
                unawaited(prefs.remove('auth_token').then((_) {}));
              }
              throw AuthExpiredException(responseBodyForException);
            }
          }
        } catch (e) {
          debugPrint('⚠️  Failed to parse response as JSON');
        }
      } catch (e) {
        debugPrint('⚠️  Failed to decode response body');
      }

      if (response.statusCode == 401 && !_isPublicEndpoint(endpoint)) {
        if (!hasAuthToken) {
          _noteLastApiError(
            endpoint: endpoint,
            statusCode: response.statusCode,
            message: 'Unauthenticated',
          );
          throw Exception('Unauthenticated');
        }
        AuthExpiryBus.trigger(endpoint: endpoint);
        // Token removal is best-effort; redirect flow also clears it.
        final prefs = _sharedPreferences;
        if (prefs != null) {
          unawaited(prefs.remove('auth_token').then((_) {}));
        }
        _noteLastApiError(
          endpoint: endpoint,
          statusCode: response.statusCode,
          message: responseBodyForException.isNotEmpty
              ? responseBodyForException
              : 'Bad credentials',
        );
        throw AuthExpiredException(
          responseBodyForException.isNotEmpty
              ? responseBodyForException
              : 'Bad credentials',
        );
      }

      if (requestBody != null) {
        debugPrint('📤 Request Body: ${jsonEncode(requestBody)}');
      }

      debugPrint('═══════════════════════════════════════');
      _noteLastApiError(
        endpoint: endpoint,
        statusCode: response.statusCode,
        message: responseBodyForException.isNotEmpty
            ? responseBodyForException
            : response.body,
      );
      throw ApiClientException(
        responseBodyForException.isNotEmpty
            ? responseBodyForException
            : response.body,
        statusCode: response.statusCode,
        code: parsedCode,
        data: parsedErrorData,
      );
    }
  }
}
