import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Image.network(
      url,
      fit: fit,
      alignment: alignment,
      headers: headers,
      cacheWidth: decodeWidth == null ? null : (decodeWidth! * dpr).round(),
      errorBuilder: (_, __, ___) => placeholder ?? const SizedBox.shrink(),
      loadingBuilder: (context, child, progress) => progress == null ? child : (placeholder ?? const SizedBox.shrink()),
    );
  }
}
