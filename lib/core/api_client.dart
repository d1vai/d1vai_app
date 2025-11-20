import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart';
import '../utils/image_compressor.dart';

class ApiResponse<T> {
  final int code;
  final String msg;
  final T? data;

  ApiResponse({required this.code, required this.msg, this.data});

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    return ApiResponse(
      code: json['code'] ?? -1,
      msg: json['msg'] ?? 'Unknown error',
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : json['data'],
    );
  }

  bool get isSuccess => code == 0;
}

class ApiClient {
  static const String baseUrl = 'https://api.d1v.ai';
  final http.Client client;

  // 缓存 SharedPreferences 实例以避免重复调用
  static SharedPreferences? _sharedPreferences;

  ApiClient({http.Client? client}) : client = client ?? http.Client() {
    _init();
  }

  Future<void> _init() async {
    _sharedPreferences ??= await SharedPreferences.getInstance();
  }

  Future<Map<String, String>> _getHeaders() async {
    _sharedPreferences ??= await SharedPreferences.getInstance();
    final token = _sharedPreferences!.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<T> get<T>(
    String endpoint, {
    T Function(dynamic)? fromJsonT,
    Map<String, String>? queryParams,
    int retries = 3,
  }) async {
    final headers = await _getHeaders();
    final uri = Uri.parse(
      '$baseUrl$endpoint',
    ).replace(queryParameters: queryParams);

    return executeWithRetry<T>(
      () => client.get(uri, headers: headers),
      fromJsonT,
      retries: retries,
    );
  }

  Future<T> postWithQuery<T>(
    String endpoint,
    Map<String, String> queryParams,
    dynamic body, {
    T Function(dynamic)? fromJsonT,
    int retries = 3,
  }) async {
    final headers = await _getHeaders();
    final uri = Uri.parse(
      '$baseUrl$endpoint',
    ).replace(queryParameters: queryParams);

    return executeWithRetry<T>(
      () => client.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      ),
      fromJsonT,
      retries: retries,
    );
  }

  Future<T> post<T>(
    String endpoint,
    dynamic body, {
    T Function(dynamic)? fromJsonT,
    int retries = 3,
  }) async {
    final headers = await _getHeaders();
    return executeWithRetry<T>(
      () => client.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      ),
      fromJsonT,
      retries: retries,
    );
  }

  Future<T> put<T>(
    String endpoint,
    dynamic body, {
    T Function(dynamic)? fromJsonT,
    int retries = 3,
  }) async {
    final headers = await _getHeaders();
    return executeWithRetry<T>(
      () => client.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      ),
      fromJsonT,
      retries: retries,
    );
  }

  // PATCH request method
  Future<T> patch<T>(
    String endpoint,
    dynamic body, {
    T Function(dynamic)? fromJsonT,
    int retries = 3,
  }) async {
    final headers = await _getHeaders();
    return executeWithRetry<T>(
      () => client.patch(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      ),
      fromJsonT,
      retries: retries,
    );
  }

  Future<T> delete<T>(
    String endpoint, {
    T Function(dynamic)? fromJsonT,
    int retries = 3,
  }) async {
    final headers = await _getHeaders();
    return executeWithRetry<T>(
      () => client.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      ),
      fromJsonT,
      retries: retries,
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
        final ratio = ImageCompressor.getCompressionRatio(originalSize, compressedSize);

        debugPrint('Image compressed: ${(ratio * 100).toStringAsFixed(1)}% reduction');
      } catch (e) {
        debugPrint('Compression failed, using original file: $e');
        finalBytes = fileBytes;
      }
    }

    final headers = await _getHeaders();
    headers.remove('Content-Type');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/upload'),
    );
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
      throw Exception('Upload failed: ${httpResponse.statusCode} ${httpResponse.body}');
    }
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

  /// 执行可重试的 HTTP 请求
  /// [requestBuilder] 请求构建器函数
  /// [retries] 重试次数，默认 3
  Future<T> executeWithRetry<T>(
    Future<http.Response> Function() requestBuilder,
    T Function(dynamic)? fromJsonT, {
    int retries = 3,
    Duration initialDelay = const Duration(seconds: 1),
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (attempt <= retries) {
      try {
        final response = await requestBuilder();
        return _handleResponse<T>(response, fromJsonT);
      } on SocketException catch (e) {
        // 网络错误，可以重试
        if (attempt == retries) {
          throw Exception('Network error after $retries retries: $e');
        }
        debugPrint('Network error on attempt ${attempt + 1}, retrying in ${delay.inMilliseconds}ms: $e');
        await Future.delayed(delay);
        delay *= 2; // 指数退避
        attempt++;
      } on HttpException {
        // HTTP 错误，通常不重试
        rethrow;
      } catch (e) {
        // 其他错误，检查是否包含可重试的状态码
        if (e.toString().contains('HTTP Error: 5')) {
          // 服务器错误，可以重试
          if (attempt == retries) {
            rethrow;
          }
          debugPrint('Server error on attempt ${attempt + 1}, retrying in ${delay.inMilliseconds}ms: $e');
          await Future.delayed(delay);
          delay *= 2;
          attempt++;
        } else {
          // 客户端错误或其他错误，不重试
          rethrow;
        }
      }
    }

    throw Exception('Max retries exceeded');
  }

  T _handleResponse<T>(http.Response response, T Function(dynamic)? fromJsonT) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final Map<String, dynamic> json = jsonDecode(
        utf8.decode(response.bodyBytes),
      );
      final apiResponse = ApiResponse<T>.fromJson(json, fromJsonT);

      if (apiResponse.isSuccess) {
        return apiResponse.data as T;
      } else {
        throw Exception(apiResponse.msg);
      }
    } else {
      throw Exception('HTTP Error: ${response.statusCode} ${response.body}');
    }
  }
}
