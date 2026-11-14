import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/bento_card.dart';
import '../domain/app_update.dart';
import 'update_controller.dart';

/// "Update available (vX → vY)" with Update / Later; Update downloads,
/// verifies and opens the installer while showing progress.
Future<void> showUpdateAvailableDialog(BuildContext context, WidgetRef ref, UpdateAvailable update) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text(UpdateStrings.updateAvailable),
      content: Text(UpdateStrings.updateQuestion(update.installed.name, update.release.versionName),
          key: const Key('update-question')),
      actions: [
        TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text(UpdateStrings.later)),
        FilledButton(
            key: const Key('update-confirm'),
            onPressed: () => Navigator.of(d).pop(true),
            child: const Text(UpdateStrings.update)),
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
    return AlertDialog(
      title: const Text(UpdateStrings.update),
      content: error != null
          ? Text(updateErrorMessage(error), key: const Key('update-error'))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(UpdateStrings.downloading),
                const SizedBox(height: 14),
                LinearProgressIndicator(value: s.progress, color: QodiTokens.orange),
              ],
            ),
      actions: [
        if (error == UpdateError.permissionDenied)
          TextButton(onPressed: controller.openInstallSettings, child: const Text(UpdateStrings.openSettings)),
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

String _when(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  final l = t.toLocal();
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}

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
    final last = s.lastResult;
    final status = s.checking
        ? UpdateStrings.checking
        : last == null
            ? UpdateStrings.neverChecked
            : s.lastCheck == null
                ? last
                : UpdateStrings.lastChecked(_when(s.lastCheck!), last);
    return BentoCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        key: const Key('settings-check-updates'),
        leading: const Icon(Icons.system_update_rounded, color: QodiTokens.orange),
        title: Text(version == null
            ? UpdateStrings.checkForUpdates
            : UpdateStrings.currentVersion('${version.name} (${version.buildNumber})')),
        subtitle: Text(status, key: const Key('update-status')),
        trailing: s.checking
            ? const SizedBox.square(
                dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: QodiTokens.orange))
            : TextButton(onPressed: _check, child: const Text(UpdateStrings.checkForUpdates)),
        onTap: s.checking ? null : _check,
      ),
    );
  }
}
