// lib/core/config/api_config.dart
// ✅ PLATFORM-AWARE API CONFIGURATION
// ✅ WORKS WITH: Android Emulator, Real Device (adb reverse), iOS, Web

import 'package:flutter/foundation.dart';
import '../utils/platform_utils.dart';

class ApiConfig {
  static String get baseUrl {
    debugPrint("🌐 Platform: ${PlatformUtils.platformName}");
    debugPrint("📱 Mode: ${kReleaseMode ? 'Release' : 'Development'}");

    // ==================== PRODUCTION ====================
    if (kReleaseMode) {
      return "https://www.rojgarnest.com/api/v1";
    }

    // ==================== DEVELOPMENT ====================
    // Web browser
    if (PlatformUtils.isWeb) {
      return "http://localhost:8000/api/v1";
    }

    // ✅ ANDROID (Real Device via USB + adb reverse, OR Emulator)
    // 
    // FOR REAL DEVICE WITH USB DEBUGGING:
    //   Step 1: adb reverse tcp:8000 tcp:8000
    //   Step 2: Use "localhost:8000" (NOT 10.0.2.2)
    //
    // FOR ANDROID EMULATOR:
    //   Use "10.0.2.2:8000" (emulator's alias for host machine)
    //
    // 👇 CURRENTLY SET FOR REAL DEVICE (USB + adb reverse)
    if (PlatformUtils.isAndroid) {
      return "http://localhost:8000/api/v1";
    }

    // iOS Simulator
    if (PlatformUtils.isIOS) {
      return "http://localhost:8000/api/v1";
    }

    // Desktop
    if (PlatformUtils.isDesktop) {
      return "http://localhost:8000/api/v1";
    }

    return "http://localhost:8000/api/v1";
  }

  static String get webSocketUrl {
    if (kReleaseMode) {
      return "wss://www.rojgarnest.com/ws/notification/ws";
    }

    if (PlatformUtils.isWeb) {
      return "ws://localhost:8000/notification/ws";
    }

    if (PlatformUtils.isAndroid) {
      // ✅ adb reverse tcp:8000 ke saath localhost use karo
      return "ws://localhost:8000/notification/ws";
    }

    return "ws://localhost:8000/notification/ws";
  }

  // ✅ PRODUCTION UPI ID - Read from .env via backend
  static String get upiId {
    if (kReleaseMode) {
      return "your-business-upi@ybl"; // Replace with your actual UPI ID
    }
    return "7869986602@ybl"; // Test UPI ID
  }

  static bool get isDevelopment => !kReleaseMode;
  static bool get isProduction => kReleaseMode;
}