import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api/api_error.dart';
import '../../../core/theme/tokens.dart';
import '../domain/account.dart';
import 'account_providers.dart';

/// Maps a change-password failure to a user-facing message.
String changePasswordErrorMessage(Object error) {
  if (error is InvalidCredentialsException) return AccountStrings.wrongCurrentPassword;
  if (error is ApiException && error.code == 'bad_request') return AccountStrings.passwordRule;
  return friendlyApiError(error);
}

/// Returns true when the password was changed.
Future<bool> showChangePasswordDialog(BuildContext context) async =>
    await showDialog<bool>(context: context, builder: (_) => const ChangePasswordDialog()) ?? false;

class ChangePasswordDialog extends ConsumerStatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  ConsumerState<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<ChangePasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(accountApiProvider).changePassword(_current.text, _next.text);
      if (mounted) Navigator.of(context).pop(true);
      return;
    } catch (e) {
      _error = changePasswordErrorMessage(e);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    TextFormField field(String key, TextEditingController c, String hint, String? Function(String?) v) =>
        TextFormField(
          key: Key(key),
          controller: c,
          obscureText: true,
          decoration: InputDecoration(hintText: hint),
          validator: v,
        );
    return AlertDialog(
      title: const Text(AccountStrings.changePassword),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              field('pw-current', _current, AccountStrings.currentPassword,
                  (v) => (v == null || v.isEmpty) ? AccountStrings.enterPassword : null),
              const SizedBox(height: 10),
              field('pw-new', _next, AccountStrings.newPassword, validateNewPassword),
              const SizedBox(height: 10),
              field('pw-confirm', _confirm, AccountStrings.confirmNewPassword,
                  (v) => validatePasswordConfirmation(v, _next.text)),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    key: const Key('pw-error'),
                    style: const TextStyle(color: QodiTokens.orange, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            child: const Text(AccountStrings.cancel)),
        FilledButton(
            key: const Key('pw-save'), onPressed: _busy ? null : _save, child: const Text(AccountStrings.save)),
      ],
    );
  }
}
