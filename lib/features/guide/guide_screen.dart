import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../core/api/temple_repository.dart';
import '../../core/l10n/strings.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/day_controller.dart';
import '../../core/theme/day_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/temple_door.dart';
import '../../core/widgets/temple_widgets.dart';
import '../temple/temple_screen.dart';
import 'guide_engine.dart';

/// A conversation with the temple guide, laid out like palm-leaf notes.
class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key, this.initialQuestion});

  final String? initialQuestion;

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _Turn {
  _Turn.user(this.text) : reply = null;
  _Turn.guide(this.reply) : text = reply!.text;

  final String text;
  final GuideReply? reply;
  bool get isUser => reply == null;
}

class _GuideScreenState extends State<GuideScreen> {
  late final GuideEngine _engine = GuideEngine(context.read<TempleRepository>());
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_Turn> _turns = [];
  bool _thinking = false;

  static const _suggestions = ['What is today?', 'Temples near me', 'Timings at Tirumala', 'Pujas at Kashi Vishwanath', 'Jyotirlinga temples', 'Dress code at Meenakshi Amman'];

  @override
  void initState() {
    super.initState();
    _turns.add(_Turn.guide(const GuideReply('Namaste. I answer only from the verified temple records in this app: timings, pujas, deities, circuits, and what is near you. What would you like to know?')));
    _locate();
    if (widget.initialQuestion != null) WidgetsBinding.instance.addPostFrameCallback((_) => _ask(widget.initialQuestion!));
  }

  Future<void> _locate() async {
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getLastKnownPosition() ?? await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.low));
      _engine
        ..lat = pos.latitude
        ..lng = pos.longitude;
    } catch (_) {}
  }

  Future<void> _ask(String q) async {
    if (q.trim().isEmpty) return;
    _input.clear();
    setState(() {
      _turns.add(_Turn.user(q.trim()));
      _thinking = true;
    });
    _scrollDown();
    final r = await _engine.ask(q);
    if (!mounted) return;
    setState(() {
      _turns.add(_Turn.guide(r));
      _thinking = false;
    });
    _scrollDown();
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent + 200, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      });

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final day = context.watch<DayController>().theme;
    return Scaffold(
      appBar: AppBar(title: Text(s('guide'))),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: _turns.length + (_thinking ? 1 : 0),
              itemBuilder: (context, i) {
                if (i >= _turns.length) return const Padding(padding: EdgeInsets.all(12), child: DiyaLoader(size: 32));
                final t = _turns[i];
                return t.isUser ? _UserBubble(text: t.text, day: day) : _GuideBubble(reply: t.reply!, day: day);
              },
            ),
          ),
          if (_turns.length <= 1)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => ActionChip(label: Text(_suggestions[i]), onPressed: () => _ask(_suggestions[i])),
              ),
            ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 12),
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant))),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _ask,
                    decoration: InputDecoration(hintText: s('guide_hint'), prefixIcon: MotifIcon(Motif.diya, size: 20, color: day.accent, secondary: Palette.turmeric)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: () => _ask(_input.text), icon: const Icon(Icons.send_rounded)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text, required this.day});

  final String text;
  final DayTheme day;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(top: 10, left: 60),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: day.accent, borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomLeft: Radius.circular(18), bottomRight: Radius.circular(4))),
          child: Text(text, style: TextStyle(color: day.onAccent())),
        ),
      );
}

class _GuideBubble extends StatelessWidget {
  const _GuideBubble({required this.reply, required this.day});

  final GuideReply reply;
  final DayTheme day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = reply.day ?? day;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 10, right: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(18), bottomLeft: Radius.circular(18), bottomRight: Radius.circular(18)),
            border: Border.all(color: d.accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MotifIcon(d.motif, size: 22, color: d.accent, secondary: d.secondary),
              const SizedBox(width: 10),
              Expanded(child: SelectableText(reply.text, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45))),
            ],
          ),
        ),
        if (reply.temples.isNotEmpty)
          SizedBox(
            height: scaledHeight(context, 100),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(top: 8),
              itemCount: reply.temples.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final t = reply.temples[i];
                return SizedBox(width: 280, child: TempleCard(temple: t, compact: true, onTap: () => enterTemple(context, TempleScreen(slug: t.slug, preview: t), accent: DayTheme.forDeity(t.deity?.slug).accent)));
              },
            ),
          ),
      ],
    );
  }
}
