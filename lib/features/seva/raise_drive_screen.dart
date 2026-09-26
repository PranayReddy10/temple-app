import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/seva_repository.dart';
import '../../core/models/seva.dart';
import '../../core/theme/palette.dart';
import 'seva_drive_screen.dart';
import 'seva_widgets.dart';

/// Raise a seva drive in four short steps — the place, what is wrong (with
/// photographs), the plan and the day, and optionally a UPI ID for later —
/// or edit one already raised.
///
/// Editing an approved drive changes only the arrangements: volunteers
/// signed up for the place and plan the team approved.
class RaiseDriveScreen extends StatefulWidget {
  const RaiseDriveScreen({super.key, this.existing, this.templeSlug, this.templeName});

  final SevaDrive? existing;

  /// When raised from a temple's own page.
  final String? templeSlug;
  final String? templeName;

  @override
  State<RaiseDriveScreen> createState() => _RaiseDriveScreenState();
}

class _RaiseDriveScreenState extends State<RaiseDriveScreen> {
  late final SevaRepository _repo = SevaRepository(context.read<ApiClient>());
  late final SevaDrive? _e = widget.existing;

  late final _title = TextEditingController(text: _e?.title);
  late final _place = TextEditingController(text: _e?.placeName ?? widget.templeName);
  late final _address = TextEditingController(text: _e?.address);
  late final _city = TextEditingController(text: _e?.city);
  late final _pincode = TextEditingController(text: _e?.pincode);
  late final _district = TextEditingController(text: _e?.district);

  /// From the PIN code: the state (sent as its id) and the towns to pick.
  late String? _stateName = _e?.state;
  int? _stateId;
  List<String> _places = const [];
  bool _lookingUp = false;
  String? _pinNote;
  late final _meeting = TextEditingController(text: _e?.meetingPoint);
  late final _problem = TextEditingController(text: _e?.problem);
  late final _plan = TextEditingController(text: _e?.plan);
  late final _bring = TextEditingController(text: _e?.whatToBring);
  late final _needed = TextEditingController(text: _e?.volunteersNeeded?.toString());
  late final _phone = TextEditingController(text: _e?.contactPhone);
  late final _upi = TextEditingController(text: _e?.myUpiId);
  late final _upiName = TextEditingController(text: _e?.myUpiName);
  late final _goal = TextEditingController(text: _e?.donations.goal?.toString());
  late final _purpose = TextEditingController(text: _e?.donations.purpose);
  final _videoLink = TextEditingController();

  late String _cause = _e?.cause.value ?? 'cleaning';
  late DateTime? _starts = _e?.startsAt;
  late DateTime? _ends = _e?.endsAt;
  late bool _multiDay = _e?.isMultiDay ?? false;
  late double? _lat = _e?.latitude;
  late double? _lng = _e?.longitude;
  final List<String> _photos = [];
  String? _video;

  int _step = 0;
  bool _saving = false;
  bool _locating = false;

  bool get _editing => _e != null;

  /// An approved drive keeps its place, cause and plan.
  bool get _locked => _e?.isOpen == true;

  @override
  void dispose() {
    for (final c in [_title, _place, _address, _city, _pincode, _district, _meeting, _problem, _plan, _bring, _needed, _phone, _upi, _upiName, _goal, _purpose, _videoLink]) {
      c.dispose();
    }
    super.dispose();
  }

  // --- Checking each step before moving on ---

