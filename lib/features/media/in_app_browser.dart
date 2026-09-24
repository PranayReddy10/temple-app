import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// A web page shown inside the app: a YouTube search, a temple's website, a
/// booking page. Links that try to hand off to another app (intent://,
/// vnd.youtube://, market://) are refused, so a devotee is never dropped
/// out of the app by a page they opened from it.
class InAppBrowserScreen extends StatefulWidget {
  const InAppBrowserScreen({super.key, required this.url, this.title});

  final String url;
  final String? title;

  /// Opens [url] in the app. On the web build, where there is no web view,
  /// it opens in a new tab instead.
  /// For pages that take payment or sign-in: a temple's booking site, a
  /// payment gateway. The system's own in-app browser tab (Chrome Custom
  /// Tabs, Safari View) stays inside the app but is the real browser, so
  /// bank pages, captchas and UPI apps work. A plain web view is refused by
  /// many gateways and cannot hand a payment to a UPI app, which is how a
  /// booking ended at "too many attempts".
  static Future<void> openSecure(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.inAppBrowserView);
    if (!ok) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<void> open(BuildContext context, String url, {String? title}) async {
    if (kIsWeb) {
      await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => InAppBrowserScreen(url: url, title: title)));
  }

  @override
  State<InAppBrowserScreen> createState() => InAppBrowserScreenState();
}

class InAppBrowserScreenState extends State<InAppBrowserScreen> {
  late final WebViewController _web;
  int _progress = 0;
  String? _pageTitle;

  /// UPI and the payment apps a checkout page may open.
  static bool isPayment(Uri u) => const {'upi', 'tez', 'gpay', 'phonepe', 'paytmmp', 'bhim', 'credpay'}.contains(u.scheme);

  /// Schemes a page may load. Everything else is another app.
  static bool isWebUri(Uri? u) => u != null && (u.scheme == 'https' || u.scheme == 'http' || u.scheme == 'about' || u.scheme == 'data' || u.scheme == 'blob');

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (r) {
          final u = Uri.tryParse(r.url);
          if (isWebUri(u)) return NavigationDecision.navigate;
          // A payment hands off to a UPI app; that one hand-off is allowed.
          if (u != null && isPayment(u)) launchUrl(u, mode: LaunchMode.externalApplication);
          return NavigationDecision.prevent;
        },
        onProgress: (p) => mounted ? setState(() => _progress = p) : null,
        onPageFinished: (_) async {
          final t = await _web.getTitle();
          if (mounted) setState(() => _pageTitle = t);
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _web.canGoBack()) {
          await _web.goBack();
        } else if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.close_rounded), tooltip: 'Close', onPressed: () => Navigator.of(context).pop()),
          title: Text(widget.title ?? _pageTitle ?? Uri.parse(widget.url).host, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [IconButton(tooltip: 'Reload', onPressed: () => _web.reload(), icon: const Icon(Icons.refresh_rounded))],
          bottom: _progress < 100 ? PreferredSize(preferredSize: const Size.fromHeight(2), child: LinearProgressIndicator(value: _progress / 100, minHeight: 2)) : null,
        ),
        body: WebViewWidget(controller: _web),
      ),
    );
  }
}
