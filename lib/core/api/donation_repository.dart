import '../models/models.dart';
import 'api_client.dart';
import 'booking_repository.dart';

/// What `POST /temples/{slug}/donations` answers: the gift, awaiting
/// payment, and the same checkout a seva booking is paid through.
class DonationStart {
  const DonationStart({required this.donation, this.checkout});

  final Donation donation;
  final Checkout? checkout;
}

/// The temple's online hundi.
class DonationRepository {
  DonationRepository(this._api);

  final ApiClient _api;

  Future<DonationStart> give({
    required String templeSlug,
    required int amountRupees,
    String? purpose,
    String? donorName,
    bool anonymous = false,
    String? note,
    String? gateway,
    required String platform,
  }) async {
    final body = await _api.post('temples/$templeSlug/donations', {
      'amount': amountRupees,
      if (purpose != null) 'purpose': purpose,
      if (donorName != null && donorName.isNotEmpty) 'donor_name': donorName,
      'is_anonymous': anonymous,
      if (note != null && note.isNotEmpty) 'note': note,
      if (gateway != null) 'gateway': gateway,
      'platform': platform,
      'mode': 'sdk',
    });
    return DonationStart(donation: Donation.fromJson(Map<String, dynamic>.from(body['data'] as Map)), checkout: Checkout.fromJson(body['checkout']));
  }

  Future<List<Donation>> mine() async {
    final body = await _api.get('me/donations');
    return (body['data'] as List? ?? const []).map((e) => Donation.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// One gift; the server asks the gateway first if the payment is open, so
  /// this is what to call when the devotee comes back from paying.
  Future<Donation> show(String reference) async => Donation.fromJson(Map<String, dynamic>.from((await _api.get('me/donations/$reference'))['data'] as Map));
}
