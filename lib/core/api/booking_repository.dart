import '../models/models.dart';
import 'api_client.dart';

/// What `POST /temples/{slug}/pujas/{id}/bookings` answers: the booking,
/// and for a priced seva the same checkout the plans use.
class BookingStart {
  const BookingStart({required this.booking, this.paymentId, this.checkoutUrl, this.sdk, this.sdkError, this.gateway});

  final PujaBooking booking;

  /// Null for a free seva: nothing to pay, already confirmed.
  final String? paymentId;
  final String? checkoutUrl;

  /// What the gateway's native SDK needs, when it has one.
  final Map<String, dynamic>? sdk;
  final String? sdkError;
  final String? gateway;

  bool get needsPayment => paymentId != null;
}

/// Booking a puja, seva or prasadam through the temple's own listing.
class BookingRepository {
  BookingRepository(this._api);

  final ApiClient _api;

  Future<List<PujaBooking>> mine() async {
    final body = await _api.get('me/bookings');
    return (body['data'] as List? ?? const []).map((e) => PujaBooking.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<PujaBooking> show(String reference) async => PujaBooking.fromJson(Map<String, dynamic>.from((await _api.get('me/bookings/$reference'))['data'] as Map));

  Future<PujaBooking> cancel(String reference, {String? reason}) async => PujaBooking.fromJson(Map<String, dynamic>.from((await _api.post('me/bookings/$reference/cancel', {if (reason != null && reason.isNotEmpty) 'reason': reason}))['data'] as Map));

  Future<BookingStart> book({
    required String templeSlug,
    required int pujaId,
    required DateTime day,
    required int people,
    String? name,
    String? phone,
    String? gotram,
    String? nakshatram,
    String? note,
    String? gateway,
    required String platform,
  }) async {
    final body = await _api.post('temples/$templeSlug/pujas/$pujaId/bookings', {
      'booked_for': '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
      'people': people,
      if (name != null && name.isNotEmpty) 'devotee_name': name,
      if (phone != null && phone.isNotEmpty) 'devotee_phone': phone,
      if (gotram != null && gotram.isNotEmpty) 'gotram': gotram,
      if (nakshatram != null && nakshatram.isNotEmpty) 'nakshatram': nakshatram,
      if (note != null && note.isNotEmpty) 'note': note,
      if (gateway != null) 'gateway': gateway,
      'platform': platform,
      'mode': 'sdk',
    });
    final booking = PujaBooking.fromJson(Map<String, dynamic>.from(body['data'] as Map));
    final checkout = body['checkout'] is Map ? Map<String, dynamic>.from(body['checkout'] as Map) : null;
    if (checkout == null) return BookingStart(booking: booking);
    final payment = Map<String, dynamic>.from((checkout['payment'] as Map?) ?? const {});
    return BookingStart(
      booking: booking,
      paymentId: payment['id']?.toString(),
      checkoutUrl: checkout['checkout_url']?.toString(),
      sdk: checkout['sdk'] is Map ? Map<String, dynamic>.from(checkout['sdk'] as Map) : null,
      sdkError: checkout['sdk_error']?.toString(),
      gateway: payment['gateway']?.toString(),
    );
  }
}
