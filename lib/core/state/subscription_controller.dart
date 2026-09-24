import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../platform.dart';
import 'auth_controller.dart';

/// Plans, buying one, and the result.
///
/// Checkout happens on the server's own payment page inside the app's
/// browser; afterwards the app asks the server how the payment ended. The
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

  /// Starts a purchase: ({checkoutUrl, doneUrl, paymentId}).
  Future<({String checkoutUrl, String doneUrl, String paymentId})> begin(SubscriptionPlan plan, {String? gateway}) async {
    final json = await _api.post('me/checkout', {'plan': plan.code, 'platform': AppPlatform.name, if (gateway != null) 'gateway': gateway});
    final d = json['data'] as Map<String, dynamic>;
    return (checkoutUrl: '${d['checkout_url']}', doneUrl: '${d['done_url']}', paymentId: '${(d['payment'] as Map)['id']}');
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
