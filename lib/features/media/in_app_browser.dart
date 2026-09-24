import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// A web page shown inside the app: a YouTube search, a temple's website, a
/// booking page. Links that try to hand off to another app (intent://,
/// vnd.youtube://, market://) are refused, so a devotee is never dropped
/// out of the app by a page they opened from it.
class InAppBrowserScreen extends StatefulWidget {
  const InAppBrowserScreen({super.key, required this.url, this.title, this.closeWhenUrlStarts, this.allowPaymentApps = false});

  final String url;
  final String? title;

  /// Closes the browser (returning true) on reaching a page under this URL:
  /// the checkout's "done" page.
  final String? closeWhenUrlStarts;

  /// A checkout page opens UPI apps (upi://, intent://…, phonepe://): those
  /// are handed to the phone rather than refused. Only ever set for our own
  /// payment pages.
  final bool allowPaymentApps;

  /// Opens [url] in the app. On the web build, where there is no web view,
  /// it opens in a new tab instead.
  static Future<void> open(BuildContext context, String url, {String? title}) async {
    if (kIsWeb) {
      await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => InAppBrowserScreen(url: url, title: title)));
  }

  /// A checkout: true if it reached its done page, false if closed first.
  static Future<bool> checkout(BuildContext context, String url, {required String doneUrl, String? title}) async {
    if (kIsWeb) {
      await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
      return false;
    }
    final done = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => InAppBrowserScreen(url: url, title: title, closeWhenUrlStarts: doneUrl, allowPaymentApps: true)));
    return done ?? false;
  }

  /// An Android intent:// link as the URL the target app understands:
  /// intent://pay?pa=x#Intent;scheme=upi;package=…;end → upi://pay?pa=x.
  static Uri? fromIntentUrl(String url) {
    final m = RegExp(r'^intent://([^#]*)#Intent;(.*)end;?$').firstMatch(url);
    if (m == null) return null;
    final scheme = RegExp(r'(?:^|;)scheme=([^;]+)').firstMatch(m.group(2)!)?.group(1);
    if (scheme == null) return null;
    return Uri.tryParse('$scheme://${m.group(1)}');
  }

  @override
  State<InAppBrowserScreen> createState() => InAppBrowserScreenState();
}

class InAppBrowserScreenState extends State<InAppBrowserScreen> {
  late final WebViewController _web;
  int _progress = 0;
  String? _pageTitle;

  /// Schemes a page may load. Everything else is another app.
  static bool isWebUri(Uri? u) => u != null && (u.scheme == 'https' || u.scheme == 'http' || u.scheme == 'about' || u.scheme == 'data' || u.scheme == 'blob');

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (r) {
          final done = widget.closeWhenUrlStarts;
          if (done != null && r.url.startsWith(done)) {
            // Let the done page load first so the payment is confirmed
            // server-side, then close.
            Future<void>.delayed(const Duration(milliseconds: 1200), () {
              if (mounted) Navigator.of(context).pop(true);
            });
            return NavigationDecision.navigate;
          }
          final uri = Uri.tryParse(r.url);
          if (isWebUri(uri)) return NavigationDecision.navigate;
          if (widget.allowPaymentApps && uri != null) {
            final target = uri.scheme == 'intent' ? InAppBrowserScreen.fromIntentUrl(r.url) : uri;
            if (target != null) launchUrl(target, mode: LaunchMode.externalApplication).catchError((_) => false);
          }
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
