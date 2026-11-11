// lib/core/config/api_config.dart
// ✅ Reads --dart-define=API_BASE_URL from Docker build
// ✅ Falls back to sensible defaults per platform
// ✅ Works with Docker, local dev, emulator, real device

import 'package:flutter/foundation.dart';
import '../utils/platform_utils.dart';

class ApiConfig {
  // ============================================================
  // ✅ Read from --dart-define (set via Docker ARG)
  // ============================================================
  static const String _apiBaseUrlFromEnv = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const String _wsUrlFromEnv = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: '',
  );

  static const String _buildNumber = String.fromEnvironment(
    'BUILD_NUMBER',
    defaultValue: '1',
  );

  static const String _buildName = String.fromEnvironment(
    'BUILD_NAME',
    defaultValue: '2.0.0',
  );

  // ============================================================
  // BASE URL
  // ============================================================
  static String get baseUrl {
    // ✅ Priority 1: --dart-define (Docker build arg)
    if (_apiBaseUrlFromEnv.isNotEmpty) {
      debugPrint("🌐 Using API_BASE_URL from --dart-define: $_apiBaseUrlFromEnv");
      return _apiBaseUrlFromEnv;
    }

    // ✅ Priority 2: Runtime defaults
    debugPrint("🌐 Platform: ${PlatformUtils.platformName}");
    debugPrint("📱 Mode: ${kReleaseMode ? 'Release' : 'Development'}");

    // Production
    if (kReleaseMode) {
      return "https://www.sevanext.com/api/v1";
    }

    // Web
    if (PlatformUtils.isWeb) {
      return "http://localhost:8000/api/v1";
    }

    // Android
    if (PlatformUtils.isAndroid) {
      // Real device with adb reverse: "http://localhost:8000/api/v1"
      // Emulator: "http://10.0.2.2:8000/api/v1"
      return "http://localhost:8000/api/v1";
    }

    // iOS
    if (PlatformUtils.isIOS) {
      return "http://localhost:8000/api/v1";
    }

    // Desktop
    return "http://localhost:8000/api/v1";
  }

  // ============================================================
  // WEBSOCKET URL
  // ============================================================
  static String get webSocketUrl {
    // ✅ Priority 1: --dart-define
    if (_wsUrlFromEnv.isNotEmpty) {
      return _wsUrlFromEnv;
    }

    // ✅ Priority 2: Runtime defaults
    if (kReleaseMode) {
      return "wss://www.sevanext.com/ws/notification/ws";
    }

    return "ws://localhost:8000/notification/ws";
  }

  // ============================================================
  // BUILD INFO
  // ============================================================
  static String get buildNumber => _buildNumber;
  static String get buildName => _buildName;

  // ============================================================
  // UPI
  // ============================================================
  static String get upiId {
    if (kReleaseMode) {
      return "your-business-upi@ybl";
    }
    return "7869986602@ybl";
  }

  static bool get isDevelopment => !kReleaseMode;
  static bool get isProduction => kReleaseMode;
}