import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api/api_error.dart';
import '../../../core/config/core_providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/bento_card.dart';
import '../../auth/ui/auth_controller.dart';
import '../../library/ui/track_actions.dart' show showSnack;
import '../domain/account.dart';
import 'account_providers.dart';

String _date(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}

Future<bool> _confirm(BuildContext context, String title, String message, String action) async =>
    await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text(AccountStrings.cancel)),
          FilledButton(
              key: const Key('confirm-action'),
              onPressed: () => Navigator.of(d).pop(true),
              child: Text(action)),
        ],
      ),
    ) ??
    false;

/// Settings › Users & invites (admins only).
class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isAdminProvider)) {
      return Scaffold(
        appBar: AppBar(title: const Text(AccountStrings.usersAndInvites)),
        body: const Center(child: Text(ApiErrorStrings.forbidden, key: Key('users-forbidden'))),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text(AccountStrings.usersAndInvites)),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('invite-create'),
        backgroundColor: QodiTokens.orange,
        foregroundColor: Colors.white,
        onPressed: () => _createInvite(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text(AccountStrings.createInvite),
      ),
      body: RefreshIndicator(
        color: QodiTokens.orange,
        onRefresh: () async {
          ref.invalidate(adminUsersProvider);
          ref.invalidate(adminInvitesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: const [_UsersSection(), _InvitesSection()],
        ),
      ),
    );
  }

  Future<void> _createInvite(BuildContext context, WidgetRef ref) async {
    final params = await showDialog<({int hours, int uses})>(context: context, builder: (_) => const _InviteForm());
    if (params == null || !context.mounted) return;
    try {
      final invite =
          await ref.read(accountApiProvider).createInvite(expiresInHours: params.hours, maxUses: params.uses);
      ref.invalidate(adminInvitesProvider);
      if (!context.mounted) return;
      final server = ref.read(apiClientProvider).serverOrigin;
      await showDialog<void>(context: context, builder: (_) => InviteShareDialog(invite: invite, serverBaseUrl: server));
    } catch (e) {
      if (context.mounted) showSnack(context, friendlyApiError(e));
    }
  }
}

Widget _sectionLabel(BuildContext context, String t) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
      child: Text(t, style: TextStyle(color: QodiColors.of(context).textMuted, fontWeight: FontWeight.w700)),
    );

Widget _asyncError(Object e) => Padding(
      padding: const EdgeInsets.all(16),
      child: Text(e is ForbiddenException ? ApiErrorStrings.forbidden : AccountStrings.loadFailed),
    );

