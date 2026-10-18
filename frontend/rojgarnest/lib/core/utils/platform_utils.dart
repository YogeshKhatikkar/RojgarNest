// lib/core/utils/platform_utils.dart
// ✅ COMPLETE PLATFORM UTILITIES
// ✅ UPDATED FOR adb reverse USB DEBUGGING SUPPORT

import 'package:flutter/foundation.dart';
import 'dart:io';

class PlatformUtils {
  static bool get isWeb => kIsWeb;
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;
  static bool get isLinux => !kIsWeb && Platform.isLinux;
  static bool get isMobile => isAndroid || isIOS;
  static bool get isDesktop => isWindows || isMacOS || isLinux;

  static String get platformName {
    if (isWeb) return 'Web';
    if (isAndroid) return 'Android';
    if (isIOS) return 'iOS';
    if (isWindows) return 'Windows';
    if (isMacOS) return 'macOS';
    if (isLinux) return 'Linux';
    return 'Unknown';
  }

  static bool get supportsBiometric => isAndroid || isIOS;
  static bool get supportsPushNotifications => isAndroid || isIOS;
  static bool get supportsCamera => isAndroid || isIOS;
  static bool get supportsGPS => !isWeb;
  static bool get supportsNativeFilePicker => !isWeb;

  static String getFilePickerErrorMessage(dynamic error) {
    if (isWeb) {
      return 'File selection is not supported in this browser. Please try again.';
    }
    return 'Error selecting file: $error';
  }

  static bool isFilePickerSupported() {
    return true;
  }

  // ==================== API BASE URL ====================
  static String getApiBaseUrl() {
    // Production
    if (kReleaseMode) {
      return "https://www.rojgarnest.com/api/v1";
    }

    // Web
    if (isWeb) {
      return "http://localhost:8000/api/v1";
    }

    // ✅ Android (Real device with adb reverse OR Emulator)
    //
    // REAL DEVICE via USB:
    //   adb reverse tcp:8000 tcp:8000
    //   → Use "localhost:8000"
    //
    // EMULATOR:
    //   → Use "10.0.2.2:8000"
    //
    // 👇 CURRENTLY SET FOR REAL DEVICE (USB + adb reverse)
    if (isAndroid) {
      return "http://localhost:8000/api/v1";
    }

    // iOS
    if (isIOS) {
      return "http://localhost:8000/api/v1";
    }

    // Desktop
    return "http://localhost:8000/api/v1";
  }

  // ==================== WEBSOCKET URL ====================
  static String getWebSocketUrl() {
    if (kReleaseMode) {
      return "wss://www.rojgarnest.com/ws/notification/ws";
    }

    if (isWeb) {
      return "ws://localhost:8000/notification/ws";
    }

    if (isAndroid) {
      // ✅ adb reverse ke saath localhost
      return "ws://localhost:8000/notification/ws";
    }

    return "ws://localhost:8000/notification/ws";
  }

  static bool get isDevelopment => !kReleaseMode;
  static bool get isProduction => kReleaseMode;
}