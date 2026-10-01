import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temple_app/core/api/api_client.dart';
import 'package:temple_app/core/state/auth_controller.dart';

void main() {
  test('deleting the account asks the server, then clears this device', () async {
    SharedPreferences.setMockInitialValues({
      'devotee_token': 'tok',
      'devotee': jsonEncode({'id': 7, 'name': 'Ravi', 'email': 'ravi@example.com'}),
    });
    final prefs = await SharedPreferences.getInstance();
    http.Request? deleted;
    final api = ApiClient(
      baseUrl: 'https://api.test',
      client: MockClient((req) async {
        if (req.method == 'DELETE') deleted = req;
        return http.Response(jsonEncode({'data': {'deleted': true}}), 200, headers: {'content-type': 'application/json'});
      }),
    );
    final auth = AuthController(prefs, api);
    var cleared = false;
    auth.onSignOut(() async => cleared = true);
    expect(auth.isSignedIn, isTrue);

    await auth.deleteAccount();

    expect(deleted!.url.path, '/api/v1/me');
    expect(jsonDecode(deleted!.body), {'confirm': 'DELETE'});
    expect(auth.isSignedIn, isFalse);
    expect(prefs.getString('devotee_token'), isNull);
    expect(cleared, isTrue);
  });
}
