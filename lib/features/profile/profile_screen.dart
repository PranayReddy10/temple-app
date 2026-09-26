import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/notifications_controller.dart';
import '../notifications/notifications_screen.dart';
import '../premium/premium_screen.dart';

import '../../core/brand.dart';
import '../../core/l10n/strings.dart';
import '../../core/models/models.dart';
import '../../core/motifs/architecture.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/app_settings.dart';
import '../../core/state/auth_controller.dart';
import '../../core/state/bookings_controller.dart';
import '../../core/state/favourites_controller.dart';
import '../../core/state/offline_pack_controller.dart';
import '../../core/state/submissions_controller.dart';
import '../../core/state/sync_service.dart';
import '../../core/state/passport_controller.dart';
import '../../core/state/yatra_controller.dart';
import '../../core/theme/day_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/temple_door.dart';
import '../../core/widgets/app_image.dart';
import '../../core/widgets/temple_widgets.dart';
import '../auth/auth_screen.dart';
import '../bookings/bookings_screen.dart';
import '../certificates/certificates_screen.dart';
import '../diagnostics/diagnostics_screen.dart';
import '../family/family_screen.dart';
import '../qr/qr_screens.dart';
import '../add_temple/add_temple_screen.dart';
import '../seva/seva_screen.dart';
import '../submissions/submissions_screen.dart';
import '../temple/temple_screen.dart';
import 'edit_profile_screen.dart';
import 'memories_screen.dart';

