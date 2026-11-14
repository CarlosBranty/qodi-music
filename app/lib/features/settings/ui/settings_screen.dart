import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/config/core_providers.dart';
import '../../../core/config/settings_store.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/bento_card.dart';
import '../../account/domain/account.dart';
import '../../account/ui/account_providers.dart';
import '../../account/ui/change_password_dialog.dart';
import '../../auth/ui/auth_controller.dart';
import '../../device_music/ui/device_folders_settings.dart';
import '../../device_music/ui/device_music_providers.dart';
import '../../downloads/ui/downloads_controller.dart';
import '../../equalizer/ui/equalizer_controller.dart';
import '../../library/ui/library_providers.dart';
import '../../library/ui/track_actions.dart';
import '../../player/ui/player_providers.dart';
import '../../update/domain/app_update.dart';
import '../../update/ui/update_controller.dart';
import '../../update/ui/update_dialogs.dart';
import 'settings_controllers.dart';

final _downloadBytesProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(downloadsControllerProvider.select((s) => s.ids));
  return await ref.watch(downloadStoreProvider)?.totalBytes() ?? 0;
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider);
    final theme = ref.watch(themePreferenceProvider);
    final quality = ref.watch(qualityProvider);
    final c = QodiColors.of(context);
    final offline = ref.read(platformServicesProvider).supportsOffline;
    final server = session != null;
    final device = ref.watch(deviceMusicSupportedProvider);
    final equalizer = ref.watch(equalizerControllerProvider.select((s) => s.supported));
    final admin = ref.watch(isAdminProvider);
    final updates = ref.watch(updatesSupportedProvider);
    Widget label(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
          child: Text(t, style: TextStyle(color: c.textMuted, fontWeight: FontWeight.w700)),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          BentoCard(
            child: Row(
              children: [
                const Icon(Icons.dns_rounded, color: QodiTokens.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: server
                        ? [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(session.user.username,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w800)),
                                ),
                                if (admin) ...[
                                  const SizedBox(width: 8),
                                  const _AdminBadge(),
                                ],
                              ],
                            ),
                            Text(session.serverUrl, style: TextStyle(color: c.textMuted, fontSize: 12)),
                          ]
                        : [
                            const Text('Not connected', style: TextStyle(fontWeight: FontWeight.w800)),
                            Text('Using music on this device only',
                                style: TextStyle(color: c.textMuted, fontSize: 12)),
                          ],
                  ),
                ),
                if (!server)
                  FilledButton(
                    key: const Key('settings-connect-server'),
                    onPressed: () => context.push('/login'),
                    child: const Text('Connect to a server'),
                  ),
              ],
            ),
          ),
          if (server) ...[
            label(AccountStrings.account),
            BentoCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    key: const Key('settings-change-password'),
                    leading: const Icon(Icons.password_rounded, color: QodiTokens.orange),
                    title: const Text(AccountStrings.changePassword),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      if (await showChangePasswordDialog(context) && context.mounted) {
                        showSnack(context, AccountStrings.passwordChanged);
                      }
                    },
                  ),
                  if (admin)
                    ListTile(
                      key: const Key('settings-users'),
                      leading: const Icon(Icons.group_rounded, color: QodiTokens.orange),
                      title: const Text(AccountStrings.usersAndInvites),
                      subtitle: const Text(AccountStrings.usersSubtitle),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/settings/users'),
                    ),
                ],
              ),
            ),
          ],
          label('Appearance'),
          SegmentedButton<AppThemePreference>(
            segments: const [
              ButtonSegment(value: AppThemePreference.system, label: Text('System'), icon: Icon(Icons.brightness_auto_rounded)),
              ButtonSegment(value: AppThemePreference.light, label: Text('Light'), icon: Icon(Icons.light_mode_rounded)),
              ButtonSegment(value: AppThemePreference.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_rounded)),
            ],
            selected: {theme},
            onSelectionChanged: (s) => ref.read(themePreferenceProvider.notifier).set(s.first),
          ),
          if (equalizer) ...[
            label('Playback'),
            BentoCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                key: const Key('settings-equalizer'),
                leading: const Icon(Icons.equalizer_rounded, color: QodiTokens.orange),
                title: const Text('Equalizer'),
                subtitle: const Text('Presets and custom sound'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/equalizer'),
              ),
            ),
          ],
          if (server) label('Streaming quality'),
          if (server)
            BentoCard(
              padding: EdgeInsets.zero,
              child: RadioGroup<StreamQuality>(
                groupValue: quality,
                onChanged: (v) {
                  if (v != null) ref.read(qualityProvider.notifier).set(v);
                },
                child: Column(
                  children: [
                    for (final q in StreamQuality.values)
                      RadioListTile<StreamQuality>(
                        value: q,
                        activeColor: QodiTokens.orange,
                        title: Text(q.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(q.description),
                      ),
                  ],
                ),
              ),
            ),
          if (device) ...[
            label('Music on this device'),
            const DeviceFoldersSettings(),
          ],
          if (server) label('Server library'),
          if (server)
            BentoCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  if (offline)
                    ListTile(
                      leading: const Icon(Icons.sync_rounded),
                      title: const Text('Sync offline library'),
                      subtitle: const Text('Download the latest library changes'),
                      onTap: () async {
                        try {
                          final n = await ref.read(librarySyncProvider).sync();
                          if (context.mounted) showSnack(context, 'Library synced ($n changes)');
                        } catch (e) {
                          if (context.mounted) showSnack(context, 'Sync failed');
                        }
                      },
                    ),
                  ListTile(
                    leading: const Icon(Icons.radar_rounded),
                    title: const Text('Rescan music folder'),
                    subtitle: const Text('Ask the server to look for new songs'),
                    onTap: () async {
                      try {
                        await ref.read(libraryApiProvider).scan();
                        if (context.mounted) showSnack(context, 'Scan started');
                      } catch (_) {
                        if (context.mounted) showSnack(context, 'Could not start the scan');
                      }
                    },
                  ),
                  if (offline)
                    ListTile(
                      leading: const Icon(Icons.download_done_rounded),
                      title: const Text('Downloaded music'),
                      subtitle: Text(formatBytes(ref.watch(_downloadBytesProvider).value ?? 0)),
                    ),
                ],
              ),
            ),
          if (updates) ...[
            label(UpdateStrings.appUpdates),
            const UpdateSettingsCard(),
          ],
          const SizedBox(height: 28),
          if (server)
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: QodiTokens.ink),
              onPressed: () async {
                await ref.read(playerPortProvider).stop();
                await ref.read(authControllerProvider.notifier).logout();
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Log out'),
            ),
        ],
      ),
    );
  }
}

class _AdminBadge extends StatelessWidget {
  const _AdminBadge();

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('settings-admin-badge'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: QodiTokens.orange, borderRadius: BorderRadius.circular(10)),
        child: const Text(AccountStrings.admin,
            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
      );
}
