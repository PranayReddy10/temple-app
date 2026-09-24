import 'package:applovin_max/applovin_max.dart' as max;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../platform.dart';
import '../state/app_config_controller.dart';
import '../state/auth_controller.dart';
import '../../features/premium/premium_screen.dart';

/// Whether ads show, and starting the ad network when they do.
///
/// Everything is decided in the admin panel (network, units, placements) and
/// by the devotee's plan: a no-ads plan means none, anywhere. The SDK is not
/// even started until an ad is actually wanted.
class AdsController extends ChangeNotifier {
  AdsController(this._config, this._auth) {
    _config.addListener(notifyListeners);
    _auth.addListener(notifyListeners);
  }

  final AppConfigController _config;
  final AuthController _auth;
  Future<void>? _starting;

  /// Tests and screenshots turn ads off whatever the server says.
  static bool disabled = false;

  bool get noAdsPlan => _auth.devotee?.entitlements.noAds ?? false;

  bool shows(String placement) => !disabled && AppPlatform.isMobile && !noAdsPlan && _config.config.ads.allows(placement);

  String get network => _config.config.ads.network;
  String? get nativeUnit => _config.config.ads.nativeUnit;
  int get listInterval => _config.config.ads.listInterval;

  Future<void> ensureStarted() => _starting ??= _start();

  Future<void> _start() async {
    final ads = _config.config.ads;
    try {
      if (ads.network == 'applovin_max') {
        final key = ads.applovinSdkKey;
        if (key != null && key.isNotEmpty) {
          if (ads.testMode) max.AppLovinMAX.setVerboseLogging(true);
          await max.AppLovinMAX.initialize(key);
        }
      } else {
        await MobileAds.instance.initialize();
      }
    } catch (e) {
      debugPrint('Ads unavailable: $e');
    }
  }

  @override
  void dispose() {
    _config.removeListener(notifyListeners);
    _auth.removeListener(notifyListeners);
    super.dispose();
  }
}

/// A native ad, styled like the cards around it and labelled "Ad", with a
/// "Remove ads" link to the plans. Takes no space until an ad has loaded,
/// and none at all where ads are off.
class NativeAdSlot extends StatelessWidget {
  const NativeAdSlot({super.key, required this.placement, this.compact = false, this.padding = const EdgeInsets.symmetric(vertical: 8)});

  /// temple_detail, explore, home or day_page, as in the admin panel.
  final String placement;

  /// Small (for lists) rather than medium with media (between sections).
  final bool compact;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final ads = context.watch<AdsController>();
    if (!ads.shows(placement)) return const SizedBox.shrink();
    return Padding(padding: padding, child: _LoadedAd(key: ValueKey('${ads.network}:${ads.nativeUnit}:$compact'), ads: ads, compact: compact, placement: placement));
  }
}

class _LoadedAd extends StatefulWidget {
  const _LoadedAd({super.key, required this.ads, required this.compact, required this.placement});

  final AdsController ads;
  final bool compact;
  final String placement;

  @override
  State<_LoadedAd> createState() => _LoadedAdState();
}

class _LoadedAdState extends State<_LoadedAd> {
  NativeAd? _admob;
  bool _loaded = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await widget.ads.ensureStarted();
    if (!mounted || widget.ads.network != 'admob') return;
    final theme = Theme.of(context);
    _admob = NativeAd(
      adUnitId: widget.ads.nativeUnit!,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) => mounted ? setState(() => _loaded = true) : null,
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) setState(() => _failed = true);
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: widget.compact ? TemplateType.small : TemplateType.medium,
        mainBackgroundColor: theme.colorScheme.surfaceContainerHighest,
        cornerRadius: 16,
        callToActionTextStyle: NativeTemplateTextStyle(textColor: theme.colorScheme.onPrimary, backgroundColor: theme.colorScheme.primary, style: NativeTemplateFontStyle.bold, size: 14),
        primaryTextStyle: NativeTemplateTextStyle(textColor: theme.colorScheme.onSurface, style: NativeTemplateFontStyle.bold, size: 15),
        secondaryTextStyle: NativeTemplateTextStyle(textColor: theme.colorScheme.onSurfaceVariant, size: 13),
      ),
    )..load();
  }

  @override
  void dispose() {
    _admob?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();
    final Widget ad;
    if (widget.ads.network == 'applovin_max') {
      ad = _MaxNative(unit: widget.ads.nativeUnit!, compact: widget.compact, placement: widget.placement, onLoaded: () => mounted ? setState(() => _loaded = true) : null, onFailed: () => mounted ? setState(() => _failed = true) : null);
    } else {
      if (_admob == null) return const SizedBox.shrink();
      ad = ConstrainedBox(
        constraints: BoxConstraints(minHeight: widget.compact ? 90 : 320, maxHeight: widget.compact ? 120 : 400),
        child: AdWidget(ad: _admob!),
      );
    }
    // Laid out but invisible until it has loaded, so the page does not jump
    // around an empty box.
    return Offstage(
      offstage: !_loaded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AdLabel(),
          const SizedBox(height: 4),
          ClipRRect(borderRadius: BorderRadius.circular(16), child: ad),
        ],
      ),
    );
  }
}

class _AdLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(border: Border.all(color: theme.colorScheme.outline), borderRadius: BorderRadius.circular(4)),
          child: Text(s('ad'), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
        ),
        const Spacer(),
        InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PremiumScreen())),
          child: Padding(padding: const EdgeInsets.all(4), child: Text(s('remove_ads'), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary))),
        ),
      ],
    );
  }
}

/// AppLovin MAX's native ad, laid out in Flutter.
class _MaxNative extends StatelessWidget {
  const _MaxNative({required this.unit, required this.compact, required this.placement, required this.onLoaded, required this.onFailed});

  final String unit;
  final bool compact;
  final String placement;
  final VoidCallback onLoaded;
  final VoidCallback onFailed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: compact ? 110 : 330,
      color: theme.colorScheme.surfaceContainerHighest,
      child: max.MaxNativeAdView(
        adUnitId: unit,
        placement: placement,
        listener: max.NativeAdListener(
          onAdLoadedCallback: (_) => onLoaded(),
          onAdLoadFailedCallback: (_, __) => onFailed(),
          onAdClickedCallback: (_) {},
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const SizedBox(width: 44, height: 44, child: max.MaxNativeAdIconView()),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        max.MaxNativeAdTitleView(style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        max.MaxNativeAdAdvertiserView(style: theme.textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24, height: 24, child: max.MaxNativeAdOptionsView()),
                ],
              ),
              if (!compact) ...[
                const SizedBox(height: 8),
                max.MaxNativeAdBodyView(style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                const Expanded(child: max.MaxNativeAdMediaView()),
              ],
              const SizedBox(height: 8),
              max.MaxNativeAdCallToActionView(style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: theme.colorScheme.onPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}
