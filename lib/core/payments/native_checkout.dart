import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:phonepe_payment_sdk/phonepe_payment_sdk.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// How a checkout ended on the device. Only a hint: the server decides
/// whether it was paid, from the gateway's own records or signature.
class CheckoutResult {
  const CheckoutResult({required this.completed, this.fields = const {}, this.message});

  /// The devotee finished the gateway's flow (it may still have failed).
  final bool completed;

  /// What to send to /me/payments/{id}/confirm (Razorpay's signed result).
  final Map<String, String> fields;

  /// The gateway's reason, when it said why it stopped.
  final String? message;
}

/// Pays through the gateway's own native SDK (Razorpay, Cashfree, PhonePe):
/// its payment sheet, its UPI app picker, its card and bank pages, all
/// inside the app. A web page in a browser tab is used only for gateways
/// with no SDK here (PayU) and on the web build.
class NativeCheckout {
  NativeCheckout._();

  /// Gateways paid through their own SDK in the app. For these the app
  /// never falls back to a web page: if the SDK cannot start, it says why.
  static const nativeGateways = {'razorpay', 'cashfree', 'phonepe'};

  /// Whether this gateway is paid natively on this platform.
  static bool isNative(String? gateway) => !kIsWeb && nativeGateways.contains(gateway);

  static bool supports(Map<String, dynamic>? sdk) => !kIsWeb && sdk != null && nativeGateways.contains(sdk['gateway']);

  static Future<CheckoutResult> pay(Map<String, dynamic> sdk) => switch (sdk['gateway']) {
        'razorpay' => _razorpay(sdk),
        'cashfree' => _cashfree(sdk),
        'phonepe' => _phonepe(sdk),
        _ => Future.value(const CheckoutResult(completed: false)),
      };

  /// PhonePe's app SDK (Standard Checkout v2): initialise with the merchant,
  /// then open the order the server created with its token. PhonePe hands
  /// UPI to its own app or any other installed UPI app.
  /// The app's URL scheme, registered in ios/Runner/Info.plist.
  static const appSchema = 'templepassport';

  static Future<CheckoutResult> _phonepe(Map<String, dynamic> sdk) async {
    try {
      final sandbox = sdk['environment'] != 'PRODUCTION';
      // Logs only while testing in sandbox: they help when a payment will
      // not open, and have no place in a released app.
      final ready = await PhonePePaymentSdk.init(sandbox ? 'SANDBOX' : 'PRODUCTION', '${sdk['merchant_id']}', '${sdk['flow_id'] ?? 'templepassport'}', sandbox);
      if (!ready) return const CheckoutResult(completed: false, message: 'PhonePe could not start on this phone.');
      final request = jsonEncode({
        'orderId': sdk['order_id'],
        'merchantId': sdk['merchant_id'],
        'token': sdk['token'],
        'paymentMode': {'type': 'PAY_PAGE'},
      });
      // appSchema: the URL scheme PhonePe returns to after payment on iOS
      // (registered in Info.plist); ignored on Android.
      final result = await PhonePePaymentSdk.startTransaction(request, appSchema);
      final status = '${result?['status'] ?? ''}'.toUpperCase();
      // INTERRUPTED: the devotee backed out. SUCCESS or FAILURE: the server
      // asks PhonePe how the order ended; the app's word is not enough.
      if (status == 'INTERRUPTED' || status.isEmpty) return CheckoutResult(completed: false, message: result?['error']?.toString());
      return CheckoutResult(completed: true, message: result?['error']?.toString());
    } catch (e) {
      return CheckoutResult(completed: false, message: '$e');
    }
  }

  static Future<CheckoutResult> _razorpay(Map<String, dynamic> sdk) {
    final done = Completer<CheckoutResult>();
    final rzp = Razorpay();
    rzp.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
      if (!done.isCompleted) {
        done.complete(CheckoutResult(completed: true, fields: {
          if (r.paymentId != null) 'razorpay_payment_id': r.paymentId!,
          if (r.orderId != null) 'razorpay_order_id': r.orderId!,
          if (r.signature != null) 'razorpay_signature': r.signature!,
        }));
      }
    });
    rzp.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      if (!done.isCompleted) done.complete(CheckoutResult(completed: r.code != Razorpay.PAYMENT_CANCELLED, message: r.message));
    });
    rzp.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {
      // Paid in another wallet app: the server asks Razorpay how it ended.
      if (!done.isCompleted) done.complete(const CheckoutResult(completed: true));
    });
    final prefill = Map<String, dynamic>.from((sdk['prefill'] as Map?) ?? const {});
    rzp.open({
      'key': sdk['key'],
      'order_id': sdk['order_id'],
      'amount': sdk['amount_paise'],
      'currency': sdk['currency'] ?? 'INR',
      'name': sdk['name'],
      if (sdk['description'] != null) 'description': sdk['description'],
      if (prefill.isNotEmpty) 'prefill': prefill,
      'theme': {'color': sdk['theme_color'] ?? '#E07A1F'},
      // Show the installed UPI apps (GPay, PhonePe, Paytm…) first.
      'config': {
        'display': {
          'preferences': {'show_default_blocks': true},
        },
      },
    });
    return done.future.whenComplete(rzp.clear);
  }

  static Future<CheckoutResult> _cashfree(Map<String, dynamic> sdk) {
    final done = Completer<CheckoutResult>();
    final service = CFPaymentGatewayService();
    service.setCallback(
      (String orderId) {
        // Cashfree says "verify this order": the server asks Cashfree.
        if (!done.isCompleted) done.complete(const CheckoutResult(completed: true));
      },
      (CFErrorResponse error, String orderId) {
        if (!done.isCompleted) done.complete(CheckoutResult(completed: true, message: error.getMessage()));
      },
    );
    try {
      final session = CFSessionBuilder()
          .setEnvironment(sdk['environment'] == 'production' ? CFEnvironment.PRODUCTION : CFEnvironment.SANDBOX)
          .setOrderId('${sdk['order_id']}')
          .setPaymentSessionId('${sdk['session_id']}')
          .build();
      service.doPayment(CFWebCheckoutPaymentBuilder().setSession(session).build());
    } catch (e) {
      if (!done.isCompleted) done.complete(CheckoutResult(completed: false, message: '$e'));
    }
    return done.future;
  }

  /// The fallback: the gateway's web page in the system's browser tab
  /// (Custom Tabs / Safari View), where UPI apps and bank pages work. Waits
  /// until the devotee comes back to the app.
  static Future<void> payInBrowserTab(String url) async {
    final back = Completer<void>();
    late final AppLifecycleListener listener;
    var left = false;
    listener = AppLifecycleListener(
      onHide: () => left = true,
      onResume: () {
        if (left && !back.isCompleted) back.complete();
      },
    );
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.inAppBrowserView) || await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      listener.dispose();
      return;
    }
    // The web build stays in its own tab; nothing to wait for there.
    if (kIsWeb) {
      listener.dispose();
      return;
    }
    await back.future.timeout(const Duration(minutes: 20), onTimeout: () {});
    listener.dispose();
  }
}
