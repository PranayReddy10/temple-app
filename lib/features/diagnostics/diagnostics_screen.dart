
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/app_image.dart';
import '../../core/widgets/temple_widgets.dart';
import '../explore/search_screen.dart';

/// Checks one temple against the live API and says, line by line, what the
/// server returned and whether each image and recording actually loads.
///
/// Exists so "the cover is not showing" can be answered with the URL the
/// server sent and the HTTP status it gave, rather than a guess.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _Line {
  _Line(this.label, this.value, {this.ok, this.url});

  final String label;
  final String value;
  final bool? ok;
  final String? url;
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  TempleSummary? _temple;
  final List<_Line> _lines = [];
  bool _running = false;

  Future<void> _run() async {
    final t = _temple;
    if (t == null) return;
    final api = context.read<ApiClient>();
    setState(() {
      _running = true;
      _lines.clear();
    });
    void add(String label, String value, {bool? ok, String? url}) => setState(() => _lines.add(_Line(label, value, ok: ok, url: url)));
    add('API server', api.baseUrl);
    add('Language', api.language);
    Map<String, dynamic>? raw;
    try {
      final json = await api.get('temples/${t.slug}');
      raw = json['data'] as Map<String, dynamic>;
      add('GET /temples/${t.slug}', 'OK', ok: true);
    } catch (e) {
      add('GET /temples/${t.slug}', '$e', ok: false);
    }
    if (raw == null) {
      setState(() => _running = false);
      return;
    }
    final d = TempleDetail.fromJson(raw);
    final cover = raw['primary_photo'];
    add('primary_photo in response', cover == null ? 'absent or null (server older than the cover change, or no cover set)' : 'present', ok: cover != null);
    final photos = d.photos;
    add('photos in response', '${photos.length}', ok: photos.isNotEmpty);
    for (final p in photos.take(4)) {
      final url = p.best;
      if (url == null) {
        add('photo ${p.id}', 'no URL', ok: false);
        continue;
      }
      final resolved = AppImage.resolve(url, api.baseUrl);
      final status = await _head(resolved);
      add('photo ${p.id}${p.isPrimary ? ' (cover)' : ''}', '$status  $resolved', ok: status.startsWith('2'), url: resolved);
    }
    final mantra = raw['mantra'];
    if (mantra is! Map) {
      add('mantra', 'absent (server older than the mantra change)', ok: false);
    } else {
      final audio = mantra['audio'];
      add('mantra.text', '${mantra['text'] ?? '—'} · is_own=${mantra['is_own']}');
      if (audio is! Map) {
        add('mantra.audio', 'null: no published recording attached to this temple or its deity', ok: false);
      } else {
        final pb = audio['playback'];
        add('mantra.audio', '${audio['title']} · type=${audio['type']} · source=${audio['source_type']}', ok: true);
        add('mantra.audio.url', '${audio['url']}');
        add('mantra.audio.playback', pb is Map ? 'kind=${pb['kind']} embed=${pb['embed_url'] ?? '—'} id=${pb['youtube_id'] ?? '—'}' : 'absent (server older than the playback change)', ok: pb is Map);
        if (audio['url'] != null && (pb is! Map || pb['kind'] == 'audio')) {
          final status = await _head(AppImage.resolve('${audio['url']}', api.baseUrl));
          add('mantra.audio reachable', status, ok: status.startsWith('2'));
        }
      }
    }
    final media = raw['devotional_media'];
    add('devotional_media in response', media is List ? '${media.length} item(s)' : 'absent', ok: media is List && media.isNotEmpty);
    if (media is List) {
      for (final m in media.take(6)) {
        final mm = m as Map<String, dynamic>;
        final pb = mm['playback'];
        add('media: ${mm['title']}', 'type=${mm['type']} · kind=${pb is Map ? pb['kind'] : '?'} · ${mm['url']}', ok: mm['url'] != null);
      }
    }
    setState(() => _running = false);
  }

  Future<String> _head(String url) async {
    try {
      final res = await http.get(Uri.parse(url), headers: AppImage.headers).timeout(const Duration(seconds: 15));
      return '${res.statusCode} ${res.headers['content-type'] ?? ''}'.trim();
    } catch (e) {
      return 'failed: ${e.toString().split('\n').first}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Check a temple'),
        actions: [
          if (_lines.isNotEmpty)
            IconButton(
              tooltip: 'Copy report',
              icon: const Icon(Icons.copy_rounded),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _lines.map((l) => '${l.ok == null ? '·' : l.ok! ? '✓' : '✗'} ${l.label}: ${l.value}').join('\n')));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report copied.')));
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text('Asks the live API for one temple and checks whether its cover, gallery, mantra recording and media actually load from this phone. Copy the report and send it if something is wrong.', style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await Navigator.of(context).push<TempleSummary>(MaterialPageRoute(builder: (_) => const SearchScreen(picker: true, title: 'Which temple?')));
                    if (picked != null) setState(() => _temple = picked);
                  },
                  icon: const Icon(Icons.temple_hindu_rounded),
                  label: Text(_temple?.name.split(',').first ?? 'Choose a temple', maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _temple == null || _running ? null : _run, child: _running ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Check')),
            ],
          ),
          const SizedBox(height: 16),
          for (final l in _lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(l.ok == null ? Icons.circle_outlined : l.ok! ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 16, color: l.ok == null ? theme.colorScheme.outline : l.ok! ? Palette.tulsi : theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.label, style: theme.textTheme.labelLarge?.copyWith(letterSpacing: 0.3)),
                        SelectableText(l.value, style: theme.textTheme.bodySmall),
                        if (l.url != null && l.ok == true) Padding(padding: const EdgeInsets.only(top: 6), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(height: 80, width: 120, child: AppImage(l.url!, placeholder: const TempleImage())))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (_lines.isNotEmpty && !_running) ...[
            const SizedBox(height: 12),
            Text(_hint(), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
          ],
        ],
      ),
    );
  }

  String _hint() {
    final photoFails = _lines.where((l) => l.label.startsWith('photo ') && l.ok == false).toList();
    if (photoFails.any((l) => l.value.startsWith('404'))) {
      return 'A 404 on a /storage/ URL means the server is missing its storage link: run "php artisan storage:link" (or app:deploy) on the server.';
    }
    if (photoFails.any((l) => l.value.startsWith('403'))) {
      return 'A 403 means the file is not public: on DigitalOcean Spaces, set the files (or the bucket) to public, or re-upload from the admin panel.';
    }
    if (photoFails.any((l) => l.value.startsWith('failed'))) {
      return 'The image host could not be reached from this phone: check the hostname in the URL resolves and uses https.';
    }
    if (_lines.any((l) => l.value.contains('server older'))) {
      return 'The deployed API predates the latest backend changes. Deploy the temple-website main branch, then check again.';
    }
    return 'Everything the server sent loads from this phone.';
  }
}
