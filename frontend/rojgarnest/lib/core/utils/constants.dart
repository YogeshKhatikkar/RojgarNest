// lib/core/utils/constants.dart
class AppConstants {
  static const String appName = "RojgarNest";
  static const String appVersion = "2.0.0";

  // Animation Durations
  static const Duration splashDuration = Duration(seconds: 2);
  static const Duration pageTransitionDuration = Duration(milliseconds: 300);
  static const Duration snackBarDuration = Duration(seconds: 3);

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Cache Keys
  static const String cacheJobsKey = "cached_jobs";
  static const String cacheProfileKey = "cached_profile";
  static const Duration cacheDuration = Duration(minutes: 15);

  // OTP
  static const int otpLength = 6;
  static const int otpResendSeconds = 60;

  // Password Requirements
  static const int minPasswordLength = 8;
  static const String passwordPattern =
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$';
}
