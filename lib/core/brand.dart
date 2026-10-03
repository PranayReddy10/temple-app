/// The product name is not finalised. It is never hard-coded anywhere else.
///
/// Mirrors `config/brand.php` in the backend. Override at build time with
/// `--dart-define=BRAND_NAME=...` so a rename is a build flag, not a refactor.
class Brand {
  Brand._();

  static const String name =
      String.fromEnvironment('BRAND_NAME', defaultValue: 'Darshan Saathi');

  static const String tagline = String.fromEnvironment(
    'BRAND_TAGLINE',
    defaultValue: 'Your digital pilgrimage companion',
  );

  /// Where community submissions go until the submissions API exists.
  static const String supportEmail = String.fromEnvironment('BRAND_SUPPORT_EMAIL', defaultValue: 'support@darshansaathi.com');

  /// The devotees' website, where the privacy policy, terms and the other
  /// policy pages live (edited in the admin panel: Website → Pages).
  static const String website = String.fromEnvironment('BRAND_WEBSITE', defaultValue: 'https://darshansaathi.com');

  /// Base URL of the Laravel API, without the `/api/v1` suffix. The API and
  /// the admin panel live on temple.darshansaathi.com; darshansaathi.com
  /// itself is the devotees' website.
  /// The Darshan Saathi Trust app, for temple teams: where a devotee who
  /// runs a temple, or cannot find one, is sent to register and manage it.
  static const String trustAppUrl = String.fromEnvironment(
    'TRUST_APP_URL',
    defaultValue: 'https://play.google.com/store/apps/details?id=com.darshansaathi.temple_trust',
  );

  static const String trustAppName = 'Darshan Saathi Trust';

  static const String defaultApiBase =

      String.fromEnvironment('API_BASE_URL', defaultValue: 'https://temple.darshansaathi.com');

}