  String? _problemWithStep(int step) {
    switch (step) {
      case 0:
        if (_place.text.trim().isEmpty) return 'Name the place — the temple, tank or shrine.';
        if (_title.text.trim().length < 8) return 'Give the drive a title of at least a few words.';
      case 1:
        if (_problem.text.trim().length < 20) return 'Describe what is wrong with the place in a sentence or two.';
        if (!_editing && _photos.isEmpty && _video == null && _videoLink.text.trim().isEmpty) return 'Add at least one photograph of the place as it is now.';
      case 2:
        if (_plan.text.trim().length < 20) return 'Describe what you will do on the day.';
        if (_starts == null) return 'Choose the day and time.';
        if (!_locked && _starts!.isBefore(DateTime.now())) return 'The day has to be in the future.';
        if (_ends != null && !_ends!.isAfter(_starts!)) return 'The end has to be after the start.';
        if (_multiDay && _ends == null) return 'Choose the last day of the drive, or switch to One day.';
        if (_multiDay && DateTime(_ends!.year, _ends!.month, _ends!.day) == DateTime(_starts!.year, _starts!.month, _starts!.day)) return 'Several days needs a last day after the first — or switch to One day.';
      case 3:
        final upi = _upi.text.trim();
        if (upi.isNotEmpty && !RegExp(r'^[A-Za-z0-9.\-_]{2,256}@[A-Za-z]{2,64}$').hasMatch(upi)) return 'That does not look like a UPI ID. It is written like name@bank.';
    }
    return null;
  }

