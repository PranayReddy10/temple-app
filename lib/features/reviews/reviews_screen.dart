import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/engagement_repository.dart';
import '../../core/l10n/strings.dart';
import '../../core/models/models.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/auth_controller.dart';
import '../../core/state/passport_controller.dart';
import '../../core/theme/day_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/app_image.dart';
import '../../core/widgets/temple_widgets.dart';
import '../auth/auth_screen.dart';

/// How visits went, per dimension, as bars. There is no overall score and no
/// stars on the temple: a place of worship is not ranked.
class ReviewSummaryCard extends StatelessWidget {
  const ReviewSummaryCard({super.key, required this.summary, required this.day, this.compact = false});

  final ReviewSummary summary;
  final DayTheme day;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final dims = summary.dimensions.isNotEmpty ? summary.dimensions : [for (final d in reviewDimensions) RatingDimension(key: d.$1, label: d.$2)];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(18), border: Border.all(color: day.accent.withValues(alpha: 0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.groups_rounded, size: 18, color: day.accent),
              const SizedBox(width: 8),
              Expanded(child: Text(summary.count == 0 ? s('reviews_none_yet') : '${summary.count} ${summary.count == 1 ? s('review_one') : s('review_many')}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
              if (summary.averageWaitMinutes != null) Text('${s('reviews_wait')} ~${summary.averageWaitMinutes} min', style: theme.textTheme.labelSmall?.copyWith(color: day.accent, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          for (final d in dims.take(compact ? 3 : dims.length)) _Bar(dimension: d, accent: day.accent),
          if (summary.count > 0) Padding(padding: const EdgeInsets.only(top: 6), child: Text(s('reviews_explain'), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)))),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.dimension, required this.accent});

  final RatingDimension dimension;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avg = dimension.average;
    final local = reviewDimensions.where((d) => d.$1 == dimension.key).firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 118, child: Text(dimension.label, maxLines: 2, style: theme.textTheme.labelMedium)),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: avg == null ? 0 : ((avg - 1) / 4).clamp(0.0, 1.0), minHeight: 8, backgroundColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.5), color: accent),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: Text(
              avg == null ? '—' : (avg >= 4 ? (local?.$4 ?? avg.toStringAsFixed(1)) : avg <= 2 ? (local?.$3 ?? avg.toStringAsFixed(1)) : avg.toStringAsFixed(1)),
              textAlign: TextAlign.end,
              maxLines: 2,
              style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: avg == null ? theme.colorScheme.outline : null),
            ),
          ),
        ],
      ),
    );
  }
}

/// One devotee's account, as the list shows it.
class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review, required this.day, this.onDelete});

  final Review review;
  final DayTheme day;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final rated = review.ratings.where((r) => r.value != null).toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: day.accent.withValues(alpha: 0.18),
                  child: review.devoteeAvatarUrl != null ? ClipOval(child: SizedBox.expand(child: AppImage(review.devoteeAvatarUrl!))) : Text(review.devoteeName.characters.firstOrNull?.toUpperCase() ?? '?', style: TextStyle(color: day.accent, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(review.isMine ? '${review.devoteeName} · ${s('review_you')}' : review.devoteeName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      Text([if (review.homeState != null) review.homeState!, if (review.visitedOn != null) '${s('review_visited')} ${_date(review.visitedOn!)}'].join(' · '), style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                if (review.isMine && review.status != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: (review.isPending ? Palette.gold : review.isRejected ? Palette.kumkum : Palette.tulsi).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
                    child: Text(review.statusLabel ?? review.status!, style: theme.textTheme.labelSmall?.copyWith(color: review.isPending ? Palette.gold : review.isRejected ? Palette.kumkum : Palette.tulsi, fontWeight: FontWeight.w700)),
                  ),
                if (onDelete != null) IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded, size: 18)),
              ],
            ),
            if (rated.isNotEmpty || review.waitMinutes != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final r in rated) _Chip(text: '${r.label} ${r.value}/5', color: r.value! >= 4 ? Palette.tulsi : r.value! <= 2 ? Palette.kumkum : day.accent),
                  if (review.waitMinutes != null) _Chip(text: '${s('reviews_wait')} ${review.waitMinutes} min', color: theme.colorScheme.outline),
                ],
              ),
            ],
            if (review.body != null) ...[const SizedBox(height: 10), Text(review.body!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45))],
            if (review.isMine && review.moderationNote != null) ...[const SizedBox(height: 8), Text('${s('review_team_said')} ${review.moderationNote}', style: theme.textTheme.bodySmall?.copyWith(color: Palette.kumkum))],
            if (review.templeReply != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Palette.tulsi.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Palette.tulsi.withValues(alpha: 0.35))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [const Icon(Icons.temple_hindu_rounded, size: 14, color: Palette.tulsi), const SizedBox(width: 6), Text(s('review_temple_replied').toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(color: Palette.tulsi, letterSpacing: 1.2, fontWeight: FontWeight.w800))]),
                    const SizedBox(height: 4),
                    Text(review.templeReply!, style: theme.textTheme.bodySmall?.copyWith(height: 1.4)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _date(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('d MMM yyyy').format(d);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: 0.35))),
        child: Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
      );
}

