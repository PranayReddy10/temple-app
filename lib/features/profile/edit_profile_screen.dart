import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/temple_repository.dart';
import '../../core/l10n/strings.dart';
import '../../core/models/models.dart';
import '../../core/motifs/architecture.dart';
import '../../core/state/app_settings.dart';
import '../../core/state/auth_controller.dart';
import '../../core/theme/palette.dart';

/// The complete devotee profile: photo, name, email, phone, home state, date
/// of birth and language, saved to `/api/v1/me`.
///
/// The photo stays on the device: the API has no avatar upload yet. When one
/// lands, this screen sends it and nothing else changes.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final AuthController _auth = context.read<AuthController>();
  late final TextEditingController _name = TextEditingController(text: _auth.devotee?.name);
  late final TextEditingController _email = TextEditingController(text: _auth.devotee?.email);
  late final TextEditingController _phone = TextEditingController(text: _auth.devotee?.phone);
  List<StateRef> _states = const [];
  StateRef? _homeState;
  DateTime? _dob;
  late String _locale = _auth.devotee?.locale ?? context.read<AppSettings>().locale.languageCode;
  String? _avatar;
  bool _saving = false;
  String? _error;
  Map<String, List<String>> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    _avatar = _auth.localAvatarPath;
    final dob = _auth.devotee?.dateOfBirth;
    if (dob != null) _dob = DateTime.tryParse(dob);
    context.read<TempleRepository>().states().then((r) {
      if (!mounted) return;
      setState(() {
        _states = r.data;
        _homeState = _states.where((s) => s.name == _auth.devotee?.homeState).firstOrNull;
      });
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800);
    if (x == null) return;
    setState(() => _avatar = x.path);
    await _auth.setLocalAvatar(x.path);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = const {};
    });
    try {
      await _auth.updateProfile(
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        locale: _locale,
        homeStateId: _homeState?.id,
        clearHomeState: _homeState == null && _auth.devotee?.homeState != null,
        dateOfBirth: _dob?.toIso8601String().substring(0, 10),
        clearDateOfBirth: _dob == null && _auth.devotee?.dateOfBirth != null,
      );
      if (!mounted) return;
      await context.read<AppSettings>().setLocale(Locale(_locale));
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _fieldErrors = e.errors;
      });
    } catch (_) {
      setState(() => _error = 'Could not reach the server. Your changes were not saved.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _err(String key) => _fieldErrors[key]?.first;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final canSetState = _states.isEmpty || _states.first.id != null;
    return Scaffold(
      appBar: AppBar(title: Text(s('edit_profile'))),
      body: Stack(
        children: [
          Positioned(left: 0, right: 0, bottom: 0, child: IgnorePointer(child: SizedBox(height: 140, child: CustomPaint(painter: GopuramPainter(color: theme.colorScheme.primary, opacity: 0.1, tiers: 6))))),
          Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
              children: [
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(shape: BoxShape.circle, gradient: Palette.brass, border: Border.all(color: Palette.gold, width: 3)),
                        child: ClipOval(
                          child: _avatar != null && !kIsWeb
                              ? Image.file(File(_avatar!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, size: 56, color: Palette.deep))
                              : const Icon(Icons.person_rounded, size: 56, color: Palette.deep),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: IconButton.filled(onPressed: _pickAvatar, icon: const Icon(Icons.photo_camera_rounded, size: 18), tooltip: s('change_photo')),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text('Your photo stays on this device for now.', textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                const SizedBox(height: 20),
                TextFormField(controller: _name, decoration: InputDecoration(labelText: s('name'), errorText: _err('name'), prefixIcon: const Icon(Icons.person_outline_rounded)), validator: (v) => v == null || v.trim().isEmpty ? 'Your name, please' : null),
                const SizedBox(height: 12),
                TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: s('email'), errorText: _err('email'), prefixIcon: const Icon(Icons.mail_outline_rounded))),
                const SizedBox(height: 12),
                TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: s('phone'), errorText: _err('phone'), helperText: 'Digits only, with country code if outside India', prefixIcon: const Icon(Icons.call_outlined))),
                const SizedBox(height: 12),
                DropdownButtonFormField<StateRef?>(
                  initialValue: _homeState,
                  decoration: InputDecoration(labelText: s('home_state'), errorText: _err('home_state_id'), prefixIcon: const Icon(Icons.map_outlined), helperText: canSetState ? null : 'Server does not accept a home state yet'),
                  items: [
                    const DropdownMenuItem<StateRef?>(value: null, child: Text('Not set')),
                    for (final st in _states) DropdownMenuItem<StateRef?>(value: st, child: Text(st.name)),
                  ],
                  onChanged: canSetState ? (v) => setState(() => _homeState = v) : null,
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: InputDecoration(labelText: s('date_of_birth'), errorText: _err('date_of_birth'), prefixIcon: const Icon(Icons.cake_outlined)),
                  child: Row(
                    children: [
                      Expanded(child: Text(_dob == null ? 'Not set' : '${_dob!.day}/${_dob!.month}/${_dob!.year}')),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(context: context, initialDate: _dob ?? DateTime(1990), firstDate: DateTime(1900), lastDate: DateTime.now().subtract(const Duration(days: 1)));
                          if (picked != null) setState(() => _dob = picked);
                        },
                        child: const Text('Choose'),
                      ),
                      if (_dob != null) IconButton(onPressed: () => setState(() => _dob = null), icon: const Icon(Icons.close_rounded, size: 18)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(s('language'), style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'en', label: Text('English')),
                    ButtonSegment(value: 'te', label: Text('తెలుగు')),
                    ButtonSegment(value: 'hi', label: Text('हिन्दी')),
                  ],
                  selected: {_locale},
                  onSelectionChanged: (v) => setState(() => _locale = v.first),
                ),
                if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: TextStyle(color: theme.colorScheme.error))],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_rounded),
                  label: Text(s('save')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
