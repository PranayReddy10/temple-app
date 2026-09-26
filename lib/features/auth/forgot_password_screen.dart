import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/l10n/strings.dart';
import '../../core/state/auth_controller.dart';
import 'auth_widgets.dart';

/// Forgot password: email → 6-digit code by email → new password.
///
/// Pops with `true` once the new password is set, which also signs the
/// devotee in, so the sign-in screen behind can close too.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.email = ''});

  final String email;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const _resendAfter = 60;

  final _emailForm = GlobalKey<FormState>();
  final _resetForm = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _codeSent = false;
  bool _sending = false;
  String? _error;
  Map<String, List<String>> _fieldErrors = const {};
  int _wait = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_email, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _wait = _resendAfter);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _wait--);
      if (_wait <= 0) t.cancel();
    });
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!_codeSent && !_emailForm.currentState!.validate()) return;
    final s = S.of(context);
    setState(() {
      _sending = true;
      _error = null;
      _fieldErrors = const {};
    });
    try {
      await context.read<AuthController>().forgotPassword(_email.text.trim());
      if (!mounted) return;
      setState(() => _codeSent = true);
      _startTimer();
    } catch (e) {
      if (mounted) setState(() => _error = authErrorText(s, e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _reset() async {
    FocusScope.of(context).unfocus();
    if (!_resetForm.currentState!.validate()) return;
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _error = null;
      _fieldErrors = const {};
    });
    try {
      await context.read<AuthController>().resetPassword(email: _email.text.trim(), code: _code.text.trim(), password: _password.text);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(s('reset_done'))));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _fieldErrors = e is ApiException ? e.errors : const {};
          // Shown under the code box instead, when that is what was wrong.
          _error = _fieldErrors.containsKey('code') ? null : authErrorText(s, e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final busy = context.watch<AuthController>().busy;
    return Scaffold(
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthHeader(title: s('reset_title'), subtitle: _codeSent ? s('reset_sent').replaceAll('{email}', _email.text.trim()) : s('reset_intro'), onBack: () => Navigator.of(context).maybePop()),
            Transform.translate(
              offset: const Offset(0, -32),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AuthCard(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: !_codeSent
                        ? Form(
                            key: _emailForm,
                            child: Column(
                              key: const ValueKey('email-step'),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  key: const Key('reset-email'),
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  autocorrect: false,
                                  autofillHints: const [AutofillHints.email],
                                  decoration: authInputDecoration(context, label: s('auth_email'), icon: Icons.mail_outline_rounded),
                                  validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v?.trim() ?? '') ? null : s('auth_email_invalid'),
                                  onFieldSubmitted: (_) => _send(),
                                ),
                                if (_error != null) AuthErrorBanner(_error!),
                                const SizedBox(height: 20),
                                AuthSubmitButton(label: s('reset_send'), busy: _sending, onPressed: _send),
                              ],
                            ),
                          )
                        : AutofillGroup(
                            child: Form(
                              key: _resetForm,
                              child: Column(
                                key: const ValueKey('code-step'),
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextFormField(
                                    key: const Key('reset-code'),
                                    controller: _code,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    inputFormatters: codeFormatters,
                                    autofillHints: const [AutofillHints.oneTimeCode],
                                    style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 10, fontWeight: FontWeight.w700),
                                    decoration: authInputDecoration(context, label: s('reset_code'), icon: Icons.pin_outlined, error: _fieldErrors['code']?.first),
                                    validator: (v) => (v ?? '').length == 6 ? null : s('reset_code_invalid'),
                                  ),
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    children: [
                                      TextButton(
                                        onPressed: () => setState(() {
                                          _codeSent = false;
                                          _error = null;
                                          _code.clear();
                                        }),
                                        child: Text(s('reset_change_email')),
                                      ),
                                      TextButton(
                                        key: const Key('reset-resend'),
                                        onPressed: _wait > 0 || _sending ? null : _send,
                                        child: Text(_wait > 0 ? s('reset_resend_in').replaceAll('{s}', '$_wait') : s('reset_resend')),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  PasswordField(
                                    key: const Key('reset-password'),
                                    controller: _password,
                                    label: s('auth_new_password'),
                                    newPassword: true,
                                    textInputAction: TextInputAction.next,
                                    onChanged: (_) => setState(() {}),
                                    validator: (v) => v == null || v.length < 8 ? s('auth_password_short') : null,
                                  ),
                                  PasswordStrengthBar(password: _password.text),
                                  const SizedBox(height: 14),
                                  PasswordField(
                                    key: const Key('reset-confirm'),
                                    controller: _confirm,
                                    label: s('auth_confirm_password'),
                                    newPassword: true,
                                    validator: (v) => v != _password.text ? s('auth_password_mismatch') : null,
                                    onSubmitted: (_) => _reset(),
                                  ),
                                  if (_error != null) AuthErrorBanner(_error!),
                                  const SizedBox(height: 20),
                                  AuthSubmitButton(label: s('reset_submit'), busy: busy, onPressed: _reset),
                                ],
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
