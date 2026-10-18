// lib/core/utils/stub_local_auth.dart
// Stub implementation for web platform

class LocalAuthentication {
  Future<bool> isDeviceSupported() async => false;
  
  // ✅ FIXED: canCheckBiometrics is a getter, not a method
  Future<bool> get canCheckBiometrics async => false;
  
  Future<List<dynamic>> getAvailableBiometrics() async => [];
  Future<bool> authenticate({
    required String localizedReason,
    required AuthenticationOptions options,
  }) async => false;
}

class AuthenticationOptions {
  final bool biometricOnly;
  final bool stickyAuth;

  AuthenticationOptions({
    required this.biometricOnly,
    required this.stickyAuth,
  });
}

class BiometricType {
  static const fingerprint = 'fingerprint';
  static const face = 'face';
  static const iris = 'iris';
}