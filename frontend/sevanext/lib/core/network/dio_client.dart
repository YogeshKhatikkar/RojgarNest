// lib/core/network/dio_client.dart
// ✅ COMPLETE WITH ERROR HANDLING
// ✅ FIXED: 403, 401, 429 are treated as ERRORS
// ✅ PRESERVES detailed error info including lock_until
// ✅ CRITICAL FIX: NEVER auto-clears auth anymore.
// ✅ NEW: Payment/scheme paths are whitelisted from auth-clearing logic.

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

  bool get isAccountLocked =>
      code == 'ACCOUNT_LOCKED' || detail?['code'] == 'ACCOUNT_LOCKED';

  int? get secondsRemaining {
    final sec = detail?['seconds_remaining'];
    if (sec is int) return sec;
    if (sec is String) return int.tryParse(sec);
    return null;
  }

  DateTime? get lockUntil {
    final until = detail?['lock_until'];
    if (until is String) {
      try {
        return DateTime.parse(until);
      } catch (_) {}
    }
    return null;
  }

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

  /// ✅ Paths that must NEVER trigger auth-clearing on 401
  static const List<String> _safePaths = [
    '/payment/',
    '/schemes/',
    '/services/application/',
    '/user/full-profile',
    '/notification/',
  ];

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

          final statusCode = e.response?.statusCode;
          final path = e.requestOptions.path;

          final isSafePath = _safePaths.any((p) => path.contains(p));

          if (statusCode == 401) {
            if (isSafePath) {
              debugPrint("💳 401 on safe path ($path) — "
                  "IGNORING auth clear (prevents auto-logout after payment)");
            } else {
              debugPrint("🔐 401 detected on $path — NOT auto-clearing auth "
                  "(prevents auto-logout after payment).");
            }
          }

          return handler.next(e);
        },
      ),
    );

    _isInitialized = true;
  }

  static ApiException toApiException(DioException e) {
    final statusCode = e.response?.statusCode ?? 0;
    final data = e.response?.data;

    String code = 'E$statusCode';
    String message = e.message ?? 'Network error';
    Map<String, dynamic>? detail;

    if (data is Map<String, dynamic>) {
      code = data['code']?.toString() ?? code;

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

      if (data['detail'] is Map) {
        detail = Map<String, dynamic>.from(data['detail'] as Map);
        if (detail['code'] != null) {
          code = detail['code'].toString();
        }
      }

      if (detail == null && data.containsKey('seconds_remaining')) {
        detail = Map<String, dynamic>.from(data);
      }
    } else if (data is String && data.isNotEmpty) {
      message = data;
    }

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