import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/bento_card.dart';
import '../../library/ui/track_actions.dart';
import 'device_music_providers.dart';
import 'device_music_view.dart';

/// Settings card: scanned folders (defaults + user folders), add/remove,
/// rescan, iOS import.
class DeviceFoldersSettings extends ConsumerWidget {
  const DeviceFoldersSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = QodiColors.of(context);
    final platform = ref.watch(deviceMusicProvider)?.platform;
    final defaults = ref.watch(deviceDefaultFoldersProvider).value ?? const [];
    final folders = ref.watch(deviceFoldersProvider);
    final library = ref.watch(deviceLibraryProvider).value;
    final scanning = library?.scanning ?? false;
    final unreadable = library?.lastScan?.unreadableFolders.toSet() ?? const <String>{};
    Widget folderTile(String path, {VoidCallback? onRemove}) => ListTile(
          leading: Icon(Icons.folder_rounded, color: unreadable.contains(path) ? c.textMuted : QodiTokens.orange),
          title: Text(path, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            [onRemove == null ? 'Default' : 'Added by you', if (unreadable.contains(path)) 'not found'].join(' • '),
            style: TextStyle(color: c.textMuted, fontSize: 12),
          ),
          trailing: onRemove == null
              ? null
              : IconButton(tooltip: 'Remove folder', icon: const Icon(Icons.close_rounded), onPressed: onRemove),
        );
    return BentoCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final f in defaults) folderTile(f),
          for (final f in folders)
            folderTile(f, onRemove: () async {
              await ref.read(deviceFoldersProvider.notifier).remove(f);
              await ref.read(deviceLibraryProvider.notifier).rescan();
            }),
          if (platform?.canPickFolders ?? false)
            ListTile(
              key: const Key('device-add-folder'),
              leading: const Icon(Icons.create_new_folder_rounded),
              title: const Text('Add folder'),
              onTap: () => addDeviceFolder(context, ref),
            ),
          if (platform?.importsFiles ?? false)
            ListTile(
              leading: const Icon(Icons.file_upload_rounded),
              title: const Text('Import songs'),
              subtitle: const Text('Copies audio files into the app'),
              onTap: () => importDeviceFiles(context, ref),
            ),
          ListTile(
            key: const Key('device-rescan-settings'),
            leading: scanning
                ? const SizedBox.square(
                    dimension: 22, child: CircularProgressIndicator(strokeWidth: 2, color: QodiTokens.orange))
                : const Icon(Icons.radar_rounded),
            title: const Text('Rescan device music'),
            subtitle: Text(library == null ? '' : '${library.tracks.length} songs found'),
            onTap: scanning
                ? null
                : () async {
                    final report = await ref.read(deviceLibraryProvider.notifier).rescan();
                    if (context.mounted && report != null) {
                      showSnack(context, 'Scan done: ${report.added} new, ${report.removed} removed');
                    }
                  },
          ),
        ],
      ),
    );
  }
}
