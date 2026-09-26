import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/data/sample_data.dart';
import '../../core/l10n/strings.dart';
import '../../core/state/app_config_controller.dart';
import '../../core/state/auth_controller.dart';
import '../../core/state/passport_controller.dart';
import '../../core/state/photo_store.dart';
import '../../core/state/sync_service.dart';
import '../../core/theme/day_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/app_image.dart';
import '../../core/widgets/temple_door.dart';
import '../photo_stamp/photo_stamp_screen.dart';
import '../premium/premium_screen.dart';
import '../temple/temple_screen.dart';
import 'stamp_widget.dart';

/// One visit, opened from the passport: its stamp, the photo in the
/// passport, and up to three memory photos that stay here — never in the
/// passport book and never shown to anyone else.
class VisitDetailScreen extends StatelessWidget {
  const VisitDetailScreen({super.key, required this.visitKey});

  /// Looked up live, so a photo added here shows at once.
  final String visitKey;

  Future<void> _pick(BuildContext context, {required bool passportPhoto}) async {
    final source = kIsWeb
        ? ImageSource.gallery
        : await showModalBottomSheet<ImageSource>(
            context: context,
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(leading: const Icon(Icons.photo_library_rounded), title: Text(S.of(context)('gallery')), onTap: () => Navigator.of(context).pop(ImageSource.gallery)),
                  ListTile(leading: const Icon(Icons.photo_camera_rounded), title: Text(S.of(context)('camera')), onTap: () => Navigator.of(context).pop(ImageSource.camera)),
                ],
              ),
            ),
          );
    if (source == null || !context.mounted) return;
    final x = await ImagePicker().pickImage(source: source, maxWidth: 2400, imageQuality: 88);
    if (x == null || !context.mounted) return;
    final passport = context.read<PassportController>();
    final signedIn = context.read<AuthController>().isSignedIn;
    final sync = context.read<SyncService>();
    final visit = passport.byKey(visitKey);
    if (visit == null) return;
    final path = await PhotoStore.keep(x, folder: passportPhoto ? 'passport' : 'memories');
    if (passportPhoto) {
      await passport.attachPhoto(visit, path);
      final updated = passport.byKey(visitKey);
      if (signedIn && updated != null && updated.remotePhoto == null) {
        // Their choice, asked once, before anything leaves the phone.
        final offer = context.mounted ? await _askToOffer(context) : false;
        await sync.queuePhoto(updated, photoPath: path, offerToGallery: offer);
      }
      return;
    }
    final limit = context.mounted ? context.read<AuthController>().devotee?.entitlements.memoryPhotosPerVisit ?? Visit.maxMemoryPhotos : Visit.maxMemoryPhotos;
    final updated = await passport.addMemoryPhoto(visit, path, limit: limit);
    if (updated != null && signedIn) await sync.queueMemoryPhoto(updated, path);
  }

  /// Whether the passport photo may be offered to the temple's gallery.
  static Future<bool> _askToOffer(BuildContext context) async {
    final s = S.of(context);
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.photo_library_rounded, color: Palette.tulsi),
        title: Text(s('offer_to_gallery')),
        content: Text(s('offer_to_gallery_note')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(s('keep_private'))),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(s('offer_to_gallery'))),
        ],
      ),
    );
    return answer ?? false;
  }

  Future<void> _remove(BuildContext context, Visit visit, int index) async {
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s('memory_remove_title')),
        content: Text(s('memory_remove_body')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(s('keep'))),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(s('remove'))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final sync = context.read<SyncService>();
    final removed = await context.read<PassportController>().removeMemoryPhoto(visit, index);
    if (removed == null) return;
    await sync.removeMemoryPhoto(removed);
    await PhotoStore.discard(removed.path);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final passport = context.watch<PassportController>();
    final visit = passport.byKey(visitKey);
    if (visit == null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(s('visit_gone'))));
    }
    final day = DayTheme.forDeity(visit.deitySlug);
    final memories = visit.memoryPhotos;
    // Three on the free app; a plan raises it. Never fewer than already kept.
    final limit = [context.watch<AuthController>().devotee?.entitlements.memoryPhotosPerVisit ?? Visit.maxMemoryPhotos, memories.length].reduce((a, b) => a > b ? a : b);
    final passportImage = _image(visit.photoPath, visit.remotePhoto?.originalUrl);

    return Scaffold(
      appBar: AppBar(title: Text(visit.templeName, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Row(
            children: [
              StampWidget(visit: visit, size: 112, inked: visit.isVerified),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(visit.templeName, style: theme.textTheme.titleLarge?.copyWith(fontFamily: 'NotoSerif')),
                    if (visit.city != null) Text(visit.city!, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Text(_date(visit.visitedAt), style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    VerificationBadge(verification: visit.verification),
                  ],
                ),
              ),
            ],
          ),
          if (visit.note != null) ...[
            const SizedBox(height: 16),
            Text(visit.note!, style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 24),
          _Heading(icon: Icons.menu_book_rounded, title: s('in_passport'), subtitle: s('in_passport_note')),
          const SizedBox(height: 10),
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: passportImage == null
                  ? _AddTile(label: s('add_photo'), onTap: () => _pick(context, passportPhoto: true))
                  : GestureDetector(
                      onTap: () => _openViewer(context, [(visit.photoPath, visit.remotePhoto?.originalUrl)], 0),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          passportImage,
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: FilledButton.tonalIcon(
                              onPressed: () => _pick(context, passportPhoto: true),
                              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                              label: Text(s('change')),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 28),
          _Heading(icon: Icons.photo_library_rounded, title: '${s('memory_photos')} · ${memories.length}/$limit', subtitle: s('memory_photos_note')),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              // The free three are laid out in full; a larger plan shows the
              // photos kept plus one more slot, not a wall of empty boxes.
              for (var k = 0; k < (limit <= Visit.maxMemoryPhotos ? limit : (memories.length + 1).clamp(0, limit)); k++)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: k < memories.length
                      ? GestureDetector(
                          onTap: () => _openViewer(context, [for (final m in memories) (m.path, m.url)], k),
                          onLongPress: () => _remove(context, visit, k),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _image(memories[k].path, memories[k].url) ?? Container(color: theme.colorScheme.surfaceContainerHighest),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Material(
                                  color: Colors.black54,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () => _remove(context, visit, k),
                                    child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close_rounded, size: 16, color: Colors.white)),
                                  ),
                                ),
                              ),
                              if (memories[k].remoteId == null && context.watch<AuthController>().isSignedIn)
                                const Positioned(left: 6, bottom: 6, child: Icon(Icons.cloud_upload_outlined, size: 16, color: Colors.white)),
                            ],
                          ),
                        )
                      : k == memories.length
                          ? _AddTile(label: s('add_memory'), onTap: () => _pick(context, passportPhoto: false))
                          : Container(color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
                ),
            ],
          ),
          if (memories.length >= limit && limit <= Visit.maxMemoryPhotos && context.watch<AppConfigController>().config.paymentsEnabled)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PremiumScreen())),
                child: Row(children: [const Icon(Icons.workspace_premium_rounded, size: 18, color: Palette.gold), const SizedBox(width: 6), Expanded(child: Text(s('memory_limit_reached'), style: theme.textTheme.bodySmall))]),
              ),
            ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PhotoStampScreen(visit: visit))),
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: Text(s('photo_stamp')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => enterTemple(context, TempleScreen(slug: visit.templeSlug, preview: SampleData.bySlug(visit.templeSlug)), accent: day.accent),
                  icon: const Icon(Icons.temple_hindu_rounded),
                  label: Text(s('open_temple')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget? _image(String? path, String? url, {BoxFit fit = BoxFit.cover, int decodeWidth = 600}) {
    if (path != null) {
      if (kIsWeb) return Image.network(path, fit: fit, errorBuilder: (_, __, ___) => url != null ? AppImage(url, fit: fit, decodeWidth: decodeWidth) : const SizedBox.shrink());
      return Image.file(File(path), fit: fit, errorBuilder: (_, __, ___) => url != null ? AppImage(url, fit: fit, decodeWidth: decodeWidth) : const _Missing());
    }
    if (url != null) return AppImage(url, fit: fit, decodeWidth: decodeWidth);
    return null;
  }

  static void _openViewer(BuildContext context, List<(String?, String?)> images, int initial) => Navigator.of(context).push(
        PageRouteBuilder(
          opaque: false,
          barrierColor: Colors.black,
          pageBuilder: (_, __, ___) => _PhotoViewer(images: images, initial: initial),
          transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
        ),
      );

  static String _date(DateTime d) => '${d.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]} ${d.year}';
}

class _Heading extends StatelessWidget {
  const _Heading({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'NotoSerif')),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: onTap,
        // Scaled down rather than clipped in a small grid cell at a large
        // system text size.
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_a_photo_rounded, color: theme.colorScheme.primary),
                  const SizedBox(height: 6),
                  Text(label, textAlign: TextAlign.center, style: theme.textTheme.labelMedium),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing();

  @override
  Widget build(BuildContext context) => Container(color: Palette.stone.withValues(alpha: 0.2), child: const Icon(Icons.broken_image_outlined));
}

/// Full-screen photos, swiped between and pinched to zoom.
class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.images, required this.initial});

  final List<(String?, String?)> images;
  final int initial;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width.round();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white, elevation: 0),
      extendBodyBehindAppBar: true,
      body: PageView(
        controller: PageController(initialPage: initial),
        children: [
          for (final (path, url) in images)
            InteractiveViewer(
              maxScale: 5,
              child: SizedBox.expand(child: VisitDetailScreen._image(path, url, fit: BoxFit.contain, decodeWidth: width) ?? const SizedBox.shrink()),
            ),
        ],
      ),
    );
  }
}
