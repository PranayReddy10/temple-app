import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/brand.dart';
import '../../core/l10n/strings.dart';
import '../../core/motifs/architecture.dart';
import '../../core/motifs/motif.dart';
import '../../core/services/social_sign_in.dart';
import '../../core/state/app_config_controller.dart';
import '../../core/state/app_settings.dart';
import '../../core/state/auth_controller.dart';
import '../../core/state/favourites_controller.dart';
import '../../core/theme/palette.dart';

/// Sign in or register a devotee account.
///
/// One identifier field: the API accepts either email or phone, so the
/// devotee never has to say which kind of account this is first.
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
  final _password = TextEditingController();
  String? _error;
  Map<String, List<String>> _fieldErrors = const {};

  @override
  void dispose() {
    for (final c in [_name, _identifier, _email, _phone, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _error = null;
      _fieldErrors = const {};
    });
    final auth = context.read<AuthController>();
    try {
      if (_register) {
        await auth.register(name: _name.text.trim(), email: _email.text.trim(), phone: _phone.text.trim(), password: _password.text, locale: context.read<AppSettings>().locale.languageCode);
      } else {
        await auth.login(identifier: _identifier.text.trim(), password: _password.text);
      }
      if (!mounted) return;
      await context.read<FavouritesController>().mergeFromAccount();
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _fieldErrors = e.errors;
      });
    } catch (e) {
      setState(() => _error = 'Could not reach the server. Check the API server in Profile.');
    }
  }

  String? _fieldError(String key) => _fieldErrors[key]?.first;

  bool _showPasswordForm = false;

  Future<void> _social(Future<void> Function() signIn) async {
    setState(() {
      _error = null;
      _fieldErrors = const {};
    });
    try {
      await signIn();
      if (!mounted) return;
      await context.read<FavouritesController>().mergeFromAccount();
      if (mounted) Navigator.of(context).pop();
    } on SignInCancelled {
      // They closed the sheet: nothing to say.
    } on ApiException catch (e) {
      setState(() => _error = e.errors.values.expand((v) => v).firstOrNull ?? e.message);
    } catch (e) {
      setState(() => _error = 'Sign-in did not complete. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final busy = context.watch<AuthController>().busy;
    return Scaffold(
      appBar: AppBar(title: Text(_register ? s('create_account') : s('sign_in'))),
      body: Stack(
        children: [
          Positioned(left: 0, right: 0, bottom: 0, child: SizedBox(height: 160, child: CustomPaint(painter: GopuramPainter(color: theme.colorScheme.primary, opacity: 0.12, tiers: 6)))),
          ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: Palette.brass),
                  child: const MotifIcon(Motif.om, size: 40, color: Palette.deep),
                ),
              ),
              const SizedBox(height: 12),
              Text(Brand.name, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
              Text(_register ? 'Your passport, kept safe across devices.' : 'Welcome back, devotee.', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 24),
              Builder(builder: (context) {
                final config = context.watch<AppConfigController>().config;
                final auth = context.read<AuthController>();
                final google = SocialSignIn.googleAvailable(config);
                final apple = SocialSignIn.appleAvailable(config);
                if (!google && !apple) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Apple asks that its button is at least as prominent as
                    // any other social sign-in, so it comes first on iOS.
                    if (apple)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(50)),
                        onPressed: busy ? null : () => _social(() => SocialSignIn.apple(auth)),
                        icon: const Icon(Icons.apple, size: 24),
                        label: Text(s('continue_apple')),
                      ),
                    if (apple && google) const SizedBox(height: 10),
                    if (google)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: Colors.white, foregroundColor: const Color(0xFF1F1F1F)),
                        onPressed: busy ? null : () => _social(() => SocialSignIn.google(auth, config)),
                        icon: const Text('G', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF4285F4))),
                        label: Text(s('continue_google')),
                      ),
                    const SizedBox(height: 18),
                    if (config.passwordSignIn || _showPasswordForm) Row(children: [const Expanded(child: Divider()), Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(s('or'), style: theme.textTheme.labelMedium)), const Expanded(child: Divider())]) else TextButton(onPressed: () => setState(() => _showPasswordForm = true), child: Text(s('use_password'))),
                    if (!config.passwordSignIn && !_showPasswordForm && _error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.error))),
                    const SizedBox(height: 12),
                  ],
                );
              }),
              if (context.watch<AppConfigController>().config.passwordSignIn || _showPasswordForm || !(SocialSignIn.googleAvailable(context.watch<AppConfigController>().config) || SocialSignIn.appleAvailable(context.watch<AppConfigController>().config)))
                Form(
                  key: _form,
                  child: Column(
                    children: [
                      if (_register) ...[
                        TextFormField(controller: _name, decoration: InputDecoration(labelText: 'Name', errorText: _fieldError('name')), validator: (v) => v == null || v.trim().isEmpty ? 'Your name, please' : null),
                        const SizedBox(height: 12),
                        TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'Email', errorText: _fieldError('email'))),
                        const SizedBox(height: 12),
                        TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'Phone (optional)', errorText: _fieldError('phone'))),
                      ] else
                        TextFormField(controller: _identifier, decoration: InputDecoration(labelText: 'Email or phone', errorText: _fieldError('identifier')), validator: (v) => v == null || v.trim().isEmpty ? 'Enter your email or phone' : null),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        decoration: InputDecoration(labelText: 'Password', errorText: _fieldError('password')),
                        validator: (v) => v == null || v.length < 8 ? 'At least 8 characters' : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(onPressed: busy ? null : _submit, child: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_register ? s('create_account') : s('sign_in'))),
                      if (context.watch<AppConfigController>().config.passwordSignIn)
                        TextButton(
                          onPressed: () => setState(() {
                            _register = !_register;
                            _error = null;
                            _fieldErrors = const {};
                          }),
                          child: Text(_register ? 'Already have an account? Sign in' : 'New here? Create an account'),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
