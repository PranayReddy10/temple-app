import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/seva.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/app_image.dart';

/// The icon each cause is shown with, in lists, chips and the form.
IconData sevaCauseIcon(String value) => switch (value) {
      'cleaning' => Icons.cleaning_services_rounded,
      'water_body' => Icons.water_rounded,
      'restoration' => Icons.construction_rounded,
      'painting' => Icons.format_paint_rounded,
      'lighting' => Icons.light_rounded,
      'plantation' => Icons.park_rounded,
      'documentation' => Icons.photo_camera_rounded,
      _ => Icons.volunteer_activism_rounded,
    };

/// Status colours: green once verified, saffron while open, grey when over.
Color sevaStatusColor(String status) => switch (status) {
      'verified' => Palette.tulsi,
      'completed' => Palette.ash,
      'approved' => Palette.saffron,
      'rejected' => Palette.kumkum,
      'cancelled' => Palette.stone,
      'blocked' => Palette.kumkum,
      _ => Palette.gold,
    };

/// A photograph picked on this device, before it is uploaded.
Widget localImage(String path) => kIsWeb
    ? Image.network(path, fit: BoxFit.cover)
    : Image.file(File(path), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Palette.stone));

String sevaDate(DateTime d) => DateFormat('EEE, d MMM · h:mm a').format(d);

/// The drive's dates as people say them: one day with its hours, or a span.
///
/// "Sat, 12 Oct · 7:00 AM – 11:00 AM", "Sat, 12 Oct · 7:00 AM", or
/// "Sat 12 Oct → Mon 14 Oct · 3 days".
String sevaDateRange(SevaDrive d) {
  final end = d.endsAt;
  if (end == null) return sevaDate(d.startsAt);
  if (d.dayCount <= 1) return '${sevaDate(d.startsAt)} – ${DateFormat('h:mm a').format(end)}';
  return '${DateFormat('EEE d MMM').format(d.startsAt)} → ${DateFormat('EEE d MMM').format(end)} · ${d.dayCount} days';
}

/// A small circle with the organiser's photo or initial.
class OrganiserAvatar extends StatelessWidget {
  const OrganiserAvatar({super.key, required this.drive, this.radius = 13});

  final SevaDrive drive;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = drive.organiserAvatar;
    final initial = (drive.organiserName ?? '').characters.firstOrNull?.toUpperCase() ?? '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: (drive.isTeam ? Palette.tulsi : Palette.saffron).withValues(alpha: 0.2),
      child: url != null
          ? ClipOval(child: SizedBox.expand(child: AppImage(url)))
          : drive.isTeam
              ? Icon(Icons.groups_rounded, size: radius, color: Palette.tulsi)
              : Text(initial, style: TextStyle(fontSize: radius * 0.9, fontWeight: FontWeight.w800)),
    );
  }
}

String rupees(int amount) => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(amount);

/// A small rounded label over a photo or beside a title.
class SevaPill extends StatelessWidget {
  const SevaPill({super.key, required this.text, required this.color, this.icon, this.solid = false});

  final String text;
  final Color color;
  final IconData? icon;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final fg = solid ? Colors.white : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: solid ? null : Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
          Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.2))),
        ],
      ),
    );
  }
}

/// The four stages every drive passes through, with where this one is.
class SevaProgressSteps extends StatelessWidget {
  const SevaProgressSteps({super.key, required this.drive});

  final SevaDrive drive;

  static const _labels = ['Raised', 'Approved', 'Done', 'Verified'];
  static const _icons = [Icons.flag_rounded, Icons.how_to_reg_rounded, Icons.task_alt_rounded, Icons.verified_rounded];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stopped = drive.isRejected || drive.isCancelled || drive.isBlocked;
    final reached = drive.stage;
    final active = stopped ? Palette.stone : Palette.tulsi;
    return Row(
      children: [
        for (var i = 0; i < 4; i++) ...[
          Expanded(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= reached ? active : theme.colorScheme.surfaceContainerHighest,
                    border: Border.all(color: i <= reached ? active : theme.colorScheme.outlineVariant, width: 1.5),
                  ),
                  child: Icon(_icons[i], size: 18, color: i <= reached ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                ),
                const SizedBox(height: 6),
                Text(_labels[i], style: theme.textTheme.labelSmall?.copyWith(fontWeight: i == reached ? FontWeight.w800 : FontWeight.w500, color: i <= reached ? null : theme.colorScheme.onSurface.withValues(alpha: 0.5))),
              ],
            ),
          ),
          if (i < 3)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: Container(height: 3, decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: i < reached ? active : theme.colorScheme.outlineVariant)),
              ),
            ),
        ],
      ],
    );
  }
}

