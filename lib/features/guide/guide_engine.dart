import '../../core/api/temple_repository.dart';
import '../../core/data/sample_data.dart';
import '../../core/models/models.dart';
import '../../core/theme/day_theme.dart';

/// One reply from the guide: text, plus the temples it drew on so the UI can
/// offer them as cards and the devotee can check the record.
class GuideReply {
  const GuideReply(this.text, {this.temples = const [], this.day});

  final String text;
  final List<TempleSummary> temples;
  final DayTheme? day;
}

/// The temple guide answers only from records in the app: the temple
/// database, its timings and pujas, the weekday deities, and the devotee's
/// own location. It never invents a fact; when the record is silent it says
/// so and points at the temple's own contact details.
///
/// It is retrieval and rules, not a language model, which is exactly why it
/// can be trusted at a temple gate with no signal. A server-side assistant
/// grounded in the same verified data can replace the engine later without
/// changing the screen.
class GuideEngine {
  GuideEngine(this._repo);

  final TempleRepository _repo;
  double? lat;
  double? lng;

  static const _stop = {'the', 'a', 'an', 'of', 'in', 'at', 'to', 'for', 'is', 'are', 'what', 'when', 'which', 'where', 'how', 'me', 'tell', 'about', 'temple', 'temples', 'please', 'do', 'does', 'i', 'can', 'and', 'show', 'find', 'near', 'nearby', 'today', 'this', 'that', 'there', 'any', 'some', 'with', 'on', 'my'};

