// lib/features/payment/razorpay_web_stub.dart
// ✅ Android/iOS stub — used INSTEAD of razorpay_web_service.dart
// when compiling for native platforms.
//
// This file is intentionally safe: it does NOT import dart:js.

class RazorpayWebService {
  static RazorpayWebService? _instance;

  RazorpayWebService._internal();

  static RazorpayWebService get instance {
    _instance ??= RazorpayWebService._internal();
    return _instance!;
  }

  Future<void> initiatePayment({
    required int amount,
    required String orderId,
    required String keyId,
    required String userEmail,
    required String userName,
    required String userMobile,
    required Function(Map<String, dynamic>) onSuccess,
    required Function(String) onError,
    required Function() onExternalWallet,
  }) async {
    onError(
      "Web payment is not available on this platform. Please use the mobile app.",
    );
  }

  void dispose() {}
}