  void _next() {
    final problem = _problemWithStep(_step);
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    if (_step < 3) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  Map<String, String> _fields() {
    String? t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final all = <String, String?>{
      'title': t(_title),
      'cause': _cause,
      'place_name': t(_place),
      'address': t(_address),
      'city': t(_city),
      'pincode': t(_pincode),
      'district': t(_district),
      'state_id': _stateId?.toString(),
      'meeting_point': t(_meeting),
      'problem': t(_problem),
      'plan': t(_plan),
      'what_to_bring': t(_bring),
      'starts_at': _starts?.toUtc().toIso8601String(),
      'ends_at': _ends?.toUtc().toIso8601String(),
      'volunteers_needed': t(_needed),
      'contact_phone': t(_phone),
      'upi_id': t(_upi),
      'upi_name': t(_upiName),
      'donation_goal': t(_goal),
      'donation_purpose': t(_purpose),
      'latitude': _lat?.toStringAsFixed(7),
      'longitude': _lng?.toStringAsFixed(7),
      if (!_editing && widget.templeSlug != null) 'temple': widget.templeSlug,
    };
    const logistics = {'meeting_point', 'what_to_bring', 'ends_at', 'volunteers_needed', 'contact_phone', 'upi_id', 'upi_name', 'donation_goal', 'donation_purpose'};
    return {
      for (final e in all.entries)
        if (e.value != null && (!_locked || logistics.contains(e.key))) e.key: e.value!,
    };
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final SevaDrive drive;
      if (_editing) {
        drive = await _repo.update(_e!.id, _fields());
      } else {
        drive = await _repo.create(_fields(), SevaUpload(photos: _photos, videoPath: _video, videoUrl: _videoLink.text.trim()));
      }
      if (!mounted) return;
      if (!_editing) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.hourglass_top_rounded, color: Palette.gold, size: 40),
            title: const Text('Sent for review'),
            content: const Text('The team checks every drive before it is listed. You will see it under Mine meanwhile, and can add more photographs there.'),
            actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
          ),
        );
      }
      if (mounted) Navigator.of(context).pop(drive);
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? (e.errors.values.expand((v) => v).firstOrNull ?? e.message) : 'Could not reach the server. Your drive is still here — try again when online.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _lookUpPincode(String code) async {
    setState(() {
      _lookingUp = true;
      _pinNote = null;
    });
    try {
      final info = await _repo.pincode(code);
      if (!mounted || _pincode.text != code) return;
      setState(() {
        if (info == null) {
          _pinNote = 'No post office has that PIN code. Check it, or fill in the rest yourself.';
          _places = const [];
          return;
        }
        _stateName = info.state;
        _stateId = info.stateId;
        if (info.district != null) _district.text = info.district!;
        _places = info.places;
        // One town under this code: that is the town.
        if (info.places.length == 1) _city.text = info.places.first;
        _pinNote = [info.district, info.state].whereType<String>().join(', ');
      });
    } catch (_) {
      if (mounted) setState(() => _pinNote = 'Could not look it up offline. Fill in the rest yourself.');
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) throw Exception();
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not get your location. Type the address instead.')));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<DateTime?> _pickDateTime(DateTime? current, {DateTime? after}) async {
    final base = current ?? after ?? DateTime.now().add(const Duration(days: 3));
    final date = await showDatePicker(context: context, initialDate: base, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (date == null || !mounted) return null;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(current ?? DateTime(base.year, base.month, base.day, 7)));
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? (_locked ? 'Change arrangements' : 'Edit drive') : 'Raise a seva drive')),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Stepper(
          currentStep: _step,
          onStepTapped: (i) => setState(() => _step = i),
          onStepContinue: _next,
          onStepCancel: _step == 0 ? null : () => setState(() => _step--),
          controlsBuilder: (context, details) => Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                FilledButton(
                  onPressed: details.onStepContinue,
                  style: FilledButton.styleFrom(backgroundColor: _step == 3 ? Palette.tulsi : null),
                  child: _saving && _step == 3
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_step == 3 ? (_editing ? 'Save' : 'Send for review') : 'Next'),
                ),
                const SizedBox(width: 8),
                if (details.onStepCancel != null) TextButton(onPressed: details.onStepCancel, child: const Text('Back')),
              ],
            ),
          ),
          steps: [
            Step(
              title: const Text('The place'),
              subtitle: const Text('Which temple or heritage place needs care'),
              isActive: _step >= 0,
              state: _step > 0 ? StepState.complete : StepState.indexed,
              content: _placeStep(),
            ),
            Step(
              title: const Text('What is wrong'),
              subtitle: const Text('The cause, and photographs as it is now'),
              isActive: _step >= 1,
              state: _step > 1 ? StepState.complete : StepState.indexed,
              content: _problemStep(),
            ),
            Step(
              title: const Text('The plan & the day'),
              subtitle: const Text('What will be done, when, and how many hands'),
              isActive: _step >= 2,
              state: _step > 2 ? StepState.complete : StepState.indexed,
              content: _planStep(),
            ),
            Step(
              title: const Text('Contact & donations'),
              subtitle: const Text('Optional — shown only after the work is verified'),
              isActive: _step >= 3,
              content: _donationStep(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeStep() => Column(
        children: [
          if (_locked) const _LockedNote(),
          TextField(controller: _place, enabled: !_locked, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Place name', hintText: 'Old Someshwara temple, Kolanupaka', prefixIcon: Icon(Icons.temple_hindu_rounded))),
          const SizedBox(height: 12),
          TextField(controller: _title, enabled: !_locked, maxLength: 120, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Drive title', hintText: 'Clean the old Shiva temple steps and mandapam')),
          const SizedBox(height: 4),
          TextField(controller: _address, enabled: !_locked, decoration: const InputDecoration(labelText: 'Address or landmark (optional)', prefixIcon: Icon(Icons.signpost_rounded))),
          const SizedBox(height: 12),
          TextField(
            controller: _pincode,
            enabled: !_locked,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (v) {
              if (v.length == 6) _lookUpPincode(v);
            },
            decoration: InputDecoration(
              labelText: 'PIN code',
              helperText: _pinNote ?? 'Fills in the state, district and town',
              prefixIcon: const Icon(Icons.markunread_mailbox_rounded),
              suffixIcon: _lookingUp ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))) : (_stateName != null && _pincode.text.length == 6 ? const Icon(Icons.check_circle_rounded, color: Palette.tulsi) : null),
            ),
          ),
          if (_places.length > 1) ...[
            Align(alignment: Alignment.centerLeft, child: Text('Which village or town?', style: Theme.of(context).textTheme.labelLarge)),
            const SizedBox(height: 6),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final p in _places)
                    Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(p), selected: _city.text == p, onSelected: (_) => setState(() => _city.text = p))),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          TextField(controller: _city, enabled: !_locked, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Village / town / city', prefixIcon: Icon(Icons.location_city_rounded))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextField(controller: _district, enabled: !_locked, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'District'))),
              const SizedBox(width: 12),
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'State'),
                  child: Text(_stateName ?? 'From the PIN code', maxLines: 1, overflow: TextOverflow.ellipsis, style: _stateName == null ? TextStyle(color: Theme.of(context).hintColor) : null),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _lat == null ? 'Drop a pin so volunteers can find it.' : 'Pinned at ${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _locked || _locating ? null : _locate,
                icon: _locating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(_lat == null ? Icons.my_location_rounded : Icons.check_circle_rounded, color: _lat == null ? null : Palette.tulsi),
                label: Text(_lat == null ? "I'm here now" : 'Pinned'),
              ),
            ],
          ),
          if (widget.templeName != null) Padding(padding: const EdgeInsets.only(top: 8), child: SevaPill(text: 'Linked to ${widget.templeName}', color: Palette.kumkum, icon: Icons.link_rounded)),
        ],
      );

  Widget _problemStep() {
    final theme = Theme.of(context);
    final cause = SevaCause.of(_cause);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What kind of seva?', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in SevaCause.all)
              ChoiceChip(
                avatar: Icon(sevaCauseIcon(c.value), size: 16),
                label: Text(c.label),
                selected: _cause == c.value,
                onSelected: _locked ? null : (_) => setState(() => _cause = c.value),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(cause.description, style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        TextField(controller: _problem, enabled: !_locked, maxLines: 4, maxLength: 3000, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'What is wrong with the place now?', hintText: 'Weeds have covered the steps, the tank is full of plastic, the shrine has no light…', alignLabelWithHint: true)),
        if (!_editing) ...[
          const SizedBox(height: 8),
          Text('Photographs of the place as it is', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text('These become the "before". The team uses them to approve the drive, and to verify it afterwards.', style: theme.textTheme.bodySmall),
          const SizedBox(height: 10),
          SevaMediaPicker(photos: _photos, video: _video, link: _videoLink, onChanged: (p, v) => setState(() => _video = v)),
        ] else
          Text('Add or change photographs from the drive page.', style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _planStep() {
    final theme = Theme.of(context);
    final fmt = DateFormat('EEE d MMM yyyy, h:mm a');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(controller: _plan, enabled: !_locked, maxLines: 4, maxLength: 3000, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'What will you do on the day?', hintText: 'Clear the weeds, sweep the mandapam, bag and carry away the litter, wash the steps.', alignLabelWithHint: true)),
        const SizedBox(height: 4),
        Text('How long is it?', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, icon: Icon(Icons.event_rounded), label: Text('One day')),
            ButtonSegment(value: true, icon: Icon(Icons.date_range_rounded), label: Text('Several days')),
          ],
          selected: {_multiDay},
          onSelectionChanged: (v) => setState(() {
            _multiDay = v.first;
            // Switching back to one day keeps only the end time, on that day.
            if (!_multiDay && _ends != null && _starts != null) _ends = DateTime(_starts!.year, _starts!.month, _starts!.day, _ends!.hour, _ends!.minute);
            if (_multiDay && _ends != null && _starts != null && !_ends!.isAfter(DateTime(_starts!.year, _starts!.month, _starts!.day, 23, 59))) _ends = null;
          }),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          enabled: !_locked,
          leading: const Icon(Icons.play_circle_outline_rounded, color: Palette.saffron),
          title: Text(_starts == null ? (_multiDay ? 'Choose the first day and start time' : 'Choose the day and start time') : fmt.format(_starts!)),
          subtitle: Text(_multiDay ? 'From' : 'Day and start time'),
          trailing: const Icon(Icons.edit_calendar_rounded),
          onTap: () async {
            final d = await _pickDateTime(_starts);
            if (d == null) return;
            setState(() {
              _starts = d;
              // A one-day end time follows the day it belongs to.
              if (!_multiDay && _ends != null) _ends = DateTime(d.year, d.month, d.day, _ends!.hour, _ends!.minute);
            });
          },
        ),
        if (_multiDay)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.stop_circle_outlined, color: Palette.ash),
            title: Text(_ends == null ? 'Choose the last day and end time' : fmt.format(_ends!)),
            subtitle: const Text('To'),
            trailing: const Icon(Icons.edit_calendar_rounded),
            onTap: () async {
              final d = await _pickDateTime(_ends, after: _starts?.add(const Duration(days: 1)));
              if (d != null) setState(() => _ends = d);
            },
          )
        else
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.stop_circle_outlined, color: Palette.ash),
            title: Text(_ends == null ? 'Add the time it ends (optional)' : 'Ends at ${DateFormat('h:mm a').format(_ends!)}'),
            subtitle: const Text('Same day'),
            trailing: _ends == null ? const Icon(Icons.add_rounded) : IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () => setState(() => _ends = null)),
            onTap: _starts == null
                ? null
                : () async {
                    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_ends ?? _starts!.add(const Duration(hours: 4))));
                    if (t != null) setState(() => _ends = DateTime(_starts!.year, _starts!.month, _starts!.day, t.hour, t.minute));
                  },
          ),
        if (_starts != null && (_ends != null))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: SevaPill(
              text: _multiDay
                  ? '${DateFormat('d MMM').format(_starts!)} → ${DateFormat('d MMM').format(_ends!)} · ${DateTime(_ends!.year, _ends!.month, _ends!.day).difference(DateTime(_starts!.year, _starts!.month, _starts!.day)).inDays + 1} days'
                  : '${DateFormat('EEE d MMM').format(_starts!)} · ${DateFormat('h:mm a').format(_starts!)} – ${DateFormat('h:mm a').format(_ends!)}',
              color: Palette.saffron,
              icon: Icons.schedule_rounded,
            ),
          ),
        const SizedBox(height: 8),
        TextField(controller: _meeting, decoration: const InputDecoration(labelText: 'Meeting point (optional)', hintText: 'Under the banyan tree by the east gate', prefixIcon: Icon(Icons.flag_circle_rounded))),
        const SizedBox(height: 12),
        TextField(controller: _needed, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Volunteers needed (optional)', prefixIcon: Icon(Icons.groups_rounded))),
        const SizedBox(height: 12),
        TextField(controller: _bring, decoration: const InputDecoration(labelText: 'What should volunteers bring?', hintText: 'Gloves, broom, water bottle, sacks', helperText: 'Separate with commas', prefixIcon: Icon(Icons.backpack_rounded))),
        const SizedBox(height: 8),
        Text('Stay safe: go with permission from the temple or the local body, and never alter carvings or inscriptions.', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
      ],
    );
  }

  Widget _donationStep() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Your phone (optional)', helperText: 'Shown only to volunteers who join', prefixIcon: Icon(Icons.call_rounded))),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Palette.tulsi.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_rounded, color: Palette.tulsi),
              const SizedBox(width: 10),
              Expanded(child: Text('Your UPI ID stays hidden until the drive is done and the team has verified the before and after photographs. Then a Donate button and a UPI QR appear on the drive.', style: theme.textTheme.bodySmall)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(controller: _upi, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'UPI ID (optional)', hintText: 'yourname@okaxis', prefixIcon: Icon(Icons.account_balance_wallet_rounded))),
        const SizedBox(height: 12),
        TextField(controller: _upiName, decoration: const InputDecoration(labelText: 'Name on the UPI account', prefixIcon: Icon(Icons.badge_rounded))),
        const SizedBox(height: 12),
        TextField(controller: _goal, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Donation goal (optional)', prefixText: '₹ ')),
        const SizedBox(height: 12),
        TextField(controller: _purpose, decoration: const InputDecoration(labelText: 'What donations will pay for', hintText: 'Lamps and oil for a year, lime for the next whitewash')),
      ],
    );
  }
}

class _LockedNote extends StatelessWidget {
  const _LockedNote();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Palette.gold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
        child: Text('This drive is approved and volunteers have signed up for this place and plan, so only the arrangements can change now.', style: Theme.of(context).textTheme.bodySmall),
      );
}
