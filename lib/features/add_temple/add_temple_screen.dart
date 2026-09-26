import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/seva_repository.dart';
import '../../core/api/temple_repository.dart';
import '../../core/api/temple_suggestion_repository.dart';
import '../../core/models/models.dart';
import '../../core/models/seva.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/auth_controller.dart';
import '../../core/state/location_controller.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/temple_widgets.dart';
import '../auth/auth_screen.dart';
import '../seva/seva_widgets.dart';
import '../temple/temple_screen.dart';

/// "My temple is not listed": the full form to add one.
///
/// No catalogue has every temple — a village shrine is known to the people
/// who go there. Anyone signed in can add one; somebody from the temple
/// itself (trustee, priest, committee) says so and leaves a number, because
/// they are who the temple's own app will be handed to later. Nothing is
/// published until the editors have checked it.
class AddTempleScreen extends StatefulWidget {
  const AddTempleScreen({super.key, this.initialName});

  final String? initialName;

  /// Opens the form, asking the devotee to sign in first if need be.
  static Future<void> open(BuildContext context, {String? name}) async {
    if (!context.read<AuthController>().isSignedIn) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
      if (!context.mounted || !context.read<AuthController>().isSignedIn) return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddTempleScreen(initialName: name)));
  }

  @override
  State<AddTempleScreen> createState() => _AddTempleScreenState();
}

class _AddTempleScreenState extends State<AddTempleScreen> {
  late final _api = context.read<ApiClient>();
  late final _suggestions = TempleSuggestionRepository(_api);
  late final _seva = SevaRepository(_api);

  late final _name = TextEditingController(text: widget.initialName);
  final _aka = TextEditingController();
  final _deity = TextEditingController();
  final _address = TextEditingController();
  final _pincode = TextEditingController();
  final _city = TextEditingController();
  final _district = TextEditingController();
  final _about = TextEditingController();
  final _history = TextEditingController();
  final _built = TextEditingController();
  final _festivals = TextEditingController();
  final _timingsNote = TextEditingController();
  final _phone = TextEditingController();
  final _website = TextEditingController();
  final _yourName = TextEditingController();
  final _yourPhone = TextEditingController();
  final _note = TextEditingController();

  String? _stateName;
  int? _stateId;
  List<String> _places = const [];
  String? _pinNote;
  bool _lookingUp = false;
  double? _lat;
  double? _lng;
  TimeOfDay? _opens;
  TimeOfDay? _closes;
  final List<String> _photos = [];
  String _role = 'devotee';
  List<String> _deityNames = const [];

  /// Temples already listed under a similar name — the commonest "missing"
  /// temple is one that is there under another spelling.
  List<TempleSummary>? _matches;
  bool _searching = false;

