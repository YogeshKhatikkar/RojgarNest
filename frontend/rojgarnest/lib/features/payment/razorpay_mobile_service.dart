// lib/features/payment/razorpay_mobile_service.dart
// ✅ ANDROID / iOS — Uses razorpay_flutter SDK
// ✅ Razorpay expects amount in PAISE (int)
// ✅ Input `amount` is in RUPEES → multiply by 100 exactly once

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayMobileService {
  static RazorpayMobileService? _instance;
  Razorpay? _razorpay;
  bool _isPaymentOpen = false;

  RazorpayMobileService._internal();

  static RazorpayMobileService get instance {
    _instance ??= RazorpayMobileService._internal();
    return _instance!;
  }

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
      onError("Mobile service called on web platform");
      return;
    }

    // ✅ Convert rupees → paise (EXACTLY ONCE)
    final int amountInPaise = (amount * 100).round();

    debugPrint("=" * 60);
    debugPrint("💰 MOBILE RAZORPAY");
    debugPrint("   Amount (rupees): ₹$amount");
    debugPrint("   Amount (paise):  $amountInPaise");
    debugPrint("   Order ID:        $orderId");
    debugPrint("=" * 60);

    try {
      if (_razorpay == null) {
        _razorpay = Razorpay();
      }

      _razorpay!.clear();

      // ✅ Success
      _razorpay!.on(
        Razorpay.EVENT_PAYMENT_SUCCESS,
        (PaymentSuccessResponse response) {
          _isPaymentOpen = false;
          if (response.paymentId == null || response.paymentId!.isEmpty) {
            onError("Payment verification failed.");
            return;
          }
          onSuccess({
            'razorpay_payment_id': response.paymentId,
            'razorpay_order_id': response.orderId ?? orderId,
            'razorpay_signature': response.signature,
          });
        },
      );

      // ✅ Error
      _razorpay!.on(
        Razorpay.EVENT_PAYMENT_ERROR,
        (PaymentFailureResponse response) {
          _isPaymentOpen = false;
          onError(response.message ?? 'Payment failed. Please try again.');
        },
      );

      // ✅ External Wallet
      _razorpay!.on(
        Razorpay.EVENT_EXTERNAL_WALLET,
        (ExternalWalletResponse response) {
          onExternalWallet();
        },
      );

      final options = {
        'key': keyId,
        // ✅ Razorpay SDK requires PAISE
        'amount': amountInPaise,
        'currency': 'INR',
        'name': 'RojgarNest',
        'description': 'Payment for service',
        'order_id': orderId,
        'prefill': {
          'contact': userMobile.isNotEmpty ? userMobile : '9999999999',
          'email': userEmail.isNotEmpty ? userEmail : 'user@example.com',
          'name': userName.isNotEmpty ? userName : 'User',
        },
        'theme': {'color': '#1E3A8A'},
      };

      debugPrint("📤 Razorpay options sent: amount=${options['amount']} paise");

      _isPaymentOpen = true;
      _razorpay!.open(options);
    } catch (e) {
      _isPaymentOpen = false;
      onError("Failed to open payment: ${e.toString()}");
    }
  }

  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
    _isPaymentOpen = false;
  }
}