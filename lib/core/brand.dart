/// The product name is not finalised. It is never hard-coded anywhere else.
///
/// Mirrors `config/brand.php` in the backend. Override at build time with
/// `--dart-define=BRAND_NAME=...` so a rename is a build flag, not a refactor.
class Brand {
  Brand._();

  static const String name =
      String.fromEnvironment('BRAND_NAME', defaultValue: 'Temple Passport');

  static const String tagline = String.fromEnvironment(
    'BRAND_TAGLINE',
    defaultValue: 'Your digital pilgrimage companion',
  );

  /// Base URL of the Laravel API, without the `/api/v1` suffix.
  static const String defaultApiBase =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000');
}
