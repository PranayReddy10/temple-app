import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temple_app/core/api/api_client.dart';
import 'package:temple_app/core/models/models.dart';
import 'package:temple_app/core/payments/native_checkout.dart';
import 'package:temple_app/core/state/auth_controller.dart';
import 'package:temple_app/core/state/subscription_controller.dart';

/// Buying a plan asks for the gateway's native SDK, and the SDK's result
/// goes back to the server to be checked, never trusted by the app.
void main() {
  test('checkout asks for the SDK, and the SDK result is confirmed by the server', () async {
    SharedPreferences.setMockInitialValues({'devotee_token': 't', 'devotee': jsonEncode({'id': 1, 'name': 'Anu'})});
    final prefs = await SharedPreferences.getInstance();
    final requests = <http.Request>[];
    final api = ApiClient(baseUrl: 'http://api.test', client: MockClient((r) async {
      requests.add(r);
      if (r.url.path.endsWith('/me/checkout')) {
        return http.Response(jsonEncode({'data': {
          'payment': {'id': 'uuid-1', 'status': 'pending'},
          'checkout_url': 'https://site/pay/uuid-1?signature=x',
          'done_url': 'https://site/pay/uuid-1/done',
          'sdk': {'gateway': 'razorpay', 'key': 'rzp_test', 'order_id': 'order_1', 'amount_paise': 4900},
        }}), 201);
      }
      if (r.url.path.endsWith('/me/payments/uuid-1/confirm')) {
        return http.Response(jsonEncode({'data': {'id': 'uuid-1', 'status': 'paid'}}), 200);
      }
      return http.Response(jsonEncode({'data': {}}), 200);
    }));
    final subs = SubscriptionController(api, AuthController(prefs, api));

    final start = await subs.begin(const SubscriptionPlan(code: 'yatri-plus', name: 'Yatri Plus', price: '₹49'), gateway: 'razorpay');
    final sent = jsonDecode(requests.first.body) as Map<String, dynamic>;
    expect(sent['mode'], 'sdk');
    expect(start.sdk!['order_id'], 'order_1');
    expect(start.paymentId, 'uuid-1');

    final status = await subs.confirm('uuid-1', {'razorpay_payment_id': 'pay_1', 'razorpay_order_id': 'order_1', 'razorpay_signature': 'sig'});
    expect(status, 'paid');
    final confirm = requests.firstWhere((r) => r.url.path.endsWith('/confirm'));
    expect(jsonDecode(confirm.body)['razorpay_signature'], 'sig');
  });

  test('Razorpay, Cashfree and PhonePe open natively; only PayU uses a browser tab', () {
    expect(NativeCheckout.supports({'gateway': 'razorpay'}), isTrue);
    expect(NativeCheckout.supports({'gateway': 'cashfree'}), isTrue);
    expect(NativeCheckout.supports({'gateway': 'phonepe'}), isTrue);
    expect(NativeCheckout.supports({'gateway': 'payu'}), isFalse);
    expect(NativeCheckout.supports(null), isFalse);
    expect(NativeCheckout.isNative('phonepe'), isTrue);
    expect(NativeCheckout.isNative('payu'), isFalse);
  });

  test('the reason is passed on when the SDK could not start, and an old server is named', () async {
    SharedPreferences.setMockInitialValues({'devotee_token': 't', 'devotee': jsonEncode({'id': 1, 'name': 'Anu'})});
    final prefs = await SharedPreferences.getInstance();
    var withSdkKey = true;
    final api = ApiClient(baseUrl: 'http://api.test', client: MockClient((r) async => http.Response.bytes(utf8.encode(jsonEncode({'data': {
          'payment': {'id': 'u', 'status': 'pending', 'gateway': 'phonepe'},
          'checkout_url': 'https://site/pay/u', 'done_url': 'https://site/pay/u/done',
          if (withSdkKey) 'sdk': null,
          if (withSdkKey) 'sdk_error': 'PhonePe merchant id is not set in the admin (Settings → Payments).',
        }})), 201, headers: {'content-type': 'application/json; charset=utf-8'})));
    final subs = SubscriptionController(api, AuthController(prefs, api));
    const plan = SubscriptionPlan(code: 'p', name: 'P', price: '₹49');

    var start = await subs.begin(plan);
    expect(start.sdk, isNull);
    expect(start.gateway, 'phonepe');
    expect(start.sdkError, contains('merchant id'));

    withSdkKey = false;
    start = await subs.begin(plan);
    expect(start.sdkError, contains('server has not been updated'));
  });
}
