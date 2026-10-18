// lib/core/utils/logger.dart
// ✅ COMPLETE - Safe on all platforms

import 'package:flutter/foundation.dart';

class Logger {
  static void info(String message) {
    if (kDebugMode) {
      debugPrint('📘 INFO: $message');
    }
  }

  static void error(String message, [dynamic error]) {
    if (kDebugMode) {
      debugPrint('❌ ERROR: $message');
      if (error != null) {
        debugPrint('   Details: $error');
      }
    }
  }

  static void warning(String message) {
    if (kDebugMode) {
      debugPrint('⚠️ WARNING: $message');
    }
  }

  static void debug(String message) {
    if (kDebugMode) {
      debugPrint('🔍 DEBUG: $message');
    }
  }

  static void api(String method, String url, {dynamic data, dynamic response}) {
    if (kDebugMode) {
      debugPrint('🌐 API: $method $url');
      if (data != null) debugPrint('   Request: $data');
      if (response != null) debugPrint('   Response: $response');
    }
  }
}