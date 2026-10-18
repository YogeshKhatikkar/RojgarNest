// lib/features/payment/razorpay_web_service.dart
// ✅ WEB ONLY — Uses checkout.js
// ✅ Razorpay expects amount in PAISE (int)
// ✅ Input `amount` is in RUPEES → multiply by 100 exactly once

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'dart:js' as js;

class RazorpayWebService {
  static RazorpayWebService? _instance;
  bool _isSDKLoaded = false;
  bool _isPaymentOpen = false;
  Completer<bool>? _sdkLoadCompleter;

  RazorpayWebService._internal();

  static RazorpayWebService get instance {
    _instance ??= RazorpayWebService._internal();
    return _instance!;
  }

  Future<bool> _loadRazorpaySDK() async {
    if (!kIsWeb) return false;
    if (_isSDKLoaded) return true;
    if (_sdkLoadCompleter != null) return _sdkLoadCompleter!.future;

    _sdkLoadCompleter = Completer<bool>();

    try {
      try {
        final existing =
            js.context.callMethod('eval', ['typeof Razorpay']);
        if (existing != 'undefined') {
          _isSDKLoaded = true;
          _sdkLoadCompleter!.complete(true);
          return true;
        }
      } catch (_) {}

      final script =
          js.context.callMethod('document.createElement', ['script']);
      script['src'] = 'https://checkout.razorpay.com/v1/checkout.js';
      script['async'] = true;
      script['defer'] = true;

      script['onload'] = js.allowInterop(() {
        _isSDKLoaded = true;
        if (!_sdkLoadCompleter!.isCompleted) {
          _sdkLoadCompleter!.complete(true);
        }
      });

      script['onerror'] = js.allowInterop((error) {
        if (!_sdkLoadCompleter!.isCompleted) {
          _sdkLoadCompleter!.complete(false);
        }
      });

      final head =
          js.context.callMethod('document.getElementsByTagName', ['head']);
      if (head != null && head.length > 0) {
        head[0].callMethod('appendChild', [script]);
      } else {
        final body =
            js.context.callMethod('document.getElementsByTagName', ['body']);
        if (body != null && body.length > 0) {
          body[0].callMethod('appendChild', [script]);
        } else {
          _sdkLoadCompleter!.complete(false);
          return false;
        }
      }

      await Future.any([
        _sdkLoadCompleter!.future,
        Future.delayed(const Duration(seconds: 10), () => false),
      ]);

      try {
        final check = js.context.callMethod('eval', ['typeof Razorpay']);
        if (check != 'undefined') {
          _isSDKLoaded = true;
          if (!_sdkLoadCompleter!.isCompleted) {
            _sdkLoadCompleter!.complete(true);
          }
          return true;
        }
      } catch (_) {}

      return false;
    } catch (e) {
      debugPrint("❌ SDK load error: $e");
      if (!_sdkLoadCompleter!.isCompleted) {
        _sdkLoadCompleter!.complete(false);
      }
      return false;
    } finally {
      _sdkLoadCompleter = null;
    }
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
    if (!kIsWeb) {
      onError("Payment service not available on this platform.");
      return;
    }

    final bool sdkLoaded = await _loadRazorpaySDK();
    if (!sdkLoaded) {
      onError("Payment service not available. Please refresh and try again.");
      return;
    }

    if (_isPaymentOpen) {
      onError("Payment window is already open");
      return;
    }

    // ✅ Convert rupees → paise (EXACTLY ONCE)
    final int amountInPaise = (amount * 100).round();

    debugPrint("=" * 60);
    debugPrint("💰 WEB RAZORPAY");
    debugPrint("   Amount (rupees): ₹$amount");
    debugPrint("   Amount (paise):  $amountInPaise");
    debugPrint("   Order ID:        $orderId");
    debugPrint("   Key ID:          $keyId");
    debugPrint("=" * 60);

    try {
      final options = {
        'key': keyId,
        // ✅ Razorpay checkout.js requires PAISE
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
        'modal': {
          'ondismiss': js.allowInterop(() {
            _isPaymentOpen = false;
            onError('Payment cancelled by user');
          }),
        },
        'handler': js.allowInterop((response) {
          _isPaymentOpen = false;
          final paymentId = response['razorpay_payment_id']?.toString();
          final orderIdResp = response['razorpay_order_id']?.toString();
          final signature = response['razorpay_signature']?.toString();

          if (paymentId == null || paymentId.isEmpty) {
            onError("Payment verification failed.");
            return;
          }

          onSuccess({
            'razorpay_payment_id': paymentId,
            'razorpay_order_id': orderIdResp ?? orderId,
            'razorpay_signature': signature,
          });
        }),
      };

      debugPrint("📤 Razorpay options sent: amount=${options['amount']} paise");

      final razorpayConstructor = js.context['Razorpay'];
      if (razorpayConstructor == null) {
        onError('Payment service not available.');
        return;
      }

      final jsOptions = js.JsObject.jsify(options);
      final razorpay = js.JsObject(razorpayConstructor, [jsOptions]);

      _isPaymentOpen = true;
      razorpay.callMethod('open');
    } catch (e) {
      _isPaymentOpen = false;
      onError("Failed to open payment: ${e.toString()}");
    }
  }

  void dispose() {
    _isSDKLoaded = false;
    _isPaymentOpen = false;
    _sdkLoadCompleter = null;
  }
}