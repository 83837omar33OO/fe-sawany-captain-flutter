import 'dart:convert';
import 'package:http/http.dart' as http;
import '../storage/secure_storage_service.dart';
import 'api_endpoints.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final String? code;

  ApiException(this.message, {this.statusCode = 500, this.code});

  @override
  String toString() => message;
}

class ApiClient {
  static Future<Map<String, dynamic>> get(String url) async {
    return _executeWithFallback((targetUrl) async {
      final token = await SecureStorageService.getToken();
      final headers = {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
        if (token != null) "x-rider-token": token,
      };

      final response = await http
          .get(Uri.parse(targetUrl), headers: headers)
          .timeout(const Duration(seconds: 15));

      return _handleResponse(response);
    }, url);
  }

  static Future<Map<String, dynamic>> post(String url, Map<String, dynamic> body) async {
    return _executeWithFallback((targetUrl) async {
      final token = await SecureStorageService.getToken();
      final headers = {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
        if (token != null) "x-rider-token": token,
      };

      final response = await http
          .post(Uri.parse(targetUrl), headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      return _handleResponse(response);
    }, url);
  }

  static Future<Map<String, dynamic>> _executeWithFallback(
    Future<Map<String, dynamic>> Function(String url) action,
    String primaryUrl,
  ) async {
    try {
      return await action(primaryUrl);
    } catch (e) {
      // If error is 402 or network error, attempt fallback server if primary is baseUrl
      final isRecoverable = (e is ApiException && (e.statusCode == 402 || e.statusCode >= 500)) ||
          e is! ApiException;

      if (isRecoverable && primaryUrl.startsWith(ApiEndpoints.baseUrl)) {
        final fallbackUrl = primaryUrl.replaceFirst(
          ApiEndpoints.baseUrl,
          ApiEndpoints.fallbackBaseUrl,
        );
        try {
          return await action(fallbackUrl);
        } catch (_) {}
      }

      if (e is ApiException) rethrow;
      throw ApiException("تعذر الاتصال بالخادم. يرجى التحقق من اتصالك بالإنترنت.");
    }
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {}

    if (response.statusCode == 200 || response.statusCode == 201) {
      if (data["success"] == false) {
        throw ApiException(data["error"] ?? "حدث خطأ غير متوقع", statusCode: response.statusCode);
      }
      return data;
    }

    if (response.statusCode == 409) {
      throw ApiException(
        data["error"] ?? "عفواً، سبقك كابتن آخر في قبول هذا الطلب",
        statusCode: 409,
        code: "CLAIM_CONFLICT",
      );
    }

    if (response.statusCode == 403 || response.statusCode == 401) {
      final isSuspended = data["isSuspended"] == true || (data["error"]?.toString().contains("موقوف") ?? false);
      throw ApiException(
        data["error"] ?? (data["message"] ?? "انتهت صلاحية الجلسة أو بيانات الدخول غير صحيحة"),
        statusCode: response.statusCode,
        code: isSuspended ? "ACCOUNT_SUSPENDED" : "UNAUTHORIZED",
      );
    }

    throw ApiException(
      data["error"] ?? "حدث خطأ في معالجة الطلب (${response.statusCode})",
      statusCode: response.statusCode,
    );
  }
}
