import 'package:flutter_test/flutter_test.dart';
import 'package:temple_app/core/models/models.dart';
import 'package:temple_app/core/services/analytics.dart';

void main() {
  test('analytics is on only when the server says so and sends the ids', () {
    expect(AppConfig.fromJson({}).analyticsEnabled, isFalse);
    expect(AppConfig.fromJson({'analytics': {'enabled': true, 'firebase': null}}).analyticsEnabled, isFalse);

    final c = AppConfig.fromJson({
      'analytics': {
        'enabled': true,
        'firebase': {'project_id': 'darshan-saathi', 'api_key': 'AIza', 'app_id': '1:1:web:1', 'measurement_id': 'G-ABC123', 'messaging_sender_id': null},
      },
    });
    expect(c.analyticsEnabled, isTrue);
    expect(c.analyticsFirebase, {'project_id': 'darshan-saathi', 'api_key': 'AIza', 'app_id': '1:1:web:1', 'measurement_id': 'G-ABC123'});
  });

  test('with analytics off, logging is a harmless no-op', () async {
    await Analytics.instance.start(AppConfig.fallback);
    Analytics.instance
      ..screen('temple', item: 'somnath')
      ..search('shiva')
      ..beginCheckout('seva', value: 101)
      ..purchase('plan', item: 'yearly');
    expect(Analytics.instance.isOn, isFalse);
  });
}