/// Every published account of visiting a temple, with the summary on top.
class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key, required this.temple, this.initialSummary});

  final TempleSummary temple;
  final ReviewSummary? initialSummary;

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  late final _repo = EngagementRepository(context.read<ApiClient>());
  List<Review>? _reviews;
  late ReviewSummary _summary = widget.initialSummary ?? ReviewSummary.empty;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final page = await _repo.reviews(widget.temple.slug);
      if (mounted) {
        setState(() {
          _reviews = page.reviews;
          _summary = page.summary;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : S.of(context)('payment_offline'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final day = DayTheme.forDeity(widget.temple.deity?.slug);
    final reviews = _reviews;
    return Scaffold(
      appBar: AppBar(title: Text(s('reviews'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => writeReview(context, widget.temple).then((r) {
          if (r != null) _load();
        }),
        backgroundColor: day.accent,
        foregroundColor: day.onAccent(),
        icon: const Icon(Icons.rate_review_rounded),
        label: Text(s('review_write')),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            Text(widget.temple.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontFamily: 'NotoSerif')),
            const SizedBox(height: 12),
            ReviewSummaryCard(summary: _summary, day: day),
            const SizedBox(height: 16),
            if (reviews == null && _error == null)
              const Padding(padding: EdgeInsets.all(30), child: DiyaLoader(size: 40))
            else if (reviews == null)
              EmptyShrine(motif: Motif.diya, message: _error!, action: OutlinedButton(onPressed: _load, child: Text(s('retry'))))
            else if (reviews.isEmpty)
              EmptyShrine(motif: Motif.lotus, message: s('reviews_empty'))
            else
              for (final r in reviews) ReviewCard(review: r, day: day),
          ],
        ),
      ),
    );
  }
}

/// "Write about your visit": the sheet. Rates the visit, never the temple.
/// Returns the review the server kept, or null.
Future<Review?> writeReview(BuildContext context, TempleSummary temple, {Visit? visit}) async {
  final auth = context.read<AuthController>();
  if (!auth.isSignedIn) {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
    if (!context.mounted || !auth.isSignedIn) return null;
  }
  return showModalBottomSheet<Review>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _WriteReviewSheet(temple: temple, visit: visit),
  );
}

class _WriteReviewSheet extends StatefulWidget {
  const _WriteReviewSheet({required this.temple, this.visit});

  final TempleSummary temple;
  final Visit? visit;

