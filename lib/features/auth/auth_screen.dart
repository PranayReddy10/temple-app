import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/l10n/strings.dart';
import '../../core/services/social_sign_in.dart';
import '../../core/state/app_config_controller.dart';
import '../../core/state/app_settings.dart';
import '../../core/state/auth_controller.dart';
import '../../core/state/favourites_controller.dart';
import '../../core/theme/palette.dart';
import 'auth_widgets.dart';
import 'forgot_password_screen.dart';

/// Sign in or register a devotee account.
///
/// One identifier field for signing in: the API accepts either email or phone,
/// so the devotee never has to say which kind of account this is first.
///
/// Each mode has its own password boxes, cleared on every switch, so a
/// password typed (or filled in by the phone) for signing in never turns up
/// in "Create account".
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.register = false});

  final bool register;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool _register = widget.register;
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _identifier = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _signInPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  String? _error;
  Map<String, List<String>> _fieldErrors = const {};
  bool _showPasswordForm = false;

  @override
  void initState() {
    super.initState();
    // The admin may have just switched Google on: ask again rather than use
    // what the app was told at launch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppConfigController>().load();
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _identifier, _email, _phone, _signInPassword, _newPassword, _confirmPassword]) {
      c.dispose();
    }
    super.dispose();
  }

  void _switchMode(bool register) {
    if (register == _register) return;
    setState(() {
      _register = register;
      _error = null;
      _fieldErrors = const {};
      _signInPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      _form.currentState?.reset();
    });
  }

  Future<void> _finish() async {
    // Merging saved temples is a nicety; a hiccup there must not leave the
    // devotee staring at a form for an account that was already created.
    try {
      await context.read<FavouritesController>().mergeFromAccount();
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() {
      _error = null;
      _fieldErrors = const {};
    });
    final auth = context.read<AuthController>();
    final s = S.of(context);
    try {
      if (_register) {
        await auth.register(name: _name.text.trim(), email: _email.text.trim(), phone: _phone.text.trim(), password: _newPassword.text, locale: context.read<AppSettings>().locale.languageCode);
      } else {
        await auth.login(identifier: _identifier.text.trim(), password: _signInPassword.text);
      }
      if (!mounted) return;
      TextInput.finishAutofillContext();
      await _finish();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = authErrorText(s, e);
        _fieldErrors = e is ApiException ? e.errors : const {};
      });
    }
  }

  String? _fieldError(String key) => _fieldErrors[key]?.first;

  Future<void> _social(Future<void> Function() signIn) async {
    setState(() {
      _error = null;
      _fieldErrors = const {};
    });
    final s = S.of(context);
    try {
      await signIn();
      if (!mounted) return;
      await _finish();
    } on SignInCancelled {
      // They closed the sheet: nothing to say.
    } catch (e) {
      if (mounted) setState(() => _error = authErrorText(s, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final busy = context.watch<AuthController>().busy;
    final config = context.watch<AppConfigController>().config;
    final google = SocialSignIn.googleAvailable(config);
    final apple = SocialSignIn.appleAvailable(config);
    final social = google || apple;
    final showForm = config.passwordSignIn || _showPasswordForm || !social;
    final auth = context.read<AuthController>();

    return Scaffold(
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthHeader(
              title: _register ? s('auth_join') : s('auth_welcome_back'),
              subtitle: _register ? s('auth_join_sub') : s('auth_welcome_sub'),
              onBack: Navigator.of(context).canPop() ? () => Navigator.of(context).maybePop() : null,
            ),
            Transform.translate(
              offset: const Offset(0, -32),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AuthCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (config.passwordSignIn) ...[
                        SegmentedButton<bool>(
                          key: const Key('auth-mode'),
                          showSelectedIcon: false,
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: theme.colorScheme.primary,
                            selectedForegroundColor: theme.colorScheme.onPrimary,
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          segments: [
                            ButtonSegment(value: false, label: Text(s('sign_in')), icon: const Icon(Icons.login_rounded, size: 18)),
                            ButtonSegment(value: true, label: Text(s('create_account')), icon: const Icon(Icons.person_add_alt_rounded, size: 18)),
                          ],
                          selected: {_register},
                          onSelectionChanged: busy ? null : (v) => _switchMode(v.first),
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (social) ...[
                        // Apple asks that its button is at least as prominent
                        // as any other social sign-in, so it comes first on iOS.
                        if (apple)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                            onPressed: busy ? null : () => _social(() => SocialSignIn.apple(auth)),
                            icon: const Icon(Icons.apple, size: 24),
                            label: Text(s('continue_apple')),
                          ),
                        if (apple && google) const SizedBox(height: 10),
                        if (google)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF1F1F1F),
                              side: const BorderSide(color: Color(0xFFDADCE0)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: busy ? null : () => _social(() => SocialSignIn.google(auth, config)),
                            icon: const _GoogleMark(),
                            label: Text(s('continue_google')),
                          ),
                        const SizedBox(height: 16),
                        if (showForm)
                          Row(children: [
                            const Expanded(child: Divider()),
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(s('or'), style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
                            const Expanded(child: Divider()),
                          ])
                        else
                          TextButton(onPressed: () => setState(() => _showPasswordForm = true), child: Text(s('use_password'))),
                        const SizedBox(height: 12),
                      ],
                      if (showForm) _buildForm(context, busy, config.passwordReset),
                      if (!showForm && _error != null) AuthErrorBanner(_error!),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(s('auth_terms'), textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, bool busy, bool canReset) {
    final s = S.of(context);
    return AutofillGroup(
      // A new group per mode, so the phone treats them as different forms.
      key: ValueKey(_register),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _register ? _registerFields(context) : _signInFields(context, canReset),
            ),
            if (_error != null) AuthErrorBanner(_error!),
            const SizedBox(height: 20),
            AuthSubmitButton(label: _register ? s('create_account') : s('sign_in'), busy: busy, onPressed: _submit),
          ],
        ),
      ),
    );
  }

  Widget _signInFields(BuildContext context, bool canReset) {
    final s = S.of(context);
    return Column(
      key: const ValueKey('sign-in-fields'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: const Key('auth-identifier'),
          controller: _identifier,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          autofillHints: const [AutofillHints.username, AutofillHints.email, AutofillHints.telephoneNumber],
          decoration: authInputDecoration(context, label: s('auth_identifier'), icon: Icons.alternate_email_rounded, error: _fieldError('identifier')),
          validator: (v) => v == null || v.trim().isEmpty ? s('auth_identifier_required') : null,
        ),
        const SizedBox(height: 14),
        PasswordField(
          key: const Key('auth-password'),
          controller: _signInPassword,
          label: s('auth_password'),
          error: _fieldError('password'),
          validator: (v) => v == null || v.isEmpty ? s('auth_password_short') : null,
          onSubmitted: (_) => _submit(),
        ),
        if (canReset)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('auth-forgot'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ForgotPasswordScreen(email: _identifier.text.contains('@') ? _identifier.text.trim() : ''))).then((signedIn) {
                if (signedIn == true && mounted) _finish();
              }),
              child: Text(s('auth_forgot')),
            ),
          ),
      ],
    );
  }

  Widget _registerFields(BuildContext context) {
    final s = S.of(context);
    return Column(
      key: const ValueKey('register-fields'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: const Key('auth-name'),
          controller: _name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          decoration: authInputDecoration(context, label: s('auth_name'), icon: Icons.person_outline_rounded, error: _fieldError('name')),
          validator: (v) => v == null || v.trim().isEmpty ? s('auth_name_required') : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          key: const Key('auth-email'),
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          decoration: authInputDecoration(context, label: s('auth_email'), icon: Icons.mail_outline_rounded, error: _fieldError('email'), helper: s('auth_email_hint')),
          validator: (v) {
            final t = v?.trim() ?? '';
            if (t.isEmpty) return _phone.text.trim().isEmpty ? s('auth_need_contact') : null;
            return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t) ? null : s('auth_email_invalid');
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          key: const Key('auth-phone'),
          controller: _phone,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.telephoneNumber],
          decoration: authInputDecoration(context, label: s('auth_phone_optional'), icon: Icons.phone_outlined, error: _fieldError('phone')),
        ),
        const SizedBox(height: 14),
        PasswordField(
          key: const Key('auth-new-password'),
          controller: _newPassword,
          label: s('auth_password'),
          newPassword: true,
          textInputAction: TextInputAction.next,
          error: _fieldError('password'),
          onChanged: (_) => setState(() {}),
          validator: (v) => v == null || v.length < 8 ? s('auth_password_short') : null,
        ),
        PasswordStrengthBar(password: _newPassword.text),
        const SizedBox(height: 14),
        PasswordField(
          key: const Key('auth-confirm-password'),
          controller: _confirmPassword,
          label: s('auth_confirm_password'),
          newPassword: true,
          validator: (v) => v != _newPassword.text ? s('auth_password_mismatch') : null,
          onSubmitted: (_) => _submit(),
        ),
      ],
    );
  }
}

/// Google's four-colour G, drawn rather than shipped as an asset.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) => ShaderMask(
        shaderCallback: (r) => const SweepGradient(colors: [Color(0xFFEA4335), Color(0xFFFBBC05), Color(0xFF34A853), Color(0xFF4285F4), Color(0xFFEA4335)]).createShader(r),
        child: const Text('G', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Palette.ivory)),
      );
}