  Future<GuideReply> ask(String question) async {
    final q = question.toLowerCase().trim();
    if (q.isEmpty) return const GuideReply('Ask me about a temple, a deity, timings, pujas, or what is near you.');

    // 1. Today / weekday deity.
    if (RegExp(r'\b(today|which day|what day|deity of the day|whose day)\b').hasMatch(q) && !_mentionsTemple(q)) {
      final d = DayTheme.today();
      final temples = await _templesOf(d.deitySlug);
      return GuideReply(
        '${d.dayName} is ${d.sanskritDay}, kept for ${d.deityName}, ${d.epithet}.\n\nMantra: ${d.mantra} (${d.transliteration})\nOffering: ${d.offering}\n${d.fastingNote}',
        temples: temples,
        day: d,
      );
    }
    for (final d in DayTheme.all) {
      if (q.contains(d.dayName.toLowerCase()) && RegExp(r'\b(deity|god|worship|pray|fast|vrat|day)\b').hasMatch(q)) {
        return GuideReply('${d.dayName} (${d.sanskritDay}) is kept for ${d.deityName}. ${d.greeting}\n\nMantra: ${d.mantra}\nOffering: ${d.offering}\n${d.fastingNote}', temples: await _templesOf(d.deitySlug), day: d);
      }
    }

    // 2. Nearby.
    if (RegExp(r'\b(near|nearby|around|close|closest|nearest)\b').hasMatch(q)) {
      if (lat == null || lng == null) {
        return const GuideReply('I can find temples near you once the app has your location. Tap Locate on the Home tab, then ask again.');
      }
      final deity = _deityIn(q);
      final r = await _repo.temples(TempleQuery(lat: lat, lng: lng, radiusKm: 300, perPage: 5, deity: deity));
      if (r.data.items.isEmpty) return GuideReply(deity == null ? 'No temples within 300 km in our records yet.' : 'No ${_deityName(deity)} temples within 300 km in our records.');
      final lines = r.data.items.map((t) => '• ${t.name} · ${t.distanceKm?.toStringAsFixed(0)} km').join('\n');
      return GuideReply('${deity == null ? 'Nearest temples' : 'Nearest ${_deityName(deity)} temples'} from where you are:\n$lines', temples: r.data.items);
    }

    // 3. A specific temple: timings, pujas, rules, contact, history, closed.
    final temple = await _findTemple(q);
    if (temple != null) {
      final r = await _repo.temple(temple.slug);
      final d = r.data;
      final trust = d.summary.trust;
      final trustLine = trust.level == TrustLevel.official || trust.level == TrustLevel.verified
          ? 'This is a ${trust.level.label.toLowerCase()} record${trust.lastVerifiedAt != null ? ', last verified ${trust.lastVerifiedAt}' : ''}.'
          : 'This is a ${trust.level.label.toLowerCase()} record, not yet checked against an official source, so confirm with the temple before travelling.';
      if (RegExp(r'\b(time|timing|timings|open|opens|close|closes|hours|darshan|aarti|when)\b').hasMatch(q)) {
        if (d.timings.isEmpty) return GuideReply('The record for ${d.summary.name} does not list timings yet. ${_contactLine(d)}\n\n$trustLine', temples: [d.summary]);
        final lines = d.timings.map((t) => '• ${t.label ?? t.kind ?? 'Timing'} (${t.dayLabel ?? 'every day'}): ${t.window ?? '${t.opensAt} – ${t.closesAt}'}').join('\n');
        final closed = d.isClosedToday ? '\n\nIt is marked closed today.' : '';
        return GuideReply('${d.summary.name} timings:\n$lines$closed\n\n$trustLine', temples: [d.summary]);
      }
      if (RegExp(r'\b(pujas?|poojas?|sevas?|archanas?|abhishekam?s?|homams?|fees?|cost|price|book|booking)\b').hasMatch(q)) {
        if (d.pujas.isEmpty) return GuideReply('No pujas or sevas are published for ${d.summary.name} yet. ${_contactLine(d)}', temples: [d.summary]);
        final lines = d.pujas.map((p) => '• ${p.name}${p.startsAt != null ? ' at ${p.startsAt}' : ''} — ${p.fee.display}${p.booking.isOfficial ? ' · official booking' : ''}').join('\n');
        return GuideReply('Pujas and sevas at ${d.summary.name}:\n$lines\n\nA fee shown as "no published price" is not free; ask at the counter. Only links marked official are the temple\'s own booking route.', temples: [d.summary]);
      }
      if (RegExp(r'\b(dress|wear|photo|photograph|camera|phone|mobile|footwear|shoes|rule|rules|allowed|queue)\b').hasMatch(q)) {
        if (d.visitorRules.isEmpty) return GuideReply('No visitor rules are published for ${d.summary.name}. Traditional attire and removing footwear are safe defaults at any temple.', temples: [d.summary]);
        final lines = d.visitorRules.entries.map((e) => '• ${_ruleLabel(e.key)}: ${e.value}').join('\n');
        return GuideReply('Visitor rules at ${d.summary.name}:\n$lines', temples: [d.summary]);
      }
      if (RegExp(r'\b(contact|phone|call|website|email|number)\b').hasMatch(q)) {
        return GuideReply(d.website == null && d.phone == null && d.email == null ? 'No contact details are published for ${d.summary.name} yet.' : '${d.summary.name}:\n${[if (d.phone != null) '• Phone: ${d.phone}', if (d.website != null) '• Website: ${d.website}', if (d.email != null) '• Email: ${d.email}'].join('\n')}', temples: [d.summary]);
      }
      if (RegExp(r'\b(where|reach|get to|directions|location|address|how far|distance)\b').hasMatch(q)) {
        final dist = lat != null && lng != null && d.summary.location.hasCoordinates ? ' It is about ${TempleRepository.distanceKm(lat!, lng!, d.summary.location.latitude!, d.summary.location.longitude!).toStringAsFixed(0)} km from you.' : '';
        return GuideReply('${d.summary.name} is in ${[d.summary.location.address, d.summary.location.city, d.summary.location.district, d.summary.location.state].where((e) => e != null && e.isNotEmpty).toSet().join(', ')}.$dist Open the temple page and tap Directions for the route.', temples: [d.summary]);
      }
      if (RegExp(r'\b(closed|closure|holiday|open today)\b').hasMatch(q)) {
        final up = d.closures.map((c) => '• ${c.reason ?? 'Closed'}: ${c.startsOn}${c.endsOn != c.startsOn ? ' to ${c.endsOn}' : ''}').join('\n');
        return GuideReply('${d.summary.name} is ${d.isClosedToday ? 'marked closed today' : 'not marked closed today'}.${up.isEmpty ? '' : '\n\nUpcoming closures:\n$up'}', temples: [d.summary]);
      }
      final about = [d.summary.shortDescription, if (d.history != d.summary.shortDescription) d.history].whereType<String>().join(' ');
      final cats = d.categories.map((c) => c.name).join(', ');
      return GuideReply('${d.summary.name}${d.summary.deity != null ? ', a ${d.summary.deity!.name} temple' : ''} in ${d.summary.location.short}.${cats.isNotEmpty ? ' Part of: $cats.' : ''}\n\n$about\n\n$trustLine\n\nAsk me about its timings, pujas, rules or how to reach it.', temples: [d.summary]);
    }

    // 4. A deity or a circuit.
    final deity = _deityIn(q);
    if (deity != null) {
      final temples = await _templesOf(deity);
      final d = DayTheme.forDeity(deity);
      final dayLine = d.deitySlug == deity ? ' ${d.dayName} is the day kept for ${d.deityName}; the mantra is ${d.mantra}.' : '';
      return GuideReply('${temples.length} ${_deityName(deity)} temple${temples.length == 1 ? '' : 's'} in our records.$dayLine', temples: temples, day: d.deitySlug == deity ? d : null);
    }
    for (final c in SampleData.categories) {
      if (q.contains(c.name.toLowerCase()) || q.contains(c.slug.replaceAll('-', ' '))) {
        final r = await _repo.temples(TempleQuery(category: c.slug, perPage: 20));
        return GuideReply('${c.name}${c.description != null ? ': ${c.description}' : ''}\n\n${r.data.items.length} in our records.', temples: r.data.items);
      }
    }

    // 5. Free search.
    final r = await _repo.temples(TempleQuery(q: q, perPage: 5));
    if (r.data.items.isNotEmpty) {
      return GuideReply('I found these for "$question":', temples: r.data.items);
    }
    return const GuideReply('I answer only from the temple records in this app, and nothing matched. Try a temple name, a deity, a city, or "what is today".');
  }