class _UsersSection extends ConsumerWidget {
  const _UsersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(adminUsersProvider);
    final me = ref.watch(authControllerProvider)?.user.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel(context, AccountStrings.users),
        BentoCard(
          padding: EdgeInsets.zero,
          child: users.when(
            loading: () => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
            error: (e, _) => _asyncError(e),
            data: (list) => Column(
              children: [
                for (final u in list)
                  ListTile(
                    key: Key('user-${u.id}'),
                    leading: Icon(u.isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                        color: QodiTokens.orange),
                    title: Text(u.username, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text([
                      if (u.id == me) AccountStrings.you,
                      if (u.isAdmin) AccountStrings.admin,
                      _date(u.createdAt),
                    ].join(' · ')),
                    trailing: IconButton(
                      key: Key('user-delete-${u.id}'),
                      tooltip: u.id == me ? AccountStrings.cannotDeleteSelf : AccountStrings.deleteUser,
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: u.id == me ? null : () => _delete(context, ref, u),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, UserSummary u) async {
    final ok = await _confirm(
        context, AccountStrings.deleteUser, AccountStrings.deleteUserQuestion(u.username), AccountStrings.delete);
    if (!ok) return;
    try {
      await ref.read(accountApiProvider).deleteUser(u.id);
      ref.invalidate(adminUsersProvider);
      if (context.mounted) showSnack(context, AccountStrings.userDeleted(u.username));
    } catch (e) {
      if (context.mounted) showSnack(context, friendlyApiError(e));
    }
  }
}

class _InvitesSection extends ConsumerWidget {
  const _InvitesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(adminInvitesProvider);
    final now = ref.watch(clockProvider)();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel(context, AccountStrings.invites),
        BentoCard(
          padding: EdgeInsets.zero,
          child: invites.when(
            loading: () => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
            error: (e, _) => _asyncError(e),
            data: (list) => list.isEmpty
                ? const Padding(padding: EdgeInsets.all(16), child: Text(AccountStrings.noInvites))
                : Column(
                    children: [
                      for (final i in list) _InviteTile(invite: i, status: i.statusAt(now), now: now),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _InviteTile extends ConsumerWidget {
  const _InviteTile({required this.invite, required this.status, required this.now});
  final Invite invite;
  final InviteStatus status;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = status == InviteStatus.active;
    final exp = invite.expiresAt;
    final expiry = exp == null
        ? null
        : (exp.isAfter(now) ? AccountStrings.expiresOn(_date(exp)) : AccountStrings.expiredOn(_date(exp)));
    return ListTile(
      key: Key('invite-${invite.code}'),
      title: Text(invite.code, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
      subtitle: Text([
        inviteStatusLabel(status),
        AccountStrings.uses(invite.uses, invite.maxUses),
        ?expiry,
      ].join(' · ')),
      leading: Icon(Icons.confirmation_number_rounded, color: active ? QodiTokens.orange : null),
      onTap: active
          ? () => showDialog<void>(
                context: context,
                builder: (_) =>
                    InviteShareDialog(invite: invite, serverBaseUrl: ref.read(apiClientProvider).serverOrigin),
              )
          : null,
      trailing: IconButton(
        key: Key('invite-revoke-${invite.code}'),
        tooltip: AccountStrings.revokeInvite,
        icon: const Icon(Icons.block_rounded),
        onPressed: () => _revoke(context, ref),
      ),
    );
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref) async {
    final ok = await _confirm(context, AccountStrings.revokeInvite, AccountStrings.revokeInviteQuestion(invite.code),
        AccountStrings.revoke);
    if (!ok) return;
    try {
      await ref.read(accountApiProvider).revokeInvite(invite.code);
      ref.invalidate(adminInvitesProvider);
      if (context.mounted) showSnack(context, AccountStrings.inviteRevoked);
    } catch (e) {
      if (context.mounted) showSnack(context, friendlyApiError(e));
    }
  }
}

class _InviteForm extends StatefulWidget {
  const _InviteForm();

  @override
  State<_InviteForm> createState() => _InviteFormState();
}

class _InviteFormState extends State<_InviteForm> {
  final _form = GlobalKey<FormState>();
  final _hours = TextEditingController(text: '72');
  final _uses = TextEditingController(text: '1');

  @override
  void dispose() {
    _hours.dispose();
    _uses.dispose();
    super.dispose();
  }

  String? Function(String?) _range(int min, int max, String rule) => (v) {
        final n = int.tryParse(v?.trim() ?? '');
        return (n == null || n < min || n > max) ? rule : null;
      };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(AccountStrings.createInvite),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const Key('invite-hours'),
              controller: _hours,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: AccountStrings.expiresInHours),
              validator: _range(1, 720, AccountStrings.expiryRule),
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('invite-uses'),
              controller: _uses,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: AccountStrings.maxUses),
              validator: _range(1, 50, AccountStrings.usesRule),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text(AccountStrings.cancel)),
        FilledButton(
          key: const Key('invite-submit'),
          onPressed: () {
            if (!(_form.currentState?.validate() ?? false)) return;
            Navigator.of(context).pop((hours: int.parse(_hours.text.trim()), uses: int.parse(_uses.text.trim())));
          },
          child: const Text(AccountStrings.create),
        ),
      ],
    );
  }
}

/// Shows an invite code with copy actions for the join and APK links.
class InviteShareDialog extends StatelessWidget {
  const InviteShareDialog({super.key, required this.invite, required this.serverBaseUrl});
  final Invite invite;
  final String serverBaseUrl;

  @override
  Widget build(BuildContext context) {
    final join = inviteJoinLink(serverBaseUrl, invite.code);
    final apk = androidApkLink(serverBaseUrl);
    Future<void> copy(String value) async {
      await Clipboard.setData(ClipboardData(text: value));
      if (context.mounted) showSnack(context, AccountStrings.copied);
    }

    Widget link(String key, String label, String value) => ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: SelectableText(value, key: Key('$key-text')),
          trailing: IconButton(
            key: Key('$key-copy'),
            tooltip: AccountStrings.copy,
            icon: const Icon(Icons.copy_rounded),
            onPressed: () => copy(value),
          ),
        );

    return AlertDialog(
      title: const Text(AccountStrings.inviteCreated),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(
              invite.code,
              key: const Key('invite-code'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 3, color: QodiTokens.orange),
            ),
            TextButton.icon(
              key: const Key('invite-code-copy'),
              onPressed: () => copy(invite.code),
              icon: const Icon(Icons.copy_rounded),
              label: const Text(AccountStrings.copyCode),
            ),
            const SizedBox(height: 4),
            Text(AccountStrings.shareInviteHint, style: TextStyle(color: QodiColors.of(context).textMuted)),
            link('invite-join', AccountStrings.joinLink, join),
            link('invite-apk', AccountStrings.apkLink, apk),
          ],
        ),
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text(AccountStrings.done)),
      ],
    );
  }
}