  @override
  State<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<_WriteReviewSheet> {
  final Map<String, int> _ratings = {};
  final _body = TextEditingController();
  late DateTime _visitedOn = widget.visit?.visitedAt ?? _lastVisitDate() ?? DateTime.now();
  int? _wait;
  bool _saving = false;

  DateTime? _lastVisitDate() {
    try {
      return context.read<PassportController>().visits.where((v) => v.templeSlug == widget.temple.slug).map((v) => v.visitedAt).fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = S.of(context);
    if (_ratings.isEmpty && _wait == null && _body.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s('review_say_something'))));
      return;
    }
    setState(() => _saving = true);
    try {
      final r = await EngagementRepository(context.read<ApiClient>()).write(
        widget.temple.slug,
        visitedOn: DateFormat('yyyy-MM-dd').format(_visitedOn),
        visitId: widget.visit?.remoteId,
        ratings: _ratings,
        waitMinutes: _wait,
        body: _body.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(r);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s('review_sent'))));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.errors.values.expand((v) => v).firstOrNull ?? e.message)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of(context)('payment_offline'))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final day = DayTheme.forDeity(widget.temple.deity?.slug);
    const waits = [0, 15, 30, 60, 120, 180];
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            Text(s('review_write'), style: theme.textTheme.titleLarge?.copyWith(fontFamily: 'NotoSerif')),
            Text(widget.temple.name, style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(s('review_intro'), style: theme.textTheme.bodySmall?.copyWith(height: 1.4)),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(s('review_visited'), style: theme.textTheme.labelLarge),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.calendar_month_rounded, size: 16),
                  label: Text(DateFormat('d MMM yyyy').format(_visitedOn)),
                  onPressed: () async {
                    final p = await showDatePicker(context: context, initialDate: _visitedOn, firstDate: DateTime(2000), lastDate: DateTime.now());
                    if (p != null) setState(() => _visitedOn = p);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final d in reviewDimensions) ...[
              Row(
                children: [
                  Expanded(child: Text(d.$2, style: theme.textTheme.labelLarge)),
                  Text(_ratings[d.$1] == null ? s('review_skip') : (_ratings[d.$1]! <= 2 ? d.$3 : _ratings[d.$1]! >= 4 ? d.$4 : s('review_fair')), style: theme.textTheme.labelSmall?.copyWith(color: day.accent)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  for (var v = 1; v <= 5; v++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => setState(() => _ratings[d.$1] == v ? _ratings.remove(d.$1) : _ratings[d.$1] = v),
                          child: Container(
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: (_ratings[d.$1] ?? 0) >= v ? day.accent : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: (_ratings[d.$1] ?? 0) >= v ? day.accent : theme.colorScheme.outlineVariant),
                            ),
                            child: Text('$v', style: theme.textTheme.labelLarge?.copyWith(color: (_ratings[d.$1] ?? 0) >= v ? day.onAccent() : null, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            Text(s('review_wait_q'), style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final w in waits) ChoiceChip(label: Text(w == 0 ? s('review_no_wait') : w >= 60 ? '${w ~/ 60} h${w % 60 == 0 ? '' : ' ${w % 60} min'}' : '$w min'), selected: _wait == w, onSelected: (_) => setState(() => _wait = _wait == w ? null : w))],
            ),
            const SizedBox(height: 12),
            TextField(controller: _body, maxLines: 4, maxLength: 3000, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(labelText: s('review_body'), hintText: s('review_body_hint'), alignLabelWithHint: true)),
            const SizedBox(height: 6),
            Text(s('review_footnote'), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: day.accent, foregroundColor: day.onAccent(), minimumSize: const Size.fromHeight(48)),
              icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded),
              label: Text(s('review_send')),
            ),
          ],
        ),
      ),
    );
  }
}

/// The devotee's own accounts, wherever they wrote them.
class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  late final _repo = EngagementRepository(context.read<ApiClient>());
  List<Review>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _repo.myReviews();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : S.of(context)('payment_offline'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: Text(s('my_reviews'))),
      body: items == null
          ? (_error == null ? const DiyaLoader() : EmptyShrine(motif: Motif.diya, message: _error!, action: OutlinedButton(onPressed: _load, child: Text(s('retry')))))
          : items.isEmpty
              ? EmptyShrine(motif: Motif.lotus, message: s('my_reviews_empty'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                    children: [
                      for (final r in items) ...[
                        if (r.templeName != null) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(r.templeName!, style: Theme.of(context).textTheme.labelLarge)),
                        ReviewCard(
                          review: r,
                          day: DayTheme.today(),
                          onDelete: r.id == null
                              ? null
                              : () async {
                                  await _repo.remove(r.id!);
                                  _load();
                                },
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
