import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api/api_error.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/wordmark.dart';
import '../../auth/ui/auth_controller.dart';
import '../../auth/ui/login_screen.dart' show validateServerUrl;
import '../../../l10n/l10n.dart';
import '../domain/account.dart';
import 'account_messages.dart';

/// Maps a registration failure to a user-facing message.
String registerErrorMessage(AppLocalizations l, Object error) {
  if (error is ApiException) {
    switch (error.code) {
      case 'invalid_invite':
        return l.invalidInvite;
      case 'username_taken':
        return l.usernameTaken;
      case 'bad_request':
        return l.badRequest;
    }
  }
  return friendlyApiError(l, error);
}

/// Invite-based sign-up: server URL, invite code, username, password.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.initialServer = '', this.initialCode = ''});
  final String initialServer;
  final String initialCode;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  late final _server = TextEditingController(text: widget.initialServer);
  late final _code = TextEditingController(text: widget.initialCode);
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_server, _code, _user, _pass, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final l = context.l10n;
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).register(
            _server.text.trim(),
            normalizeInviteCode(_code.text),
            normalizeUsername(_user.text),
            _pass.text,
          );
      if (mounted) context.go('/home');
    } catch (e) {
      _error = registerErrorMessage(l, e);
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _field(String key, TextEditingController c, String hint, IconData icon,
          {String? Function(String?)? validator, bool obscure = false, TextInputType? type}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          key: Key(key),
          controller: c,
          obscureText: obscure,
          autocorrect: false,
          keyboardType: type,
          decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon)),
          validator: validator,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = QodiColors.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: QodiWordmark(height: 40)),
                    const SizedBox(height: 10),
                    Text(l.createAccountSubtitle,
                        textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: c.textMuted)),
                    const SizedBox(height: 24),
                    _field('register-server', _server, l.serverUrl, Icons.dns_rounded,
                        validator: (v) => validateServerUrl(l, v), type: TextInputType.url),
                    _field('register-code', _code, l.inviteCode, Icons.confirmation_number_rounded,
                        validator: (v) => accountErrorText(l, validateInviteCode(v))),
                    _field('register-username', _user, l.username, Icons.person_rounded,
                        validator: (v) => accountErrorText(l, validateUsername(v))),
                    _field('register-password', _pass, l.password, Icons.lock_rounded,
                        validator: (v) => accountErrorText(l, validateNewPassword(v)), obscure: true),
                    _field('register-confirm', _confirm, l.confirmPassword, Icons.lock_outline_rounded,
                        validator: (v) => accountErrorText(l, validatePasswordConfirmation(v, _pass.text)),
                        obscure: true),
                    if (_error != null) ...[
                      const SizedBox(height: 4),
                      Text(_error!,
                          key: const Key('register-error'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: QodiTokens.orange, fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const Key('register-submit'),
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : Text(l.createAccount),
                    ),
                    TextButton(
                      onPressed: _busy ? null : () => context.go('/login'),
                      child: Text(l.haveAccount),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
