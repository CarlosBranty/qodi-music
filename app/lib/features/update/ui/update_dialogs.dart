import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/bento_card.dart';
import '../domain/app_update.dart';
import 'update_controller.dart';

/// "Update available (vX → vY)" with Update / Later; Update downloads,
/// verifies and opens the installer while showing progress.
Future<void> showUpdateAvailableDialog(BuildContext context, WidgetRef ref, UpdateAvailable update) async {
  final l = context.l10n;
  final go = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(l.updateAvailable),
      content: Text(l.updateQuestion(update.installed.name, update.release.versionName),
          key: const Key('update-question')),
      actions: [
        TextButton(onPressed: () => Navigator.of(d).pop(false), child: Text(l.later)),
        FilledButton(
            key: const Key('update-confirm'),
            onPressed: () => Navigator.of(d).pop(true),
            child: Text(l.update)),
      ],
    ),
  );
  if (go != true || !context.mounted) return;
  ref.read(updateControllerProvider.notifier).downloadAndInstall(update.release);
  await showDialog<void>(context: context, builder: (_) => const UpdateProgressDialog());
}

class UpdateProgressDialog extends ConsumerWidget {
  const UpdateProgressDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(updateControllerProvider);
    final error = s.error;
    final controller = ref.read(updateControllerProvider.notifier);
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.update),
      content: error != null
          ? Text(updateErrorMessage(l, error), key: const Key('update-error'))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.downloadingUpdate),
                const SizedBox(height: 14),
                LinearProgressIndicator(value: s.progress, color: QodiTokens.orange),
              ],
            ),
      actions: [
        if (error == UpdateError.permissionDenied)
          TextButton(onPressed: controller.openInstallSettings, child: Text(l.openSettings)),
        TextButton(
          onPressed: () {
            controller.clearError();
            Navigator.of(context).pop();
          },
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }
}

String _when(AppLocalizations l, DateTime t) => DateFormat.yMMMd(l.localeName).add_Hm().format(t.toLocal());

/// Settings › App updates (Android only): current version, last check result
/// and "Check for updates".
class UpdateSettingsCard extends ConsumerStatefulWidget {
  const UpdateSettingsCard({super.key});

  @override
  ConsumerState<UpdateSettingsCard> createState() => _UpdateSettingsCardState();
}

class _UpdateSettingsCardState extends ConsumerState<UpdateSettingsCard> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(updateControllerProvider.notifier).loadInstalled());
  }

  Future<void> _check() async {
    final result = await ref.read(updateControllerProvider.notifier).check();
    if (result is UpdateAvailable && mounted) await showUpdateAvailableDialog(context, ref, result);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(updateControllerProvider);
    final version = s.installed;
    final l = context.l10n;
    final last = s.lastResult == null ? null : describeUpdateResult(l, s.lastResult!);
    final status = s.checking
        ? l.checking
        : last == null
            ? l.neverChecked
            : s.lastCheck == null
                ? last
                : l.lastChecked(last, _when(l, s.lastCheck!));
    return BentoCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        key: const Key('settings-check-updates'),
        leading: const Icon(Icons.system_update_rounded, color: QodiTokens.orange),
        title: Text(version == null ? l.checkForUpdates : l.currentVersion('${version.name} (${version.buildNumber})')),
        subtitle: Text(status, key: const Key('update-status')),
        trailing: s.checking
            ? const SizedBox.square(
                dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: QodiTokens.orange))
            : TextButton(onPressed: _check, child: Text(l.checkForUpdates)),
        onTap: s.checking ? null : _check,
      ),
    );
  }
}