  int _step = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _yourName.text = context.read<AuthController>().devotee?.name ?? '';
    context.read<TempleRepository>().deities().then((r) {
      if (mounted) setState(() => _deityNames = r.data.map((d) => d.name).toList());
    }).catchError((_) {});
    if (_name.text.trim().length >= 3) _findMatches();
  }

  @override
  void dispose() {
    for (final c in [_name, _aka, _deity, _address, _pincode, _city, _district, _about, _history, _built, _festivals, _timingsNote, _phone, _website, _yourName, _yourPhone, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _findMatches() async {
    final q = _name.text.trim();
    if (q.length < 3) return;
    setState(() => _searching = true);
    try {
      final r = await context.read<TempleRepository>().temples(TempleQuery(q: q, perPage: 5));
      if (mounted && _name.text.trim() == q) setState(() => _matches = r.data.items);
    } catch (_) {
      if (mounted) setState(() => _matches = const []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _lookUpPincode(String code) async {
    setState(() {
      _lookingUp = true;
      _pinNote = null;
    });
    try {
      final info = await _seva.pincode(code);
      if (!mounted || _pincode.text != code) return;
      setState(() {
        if (info == null) {
          _pinNote = _lat == null
              ? 'No post office has that PIN code. Standing at the temple? Tap "I\'m here" and the address is read off the map.'
              : 'No post office has that PIN code. Check it, or fill in the rest yourself.';
          _places = const [];
          return;
        }
        _fillFrom(info, fromMap: false);
      });
    } on ApiException catch (e) {
      // 503: the directory could not be reached. That is not a verdict on
      // the code, and is said differently.
      if (mounted) setState(() => _pinNote = e.message);
    } catch (_) {
      if (mounted) setState(() => _pinNote = 'Could not look it up offline. Fill in the rest yourself.');
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  /// Fills the place fields from a PIN code lookup or the map. Never
  /// overwrites something the devotee typed themselves, except the state,
  /// which is only ever set this way.
  void _fillFrom(PincodeInfo info, {required bool fromMap}) {
    if (info.state != null) {
      _stateName = info.state;
      _stateId = info.stateId;
    }
    if (info.district != null && (_district.text.trim().isEmpty || !fromMap)) _district.text = info.district!;
    _places = info.places;
    if (info.city != null && _city.text.trim().isEmpty) {
      _city.text = info.city!;
    } else if (info.places.length == 1 && _city.text.trim().isEmpty) {
      _city.text = info.places.first;
    }
    if (fromMap) {
      if (info.pincode != null && _pincode.text.trim().isEmpty) _pincode.text = info.pincode!;
      if (info.address != null && _address.text.trim().isEmpty) _address.text = info.address!;
    }
    final place = [if (fromMap) info.city, info.district, info.state].whereType<String>().join(', ');
    _pinNote = fromMap ? 'From your location: $place' : place;
  }

  /// "I'm here": the pin, and the address read off the map for it, so the
  /// PIN code, village, district and state are filled without typing.
  Future<void> _pin() async {
    final loc = context.read<LocationController>();
    final ok = await loc.request();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not get your location. Type the address instead.')));
      return;
    }
    setState(() {
      _lat = loc.latitude;
      _lng = loc.longitude;
      _lookingUp = true;
    });
    try {
      final info = await _seva.reverseGeocode(_lat!, _lng!);
      if (!mounted) return;
      setState(() {
        if (info == null) {
          _pinNote = 'Pinned. The map has no address for this spot; fill in the rest yourself.';
        } else {
          _fillFrom(info, fromMap: true);
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _pinNote = 'Pinned. ${e.message}');
    } catch (_) {
      if (mounted) setState(() => _pinNote = 'Pinned. Could not read the address off the map offline; fill in the rest yourself.');
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  Future<void> _addPhotos({bool camera = false}) async {
    final picker = ImagePicker();
    final picked = camera ? [if (await picker.pickImage(source: ImageSource.camera, maxWidth: 2400, imageQuality: 85) case final x?) x] : await picker.pickMultiImage(maxWidth: 2400, imageQuality: 85);
    setState(() => _photos.addAll(picked.map((x) => x.path).take(8 - _photos.length)));
  }

  String? _problemWith(int step) {
    switch (step) {
      case 0:
        if (_name.text.trim().length < 3) return 'Enter the temple\'s name.';
      case 1:
        if (_city.text.trim().isEmpty) return 'Enter the village, town or city it is in.';
      case 2:
        if (_about.text.trim().length < 20) return 'Write a few lines about the temple — who it is for and what it is like.';
      case 4:
        if (_photos.isEmpty) return 'Add at least one photograph of the temple.';
        if (TempleSuggestionRepository.isTempleMember(_role) && _yourPhone.text.trim().length < 6) return 'Leave a phone number so the team can reach you about the temple.';
    }
    return null;
  }

  void _next() {
    final problem = _problemWith(_step);
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    if (_step < 4) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  String _hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    String? t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final fields = <String, String?>{
      'name': t(_name),
      'alternate_names': t(_aka),
      'deity_name': t(_deity),
      'address': t(_address),
      'pincode': t(_pincode),
      'city': t(_city),
      'district': t(_district),
      'state_id': _stateId?.toString(),
      'latitude': _lat?.toStringAsFixed(7),
      'longitude': _lng?.toStringAsFixed(7),
      'description': t(_about),
      'history': t(_history),
      'built_period': t(_built),
      'festivals': t(_festivals),
      'opens_at': _opens == null ? null : _hhmm(_opens!),
      'closes_at': _closes == null ? null : _hhmm(_closes!),
      'timings_note': t(_timingsNote),
      'contact_phone': t(_phone),
      'official_website': t(_website),
      'submitter_role': _role,
      'submitter_name': t(_yourName),
      'submitter_phone': t(_yourPhone),
      'submitter_note': t(_note),
    };
    setState(() => _saving = true);
    try {
      await _suggestions.submit({for (final e in fields.entries) if (e.value != null) e.key: e.value!}, _photos);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.temple_hindu_rounded, color: Palette.saffron, size: 40),
          title: const Text('Thank you'),
          content: Text(TempleSuggestionRepository.isTempleMember(_role)
              ? 'The team will check the details and may call you. Once it is listed, you are who we will hand the temple\'s own page to when the temple app opens.'
              : 'The team will check the details and add it. You can follow it under Profile → Temples I added.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException ? (e.errors.values.expand((v) => v).firstOrNull ?? e.message) : 'Could not reach the server. Your details are still here — try again when online.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add a temple')),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Stepper(
          currentStep: _step,
          onStepTapped: (i) => setState(() => _step = i),
          onStepContinue: _next,
          onStepCancel: _step == 0 ? null : () => setState(() => _step--),
          controlsBuilder: (context, details) => Padding(
            padding: const EdgeInsets.only(top: 16),
            // Wraps rather than overflowing on a narrow phone or large text.
            child: Wrap(
              spacing: 0,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton(
                  onPressed: details.onStepContinue,
                  style: FilledButton.styleFrom(backgroundColor: _step == 4 ? Palette.tulsi : null),
                  child: _saving && _step == 4 ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_step == 4 ? 'Send to the team' : 'Next'),
                ),
                const SizedBox(width: 8),
                if (details.onStepCancel != null) TextButton(onPressed: details.onStepCancel, child: const Text('Back')),
              ],
            ),
          ),
          steps: [
            Step(title: const Text('The temple'), subtitle: const Text('Check it is not listed already'), isActive: _step >= 0, state: _step > 0 ? StepState.complete : StepState.indexed, content: _nameStep()),
            Step(title: const Text('Where it is'), subtitle: const Text('PIN code or your location fills the rest'), isActive: _step >= 1, state: _step > 1 ? StepState.complete : StepState.indexed, content: _placeStep()),
            Step(title: const Text('About it'), subtitle: const Text('Deity, history, festivals'), isActive: _step >= 2, state: _step > 2 ? StepState.complete : StepState.indexed, content: _aboutStep()),
            Step(title: const Text('Timings & contact'), subtitle: const Text('Optional'), isActive: _step >= 3, state: _step > 3 ? StepState.complete : StepState.indexed, content: _timingsStep()),
            Step(title: const Text('Photos & you'), subtitle: const Text('At least one photograph'), isActive: _step >= 4, content: _photosStep()),
          ],
        ),
      ),
    );
  }

  Widget _nameStep() {
    final theme = Theme.of(context);
    final matches = _matches;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) => _findMatches(),
          onChanged: (_) => setState(() => _matches = null),
          decoration: InputDecoration(
            labelText: 'Temple name',
            hintText: 'Sri Someshwara Swamy Temple',
            prefixIcon: const Icon(Icons.temple_hindu_rounded),
            suffixIcon: _searching ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))) : IconButton(tooltip: 'Check', icon: const Icon(Icons.search_rounded), onPressed: _findMatches),
          ),
        ),
        const SizedBox(height: 10),
        TextField(controller: _aka, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Also known as (optional)', hintText: 'Other names people use for it')),
        if (matches == null && _name.text.trim().length >= 3)
          Padding(padding: const EdgeInsets.only(top: 10), child: TextButton.icon(onPressed: _findMatches, icon: const Icon(Icons.search_rounded), label: const Text('Check whether it is already listed'))),
        if (matches != null && matches.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Is it one of these?', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          for (final m in matches)
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                leading: const Icon(Icons.temple_hindu_rounded, color: Palette.saffron),
                title: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text([m.location.city, m.location.state].whereType<String>().join(', ')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TempleScreen(slug: m.slug, preview: m))),
              ),
            ),
          Text('None of these? Carry on and add it.', style: theme.textTheme.bodySmall),
        ] else if (matches != null)
          Padding(padding: const EdgeInsets.only(top: 10), child: SevaPill(text: 'Not listed yet — add it', color: Palette.tulsi, icon: Icons.check_circle_rounded)),
      ],
    );
  }

  Widget _placeStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _pincode,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (v) {
              if (v.length == 6) _lookUpPincode(v);
            },
            decoration: InputDecoration(
              labelText: 'PIN code',
              helperText: _pinNote ?? 'Fills in the state, district and town',
              helperMaxLines: 3,
              prefixIcon: const Icon(Icons.markunread_mailbox_rounded),
              suffixIcon: _lookingUp ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))) : null,
            ),
          ),
          if (_places.length > 1) ...[
            Text('Which village or town?', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final p in _places) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(p), selected: _city.text == p, onSelected: (_) => setState(() => _city.text = p))),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          TextField(controller: _city, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Village / town / city', prefixIcon: Icon(Icons.location_city_rounded))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextField(controller: _district, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'District'))),
              const SizedBox(width: 12),
              Expanded(child: InputDecorator(decoration: const InputDecoration(labelText: 'State'), child: Text(_stateName ?? 'From the PIN code', maxLines: 1, overflow: TextOverflow.ellipsis, style: _stateName == null ? TextStyle(color: Theme.of(context).hintColor) : null))),
            ],
          ),
          const SizedBox(height: 12),
          TextField(controller: _address, maxLines: 2, decoration: const InputDecoration(labelText: 'Street, landmark (optional)', prefixIcon: Icon(Icons.signpost_rounded))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text(_lat == null ? 'Standing at the temple? Tap "I\'m here": the pin helps others find it, and the address is filled in from the map.' : 'Pinned at ${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}', style: Theme.of(context).textTheme.bodySmall)),
              OutlinedButton.icon(onPressed: _lookingUp ? null : _pin, icon: Icon(_lat == null ? Icons.my_location_rounded : Icons.check_circle_rounded, color: _lat == null ? null : Palette.tulsi), label: Text(_lat == null ? "I'm here" : 'Pinned')),
            ],
          ),
        ],
      );

  Widget _aboutStep() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(controller: _deity, textCapitalization: TextCapitalization.words, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Main deity', hintText: 'Shiva, Venkateswara, Durga…', prefixIcon: Icon(Icons.auto_awesome_rounded))),
        if (_deityNames.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final d in _deityNames) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(d), selected: _deity.text == d, onSelected: (_) => setState(() => _deity.text = d))),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextField(controller: _about, maxLines: 4, maxLength: 5000, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'About the temple', hintText: 'What it is, who it is dedicated to, what a visitor will find', alignLabelWithHint: true)),
        TextField(controller: _history, maxLines: 3, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'History or legend (optional)', alignLabelWithHint: true)),
        const SizedBox(height: 12),
        TextField(controller: _built, decoration: const InputDecoration(labelText: 'How old is it? (optional)', hintText: 'About 800 years; rebuilt in 1952')),
        const SizedBox(height: 12),
        TextField(controller: _festivals, maxLines: 2, decoration: const InputDecoration(labelText: 'Festivals celebrated (optional)', hintText: 'Maha Shivaratri, Karthika Pournami')),
        const SizedBox(height: 6),
        Text('Write what you know; the team can fill in the rest.', style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _timingsStep() {
    Future<void> pick(bool opens) async {
      final t = await showTimePicker(context: context, initialTime: (opens ? _opens : _closes) ?? TimeOfDay(hour: opens ? 6 : 20, minute: 0));
      if (t != null) setState(() => opens ? _opens = t : _closes = t);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => pick(true), icon: const Icon(Icons.wb_sunny_outlined), label: Text(_opens == null ? 'Opens' : 'Opens ${_opens!.format(context)}'))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(onPressed: () => pick(false), icon: const Icon(Icons.nightlight_outlined), label: Text(_closes == null ? 'Closes' : 'Closes ${_closes!.format(context)}'))),
          ],
        ),
        const SizedBox(height: 12),
        TextField(controller: _timingsNote, decoration: const InputDecoration(labelText: 'Timings in words (optional)', hintText: 'Closed 12:30–4 pm; open all day on Mondays')),
        const SizedBox(height: 12),
        TextField(controller: _phone, keyboardType: TextInputType.phone, scrollPadding: const EdgeInsets.only(bottom: 160), decoration: const InputDecoration(labelText: 'Temple phone (optional)', prefixIcon: Icon(Icons.call_rounded))),
        const SizedBox(height: 12),
        TextField(controller: _website, keyboardType: TextInputType.url, scrollPadding: const EdgeInsets.only(bottom: 160), decoration: const InputDecoration(labelText: 'Website or social page (optional)', prefixIcon: Icon(Icons.public_rounded))),
      ],
    );
  }

  Widget _photosStep() {
    final theme = Theme.of(context);
    final member = TempleSuggestionRepository.isTempleMember(_role);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Photographs', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('The front, the gopuram or entrance, and the shrine if photography is allowed.', style: theme.textTheme.bodySmall),
        const SizedBox(height: 10),
        if (_photos.isNotEmpty)
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => Stack(
                children: [
                  ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 88, height: 88, child: localImage(_photos[i]))),
                  Positioned(top: 2, right: 2, child: InkWell(onTap: () => setState(() => _photos.removeAt(i)), child: const CircleAvatar(radius: 11, backgroundColor: Colors.black54, child: Icon(Icons.close_rounded, size: 14, color: Colors.white)))),
                ],
              ),
            ),
          ),
        if (_photos.isNotEmpty) const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(onPressed: _photos.length >= 8 ? null : _addPhotos, icon: const Icon(Icons.photo_library_rounded), label: Text(_photos.isEmpty ? 'Choose photos' : 'Add more (${_photos.length}/8)')),
            OutlinedButton.icon(onPressed: _photos.length >= 8 ? null : () => _addPhotos(camera: true), icon: const Icon(Icons.photo_camera_rounded), label: const Text('Camera')),
          ],
        ),
        const SizedBox(height: 20),
        Text('Who are you to this temple?', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final r in TempleSuggestionRepository.roles) ChoiceChip(label: Text(r.$2), selected: _role == r.$1, onSelected: (_) => setState(() => _role = r.$1)),
          ],
        ),
        if (member) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Palette.tulsi.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.admin_panel_settings_rounded, color: Palette.tulsi),
                const SizedBox(width: 10),
                Expanded(child: Text('Temple trusts will soon get their own app to manage their listing — timings, pujas, events. Leave your number and the team will contact you when it opens.', style: theme.textTheme.bodySmall)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextField(controller: _yourName, scrollPadding: const EdgeInsets.only(bottom: 160), textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Your name', prefixIcon: Icon(Icons.person_rounded))),
        const SizedBox(height: 12),
        TextField(controller: _yourPhone, scrollPadding: const EdgeInsets.only(bottom: 160), keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: member ? 'Your phone' : 'Your phone (optional)', helperText: 'Only the team sees this', prefixIcon: const Icon(Icons.call_rounded))),
        const SizedBox(height: 12),
        TextField(controller: _note, scrollPadding: const EdgeInsets.only(bottom: 160), maxLines: 2, decoration: const InputDecoration(labelText: 'Anything else for the team (optional)')),
      ],
    );
  }
}

