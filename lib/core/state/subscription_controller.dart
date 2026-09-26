import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../platform.dart';
import 'auth_controller.dart';

/// Plans, buying one, and the result.
///
/// Checkout happens in the gateway's native SDK where it has one (Razorpay,
/// Cashfree), otherwise on the server's payment page in the system browser
/// tab; afterwards the app asks the server how the payment ended. The
/// plan is switched on by the server once the gateway confirms, never by
/// the app.
class SubscriptionController extends ChangeNotifier {
  SubscriptionController(this._api, this._auth);

  final ApiClient _api;
  final AuthController _auth;

  List<SubscriptionPlan> plans = const [];
  bool loading = false;
  String? error;

  Future<void> loadPlans() async {
    loading = true;
    notifyListeners();
    try {
      final json = await _api.get('plans', {'platform': AppPlatform.name});
      plans = (json['data'] as List).map((e) => SubscriptionPlan.fromJson(e as Map<String, dynamic>)).toList();
      error = null;
    } catch (e) {
      error = '$e';
    }
    loading = false;
    notifyListeners();
  }

  /// Starts a purchase. [sdk] is what the gateway's native SDK needs, when
  /// the gateway has one; otherwise the web checkout at [checkoutUrl].
  Future<({String checkoutUrl, String doneUrl, String paymentId, Map<String, dynamic>? sdk, String? sdkError, String? gateway})> begin(SubscriptionPlan plan, {String? gateway}) async {
    final json = await _api.post('me/checkout', {'plan': plan.code, 'platform': AppPlatform.name, 'mode': 'sdk', if (gateway != null) 'gateway': gateway});
    final d = json['data'] as Map<String, dynamic>;
    return (
      checkoutUrl: '${d['checkout_url']}',
      doneUrl: '${d['done_url']}',
      paymentId: '${(d['payment'] as Map)['id']}',
      sdk: d['sdk'] is Map ? Map<String, dynamic>.from(d['sdk'] as Map) : null,
      // Why the server could not start the SDK (wrong keys, no merchant
      // id). Absent from a server older than native checkout.
      sdkError: d.containsKey('sdk') ? d['sdk_error']?.toString() : 'The server has not been updated for in-app payments yet.',
      // The gateway the server actually used (its default when none chosen).
      gateway: (d['payment'] as Map)['gateway']?.toString(),
    );
  }

  /// Hands the SDK's result to the server, which checks it with the gateway
  /// (Razorpay's signature, or Cashfree's own record) and answers the status.
  Future<String> confirm(String paymentId, Map<String, String> fields) async {
    try {
      final json = await _api.post('me/payments/$paymentId/confirm', fields);
      final status = '${(json['data'] as Map)['status']}';
      if (status == 'paid') await _auth.reload();
      return status;
    } catch (_) {
      return 'pending';
    }
  }

  /// How a payment ended, asking a few times while the bank confirms.
  Future<String> settle(String paymentId, {int attempts = 6, Duration gap = const Duration(seconds: 2)}) async {
    var status = 'pending';
    for (var i = 0; i < attempts; i++) {
      try {
        final json = await _api.get('me/payments/$paymentId');
        status = '${(json['data'] as Map)['status']}';
      } catch (_) {}
      if (status == 'paid' || status == 'failed' || status == 'refunded') break;
      await Future<void>.delayed(gap);
    }
    if (status == 'paid') await _auth.reload();
    return status;
  }
}
