import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

/// A temple to open, from a link: a shared `darshansaathi.com/temples/<slug>`
/// page opened on the phone, the website's "Open in the app" / "Book a
/// seva" / "Donate" (`/?temple=<slug>&action=book|donate`), or the temple's
/// QR code scanned with the phone camera (`/temples/<slug>/checkin?s=…`).
class DeepLink {
  const DeepLink(this.slug,
      {this.book = false, this.donate = false, this.checkinCode});

  final String slug;

  /// Straight to the temple's sevas.
  final bool book;

  /// Straight to its hundi.
  final bool donate;

  /// The scanned check-in code, whole: the visit is checked in with it.
  final String? checkinCode;

  @override
  bool operator ==(Object other) =>
      other is DeepLink &&
      other.slug == slug &&
      other.book == book &&
      other.donate == donate &&
      other.checkinCode == checkinCode;

  @override
  int get hashCode => Object.hash(slug, book, donate, checkinCode);

  /// The temple a URL is about, or null when it is not one.
  static DeepLink? parse(Uri uri) {
    final query = uri.queryParameters['temple']?.trim();
    final action = uri.queryParameters['action'];
    final book = action == 'book';
    final donate = action == 'donate';
    if (query != null && _slug.hasMatch(query)) {
      return DeepLink(query, book: book, donate: donate);
    }

    final parts = uri.pathSegments.where((p) => p.isNotEmpty).toList();
    final i = parts.indexOf('temples');
    if (i >= 0 && i + 1 < parts.length && _slug.hasMatch(parts[i + 1])) {
      final checkin = i + 2 < parts.length &&
          parts[i + 2] == 'checkin' &&
          (uri.queryParameters['s'] ?? '').isNotEmpty;
      return DeepLink(parts[i + 1],
          book: book,
          donate: donate,
          checkinCode: checkin ? uri.toString() : null);
    }
    return null;
  }

  static final _slug = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');
}

/// Links waiting to be opened. The shell opens the temple once the app is
/// on screen; a link arriving while the app runs opens at once.
class DeepLinks {
  DeepLinks._();

  static final pending = ValueNotifier<DeepLink?>(null);

  /// A payment made on the website, whose page sent the devotee back here
  /// (`/?payment=<id>`): its result is shown.
  static final pendingPayment = ValueNotifier<String?>(null);

  static final _paymentId = RegExp(r'^[0-9a-fA-F-]{36}$');

  static StreamSubscription<Uri>? _sub;

  /// Reads the link the app was opened with, and listens for later ones.
  static Future<void> start() async {
    if (kIsWeb) {
      // The web app: the address it was opened at.
      pending.value = DeepLink.parse(Uri.base);
      final payment = Uri.base.queryParameters['payment'];
      if (payment != null && _paymentId.hasMatch(payment)) {
        pendingPayment.value = payment;
      }
      return;
    }
    try {
      final links = AppLinks();
      final first = await links.getInitialLink();
      if (first != null) pending.value = DeepLink.parse(first);
      _sub ??= links.uriLinkStream.listen((uri) {
        final link = DeepLink.parse(uri);
        if (link != null) pending.value = link;
      });
    } catch (_) {
      // No link support on this platform: the app opens as usual.
    }
  }

  /// Takes the waiting link, so it opens once.
  static DeepLink? take() {
    final link = pending.value;
    pending.value = null;
    return link;
  }
}
