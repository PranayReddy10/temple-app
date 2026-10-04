import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:temple_app/core/api/api_client.dart';
import 'package:temple_app/features/payments/payment_result_screen.dart';

Widget _screen(Map<String, dynamic> payment) {
  final api = ApiClient(
    baseUrl: 'http://api.test',
    client: MockClient((r) async => http.Response(jsonEncode({'data': payment}), 200, headers: {'content-type': 'application/json'})),
  );
  return Provider<ApiClient>.value(value: api, child: const MaterialApp(home: PaymentResultScreen(paymentId: '0b8a1c2d-3e4f-5a6b-7c8d-9e0f1a2b3c4d')));
}

void main() {
  testWidgets('back from the website: a hundi offering that went through', (tester) async {
    await tester.pumpWidget(_screen({'status': 'paid', 'purpose': 'donation', 'description': 'Hundi · Sri Rama Temple', 'amount': '₹501'}));
    await tester.pumpAndSettle();
    expect(find.text('Payment successful'), findsOneWidget);
    expect(find.text('Hundi · Sri Rama Temple · ₹501'), findsOneWidget);
    expect(find.text('My hundi offerings'), findsOneWidget);
  });

  testWidgets('back from the website: a seva payment that failed', (tester) async {
    await tester.pumpWidget(_screen({'status': 'failed', 'purpose': 'puja_booking', 'description': 'Abhishekam', 'amount': '₹172', 'failure_reason': 'Cancelled.'}));
    await tester.pumpAndSettle();
    expect(find.text('Payment not completed'), findsOneWidget);
    expect(find.textContaining('Cancelled.'), findsOneWidget);
    expect(find.text('My seva bookings'), findsNothing);
  });
}