/// The temples this devotee has added, and what the team did with each.
class MyAddedTemplesScreen extends StatefulWidget {
  const MyAddedTemplesScreen({super.key});

  @override
  State<MyAddedTemplesScreen> createState() => _MyAddedTemplesScreenState();
}

class _MyAddedTemplesScreenState extends State<MyAddedTemplesScreen> {
  late final _repo = TempleSuggestionRepository(context.read<ApiClient>());
  List<TempleSuggestionItem>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _repo.mine();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'Could not reach the server.');
    }
  }

  Color _color(String status) => switch (status) {
        'approved' => Palette.tulsi,
        'duplicate' => Palette.ash,
        'rejected' => Palette.kumkum,
        _ => Palette.gold,
      };

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Temples I added')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await AddTempleScreen.open(context);
          _load();
        },
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Add a temple'),
      ),
      body: items == null
          ? (_error == null ? const DiyaLoader() : EmptyShrine(motif: Motif.diya, message: _error!, action: OutlinedButton(onPressed: _load, child: const Text('Try again'))))
          : items.isEmpty
              ? EmptyShrine(motif: Motif.lotus, message: 'Know a temple that is not in the app? Add it — the team checks it and lists it for everyone.', action: FilledButton.icon(onPressed: () => AddTempleScreen.open(context).then((_) => _load()), icon: const Icon(Icons.add_location_alt_rounded), label: const Text('Add a temple')))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                    children: [
                      for (final s in items)
                        Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: const Icon(Icons.temple_hindu_rounded, color: Palette.saffron),
                            title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text([if (s.place != null && s.place!.isNotEmpty) s.place!, if (s.reviewNote != null) s.reviewNote!].join('\n')),
                            isThreeLine: s.reviewNote != null,
                            trailing: SevaPill(text: s.statusLabel, color: _color(s.status)),
                            onTap: s.templeSlug == null ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TempleScreen(slug: s.templeSlug!))),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
