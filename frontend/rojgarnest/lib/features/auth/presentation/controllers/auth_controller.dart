// lib/features/auth/presentation/controllers/auth_controller.dart
// ✅ COMPLETE PRODUCTION-READY VERSION
// ✅ AUTO-UNLOCK: Locked account automatically unlocks after countdown
// ✅ Live countdown timer shown to user
// ✅ Profile photo loaded after every login type
// ✅ All original functionality preserved

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:local_auth/local_auth.dart';

import 'package:rojgarnest/core/storage/secure_storage.dart';
import 'package:rojgarnest/core/network/dio_client.dart';
import 'package:rojgarnest/core/services/profile_state_service.dart';
import 'package:rojgarnest/features/auth/services/auth_service.dart';
import 'package:rojgarnest/core/routes/app_routes.dart';
import 'package:rojgarnest/core/services/unified_location_service.dart';
import 'package:rojgarnest/core/utils/platform_utils.dart';
import 'package:rojgarnest/features/auth/presentation/screens/fingerprint_setup_page.dart';

typedef MessageCallback = void Function(String message,
    {bool isError});

class AuthController extends ChangeNotifier {
  bool isLoading = false;
  MessageCallback? onShowMessage;

  bool _isResetEmailVerified = false;
  bool _isResetMobileVerified = false;

  // ============================================================
  // ACCOUNT LOCK STATE
  // ============================================================
  bool _isAccountLocked = false;
  int _lockSecondsRemaining = 0;
  DateTime? _lockUntil;
  Timer? _lockCountdownTimer;
  String? _lockedEmail;

  bool get isAccountLocked => _isAccountLocked;
  int get lockSecondsRemaining => _lockSecondsRemaining;
  DateTime? get lockUntil => _lockUntil;
  String? get lockedEmail => _lockedEmail;

  // ============================================================
  // LOCATION STATE
  // ============================================================
  Map<String, dynamic>? _currentLocation;
  DateTime? _lastLocationUpdate;
  bool _hasLocation = false;
  String? _locationSource;
  String _lastLocationError = '';

  Map<String, dynamic>? get currentLocation => _currentLocation;
  DateTime? get lastLocationUpdate => _lastLocationUpdate;
  bool get hasLocation => _hasLocation;
  String? get locationSource => _locationSource;
  String get lastLocationError => _lastLocationError;

  // ============================================================
  // INTERNET STATE
  // ============================================================
  bool _isConnected = true;
  bool get isConnected => _isConnected;

  void setConnected(bool connected) {
    _isConnected = connected;
    notifyListeners();
  }

  void initialize({MessageCallback? onShowMessage}) {
    this.onShowMessage = onShowMessage;
  }

  void _setLoading(bool val) {
    isLoading = val;
    notifyListeners();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (onShowMessage != null) {
      onShowMessage!(message, isError: isError);
    } else {
      debugPrint("📝 Message: $message");
    }
  }

