import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api/api_error.dart';
import '../../../core/config/core_providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/vinyl_cover.dart';
import '../../../shared/widgets/wordmark.dart';
import '../../../l10n/l10n.dart';
import '../../device_music/ui/device_music_providers.dart';
import 'auth_controller.dart';

String? validateServerUrl(AppLocalizations l, String? v) {
  final value = v?.trim() ?? '';
  if (value.isEmpty) return l.enterServerUrl;
  final uri = Uri.tryParse(value);
  if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) {
    return l.serverUrlRule;
  }
  return null;
}

/// [message] when [v] is blank.
String? validateRequired(String? v, String message) => (v == null || v.trim().isEmpty) ? message : null;

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _server;
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(settingsStoreProvider).serverUrl;
    _server = TextEditingController(text: saved ?? (kIsWeb ? Uri.base.origin : ''));
  }

  @override
  void dispose() {
    _server.dispose();
    _user.dispose();
    _pass.dispose();
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
      await ref.read(authControllerProvider.notifier).login(_server.text.trim(), _user.text.trim(), _pass.text);
    } on InvalidCredentialsException {
      _error = l.wrongCredentials;
    } on ApiException catch (e) {
      _error = e.isNetwork ? l.errorNetwork : e.message;
    } catch (e) {
      _error = l.loginFailed('$e');
    }
    if (mounted) setState(() => _busy = false);
  }

  /// Device-only mode: no server, device music only.
  Future<void> _useWithoutServer() async {
    await ref.read(deviceOnlyProvider.notifier).set(true);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final c = QodiColors.of(context);
    final deviceMusic = ref.watch(deviceMusicSupportedProvider);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    return Scaffold(
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
                    const Center(child: VinylCover(seed: 'qodi', size: 104, spinning: true)),
                    const SizedBox(height: 24),
                    const Center(child: QodiWordmark(height: 40)),
                    const SizedBox(height: 10),
                    Text(l.signInSubtitle,
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(color: c.textMuted)),
                    const SizedBox(height: 28),
                    TextFormField(
                      key: const Key('login-server'),
                      controller: _server,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: InputDecoration(
                        hintText: l.serverUrl,
                        prefixIcon: const Icon(Icons.dns_rounded),
                      ),
                      validator: (v) => validateServerUrl(l, v),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('login-username'),
                      controller: _user,
                      autocorrect: false,
                      decoration: InputDecoration(
                        hintText: l.username,
                        prefixIcon: const Icon(Icons.person_rounded),
                      ),
                      validator: (v) => validateRequired(v, l.enterYourUsername),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('login-password'),
                      controller: _pass,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        hintText: l.password,
                        prefixIcon: const Icon(Icons.lock_rounded),
                        suffixIcon: IconButton(
                          tooltip: _obscure ? l.showPassword : l.hidePassword,
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                        ),
                      ),
                      validator: (v) => validateRequired(v, l.enterYourPassword),
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(_error!,
                          key: const Key('login-error'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: QodiTokens.orange, fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const Key('login-submit'),
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : Text(l.signIn),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      key: const Key('login-register'),
                      onPressed: _busy ? null : () => context.push('/register'),
                      child: Text(l.haveInvite),
                    ),
                    if (deviceMusic) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        key: const Key('login-device-only'),
                        onPressed: _busy ? null : _useWithoutServer,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: QodiTokens.orange,
                          side: const BorderSide(color: QodiTokens.orange, width: 1.5),
                          minimumSize: const Size.fromHeight(52),
                        ),
                        icon: const Icon(Icons.phone_android_rounded),
                        label: Text(l.useWithoutServer),
                      ),
                      const SizedBox(height: 6),
                      Text(l.useWithoutServerHint,
                          textAlign: TextAlign.center, style: text.bodySmall?.copyWith(color: c.textMuted)),
                    ],
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
