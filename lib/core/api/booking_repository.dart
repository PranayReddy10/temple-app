import '../models/models.dart';
import 'api_client.dart';

/// The `checkout` block the server sends with anything to be paid for (a
/// seva booking, an event ticket, a hundi gift): the payment, and how to
/// open the gateway for it.
class Checkout {
  const Checkout({required this.paymentId, this.checkoutUrl, this.sdk, this.sdkError, this.gateway});

  final String paymentId;
  final String? checkoutUrl;

  /// What the gateway's native SDK needs, when it has one.
  final Map<String, dynamic>? sdk;
  final String? sdkError;
  final String? gateway;

  /// Null when there is nothing to pay.
  static Checkout? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final checkout = Map<String, dynamic>.from(raw);
    final payment = Map<String, dynamic>.from((checkout['payment'] as Map?) ?? const {});
    final id = payment['id']?.toString();
    if (id == null) return null;
    return Checkout(
      paymentId: id,
      checkoutUrl: checkout['checkout_url']?.toString(),
      sdk: checkout['sdk'] is Map ? Map<String, dynamic>.from(checkout['sdk'] as Map) : null,
      sdkError: checkout['sdk_error']?.toString(),
      gateway: payment['gateway']?.toString(),
    );
  }
}

/// What `POST /temples/{slug}/pujas/{id}/bookings` answers: the booking,
/// and for a priced seva the same checkout the plans use. Joining an event
/// answers the same, with the ticket as the booking.
class BookingStart {
  const BookingStart({required this.booking, this.paymentId, this.checkoutUrl, this.sdk, this.sdkError, this.gateway});

  final PujaBooking booking;

  Checkout? get checkout => paymentId == null ? null : Checkout(paymentId: paymentId!, checkoutUrl: checkoutUrl, sdk: sdk, sdkError: sdkError, gateway: gateway);

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

  /// Seva bookings live under me/bookings, event tickets under
  /// me/event-tickets; both answer in the same shape.
  static String _base(bool event) => event ? 'me/event-tickets' : 'me/bookings';

  Future<PujaBooking> show(String reference, {bool event = false}) async => PujaBooking.fromJson(Map<String, dynamic>.from((await _api.get('${_base(event)}/$reference'))['data'] as Map));

  Future<PujaBooking> cancel(String reference, {String? reason, bool event = false}) async => PujaBooking.fromJson(Map<String, dynamic>.from((await _api.post('${_base(event)}/$reference/cancel', {if (reason != null && reason.isNotEmpty) 'reason': reason}))['data'] as Map));

  /// The devotee's event tickets ("I'll join" and paid).
  Future<List<PujaBooking>> eventTickets() async {
    final body = await _api.get('me/event-tickets');
    return (body['data'] as List? ?? const []).map((e) => PujaBooking.fromJson({...Map<String, dynamic>.from(e as Map), 'kind': 'event'})).toList();
  }

  /// "I'll join" a gathering, or buy tickets for a paid one. A free one is
  /// confirmed at once; a paid one comes back with the same checkout a seva
  /// booking does.
  Future<BookingStart> joinEvent({
    required int eventId,
    DateTime? occursOn,
    required int people,
    String? name,
    String? phone,
    String? gateway,
    required String platform,
  }) async {
    final body = await _api.post('events/$eventId/join', {
      if (occursOn != null) 'occurs_on': _date(occursOn),
      'people': people,
      if (name != null && name.isNotEmpty) 'devotee_name': name,
      if (phone != null && phone.isNotEmpty) 'devotee_phone': phone,
      if (gateway != null) 'gateway': gateway,
      'platform': platform,
      'mode': 'sdk',
    });
    return _start(body, event: true);
  }

  /// A seva's time slots on one day, with the places left in each.
  Future<List<PujaSlot>> slots({required String templeSlug, required int pujaId, required DateTime day}) async {
    final body = await _api.get('temples/$templeSlug/pujas/$pujaId/slots', {'date': _date(day)});
    return (body['data'] as List? ?? const []).map((e) => PujaSlot.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  static String _date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<BookingStart> book({
    required String templeSlug,
    required int pujaId,
    required DateTime day,
    int? slotId,
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
      if (slotId != null) 'slot_id': slotId,
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
    return _start(body);
  }

  /// "Pay now" for a booking (or event ticket) still awaiting payment: a
  /// fresh checkout.
  Future<BookingStart> pay(String reference, {String? gateway, required String platform, bool event = false}) async {
    final body = await _api.post('${_base(event)}/$reference/pay', {
      if (gateway != null) 'gateway': gateway,
      'platform': platform,
      'mode': 'sdk',
    });
    return _start(body, event: event);
  }

  BookingStart _start(Map<String, dynamic> body, {bool event = false}) {
    final booking = PujaBooking.fromJson({...Map<String, dynamic>.from(body['data'] as Map), if (event) 'kind': 'event'});
    final checkout = Checkout.fromJson(body['checkout']);
    if (checkout == null) return BookingStart(booking: booking);
    return BookingStart(
      booking: booking,
      paymentId: checkout.paymentId,
      checkoutUrl: checkout.checkoutUrl,
      sdk: checkout.sdk,
      sdkError: checkout.sdkError,
      gateway: checkout.gateway,
    );
  }
}
