import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/api_client.dart';
import '../../core/brand.dart';
import '../../core/l10n/strings.dart';
import '../../core/motifs/architecture.dart';
import '../../core/motifs/motif.dart';
import '../../core/theme/palette.dart';

/// Words for a failed sign-in, register or reset.
///
/// A 429 gets its own sentence: the server's "Too Many Attempts." reads like
/// the account is locked, when all it means is "wait a minute".
String authErrorText(S s, Object error) {
  if (error is ApiException) {
    if (error.statusCode == 429) return s('auth_too_many');
    final first = error.errors.values.expand((v) => v).firstOrNull;
    return first ?? error.message;
  }
  return s('auth_offline');
}

/// The maroon header with the brass om, the brand and a line under it.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.title, required this.subtitle, this.onBack});

  final String title;
  final String subtitle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 8, 20, 56),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF7A1628), Color(0xFF4A0D18)]),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: Opacity(opacity: 0.08, child: CustomPaint(painter: LatticePainter(color: Palette.gold, cell: 26)))),
          const Positioned(right: -10, bottom: -56, child: SizedBox(width: 150, height: 150, child: CustomPaint(painter: GopuramPainter(color: Palette.gold, opacity: 0.16, tiers: 5)))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 44,
                child: onBack == null
                    ? null
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: onBack,
                          icon: const Icon(Icons.arrow_back_rounded, color: Palette.sandal),
                          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                        ),
                      ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(shape: BoxShape.circle, gradient: Palette.brass, boxShadow: [BoxShadow(color: Palette.gold.withValues(alpha: 0.4), blurRadius: 16)]),
                    child: const MotifIcon(Motif.om, size: 28, color: Palette.deep),
                  ),
                  const SizedBox(width: 12),
                  Flexible(child: Text(Brand.name.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge?.copyWith(color: Palette.gold, letterSpacing: 2.5, fontWeight: FontWeight.w600))),
                ],
              ),
              const SizedBox(height: 20),
              Text(title, style: theme.textTheme.headlineMedium?.copyWith(color: Palette.sandal, fontFamily: 'NotoSerif', fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: Palette.sandal.withValues(alpha: 0.82))),
            ],
          ),
        ],
      ),
    );
  }
}

/// The white card the form sits in, lifted over the header's edge.
class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: child,
    );
  }
}

InputDecoration authInputDecoration(BuildContext context, {required String label, required IconData icon, String? error, String? helper, Widget? suffix}) {
  final theme = Theme.of(context);
  final radius = BorderRadius.circular(16);
  return InputDecoration(
    labelText: label,
    errorText: error,
    helperText: helper,
    helperMaxLines: 2,
    errorMaxLines: 3,
    prefixIcon: Icon(icon, size: 22),
    suffixIcon: suffix,
    filled: true,
    fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
    border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6))),
    focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.6)),
    errorBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: theme.colorScheme.error)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: theme.colorScheme.error, width: 1.6)),
  );
}

/// A password box with a show/hide eye.
///
/// [newPassword] tells the system's password manager this is a new password,
/// so it offers to create one instead of filling in a saved one.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.newPassword = false,
    this.error,
    this.validator,
    this.onSubmitted,
    this.onChanged,
    this.textInputAction = TextInputAction.done,
  });

  final TextEditingController controller;
  final String label;
  final bool newPassword;
  final String? error;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final TextInputAction textInputAction;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _hidden,
      enableSuggestions: false,
      autocorrect: false,
      textInputAction: widget.textInputAction,
      autofillHints: [widget.newPassword ? AutofillHints.newPassword : AutofillHints.password],
      decoration: authInputDecoration(
        context,
        label: widget.label,
        icon: Icons.lock_outline_rounded,
        error: widget.error,
        suffix: IconButton(
          icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _hidden = !_hidden),
        ),
      ),
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
    );
  }
}

/// 0 = empty, 1 weak, 2 good, 3 strong: length plus variety.
int passwordStrength(String p) {
  if (p.isEmpty) return 0;
  if (p.length < 8) return 1;
  var kinds = 0;
  for (final r in [RegExp('[a-z]'), RegExp('[A-Z]'), RegExp('[0-9]'), RegExp(r'[^A-Za-z0-9]')]) {
    if (r.hasMatch(p)) kinds++;
  }
  if (p.length >= 12 && kinds >= 3) return 3;
  return kinds >= 2 ? 2 : 1;
}

class PasswordStrengthBar extends StatelessWidget {
  const PasswordStrengthBar({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final level = passwordStrength(password);
    if (level == 0) return const SizedBox.shrink();
    final color = [Colors.transparent, const Color(0xFFC1440E), Palette.turmeric, Palette.tulsi][level];
    final label = [null, s('auth_strength_weak'), s('auth_strength_ok'), s('auth_strength_strong')][level]!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        children: [
          for (var i = 1; i <= 3; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 4,
                decoration: BoxDecoration(color: i <= level ? color : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(width: 4),
          ],
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// An error line in a tinted box, so it is seen.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: theme.colorScheme.errorContainer.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 20, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onErrorContainer))),
        ],
      ),
    );
  }
}

/// The big primary button, with a spinner while working.
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({super.key, required this.label, required this.busy, required this.onPressed});

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      onPressed: busy ? null : onPressed,
      child: busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)) : Text(label),
    );
  }
}

/// Digits only, at most six.
final codeFormatters = <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)];
