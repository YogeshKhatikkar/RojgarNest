// lib/features/auth/services/auth_service.dart
// ✅ Login ke baad photo ab CACHE me save hoti hai
// ✅ Next app open pe INSTANT load hoga

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:rojgarnest/core/network/dio_client.dart';
import 'package:rojgarnest/core/storage/secure_storage.dart';
import 'package:rojgarnest/core/services/profile_state_service.dart';

class AuthService {
  static const String _auth = "/auth";

  static Dio get _dio => DioClient.dio;

  static void _log(String msg) {
    if (kDebugMode) debugPrint(msg);
  }

  static dynamic _unwrap(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      if (responseData.containsKey('data') &&
          responseData['data'] != null) {
        return responseData['data'];
      }
    }
    return responseData;
  }

  // ============================================================
  // ✅ LOAD PROFILE PHOTO AFTER LOGIN — NOW SAVES TO CACHE
  // ============================================================
  static Future<void> loadProfilePhotoAfterLogin() async {
    try {
      _log("📸 AuthService: Loading profile photo after login...");

      // ✅ Force refresh ProfileStateService (which SAVES to cache)
      await ProfileStateService().loadPhotoFromBackend(forceRefresh: true);

      final photoUrl = ProfileStateService().profilePhotoUrl.value;
      final publicId = ProfileStateService().profilePhotoPublicId.value;

      _log("📸 AuthService: ProfileStateService photo = $photoUrl");
      _log("📸 AuthService: ProfileStateService publicId = $publicId");
      _log("📸 AuthService: Photo saved to CACHE for instant load next time");
    } catch (e) {
      _log("⚠️ AuthService: Failed to load profile photo: $e");
      // Don't fail login if photo load fails
    }
  }

  // ============================================================
  // REGISTER (unchanged)
  // ============================================================
  static Future<dynamic> register(
    Map<String, dynamic> data, {
    double? latitude,
    double? longitude,
    String? locationName,
  }) async {
    try {
      final Map<String, dynamic> requestData = <String, dynamic>{
        'name': data['name'] ?? '',
        'email': data['email'] ?? '',
        'mobile': data['mobile'] ?? '',
        'password': data['password'] ?? '',
      };

      if (latitude != null) requestData['latitude'] = latitude;
      if (longitude != null) requestData['longitude'] = longitude;
      if (locationName != null && locationName.isNotEmpty) {
        requestData['location_name'] = locationName;
      }

      _log("📤 Register: ${data['email']}");
      final Response res =
          await _dio.post("$_auth/register", data: requestData);
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.toApiException(e);
    }
  }

  // ============================================================
  // LOGIN (unchanged — already calls loadProfilePhotoAfterLogin)
  // ============================================================
  static Future<Map<String, dynamic>> login(
    Map<String, dynamic> data, {
    double? latitude,
    double? longitude,
    String? locationName,
    bool forceLocationUpdate = true,
  }) async {
    try {
      final Map<String, dynamic> requestData = <String, dynamic>{
        'email': data['email'] ?? '',
        'password': data['password'] ?? '',
      };

      if (latitude != null) requestData['latitude'] = latitude;
      if (longitude != null) requestData['longitude'] = longitude;
      if (locationName != null && locationName.isNotEmpty) {
        requestData['location_name'] = locationName;
      }
      if (forceLocationUpdate) {
        requestData['force_location_update'] = true;
      }

      debugPrint("📤 Login request: ${data['email']}");

      final Response res =
          await _dio.post("$_auth/login", data: requestData);

      dynamic unwrapped = _unwrap(res.data);

      if (unwrapped is! Map<String, dynamic>) {
        throw ApiException(
          statusCode: 500,
          code: 'INVALID_RESPONSE',
          message: 'Invalid response from server',
        );
      }

      final Map<String, dynamic> result = unwrapped;

      final String? accessToken = result["access_token"]?.toString();
      if (accessToken == null || accessToken.isEmpty) {
        throw ApiException(
          statusCode: 500,
          code: 'NO_TOKEN',
          message: 'Login failed: No access token received',
        );
      }

      // Save auth data
      await SecureStorage.setToken(accessToken);
      await SecureStorage.setRole(result["role"]?.toString() ?? "user");
      await SecureStorage.setEmail(
        result['email']?.toString() ?? data['email']?.toString() ?? "",
      );
      await SecureStorage.setMobile(result['mobile']?.toString() ?? "");
      await SecureStorage.setName(result['name']?.toString() ?? "");
      await SecureStorage.saveIsLoggedIn(true);

      debugPrint("✅ Login successful: ${result["role"]}");

      // ✅ Load profile photo AFTER login (SAVES to cache)
      await loadProfilePhotoAfterLogin();

      return result;
    } on DioException catch (e) {
      final apiEx = DioClient.toApiException(e);

      debugPrint("=" * 60);
      debugPrint("❌ LOGIN FAILED");
      debugPrint("   Status: ${apiEx.statusCode}");
      debugPrint("   Code: ${apiEx.code}");
      debugPrint("   Message: ${apiEx.message}");
      debugPrint("   Is Locked: ${apiEx.isAccountLocked}");
      debugPrint("   Seconds Remaining: ${apiEx.secondsRemaining}");
      debugPrint("   Lock Until: ${apiEx.lockUntil}");
      debugPrint("=" * 60);

      throw apiEx;
    }
  }

  // ============================================================
  // UPDATE LOCATION (unchanged)
  // ============================================================
  static Future<Map<String, dynamic>> updateLocation({
    required double latitude,
    required double longitude,
    String? locationName,
  }) async {
    try {
      final Map<String, dynamic> requestData = <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
      };

      if (locationName != null && locationName.isNotEmpty) {
        requestData['location_name'] = locationName;
      }

      final Response res = await _dio
          .post("$_auth/update-location", data: requestData);
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.toApiException(e);
    }
  }

  // ============================================================
  // GET MY LOCATION (unchanged)
  // ============================================================
  static Future<Map<String, dynamic>> getMyLocation() async {
    try {
      final Response res = await _dio.get("$_auth/my-location");
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.toApiException(e);
    }
  }

  // ============================================================
  // MPIN LOGIN (unchanged — already calls loadProfilePhotoAfterLogin)
  // ============================================================
  static Future<Map<String, dynamic>> loginPin(
      Map<String, dynamic> data) async {
    try {
      final Response res =
          await _dio.post("$_auth/login-pin", data: data);

      dynamic unwrapped = _unwrap(res.data);
      if (unwrapped is! Map<String, dynamic>) {
        throw ApiException(
          statusCode: 500,
          code: 'INVALID_RESPONSE',
          message: 'Invalid response',
        );
      }

      final Map<String, dynamic> result = unwrapped;

      final String? token = result["access_token"]?.toString();
      if (token == null || token.isEmpty) {
        throw ApiException(
          statusCode: 500,
          code: 'NO_TOKEN',
          message: 'MPIN login failed: No access token',
        );
      }

      await SecureStorage.setToken(token);
      await SecureStorage.setRole(result["role"]?.toString() ?? "user");
      await SecureStorage.setEmail(result["email"]?.toString() ?? "");
      await SecureStorage.setName(result["name"]?.toString() ?? "");
      await SecureStorage.setMobile(result["mobile"]?.toString() ?? "");
      await SecureStorage.saveIsLoggedIn(true);

      // ✅ Load profile photo AFTER MPIN login (SAVES to cache)
      await loadProfilePhotoAfterLogin();

      return result;
    } on DioException catch (e) {
      throw DioClient.toApiException(e);
    }
  }

  // ============================================================
  // MPIN SETUP (unchanged)
  // ============================================================
  static Future<dynamic> setupMpin(
      Map<String, dynamic> data) async {
    try {
      final String email = data["email"]?.toString().trim() ?? "";

      if (!email.contains('@')) {
        throw ApiException(
          statusCode: 400,
          code: 'INVALID_EMAIL',
          message: "Please login again with email & password first",
        );
      }

      final String pin = data["pin"]?.toString().trim() ?? "";

      if (pin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(pin)) {
        throw ApiException(
          statusCode: 400,
          code: 'INVALID_PIN',
          message: "PIN must be 6 digits",
        );
      }

      final Map<String, dynamic> requestData = {
        "email": email,
        "pin": pin,
      };

      final Response res =
          await _dio.post("$_auth/set-pin", data: requestData);
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.toApiException(e);
    }
  }

  // ============================================================
  // ENABLE BIOMETRIC (unchanged)
  // ============================================================
  static Future<dynamic> enableBiometric(
      Map<String, dynamic> data) async {
    try {
      final String email = data["email"]?.toString().trim() ?? "";

      if (email.isEmpty || !email.contains('@')) {
        throw ApiException(
          statusCode: 400,
          code: 'INVALID_EMAIL',
          message: "Invalid email",
        );
      }

      final String biometricType =
          data["biometric_type"] ?? "fingerprint";
      final allowedTypes = [
        "fingerprint",
        "face",
        "iris",
        "none"
      ];
      final String validType = allowedTypes.contains(biometricType)
          ? biometricType
          : "fingerprint";

      final Map<String, dynamic> requestData = {
        "email": email,
        "device_info": data["device_info"] ?? "Flutter Device",
        "device_id": data["device_id"] ?? "",
        "biometric_type": validType,
      };

      final Response res = await _dio
          .post("$_auth/enable-biometric", data: requestData);

      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.toApiException(e);
    }
  }

  // ============================================================
  // BIOMETRIC LOGIN (unchanged — already calls loadProfilePhotoAfterLogin)
  // ============================================================
  static Future<Map<String, dynamic>> biometricLogin(
      Map<String, dynamic> data) async {
    try {
      final String email = data["email"]?.toString().trim() ?? "";

      if (email.isEmpty || !email.contains('@')) {
        throw ApiException(
          statusCode: 400,
          code: 'INVALID_EMAIL',
          message: "Invalid email",
        );
      }

      final Map<String, dynamic> requestData = <String, dynamic>{
        "email": email,
        "device_info": data["device_info"] ?? "Flutter Device",
      };

      if (data.containsKey('latitude') && data['latitude'] != null) {
        requestData['latitude'] = data['latitude'];
        requestData['longitude'] = data['longitude'];
        requestData['location_name'] = data['location_name'];
      }

      final Response res = await _dio
          .post("$_auth/biometric-login", data: requestData);

      dynamic unwrapped = _unwrap(res.data);
      if (unwrapped is! Map<String, dynamic>) {
        throw ApiException(
          statusCode: 500,
          code: 'INVALID_RESPONSE',
          message: 'Invalid response',
        );
      }

      final Map<String, dynamic> result = unwrapped;

      final String? token = result["access_token"]?.toString();
      if (token == null || token.isEmpty) {
        throw ApiException(
          statusCode: 500,
          code: 'NO_TOKEN',
          message: "Biometric login failed: No access token",
        );
      }

      await SecureStorage.setToken(token);
      await SecureStorage.setRole(result["role"]?.toString() ?? "user");
      await SecureStorage.setEmail(
          result["email"]?.toString() ?? email);
      await SecureStorage.setName(result["name"]?.toString() ?? "");
      await SecureStorage.setMobile(result["mobile"]?.toString() ?? "");
      await SecureStorage.saveIsLoggedIn(true);

      // ✅ Load profile photo AFTER biometric login (SAVES to cache)
      await loadProfilePhotoAfterLogin();

      return result;
    } on DioException catch (e) {
      throw DioClient.toApiException(e);
    }
  }

  // ============================================================
  // FORGOT PASSWORD (unchanged)
  // ============================================================
  static Future<Map<String, dynamic>> forgotPassword(
      String email) async {
    try {
      final Response res = await _dio.post("$_auth/forgot-password",
          data: <String, dynamic>{"email": email});
      final Map<String, dynamic> body =
          _unwrap(res.data) as Map<String, dynamic>;
      final String mobile = body['mobile']?.toString() ?? '';
      if (mobile.isNotEmpty) {
        await SecureStorage.setMobile(mobile);
      }
      return body;
    } on DioException catch (e) {
      throw DioClient.toApiException(e);
    }
  }

  // ============================================================
  // RESEND RESET EMAIL OTP (unchanged)
  // ============================================================
  static Future<dynamic> resendResetEmailOtp(String email) async {
    try {
      final Response res = await _dio.post("$_auth/resend-reset-email-otp",
          data: <String, dynamic>{"email": email});
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.toApiException(e);
    }
  }

  // ============================================================
  // RESEND RESET MOBILE OTP (unchanged)
  // ============================================================
  static Future<dynamic> resendResetMobileOtp(String mobile) async {
    try {
      final Response res = await _dio.post("$_auth/resend-reset-mobile-otp",
          data: <String, dynamic>{"mobile": mobile});
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.toApiException(e);
    }
  }

  // ============================================================
  // VERIFY RESET EMAIL (unchanged)
  // ============================================================
  static Future<dynamic> verifyResetEmail(
      Map<String, dynamic> data) async {
    try {
      final Response res = await _dio
          .post("$_auth/verify-reset-email", data: data);
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.toApiException(e);
    }
  }

  // ============================================================
  // VERIFY RESET MOBILE (unchanged)
  // ============================================================
  static Future<dynamic> verifyResetMobile(
      Map<String, dynamic> data) async {
    try {
      final Response res = await _dio
          .post("$_auth/verify-reset-mobile", data: data);
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.toApiException(e);
    }
  }

  // ============================================================
  // RESET PASSWORD (unchanged)
  // ============================================================
  static Future<dynamic> resetPassword(
      Map<String, dynamic> data) async {
    try {
      final Response res =
          await _dio.post("$_auth/reset-password", data: data);
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.toApiException(e);
    }
  }

  // ============================================================
  // VERIFY EMAIL (unchanged)
  // ============================================================
  static Future<dynamic> verifyEmail(
      Map<String, dynamic> data) async {
    try {
      final Response res =
          await _dio.post("$_auth/verify-email", data: data);
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.toApiException(e);
    }
  }

  // ============================================================
  // VERIFY MOBILE (unchanged)
  // ============================================================
  static Future<dynamic> verifyMobile(
      Map<String, dynamic> data) async {
    try {
      final Response res =
          await _dio.post("$_auth/verify-mobile", data: data);
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.toApiException(e);
    }
  }

  // ============================================================
  // RESEND EMAIL OTP (unchanged)
  // ============================================================
  static Future<dynamic> resendEmailOtp(String email) async {
    try {
      final Response res = await _dio.post("$_auth/resend-email-otp",
          data: <String, dynamic>{"email": email});
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.toApiException(e);
    }
  }

  // ============================================================
  // RESEND MOBILE OTP (unchanged)
  // ============================================================
  static Future<dynamic> resendMobileOtp(String mobile) async {
    try {
      final Response res = await _dio.post("$_auth/resend-mobile-otp",
          data: <String, dynamic>{"mobile": mobile});
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw DioClient.toApiException(e);
    }
  }
}