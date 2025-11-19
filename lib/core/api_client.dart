import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiResponse<T> {
  final int code;
  final String msg;
  final T? data;

  ApiResponse({required this.code, required this.msg, this.data});

  factory ApiResponse.fromJson(Map<String, dynamic> json, T Function(dynamic)? fromJsonT) {
    return ApiResponse(
      code: json['code'] ?? -1,
      msg: json['msg'] ?? 'Unknown error',
      data: json['data'] != null && fromJsonT != null ? fromJsonT(json['data']) : json['data'],
    );
  }

  bool get isSuccess => code == 0;
}

class ApiClient {
  static const String baseUrl = 'https://api.d1v.ai/api';
  final http.Client client;

  ApiClient({http.Client? client}) : client = client ?? http.Client();

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<T> get<T>(String endpoint, {T Function(dynamic)? fromJsonT}) async {
    final headers = await _getHeaders();
    final response = await client.get(Uri.parse('$baseUrl$endpoint'), headers: headers);
    return _handleResponse<T>(response, fromJsonT);
  }

  Future<T> post<T>(String endpoint, dynamic body, {T Function(dynamic)? fromJsonT}) async {
    final headers = await _getHeaders();
    final response = await client.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: jsonEncode(body),
    );
    return _handleResponse<T>(response, fromJsonT);
  }

  Future<T> put<T>(String endpoint, dynamic body, {T Function(dynamic)? fromJsonT}) async {
    final headers = await _getHeaders();
    final response = await client.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: headers,
      body: jsonEncode(body),
    );
    return _handleResponse<T>(response, fromJsonT);
  }

  Future<T> delete<T>(String endpoint, {T Function(dynamic)? fromJsonT}) async {
    final headers = await _getHeaders();
    final response = await client.delete(Uri.parse('$baseUrl$endpoint'), headers: headers);
    return _handleResponse<T>(response, fromJsonT);
  }

  T _handleResponse<T>(http.Response response, T Function(dynamic)? fromJsonT) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final Map<String, dynamic> json = jsonDecode(utf8.decode(response.bodyBytes));
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

