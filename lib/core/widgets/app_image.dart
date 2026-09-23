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
  const AppImage(this.url, {super.key, this.fit = BoxFit.cover, this.placeholder, this.decodeWidth, this.alignment = Alignment.center});

  final String url;
  final BoxFit fit;
  final Widget? placeholder;
  final int? decodeWidth;
  final Alignment alignment;

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
      headers: headers,
      cacheWidth: decodeWidth == null ? null : (decodeWidth! * dpr).round(),
      errorBuilder: (_, __, ___) => placeholder ?? const SizedBox.shrink(),
      loadingBuilder: (context, child, progress) => progress == null ? child : (placeholder ?? const SizedBox.shrink()),
    );
  }
}
