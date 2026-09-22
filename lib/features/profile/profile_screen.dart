import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand.dart';
import '../../core/data/sample_data.dart';
import '../../core/l10n/strings.dart';
import '../../core/motifs/architecture.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/app_settings.dart';
import '../../core/state/auth_controller.dart';
import '../../core/state/favourites_controller.dart';
import '../../core/state/passport_controller.dart';
import '../../core/theme/day_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/temple_door.dart';
import '../../core/widgets/temple_widgets.dart';
import '../auth/auth_screen.dart';
import '../photo_stamp/photo_stamp_screen.dart';
import '../temple/temple_screen.dart';

/// Profile: the devotee, their memories and saved temples, language and
/// appearance, and the server the app talks to.
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
    final top = MediaQuery.paddingOf(context).top;
    final d = auth.devotee;
    final memories = passport.visits.where((v) => v.photoPath != null).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(0, top, 0, 40),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: Palette.brass, border: Border.all(color: Palette.gold, width: 2)),
                child: ClipOval(
                  child: d?.avatarUrl != null
                      ? Image.network(d!.avatarUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, color: Palette.deep, size: 36))
                      : const Icon(Icons.person_rounded, color: Palette.deep, size: 36),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d?.name ?? s('guest'), style: theme.textTheme.headlineSmall),
                    Text(d?.email ?? d?.phone ?? 'Sign in to keep your passport across devices', style: theme.textTheme.bodySmall),
                    if (d != null && d.isVerified) Row(children: [const Icon(Icons.verified_rounded, size: 14, color: Palette.tulsi), const SizedBox(width: 4), Text('Verified devotee', style: theme.textTheme.labelSmall?.copyWith(color: Palette.tulsi))]),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: d == null
              ? Row(
                  children: [
                    Expanded(child: FilledButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen())), child: Text(s('sign_in')))),
                    const SizedBox(width: 10),
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen(register: true))), child: Text(s('create_account')))),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: OutlinedButton.icon(onPressed: () => _editName(context, auth), icon: const Icon(Icons.edit_rounded), label: const Text('Edit name'))),
                    const SizedBox(width: 10),
                    Expanded(child: OutlinedButton.icon(onPressed: auth.logout, icon: const Icon(Icons.logout_rounded), label: Text(s('sign_out')))),
                  ],
                ),
        ),
        SectionHeader(title: s('memories'), motif: Motif.lotus, subtitle: memories.isEmpty ? 'Photos you attach to visits appear here' : '${memories.length} photo${memories.length == 1 ? '' : 's'}'),
        if (memories.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _MemoryPlaceholder(color: theme.colorScheme.primary))
        else
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: memories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final v = memories[i];
                return GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PhotoStampScreen(visit: v))),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 130,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (kIsWeb) TempleImage(deitySlug: v.deitySlug) else Image.file(File(v.photoPath!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => TempleImage(deitySlug: v.deitySlug)),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              color: Colors.black45,
                              child: Text(v.templeName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'NotoSerif')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        SectionHeader(title: s('saved'), motif: Motif.kalasha, subtitle: '${favs.slugs.length} temples'),
        if (favs.slugs.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text('Tap the bookmark on any temple to keep it here.', style: theme.textTheme.bodySmall))
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final slug in favs.slugs)
                  ActionChip(
                    avatar: MotifIcon(DayTheme.forDeity(SampleData.bySlug(slug)?.deity?.slug).motif, size: 16, color: DayTheme.forDeity(SampleData.bySlug(slug)?.deity?.slug).accent),
                    label: Text(SampleData.bySlug(slug)?.name.split(',').first ?? slug, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onPressed: () => enterTemple(context, TempleScreen(slug: slug, preview: SampleData.bySlug(slug))),
                  ),
              ],
            ),
          ),
        SectionHeader(title: s('language'), motif: Motif.om),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'en', label: Text('English')),
              ButtonSegment(value: 'te', label: Text('తెలుగు')),
              ButtonSegment(value: 'hi', label: Text('हिन्दी')),
            ],
            selected: {settings.locale.languageCode},
            onSelectionChanged: (v) {
              settings.setLocale(Locale(v.first));
              if (auth.isSignedIn) auth.updateProfile(locale: v.first).catchError((_) {});
            },
          ),
        ),
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
              final d = DayTheme.all[i];
              return Container(
                width: 56,
                decoration: BoxDecoration(color: d.accent, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    MotifIcon(d.motif, size: 22, color: d.onAccent()),
                    Text(d.dayName.substring(0, 3), style: TextStyle(color: d.onAccent(), fontSize: 10, fontWeight: FontWeight.w700)),
                  ],
                ),
              );
            },
          ),
        ),
        SectionHeader(title: 'Server', motif: Motif.shankhaChakra, subtitle: settings.apiBase),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: OutlinedButton.icon(onPressed: () => _editServer(context, settings), icon: const Icon(Icons.dns_rounded), label: const Text('Change API server')),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
          child: Column(
            children: [
              SizedBox(height: 60, width: double.infinity, child: CustomPaint(painter: GopuramPainter(color: theme.colorScheme.primary, opacity: 0.25, tiers: 5))),
              const SizedBox(height: 8),
              Text('${Brand.name} · v0.1 · Phase 1', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.55))),
              Text(s('trust_note'), textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.55))),
            ],
          ),
        ),
      ],
    );
  }

  static Future<void> _editName(BuildContext context, AuthController auth) async {
    final c = TextEditingController(text: auth.devotee?.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(controller: c, autofocus: true),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save'))],
      ),
    );
    if (ok == true && c.text.trim().isNotEmpty) {
      try {
        await auth.updateProfile(name: c.text.trim());
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

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

class _MemoryPlaceholder extends StatelessWidget {
  const _MemoryPlaceholder({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        height: 90,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.4), style: BorderStyle.solid)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Icon(Icons.photo_library_outlined, color: color), const SizedBox(width: 10), Text('No memories yet', style: TextStyle(color: color))],
        ),
      );
}