/// One drive in a list: its photograph, where and when, and who is coming.
class SevaDriveCard extends StatelessWidget {
  const SevaDriveCard({super.key, required this.drive, required this.onTap});

  final SevaDrive drive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cover = drive.coverUrl;
    final afterCover = drive.after.where((m) => m.isPhoto && m.url != null).firstOrNull?.url;
    final beforeCover = drive.before.where((m) => m.isPhoto && m.url != null).firstOrNull?.url;
    final showPair = drive.isDone && afterCover != null && beforeCover != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (showPair)
                      Row(
                        children: [
                          Expanded(child: _Labelled(url: beforeCover, label: 'BEFORE')),
                          const SizedBox(width: 2),
                          Expanded(child: _Labelled(url: afterCover, label: 'AFTER')),
                        ],
                      )
                    else if (cover != null)
                      AppImage(cover)
                    else
                      _CausePlaceholder(cause: drive.cause.value),
                    const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.center, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xAA000000)]))),
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Row(
                        children: [
                          Flexible(child: SevaPill(text: drive.cause.label, color: Palette.deep, icon: sevaCauseIcon(drive.cause.value), solid: true)),
                          const SizedBox(width: 8),
                          const Spacer(),
                          Flexible(
                            child: drive.isMisleading
                                ? const SevaPill(text: 'Flagged misleading', color: Palette.kumkum, icon: Icons.warning_amber_rounded, solid: true)
                                : SevaPill(text: drive.statusLabel, color: sevaStatusColor(drive.status), icon: drive.isVerified ? Icons.verified_rounded : null, solid: true),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 12,
                      child: Text(drive.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.2, shadows: const [Shadow(blurRadius: 6, color: Colors.black54)])),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (drive.organiserName != null) ...[
                      Row(
                        children: [
                          OrganiserAvatar(drive: drive, radius: 11),
                          const SizedBox(width: 8),
                          Expanded(child: Text('by ${drive.organiserName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700))),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    _Line(icon: Icons.place_rounded, text: drive.where),
                    const SizedBox(height: 4),
                    _Line(icon: drive.isMultiDay ? Icons.date_range_rounded : Icons.event_rounded, text: sevaDateRange(drive)),
                    const SizedBox(height: 10),
                    if (drive.isDone && drive.donations.open)
                      _DonationStrip(donations: drive.donations)
                    else
                      _VolunteerStrip(drive: drive),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Labelled extends StatelessWidget {
  const _Labelled({required this.url, required this.label});

  final String url;
  final String label;

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          AppImage(url),
          Positioned(
            bottom: 44,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
              child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
            ),
          ),
        ],
      );
}

class _CausePlaceholder extends StatelessWidget {
  const _CausePlaceholder({required this.cause});

  final String cause;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Palette.tulsi, Palette.deep])),
        child: Center(child: Icon(sevaCauseIcon(cause), size: 64, color: Colors.white.withValues(alpha: 0.35))),
      );
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

class _VolunteerStrip extends StatelessWidget {
  const _VolunteerStrip({required this.drive});

  final SevaDrive drive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final need = drive.volunteersNeeded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.groups_rounded, size: 18, color: Palette.saffron),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                [
                  need == null ? '${drive.volunteersJoined} coming' : '${drive.volunteersJoined} of $need coming',
                  if ((drive.donations.raised ?? 0) > 0) '${rupees(drive.donations.raised!)} raised',
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (drive.hasJoined) const Flexible(child: SevaPill(text: "You're going", color: Palette.tulsi, icon: Icons.check_rounded)),
            if (drive.isOrganiser) const Flexible(child: SevaPill(text: 'Organiser', color: Palette.kumkum, icon: Icons.star_rounded)),
          ],
        ),
        if (drive.volunteerProgress != null) ...[
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: drive.volunteerProgress, minHeight: 6, color: Palette.saffron, backgroundColor: Palette.saffron.withValues(alpha: 0.15))),
        ],
      ],
    );
  }
}

class _DonationStrip extends StatelessWidget {
  const _DonationStrip({required this.donations});

  final SevaDonations donations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.volunteer_activism_rounded, size: 18, color: Palette.tulsi),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                donations.goal == null ? '${rupees(donations.raised ?? 0)} raised' : '${rupees(donations.raised ?? 0)} of ${rupees(donations.goal!)}',
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const Flexible(child: SevaPill(text: 'Accepting donations', color: Palette.tulsi)),
          ],
        ),
        if (donations.progress != null) ...[
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: donations.progress, minHeight: 6, color: Palette.tulsi, backgroundColor: Palette.tulsi.withValues(alpha: 0.15))),
        ],
      ],
    );
  }
}
