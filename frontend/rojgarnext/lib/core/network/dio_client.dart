// lib/core/network/dio_client.dart
// ✅ COMPLETE WITH ERROR HANDLING
// ✅ FIXED: 403, 401, 429 are treated as ERRORS
// ✅ PRESERVES detailed error info including lock_until
// ✅ FIXED: ONLY clears auth on GENUINE 401 (token expired/invalid)
// ✅ NEVER clears auth on 403, 429, 500, or network errors
// ✅ This prevents auto-logout after scheme submission

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../storage/secure_storage.dart';

/// ✅ Custom exception for detailed API errors
class ApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;
  final Map<String, dynamic>? detail;

  ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.detail,
  });

  /// ✅ Check if this is an account lock error
  bool get isAccountLocked =>
      code == 'ACCOUNT_LOCKED' || detail?['code'] == 'ACCOUNT_LOCKED';

  /// ✅ Get remaining seconds until unlock
  int? get secondsRemaining {
    final sec = detail?['seconds_remaining'];
    if (sec is int) return sec;
    if (sec is String) return int.tryParse(sec);
    return null;
  }

  /// ✅ Get lock_until timestamp
  DateTime? get lockUntil {
    final until = detail?['lock_until'];
    if (until is String) {
      try {
        return DateTime.parse(until);
      } catch (_) {}
    }
    return null;
  }

  /// ✅ Get remaining attempts
  int? get remainingAttempts {
    final remaining = detail?['remaining_attempts'];
    if (remaining is int) return remaining;
    if (remaining is String) return int.tryParse(remaining);
    return null;
  }

  @override
  String toString() => message;
}

class DioClient {
  static Dio? _dio;
  static bool _isInitialized = false;

  static Dio get dio {
    if (_dio == null || !_isInitialized) {
      _init();
    }
    return _dio!;
  }

  static void _init() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        validateStatus: (status) {
          // ✅ CRITICAL: Only 2xx = success
          // 4xx/5xx all throw DioException
          return status != null && status >= 200 && status < 300;
        },
      ),
    );

    _dio!.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureStorage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers["Authorization"] = "Bearer $token";
          }
          if (kDebugMode) {
            debugPrint("🌐 REQUEST: ${options.method} ${options.uri}");
            if (options.data != null) {
              debugPrint("📦 Body: ${options.data}");
            }
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint("✅ RESPONSE [${response.statusCode}]: ${response.data}");
          }
          return handler.next(response);
        },
        onError: (DioException e, handler) async {
          if (kDebugMode) {
            debugPrint(
                "❌ DIO ERROR [${e.response?.statusCode}]: ${e.response?.data}");
          }

          // ============================================================
          // ✅ CRITICAL FIX: ONLY clear auth on GENUINE 401
          // ============================================================
          // We must NOT clear auth on:
          //   - 403 (Forbidden — account locked, role denied)
          //   - 429 (Rate limit)
          //   - 500 (Server error)
          //   - Network errors (connectionError, timeout)
          //
          // Only clear when the backend explicitly says the token is
          // invalid/expired.
          // ============================================================
          final statusCode = e.response?.statusCode;
          final data = e.response?.data;

          bool shouldClearAuth = false;

          if (statusCode == 401 && data is Map) {
            final code = (data['code'] ?? data['detail']?['code'] ?? '')
                .toString()
                .toUpperCase();
            final msg = (data['message'] ??
                    data['detail']?['message'] ??
                    data['detail'] ??
                    '')
                .toString()
                .toLowerCase();

            // ✅ Only clear if the server explicitly says token is bad
            if (code.contains('TOKEN') ||
                code.contains('EXPIRED') ||
                code.contains('UNAUTHORIZED') ||
                code == 'E401' ||
                msg.contains('token expired') ||
                msg.contains('invalid token') ||
                msg.contains('not authenticated') ||
                msg.contains('session expired')) {
              shouldClearAuth = true;
            }
          }

          if (shouldClearAuth) {
            debugPrint("🔐 Genuine 401 detected — clearing auth data");
            await SecureStorage.clearAuthData();
          } else {
            debugPrint(
                "✅ NOT clearing auth (status=$statusCode, not a token error)");
          }

          return handler.next(e);
        },
      ),
    );

    _isInitialized = true;
  }

  /// ✅ Convert DioException to ApiException
  static ApiException toApiException(DioException e) {
    final statusCode = e.response?.statusCode ?? 0;
    final data = e.response?.data;

    String code = 'E$statusCode';
    String message = e.message ?? 'Network error';
    Map<String, dynamic>? detail;

    if (data is Map<String, dynamic>) {
      // ✅ Extract code
      code = data['code']?.toString() ?? code;

      // ✅ Extract message (priority: message > detail > error)
      if (data['message'] != null &&
          data['message'].toString().isNotEmpty) {
        message = data['message'].toString();
      } else if (data['detail'] != null) {
        final d = data['detail'];
        if (d is Map) {
          message = d['message']?.toString() ?? message;
          detail = Map<String, dynamic>.from(d);
        } else if (d is String) {
          message = d;
        } else if (d is List) {
          message = d.map((e) => e.toString()).join('\n');
        }
      } else if (data['error'] != null) {
        message = data['error'].toString();
      }

      // ✅ If detail is a dict, extract it
      if (data['detail'] is Map) {
        detail = Map<String, dynamic>.from(data['detail'] as Map);
        // ✅ Also check nested code in detail
        if (detail['code'] != null) {
          code = detail['code'].toString();
        }
      }

      // ✅ If top-level response IS the detail (no wrapper)
      if (detail == null && data.containsKey('seconds_remaining')) {
        detail = Map<String, dynamic>.from(data);
      }
    } else if (data is String && data.isNotEmpty) {
      message = data;
    }

    // ✅ Handle connection errors
    if (e.type == DioExceptionType.connectionError) {
      message = "Cannot connect to server.\n\n"
          "Please ensure:\n"
          "1. Backend is running on port 8000\n"
          "2. Check your internet connection";
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      message = "Connection timeout. Please check your internet connection.";
    }

    return ApiException(
      statusCode: statusCode,
      code: code,
      message: message,
      detail: detail,
    );
  }

  static String extractErrorMessage(DioException e) {
    return toApiException(e).message;
  }
}

void initDioClient() {
  DioClient.dio;
}