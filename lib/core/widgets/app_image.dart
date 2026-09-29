import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../brand.dart';

/// Every network image in the app goes through here.
///
/// Wikimedia and a number of CDNs refuse Dart's default user agent, which
/// is why a gallery could look right in the code and never open on a phone.
/// The request names the app, and a decode width keeps a 4000-pixel
/// original from being decoded at full size for a 120-pixel tile.
class AppImage extends StatelessWidget {
  const AppImage(this.url, {super.key, this.fit = BoxFit.cover, this.placeholder, this.decodeWidth, this.alignment = Alignment.center, this.fallbacks = const []});

  final String url;
  final BoxFit fit;
  final Widget? placeholder;
  final int? decodeWidth;
  final Alignment alignment;

  /// Tried in turn when [url] fails, e.g. the original when a resized copy
  /// is missing on the server.
  final List<String> fallbacks;

  static const headers = {'User-Agent': '${Brand.name}/0.5 (Flutter; +https://github.com/PranayReddy10/temple-app)', 'Accept': 'image/*,*/*;q=0.8'};

  /// A server whose APP_URL is wrong hands out `/storage/...` paths, or
  /// `http://localhost/...`; both are resolved against the API the app is
  /// actually talking to rather than left to fail.
  static String resolve(String url, String apiBase) {
    if (url.startsWith('/')) return '$apiBase$url';
    final u = Uri.tryParse(url);
    if (u != null && (u.host == 'localhost' || u.host == '127.0.0.1')) {
      final base = Uri.parse(apiBase);
      return u.replace(scheme: base.scheme, host: base.host, port: base.hasPort ? base.port : null).toString();
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final api = context.read<ApiClient?>();
    final resolved = api == null ? url : resolve(url, api.baseUrl);
    return Image.network(
      resolved,
      fit: fit,
      alignment: alignment,
      // Browsers ignore a custom User-Agent, and any header at all stops the
      // web engine from falling back to an <img> element (below).
      headers: kIsWeb ? null : headers,
      // On the web the image is fetched by script, which the browser only
      // allows from another domain if that domain sends CORS headers; photos
      // on DigitalOcean Spaces do not unless the Space is configured to. When
      // that fetch is refused, draw it as a plain <img> element instead, which
      // needs no CORS. No effect on Android and iOS.
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      cacheWidth: decodeWidth == null ? null : (decodeWidth! * dpr).round(),
      errorBuilder: (_, __, ___) => fallbacks.isEmpty
          ? (placeholder ?? const SizedBox.shrink())
          : AppImage(fallbacks.first, fit: fit, placeholder: placeholder, decodeWidth: decodeWidth, alignment: alignment, fallbacks: fallbacks.sublist(1)),
      loadingBuilder: (context, child, progress) => progress == null ? child : (placeholder ?? const SizedBox.shrink()),
    );
  }
}