/// Profile: the devotee's identity card, their pilgrimage in numbers, memories,
/// saved temples, language, appearance and the server the app talks to.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final auth = context.watch<AuthController>();
    final settings = context.watch<AppSettings>();
    final passport = context.watch<PassportController>();
    final favs = context.watch<FavouritesController>();
    final yatras = context.watch<YatraController>();
    final top = MediaQuery.paddingOf(context).top;
    final d = auth.devotee;
    final memories = passport.visits.where((v) => v.photoPath != null).toList();
    final day = DayTheme.today();

    return ListView(
      padding: EdgeInsets.fromLTRB(0, top, 0, 40),
      children: [
        // Identity card.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Palette.deep, Color.lerp(Palette.deep, day.accent, 0.45)!]),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: day.accent.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 8))],
            ),
            child: Stack(
              children: [
                const Positioned.fill(child: Opacity(opacity: 0.08, child: CustomPaint(painter: LatticePainter(color: Palette.gold, cell: 26)))),
                Positioned(right: -14, bottom: -24, child: Opacity(opacity: 0.16, child: MotifIcon(day.motif, size: 120, color: Palette.gold))),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Avatar(path: auth.localAvatarPath, url: d?.avatarUrl, size: 72),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(Brand.name.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(color: Palette.gold, letterSpacing: 3)),
                              Text(d?.name ?? s('guest'), style: theme.textTheme.headlineSmall?.copyWith(color: Palette.sandal)),
                              Text(d?.email ?? d?.phone ?? 'Sign in to keep your passport across devices', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: Palette.sandal.withValues(alpha: 0.8))),
                              if (d != null && d.isVerified) Row(children: [const Icon(Icons.verified_rounded, size: 14, color: Palette.gold), const SizedBox(width: 4), Text('Verified devotee', style: theme.textTheme.labelSmall?.copyWith(color: Palette.gold))]),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (d != null) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          if (d.phone != null) _Fact(icon: Icons.call_rounded, text: d.phone!),
                          if (d.homeState != null) _Fact(icon: Icons.map_rounded, text: d.homeState!),
                          if (d.dateOfBirth != null) _Fact(icon: Icons.cake_rounded, text: d.dateOfBirth!),
                          if (d.joinedAt != null) _Fact(icon: Icons.event_rounded, text: '${s('joined')} ${d.joinedAt!.substring(0, 4)}'),
                          _Fact(icon: Icons.translate_rounded, text: _localeName(d.locale ?? settings.locale.languageCode)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    d == null
                        ? Row(
                            children: [
                              Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: Palette.gold, foregroundColor: Palette.deep), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen())), child: Text(s('sign_in')))),
                              const SizedBox(width: 10),
                              Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Palette.sandal, side: const BorderSide(color: Palette.gold)), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen(register: true))), child: Text(s('create_account')))),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(backgroundColor: Palette.gold, foregroundColor: Palette.deep),
                                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                                  icon: const Icon(Icons.edit_rounded, size: 18),
                                  label: Text(_isComplete(d) ? s('edit_profile') : s('complete_profile')),
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton(tooltip: s('sign_out'), style: IconButton.styleFrom(foregroundColor: Palette.sandal, side: const BorderSide(color: Palette.gold)), onPressed: () => confirmSignOut(context), icon: const Icon(Icons.logout_rounded)),
                            ],
                          ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Pilgrimage in numbers.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(
            children: [
              _Stat(value: passport.stampCount, label: s('stamps'), icon: Icons.approval_rounded),
              const SizedBox(width: 8),
              _Stat(value: passport.visits.length, label: s('visits'), icon: Icons.temple_hindu_rounded),
              const SizedBox(width: 8),
              _Stat(value: yatras.yatras.length, label: s('yatras'), icon: Icons.route_rounded),
              const SizedBox(width: 8),
              _Stat(value: favs.items.length, label: s('saved'), icon: Icons.bookmark_rounded),
            ],
          ),
        ),
        // Pilgrimage tools.
        const SectionHeader(title: 'Pilgrimage tools', motif: Motif.kalasha),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              _ToolTile(
                icon: Icons.workspace_premium_outlined,
                title: s('premium'),
                subtitle: context.watch<AuthController>().devotee?.subscriptionPlan ?? s('premium_pitch'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PremiumScreen())),
              ),
              _ToolTile(
                icon: Icons.notifications_outlined,
                title: s('notifications'),
                subtitle: '${context.watch<NotificationsController>().unreadCount} unread',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
              ),
              _ToolTile(icon: Icons.add_location_alt_rounded, title: 'Temples I added', subtitle: 'Add a temple that is not listed, and follow the ones you sent', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyAddedTemplesScreen()))),
              _ToolTile(icon: Icons.volunteer_activism_rounded, title: 'Seva drives', subtitle: 'Clean-ups of old temples and heritage places you raised or joined', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SevaScreen()))),
              _ToolTile(icon: Icons.group_rounded, title: s('family_passport'), subtitle: 'Stamps for everyone who travels with you', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FamilyScreen()))),
              _ToolTile(icon: Icons.workspace_premium_rounded, title: s('certificates'), subtitle: 'Completed circuits and yatras', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CertificatesScreen()))),
              _ToolTile(icon: Icons.local_fire_department_rounded, title: s('bookings'), subtitle: '${context.watch<BookingsController>().upcomingCount} upcoming · codes for the counter', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BookingsScreen()))),
              _ToolTile(icon: Icons.qr_code_2_rounded, title: s('my_qr'), subtitle: 'For temple counters on the QR network', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyQrScreen()))),
              _ToolTile(icon: Icons.offline_pin_rounded, title: s('offline_pack'), subtitle: '${context.watch<OfflinePackController>().totalPacked} temples saved for offline, from your yatras', onTap: null),
              _ToolTile(icon: Icons.support_agent_rounded, title: s('submissions'), subtitle: '${context.watch<SubmissionsController>().all.length} requests and reports', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SubmissionsScreen()))),
            ],
          ),
        ),
        // Memories.
        SectionHeader(
          title: s('memories'),
          motif: Motif.lotus,
          subtitle: memories.isEmpty ? 'Photos you attach to visits appear here' : '${memories.length} photo${memories.length == 1 ? '' : 's'}',
          actionLabel: memories.isEmpty ? null : s('see_all'),
          onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MemoriesScreen())),
        ),
        if (memories.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _Placeholder(icon: Icons.photo_library_outlined, text: s('no_memories')))
        else
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: memories.length.clamp(0, 12),
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final v = memories[i];
                return GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MemoriesScreen())),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 130,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (kIsWeb) TempleImage(deitySlug: v.deitySlug) else Image.file(File(v.photoPath!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => TempleImage(deitySlug: v.deitySlug)),
                          Positioned(left: 0, right: 0, bottom: 0, child: Container(padding: const EdgeInsets.all(8), color: Colors.black45, child: Text(v.templeName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'NotoSerif')))),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        // Saved temples.
        SectionHeader(title: s('saved'), motif: Motif.kalasha, subtitle: '${favs.items.length} temples'),
        if (favs.items.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: _Placeholder(icon: Icons.bookmark_border_rounded, text: 'Tap the bookmark on any temple to keep it here.'))
        else
          SizedBox(
            height: scaledHeight(context, 262),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: favs.items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final t = favs.items[i].toSummary();
                return TempleCard(temple: t, width: 220, onTap: () => enterTemple(context, TempleScreen(slug: t.slug, preview: t), accent: DayTheme.forDeity(t.deity?.slug).accent));
              },
            ),
          ),
        // Account sync.
        if (d != null) ...[
          const SectionHeader(title: 'Account sync', motif: Motif.shankhaChakra),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Builder(builder: (context) {
              final sync = context.watch<SyncService>();
              return Card(
                child: ListTile(
                  leading: Icon(sync.pendingCount > 0 ? Icons.cloud_upload_outlined : Icons.cloud_done_rounded, color: sync.pendingCount > 0 ? theme.colorScheme.primary : Palette.tulsi),
                  title: Text(sync.pendingCount > 0 ? '${sync.pendingCount} change${sync.pendingCount == 1 ? '' : 's'} waiting' : 'Everything is on your account'),
                  subtitle: Text(sync.lastError != null
                      ? 'Last attempt: ${sync.lastError}'
                      : sync.lastPulledAt != null
                          ? 'Last synced ${sync.lastPulledAt!.hour.toString().padLeft(2, '0')}:${sync.lastPulledAt!.minute.toString().padLeft(2, '0')}'
                          : 'Visits, trips, memories and reports sync when online'),
                  trailing: sync.isFlushing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : IconButton(icon: const Icon(Icons.sync_rounded), onPressed: () => sync.sync()),
                ),
              );
            }),
          ),
        ],
        // Language.
        SectionHeader(title: s('language'), motif: Motif.om, subtitle: LanguageInfo.bundled.where((l) => !settings.contentAvailable(l.code)).isEmpty ? null : 'Temple content is served in ${LanguageInfo.bundled.where((l) => settings.contentAvailable(l.code)).map((l) => l.nativeName).join(', ')}; others cover the app itself'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final l in LanguageInfo.bundled.map((x) => (x.code, x.nativeName)))
                ChoiceChip(
                  label: Text(l.$2),
                  selected: settings.locale.languageCode == l.$1,
                  onSelected: (_) {
                    settings.setLocale(Locale(l.$1));
                    if (auth.isSignedIn) auth.updateProfile(locale: l.$1).catchError((_) {});
                  },
                ),
            ],
          ),
        ),
        // Appearance.
        SectionHeader(title: s('appearance'), motif: Motif.sun),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded), label: Text('System')),
                  ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.wb_sunny_rounded), label: Text('Day')),
                  ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.nightlight_round), label: Text('Night')),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (v) => settings.setThemeMode(v.first),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Temple door animations'),
                subtitle: const Text('Doors open when you enter a temple or a day'),
                value: settings.doorAnimations,
                onChanged: settings.setDoorAnimations,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Temple sounds'),
                subtitle: const Text('The bell as the app opens, and page turns in the passport. Silent when the app is muted.'),
                value: settings.templeSounds,
                onChanged: settings.setTempleSounds,
              ),
            ],
          ),
        ),
        const SectionHeader(title: 'Week of deities', motif: Motif.bell, subtitle: 'The colour the app wears each day'),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: 7,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final dt = DayTheme.all[i];
              return Container(
                width: 56,
                decoration: BoxDecoration(color: dt.accent, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [MotifIcon(dt.motif, size: 22, color: dt.onAccent()), Text(dt.dayName.substring(0, 3), style: TextStyle(color: dt.onAccent(), fontSize: 10, fontWeight: FontWeight.w700))],
                ),
              );
            },
          ),
        ),
        SectionHeader(title: 'Server', motif: Motif.shankhaChakra, subtitle: settings.apiBase),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => _editServer(context, settings), icon: const Icon(Icons.dns_rounded), label: const Text('Change API server'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DiagnosticsScreen())), icon: const Icon(Icons.troubleshoot_rounded), label: const Text('Check a temple'))),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
          child: Column(
            children: [
              SizedBox(height: 60, width: double.infinity, child: CustomPaint(painter: GopuramPainter(color: theme.colorScheme.primary, opacity: 0.25, tiers: 5))),
              const SizedBox(height: 8),
              Text('${Brand.name} · v0.4 · Phases 1–4', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.55))),
              Text(s('trust_note'), textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.55))),
            ],
          ),
        ),
      ],
    );
  }

  static bool _isComplete(dynamic d) => d.email != null && d.phone != null && d.homeState != null && d.dateOfBirth != null;

  static String _localeName(String code) => switch (code) {
        'te' => 'తెలుగు',
        'hi' => 'हिन्दी',
        'ta' => 'தமிழ்',
        'kn' => 'ಕನ್ನಡ',
        _ => 'English',
      };

  static Future<void> _editServer(BuildContext context, AppSettings settings) async {
    final c = TextEditingController(text: settings.apiBase);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API server'),
        content: TextField(controller: c, autofocus: true, keyboardType: TextInputType.url, decoration: const InputDecoration(hintText: 'https://example.com')),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save'))],
      ),
    );
    if (ok == true && c.text.trim().isNotEmpty) await settings.setApiBase(c.text.trim());
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.path, required this.url, required this.size});

  final String? path;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget fallback = Icon(Icons.person_rounded, color: Palette.deep, size: size * 0.55);
    Widget img = fallback;
    if (url != null) {
      img = AppImage(url!, placeholder: path != null && !kIsWeb ? Image.file(File(path!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback) : fallback, decodeWidth: 200);
    } else if (path != null && !kIsWeb) {
      img = Image.file(File(path!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback);
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: Palette.brass, border: Border.all(color: Palette.gold, width: 2)),
      child: ClipOval(child: img),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 13, color: Palette.gold), const SizedBox(width: 5), Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Palette.sandal))],
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.icon});

  final int value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.colorScheme.outlineVariant)),
        child: Column(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            Text('$value', style: theme.textTheme.titleLarge),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.8)),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4))),
      child: Row(children: [Icon(icon, color: theme.colorScheme.primary), const SizedBox(width: 10), Expanded(child: Text(text, style: theme.textTheme.bodySmall))]),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title, style: const TextStyle(fontFamily: 'NotoSerif')),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

/// Signing out clears this device of the account, so say so first — and
/// say plainly if anything recorded here has not reached the account yet.
Future<void> confirmSignOut(BuildContext context) async {
  final sync = context.read<SyncService>();
  final pending = sync.pendingCount;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.logout_rounded),
      title: const Text('Sign out?'),
      content: Text(
        pending == 0
            ? 'Your visits, photos, memories and trips are saved to your account and are removed from this phone. Sign in again to see them.'
            : '$pending change${pending == 1 ? ' has' : 's have'} not reached your account yet and will be lost. Connect to the internet and wait a moment to keep ${pending == 1 ? 'it' : 'them'}.\n\nEverything else is saved to your account and removed from this phone.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  await context.read<AuthController>().logout();
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed out. Nothing of your account is left on this phone.')));
}