  bool _mentionsTemple(String q) => SampleData.temples.any((t) => _matchScore(q, t) >= 2);

  Future<TempleSummary?> _findTemple(String q) async {
    TempleSummary? best;
    var bestScore = 0;
    for (final t in SampleData.temples) {
      final s = _matchScore(q, t);
      if (s > bestScore) {
        best = t;
        bestScore = s;
      }
    }
    if (bestScore >= 2) return best;
    // Try the live index for names the bundle does not know.
    final words = q.split(RegExp(r'[^a-zऀ-౿]+')).where((w) => w.length > 3 && !_stop.contains(w)).toList();
    if (words.isEmpty) return null;
    try {
      final r = await _repo.temples(TempleQuery(q: words.first, perPage: 1));
      if (!r.isOffline && r.data.items.isNotEmpty) return r.data.items.first;
    } catch (_) {}
    return null;
  }

  /// Counts distinctive words of the temple's name, city and aliases in the
  /// question. A city or an alias is distinctive on its own ("Tirupati" is
  /// enough), so those words weigh double.
  static int _matchScore(String q, TempleSummary t) {
    int words(String n, int weight) {
      var hits = 0;
      for (final w in n.toLowerCase().split(RegExp(r'[^a-zऀ-౿]+'))) {
        if (w.length > 3 && !_stop.contains(w) && !_generic.contains(w) && RegExp('\\b${RegExp.escape(w)}\\b').hasMatch(q)) hits += weight;
      }
      return hits;
    }

    var score = words(t.name, 1) + words(t.location.city ?? '', 2);
    for (final alias in SampleData.aliasesFor(t.slug)) {
      score += words(alias, 2);
    }
    return score;
  }

  static const _generic = {'swamy', 'swami', 'sree', 'shri', 'temple', 'mandir', 'devi', 'lord'};

  String? _deityIn(String q) {
    for (final d in SampleData.deities) {
      if (RegExp('\\b${d.name.toLowerCase()}\\b').hasMatch(q)) return d.slug;
      for (final a in d.alternateNames) {
        if (RegExp('\\b${a.toLowerCase()}\\b').hasMatch(q)) return d.slug;
      }
    }
    return null;
  }

  String _deityName(String slug) => SampleData.deities.where((d) => d.slug == slug).firstOrNull?.name ?? slug;

  Future<List<TempleSummary>> _templesOf(String deity) async {
    final r = await _repo.temples(TempleQuery(deity: deity, perPage: 20));
    return r.data.items;
  }

  static String _contactLine(TempleDetail d) => d.phone != null ? 'The temple can be reached on ${d.phone}.' : d.website != null ? 'Check the temple website: ${d.website}.' : 'Check with the temple office before travelling.';

  static String _ruleLabel(String key) => switch (key) {
        'dress_code' => 'Dress code',
        'photography' => 'Photography',
        'mobile' => 'Mobile phones',
        'footwear' => 'Footwear',
        'entry' => 'Entry',
        'queue' => 'Queue',
        _ => key,
      };
}
