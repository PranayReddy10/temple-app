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

  /// Base URL of the Laravel API, without the `/api/v1` suffix. The API and
  /// the admin panel live on temple.darshansaathi.com; darshansaathi.com
  /// itself is the devotees' website.
  static const String defaultApiBase =

      String.fromEnvironment('API_BASE_URL', defaultValue: 'https://temple.darshansaathi.com');

}
