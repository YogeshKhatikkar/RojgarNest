// lib/core/storage/secure_storage.dart
// ✅ COMPLETE FIXED VERSION - NEVER DELETES BIOMETRIC DATA ON LOGOUT
// ✅ FIXED: clearAuthData() now ONLY deletes tokens, never email/mobile/name
// ✅ FIXED: logout() preserves email/mobile/name for MPIN/biometric login
// ✅ NEW: Added isSessionActive() helper for safe UI checks

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class SecureStorage {
  static const storage = FlutterSecureStorage();

  // ==================== AUTH TOKENS ====================
  static Future<void> setToken(String token) async {
    await storage.write(key: "token", value: token);
    if (kDebugMode) debugPrint("✅ Token saved");
  }

  static Future<String?> getToken() async {
    return await storage.read(key: "token");
  }

  static Future<void> setRole(String role) async {
    await storage.write(key: "role", value: role);
    if (kDebugMode) debugPrint("✅ Role saved: $role");
  }

  static Future<String?> getRole() async {
    return await storage.read(key: "role");
  }

  static Future<bool> isCustomAdmin() async {
    final role = await getRole();
    return role?.toLowerCase() == 'customadmin';
  }

  static Future<bool> hasAdminAccess() async {
    final role = await getRole();
    final roleLower = role?.toLowerCase() ?? '';
    return roleLower == 'admin' ||
        roleLower == 'customadmin' ||
        roleLower == 'superadmin';
  }

  // ==================== USER INFO ====================
  static Future<void> setEmail(String email) async {
    await storage.write(key: "user_email", value: email);
    if (kDebugMode) debugPrint("✅ Email saved: $email");
  }

  static Future<String?> getEmail() async {
    return await storage.read(key: "user_email");
  }

  static Future<void> setMobile(String mobile) async {
    await storage.write(key: "user_mobile", value: mobile);
    if (kDebugMode) debugPrint("✅ Mobile saved: $mobile");
  }

  static Future<String?> getMobile() async {
    return await storage.read(key: "user_mobile");
  }

  static Future<void> setName(String name) async {
    await storage.write(key: "user_name", value: name);
    if (kDebugMode) debugPrint("✅ Name saved: $name");
  }

  static Future<String?> getName() async {
    return await storage.read(key: "user_name");
  }

  // ==================== LOGIN STATE ====================
  static Future<void> saveIsLoggedIn(bool value) async {
    await storage.write(key: "is_logged_in", value: value.toString());
    if (kDebugMode) debugPrint("✅ Login state saved: $value");
  }

  static Future<bool> getIsLoggedIn() async {
    final val = await storage.read(key: "is_logged_in");
    return val == "true";
  }

  // ✅ NEW: Safe session check used by UI before redirecting
  static Future<bool> isSessionActive() async {
    final token = await getToken();
    final loggedIn = await getIsLoggedIn();
    return token != null && token.isNotEmpty && loggedIn;
  }

  // ==================== MPIN METHODS ====================
  static Future<void> saveMpin(String mpin) async {
    if (mpin.length != 6) throw Exception('MPIN must be 6 digits');
    await storage.write(key: "user_mpin", value: mpin);
    if (kDebugMode) debugPrint("✅ MPIN saved: $mpin");
  }

  static Future<String?> getMpin() async {
    return await storage.read(key: "user_mpin");
  }

  static Future<void> deleteMpin() async {
    await storage.delete(key: "user_mpin");
    if (kDebugMode) debugPrint("✅ MPIN deleted");
  }

  static Future<bool> hasMpin() async {
    final mpin = await getMpin();
    return mpin != null && mpin.isNotEmpty;
  }

  static Future<bool> verifyMpin(String enteredMpin) async {
    final savedMpin = await getMpin();
    return savedMpin == enteredMpin;
  }

  static Future<void> setMpinEnabled(bool value) async {
    await storage.write(key: "mpin_enabled", value: value.toString());
    if (kDebugMode) debugPrint("✅ MPIN enabled: $value");
  }

  static Future<bool> isMpinEnabled() async {
    final val = await storage.read(key: "mpin_enabled");
    return val == "true";
  }

  // ==================== ✅ BIOMETRIC - PERMANENT STORAGE ====================
  static Future<void> setBiometricEnabled(bool value) async {
    await storage.write(key: "biometric_enabled", value: value.toString());
    if (kDebugMode) debugPrint("🔐 Biometric enabled: $value");
  }

  static Future<bool> isBiometricEnabled() async {
    final val = await storage.read(key: "biometric_enabled");
    if (kDebugMode) debugPrint("🔐 Biometric enabled status: $val");
    return val == "true";
  }

  static Future<void> setBiometricType(String type) async {
    await storage.write(key: "biometric_type", value: type);
  }

  static Future<String?> getBiometricType() async {
    return await storage.read(key: "biometric_type");
  }

  // ==================== ✅ LOGOUT - NEVER DELETE BIOMETRIC/MPIN/EMAIL ====================
  static Future<void> logout() async {
    // ✅ Delete ONLY the auth tokens and login flag
    await storage.delete(key: "token");
    await storage.delete(key: "role");
    await storage.delete(key: "is_logged_in");

    // ✅ CRITICAL: NEVER DELETE THESE ON LOGOUT
    // - user_email, user_mobile, user_name (needed by MPIN/biometric)
    // - biometric_enabled, biometric_type
    // - mpin_enabled, user_mpin

    if (kDebugMode) {
      debugPrint("🔐 Logout - Auth tokens cleared");
      debugPrint("   ✅ Email retained: ${await getEmail()}");
      debugPrint("   ✅ Biometric enabled: ${await isBiometricEnabled()}");
      debugPrint("   ✅ MPIN enabled: ${await isMpinEnabled()}");
      debugPrint("   ✅ MPIN exists: ${await hasMpin()}");
    }
  }

  // ==================== ✅ DISABLE BIOMETRIC - ONLY FROM SETTINGS ====================
  static Future<void> disableBiometric() async {
    await storage.delete(key: "biometric_enabled");
    await storage.delete(key: "biometric_type");
    if (kDebugMode) debugPrint("🔐 Biometric disabled by user from settings");
  }

  // ==================== ✅ DISABLE MPIN - ONLY FROM SETTINGS ====================
  static Future<void> disableMpin() async {
    await storage.delete(key: "mpin_enabled");
    if (kDebugMode) debugPrint("🔐 MPIN disabled by user from settings");
  }

  // ==================== CLEAR - ONLY FOR FULL APP RESET ====================
  static Future<void> clear() async {
    await storage.deleteAll();
    if (kDebugMode) {
      debugPrint(
          "🔐 All storage cleared (FULL RESET - includes biometric and MPIN)");
    }
  }

  // ==================== ✅ CLEAR AUTH DATA - ONLY TOKENS ====================
  // ✅ CRITICAL FIX: Only delete tokens, NEVER email/mobile/name.
  // This prevents auto-logout from wiping user identity.
  static Future<void> clearAuthData() async {
    await storage.delete(key: "token");
    await storage.delete(key: "role");
    await storage.delete(key: "is_logged_in");
    // ❌ DO NOT delete user_email, user_mobile, user_name
    // ❌ DO NOT delete mpin/biometric
    if (kDebugMode) {
      debugPrint(
          "🔐 Auth tokens cleared (email, mobile, name, MPIN, biometric preserved)");
    }
  }
}