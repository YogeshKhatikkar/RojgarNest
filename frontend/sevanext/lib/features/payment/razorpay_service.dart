// lib/features/payment/razorpay_service.dart
// ✅ Correct conditional import — Android uses stub, web uses real service.

import 'package:flutter/foundation.dart' show kIsWeb;

// ⬇️ On Android/iOS/Desktop  → uses razorpay_web_stub.dart
//    On Web                  → uses razorpay_web_service.dart
import 'razorpay_web_stub.dart'
    if (dart.library.js_interop) 'razorpay_web_service.dart' as web;

import 'razorpay_mobile_service.dart' as mobile;

class RazorpayService {
  static RazorpayService? _instance;

  RazorpayService._internal();

  static RazorpayService get instance {
    _instance ??= RazorpayService._internal();
    return _instance!;
  }

  /// `amount` MUST be in RUPEES.
  /// This service converts to paise exactly once before calling Razorpay.
  Future<void> initiatePayment({
    required int amount,           // ← RUPEES
    required String orderId,
    required String keyId,
    required String userEmail,
    required String userName,
    required String userMobile,
    required Function(Map<String, dynamic>) onSuccess,
    required Function(String) onError,
    required Function() onExternalWallet,
  }) async {
    if (kIsWeb) {
      await web.RazorpayWebService.instance.initiatePayment(
        amount: amount,             // ← RUPEES (web service × 100)
        orderId: orderId,
        keyId: keyId,
        userEmail: userEmail,
        userName: userName,
        userMobile: userMobile,
        onSuccess: onSuccess,
        onError: onError,
        onExternalWallet: onExternalWallet,
      );
      return;
    }

    await mobile.RazorpayMobileService.instance.initiatePayment(
      amount: amount,               // ← RUPEES (mobile service × 100)
      orderId: orderId,
      keyId: keyId,
      userEmail: userEmail,
      userName: userName,
      userMobile: userMobile,
      onSuccess: onSuccess,
      onError: onError,
      onExternalWallet: onExternalWallet,
    );
  }

  void dispose() {
    if (kIsWeb) {
      web.RazorpayWebService.instance.dispose();
    } else {
      mobile.RazorpayMobileService.instance.dispose();
    }
  }
}