  // ============================================================
  // ACCOUNT LOCK HANDLING
  // ============================================================
  void _startLockCountdown({
    required int secondsRemaining,
    required String email,
    DateTime? lockUntil,
  }) {
    _lockCountdownTimer?.cancel();

    _isAccountLocked = true;
    _lockSecondsRemaining = secondsRemaining;
    _lockedEmail = email;
    _lockUntil = lockUntil ??
        DateTime.now().add(Duration(seconds: secondsRemaining));

    debugPrint(
        "🔒 Account locked for $secondsRemaining seconds");
    notifyListeners();

    _lockCountdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (_lockSecondsRemaining <= 1) {
          timer.cancel();
          _onLockExpired();
        } else {
          _lockSecondsRemaining--;
          notifyListeners();
        }
      },
    );
  }

  void _onLockExpired() {
    debugPrint("✅ Account lock expired - auto-unlocking");
    _isAccountLocked = false;
    _lockSecondsRemaining = 0;
    _lockUntil = null;
    final unlockedEmail = _lockedEmail;
    _lockedEmail = null;
    notifyListeners();

    _showMessage(
      "✅ Account unlocked! You can now login again.",
      isError: false,
    );

    debugPrint("✅ Auto-unlocked for: $unlockedEmail");
  }

  void stopLockCountdown() {
    _lockCountdownTimer?.cancel();
    _lockCountdownTimer = null;
    _isAccountLocked = false;
    _lockSecondsRemaining = 0;
    _lockUntil = null;
    _lockedEmail = null;
    notifyListeners();
  }

  String get lockCountdownDisplay {
    if (_lockSecondsRemaining <= 0) return "0:00";

    final minutes = _lockSecondsRemaining ~/ 60;
    final seconds = _lockSecondsRemaining % 60;

    if (minutes > 0) {
      return "$minutes:${seconds.toString().padLeft(2, '0')}";
    }
    return "${seconds}s";
  }

  String get lockCountdownHumanReadable {
    if (_lockSecondsRemaining <= 0) return "0 seconds";

    final minutes = _lockSecondsRemaining ~/ 60;
    final seconds = _lockSecondsRemaining % 60;

    if (minutes > 0) {
      return "$minutes minute${minutes > 1 ? 's' : ''} ${seconds > 0 ? '$seconds second${seconds > 1 ? 's' : ''}' : ''}";
    }
    return "$seconds second${seconds > 1 ? 's' : ''}";
  }

  // ============================================================
  // GET STORED EMAIL
  // ============================================================
  Future<String?> _getStoredEmail() async {
    try {
      String? email = await SecureStorage.getEmail();
      if (email != null && email.isNotEmpty) return email;

      try {
        final prefs = await SharedPreferences.getInstance();
        email = prefs.getString('user_email');
        if (email != null && email.isNotEmpty) {
          await SecureStorage.setEmail(email);
          return email;
        }
      } catch (e) {
        debugPrint("SharedPreferences email read error: $e");
      }

      try {
        final box = await Hive.openBox('user_data');
        final hiveEmail = box.get('email');
        if (hiveEmail != null &&
            hiveEmail.toString().isNotEmpty) {
          email = hiveEmail.toString();
          await SecureStorage.setEmail(email);
          return email;
        }
      } catch (e) {
        debugPrint("Hive email read error: $e");
      }

      return null;
    } catch (e) {
      debugPrint("Error getting stored email: $e");
      return null;
    }
  }

  // ============================================================
  // LOCATION METHODS
  // ============================================================
  Future<Map<String, dynamic>?>
      getCurrentLocationWithDetails() async {
    _setLoading(true);
    _lastLocationError = '';

    try {
      final location =
          await UnifiedLocationService.getCurrentLocation();
      _currentLocation = location;
      _hasLocation = true;
      _locationSource = location['source'];
      _lastLocationUpdate = DateTime.now();
      notifyListeners();
      return location;
    } catch (e) {
      _lastLocationError = e.toString();
      _showMessage(
        '❌ Location Error: ${e.toString().replaceAll('Exception:', '')}',
        isError: true,
      );
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // REGISTER
  // ============================================================
  Future<void> register(
      Map<String, dynamic> data, BuildContext context) async {
    _setLoading(true);
    try {
      await AuthService.register(data);
      await SecureStorage.setEmail(data['email'] ?? '');
      await SecureStorage.setMobile(data['mobile'] ?? '');
      _showMessage(
          "OTP sent to Email & Mobile 📩\nMobile OTP: 123456 (Dev Mode)");
      if (context.mounted) {
        GoRouter.of(context).push(
          AppRoutes.verifyOtp,
          extra: <String, dynamic>{
            'email': data['email'],
            'mobile': data['mobile'],
          },
        );
      }
    } catch (e) {
      _showMessage(
        e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // LOGIN - WITH AUTO-UNLOCK SUPPORT + PHOTO LOAD
  // ============================================================
  Future<void> login(
      String email, String password, BuildContext context) async {
    // Prevent login if still locked
    if (_isAccountLocked) {
      _showMessage(
        "🔒 Account is locked. Please wait ${lockCountdownHumanReadable}.",
        isError: true,
      );
      return;
    }

    // Input validation
    if (email.isEmpty) {
      _showMessage("Please enter your email address",
          isError: true);
      return;
    }
    if (password.isEmpty) {
      _showMessage("Please enter your password", isError: true);
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      _showMessage("Please enter a valid email address",
          isError: true);
      return;
    }
    if (password.length < 6) {
      _showMessage(
          "Password must be at least 6 characters",
          isError: true);
      return;
    }

    _setLoading(true);

    try {
      final Map<String, dynamic> res =
          await AuthService.login(<String, dynamic>{
        "email": email,
        "password": password,
      });

      if (res['access_token'] == null ||
          res['access_token'].isEmpty) {
        throw ApiException(
          statusCode: 500,
          code: 'NO_TOKEN',
          message:
              "Login failed. Please check your credentials.",
        );
      }

      // Clear any lock state on success
      stopLockCountdown();

      final String role =
          (res["role"] ?? "user").toString().toLowerCase();

      // ✅ Load profile photo (already loaded by AuthService,
      // but ensure it's done)
      try {
        if (!ProfileStateService()
            .hasInitialPhotoLoaded
            .value) {
          await ProfileStateService().loadPhotoFromBackend();
        }
        debugPrint(
            "📸 Login: Photo = ${ProfileStateService().profilePhotoUrl.value}");
      } catch (photoError) {
        debugPrint(
            "⚠️ Login: Photo load failed: $photoError");
      }

      notifyListeners();
      _showMessage("Login Successful! ✅");

      if (context.mounted) {
        switch (role) {
          case "superadmin":
            GoRouter.of(context)
                .pushReplacement(AppRoutes.superAdminDashboard);
            break;
          case "admin":
            GoRouter.of(context)
                .pushReplacement(AppRoutes.adminDashboard);
            break;
          case "customadmin":
            GoRouter.of(context)
                .pushReplacement(AppRoutes.customAdminDashboard);
            break;
          default:
            GoRouter.of(context)
                .pushReplacement(AppRoutes.userDashboard);
        }
      }
    } catch (e) {
      String errorMessage =
          e.toString().replaceAll("Exception:", "").trim();

      if (e is ApiException) {
        if (e.isAccountLocked) {
          final seconds = e.secondsRemaining ?? 1800;
          _startLockCountdown(
            secondsRemaining: seconds,
            email: email,
            lockUntil: e.lockUntil,
          );

          _showMessage(
            "🔒 Account locked for ${lockCountdownHumanReadable}. Auto-unlock in progress...",
            isError: true,
          );
        } else if (e.code == 'INVALID_PASSWORD' ||
            e.code == 'EMAIL_NOT_VERIFIED' ||
            e.code == 'MOBILE_NOT_VERIFIED') {
          _showMessage(e.message, isError: true);
        } else if (e.statusCode == 400) {
          _showMessage(e.message, isError: true);
        } else {
          _showMessage(e.message, isError: true);
        }
      } else {
        final lowerError = errorMessage.toLowerCase();

        if (lowerError.contains("locked") ||
            lowerError.contains("temporarily locked")) {
          int seconds = 1800;
          final match = RegExp(r'(\d+)\s*second')
              .firstMatch(lowerError);
          if (match != null) {
            seconds =
                int.tryParse(match.group(1) ?? '1800') ??
                    1800;
          }

          _startLockCountdown(
            secondsRemaining: seconds,
            email: email,
          );

          _showMessage(
            "🔒 Account locked. Auto-unlock in progress...",
            isError: true,
          );
        } else {
          _showMessage(errorMessage, isError: true);
        }
      }
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // UPDATE LOCATION
  // ============================================================
  Future<bool> updateUserLocation() async {
    _setLoading(true);
    final location = await getCurrentLocationWithDetails();
    if (location == null) {
      _showMessage(
          "Could not get current location. Please enable GPS.",
          isError: true);
      _setLoading(false);
      return false;
    }

    try {
      final Map<String, dynamic> result =
          await AuthService.updateLocation(
        latitude: location['latitude'] as double,
        longitude: location['longitude'] as double,
        locationName:
            location['location_name'] as String?,
      );
      _showMessage("Location updated successfully!");
      _currentLocation = result['current_location'];
      _hasLocation = true;
      notifyListeners();
      return result['success'] == true;
    } catch (e) {
      _showMessage("Failed to update location: $e",
          isError: true);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>?> getUserLocationDetails() async {
    try {
      final result = await AuthService.getMyLocation();
      if (result['success'] == true) {
        _currentLocation = result['location'];
        _hasLocation = result['has_location'] ?? false;
        notifyListeners();
      }
      return result;
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // OTP METHODS
  // ============================================================
  Future<void> resendEmailOtp(String email) async {
    try {
      await AuthService.resendEmailOtp(email);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> resendMobileOtp(String mobile) async {
    try {
      await AuthService.resendMobileOtp(mobile);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> verifyEmailOtp(String email, String otp) async {
    await AuthService.verifyEmail(
        <String, dynamic>{"email": email, "otp": otp});
  }

  Future<void> verifyMobileOtp(
      String mobile, String otp) async {
    await AuthService.verifyMobile(
        <String, dynamic>{"mobile": mobile, "otp": otp});
  }

  // ============================================================
  // FORGOT PASSWORD
  // ============================================================
  Future<Map<String, dynamic>?> sendResetOtp(
      String email) async {
    if (email.isEmpty) {
      _showMessage("Email is required", isError: true);
      return null;
    }
    _setLoading(true);
    try {
      _isResetEmailVerified = false;
      _isResetMobileVerified = false;
      final result = await AuthService.forgotPassword(email);
      _showMessage("OTP sent to Email & Mobile 📩");
      return result;
    } catch (e) {
      _showMessage(
        e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> resendResetEmailOtp(String email) async {
    try {
      await AuthService.resendResetEmailOtp(email);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> resendResetMobileOtp(String mobile) async {
    try {
      await AuthService.resendResetMobileOtp(mobile);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> verifyResetOtp(String email, String mobile,
      String emailOtp, String mobileOtp) async {
    _setLoading(true);
    try {
      await AuthService.verifyResetEmail(
          <String, dynamic>{"email": email, "otp": emailOtp});
      _isResetEmailVerified = true;
      await AuthService.verifyResetMobile(
          <String, dynamic>{"mobile": mobile, "otp": mobileOtp});
      _isResetMobileVerified = true;
      _showMessage("OTP Verified! ✅");
      return true;
    } catch (e) {
      _isResetEmailVerified = false;
      _isResetMobileVerified = false;
      _showMessage(
        e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
      return false;
    } finally {
      _setLoading(false);
    }
  }

  bool get isResetOtpVerified =>
      _isResetEmailVerified && _isResetMobileVerified;

  Future<bool> resetPassword(
      String email, String newPassword) async {
    if (!isResetOtpVerified) {
      _showMessage("Please verify OTP first",
          isError: true);
      return false;
    }
    _setLoading(true);
    try {
      await AuthService.resetPassword(<String, dynamic>{
        "email": email,
        "new_password": newPassword,
      });
      await SecureStorage.logout();
      _showMessage(
          "Password changed! 🎉 Please login with your new password.");
      _isResetEmailVerified = false;
      _isResetMobileVerified = false;
      clearLocationCache();
      return true;
    } catch (e) {
      _showMessage(
        e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> changePassword(
      String email, String newPassword) async {
    return await resetPassword(email, newPassword);
  }

  // ============================================================
  // MPIN SETUP
  // ============================================================
  Future<void> setupMpin(String email, String pin) async {
    if (pin.length != 6 ||
        !RegExp(r'^\d{6}$').hasMatch(pin)) {
      _showMessage("MPIN must be 6 digits", isError: true);
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      _showMessage(
          "Invalid email. Please login again with email & password.",
          isError: true);
      return;
    }
    _setLoading(true);
    try {
      final token = await SecureStorage.getToken();
      if (token == null || token.isEmpty) {
        _showMessage("Please login again", isError: true);
        return;
      }
      final requestData = <String, String>{
        "email": email.trim(),
        "pin": pin,
      };
      await AuthService.setupMpin(requestData);
      await SecureStorage.saveMpin(pin);
      await SecureStorage.setMpinEnabled(true);
      _showMessage("MPIN Setup Successful! ✅");
    } catch (e) {
      _showMessage(
        e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // BIOMETRIC
  // ============================================================
  Future<void> enableBiometric(String email) async {
    if (email.isEmpty || !email.contains('@')) {
      _showMessage(
          "Invalid email. Please login again.",
          isError: true);
      return;
    }
    _setLoading(true);
    try {
      final token = await SecureStorage.getToken();
      if (token == null || token.isEmpty) {
        _showMessage("Please login again", isError: true);
        return;
      }
      final biometricType = await _getBiometricType();
      final deviceInfo = await _getDeviceInfo();
      final deviceId = await _getDeviceId();
      final requestData = <String, dynamic>{
        "email": email.trim(),
        "device_info": deviceInfo,
        "device_id": deviceId,
        "biometric_type": biometricType,
      };
      await AuthService.enableBiometric(requestData);
      await SecureStorage.setBiometricEnabled(true);
      await SecureStorage.setBiometricType(biometricType);
      _showMessage(
          "🔐 Fingerprint Login Enabled Successfully!");
    } catch (e) {
      _showMessage(
        e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<String> _getBiometricType() async {
    try {
      if (PlatformUtils.isWeb) return "fingerprint";
      final localAuth = LocalAuthentication();
      final isSupported =
          await localAuth.isDeviceSupported();
      if (!isSupported) return "fingerprint";
      final available =
          await localAuth.getAvailableBiometrics();
      if (available.contains(BiometricType.fingerprint)) {
        return "fingerprint";
      }
      if (available.contains(BiometricType.face)) {
        return "face";
      }
      if (available.contains(BiometricType.iris)) {
        return "iris";
      }
      return "fingerprint";
    } catch (e) {
      return "fingerprint";
    }
  }

  Future<String> _getDeviceInfo() async {
    try {
      if (PlatformUtils.isWeb) return "Web Browser";
      if (PlatformUtils.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.manufacturer} ${androidInfo.model} (Android ${androidInfo.version.release})';
      } else if (PlatformUtils.isIOS) {
        final deviceInfo = DeviceInfoPlugin();
        final iosInfo = await deviceInfo.iosInfo;
        return '${iosInfo.name} (iOS ${iosInfo.systemVersion})';
      }
      return "Flutter Device - ${DateTime.now().millisecondsSinceEpoch}";
    } catch (e) {
      return "Unknown Device";
    }
  }

  Future<String> _getDeviceId() async {
    try {
      if (PlatformUtils.isWeb) {
        return "web_${DateTime.now().millisecondsSinceEpoch}";
      }
      if (PlatformUtils.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (PlatformUtils.isIOS) {
        final deviceInfo = DeviceInfoPlugin();
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? '';
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  // ============================================================
  // MPIN LOGIN - WITH PHOTO LOAD
  // ============================================================
  Future<void> loginWithMpin(
      String email, String pin, BuildContext context) async {
    if (pin.length != 6 ||
        !RegExp(r'^\d{6}$').hasMatch(pin)) {
      _showMessage("Enter valid 6-digit MPIN",
          isError: true);
      return;
    }
    _setLoading(true);
    try {
      final Map<String, dynamic> requestData = {
        "email": email,
        "pin": pin,
      };
      final res = await AuthService.loginPin(requestData);
      if (res['success'] == false ||
          res['access_token'] == null) {
        throw ApiException(
          statusCode: 400,
          code: 'MPIN_FAILED',
          message: res['message'] ?? 'MPIN login failed.',
        );
      }
      final String role =
          (res["role"] ?? "user").toString().toLowerCase();

      // ✅ Load profile photo (already loaded by AuthService)
      try {
        if (!ProfileStateService()
            .hasInitialPhotoLoaded
            .value) {
          await ProfileStateService().loadPhotoFromBackend();
        }
        debugPrint(
            "📸 MPIN Login: Photo = ${ProfileStateService().profilePhotoUrl.value}");
      } catch (photoError) {
        debugPrint(
            "⚠️ MPIN Login: Photo load failed: $photoError");
      }

      notifyListeners();
      _showMessage("MPIN Login Successful ✅");
      if (context.mounted) {
        switch (role) {
          case "superadmin":
            GoRouter.of(context)
                .pushReplacement(AppRoutes.superAdminDashboard);
            break;
          case "admin":
            GoRouter.of(context)
                .pushReplacement(AppRoutes.adminDashboard);
            break;
          case "customadmin":
            GoRouter.of(context)
                .pushReplacement(AppRoutes.customAdminDashboard);
            break;
          default:
            GoRouter.of(context)
                .pushReplacement(AppRoutes.userDashboard);
        }
      }
    } catch (e) {
      _showMessage(
        e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // BIOMETRIC LOGIN - WITH PHOTO LOAD
  // ============================================================
  Future<void> biometricLogin(BuildContext context) async {
    _setLoading(true);
    try {
      if (PlatformUtils.isWeb) {
        _showMessage(
          '🌐 Fingerprint login is not available on Web browsers.',
          isError: true,
        );
        _setLoading(false);
        return;
      }
      final isBiometricEnabled =
          await SecureStorage.isBiometricEnabled();
      if (!isBiometricEnabled) {
        final shouldEnable =
            await _showEnableBiometricDialog(context);
        if (shouldEnable == true && context.mounted) {
          final email = await _getStoredEmail();
          if (email != null && email.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    FingerprintSetupPage(email: email),
              ),
            );
          } else {
            _showMessage(
              '📧 Please login with email & password first to enable fingerprint.',
              isError: true,
            );
          }
        }
        _setLoading(false);
        return;
      }
      final localAuth = LocalAuthentication();
      final isDeviceSupported =
          await localAuth.isDeviceSupported();
      if (!isDeviceSupported) {
        _showMessage(
          '📱 Fingerprint authentication is not supported on this device.',
          isError: true,
        );
        _setLoading(false);
        return;
      }
      final canCheckBiometrics =
          await localAuth.canCheckBiometrics;
      if (!canCheckBiometrics) {
        _showMessage(
          '❌ No fingerprint enrolled.\nPlease enable fingerprint in device settings.',
          isError: true,
        );
        _setLoading(false);
        return;
      }
      String? email = await _getStoredEmail();
      if (email == null || email.isEmpty) {
        _showMessage(
          '📧 Email not found.\nPlease login with email & password once.',
          isError: true,
        );
        _setLoading(false);
        return;
      }
      final didAuthenticate = await localAuth.authenticate(
        localizedReason:
            'Login to RojgarNest with your fingerprint',
        options: AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!didAuthenticate) {
        _showMessage(
          '❌ Fingerprint authentication cancelled or failed.',
          isError: true,
        );
        _setLoading(false);
        return;
      }
      final requestData = <String, dynamic>{
        "email": email,
        "device_info": await _getDeviceInfo(),
        "device_id": await _getDeviceId(),
      };
      final res = await AuthService.biometricLogin(requestData);
      if (res['success'] == false ||
          res['access_token'] == null) {
        throw ApiException(
          statusCode: 400,
          code: 'BIOMETRIC_FAILED',
          message: res['message'] ?? 'Biometric login failed.',
        );
      }
      final String role =
          (res["role"] ?? "user").toString().toLowerCase();
      await SecureStorage.setToken(res['access_token']);
      await SecureStorage.setRole(role);
      await SecureStorage.setEmail(res['email'] ?? email);
      await SecureStorage.setName(res['name'] ?? '');
      await SecureStorage.setMobile(res['mobile'] ?? '');
      await SecureStorage.setBiometricEnabled(true);

      // ✅ Load profile photo (already loaded by AuthService)
      try {
        if (!ProfileStateService()
            .hasInitialPhotoLoaded
            .value) {
          await ProfileStateService().loadPhotoFromBackend();
        }
        debugPrint(
            "📸 Biometric Login: Photo = ${ProfileStateService().profilePhotoUrl.value}");
      } catch (photoError) {
        debugPrint(
            "⚠️ Biometric Login: Photo load failed: $photoError");
      }

      notifyListeners();
      _showMessage("✅ Fingerprint Login Successful! 🎉");
      if (context.mounted) {
        switch (role) {
          case "superadmin":
            GoRouter.of(context)
                .pushReplacement(AppRoutes.superAdminDashboard);
            break;
          case "admin":
            GoRouter.of(context)
                .pushReplacement(AppRoutes.adminDashboard);
            break;
          case "customadmin":
            GoRouter.of(context)
                .pushReplacement(AppRoutes.customAdminDashboard);
            break;
          default:
            GoRouter.of(context)
                .pushReplacement(AppRoutes.userDashboard);
        }
      }
    } catch (e) {
      _showMessage(
        "❌ Fingerprint login failed: ${e.toString().replaceAll('Exception:', '').trim()}",
        isError: true,
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<bool?> _showEnableBiometricDialog(
      BuildContext context) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.fingerprint,
                color: Colors.blue, size: 28),
            SizedBox(width: 12),
            Text("Enable Fingerprint Login"),
          ],
        ),
        content: const Text(
          "Fingerprint login is not enabled yet.\n\n"
          "Would you like to enable it now?\n\n"
          "✅ Your fingerprint will NEVER be deleted on logout.",
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fingerprint,
                    size: 18, color: Colors.white),
                SizedBox(width: 8),
                Text("Enable Now"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> checkAndHandleBiometricLogin(
      BuildContext context) async {
    return await biometricLogin(context);
  }

  // ============================================================
  // LOGOUT - WITH PHOTO RESET
  // ============================================================
  Future<void> logout() async {
    stopLockCountdown();
    await SecureStorage.logout();

    // ✅ Reset profile photo state
    ProfileStateService().reset();

    _currentLocation = null;
    _lastLocationUpdate = null;
    _hasLocation = false;
    _locationSource = null;
    _lastLocationError = '';
    notifyListeners();

    debugPrint("👋 AuthController: Logout complete");
  }

  void clearLocationCache() {
    _currentLocation = null;
    _lastLocationUpdate = null;
    _hasLocation = false;
    _locationSource = null;
    _lastLocationError = '';
    notifyListeners();
  }

  Future<String?> getCurrentEmail() async =>
      await SecureStorage.getEmail();
  Future<String?> getCurrentRole() async =>
      await SecureStorage.getRole();

  Future<Map<String, String>> getUserDetails() async {
    return <String, String>{
      'email': await SecureStorage.getEmail() ?? '',
      'mobile': await SecureStorage.getMobile() ?? '',
      'role': await SecureStorage.getRole() ?? 'user',
    };
  }

  @override
  void dispose() {
    stopLockCountdown();
    super.dispose();
  }
}