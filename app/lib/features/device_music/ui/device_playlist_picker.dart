import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/format.dart';
import '../../library/domain/entities.dart';
import '../../playlists/ui/playlist_picker.dart';
import 'device_music_providers.dart';

/// Picks (or creates) a local device playlist and appends [tracks] to it.
Future<void> showDevicePlaylistPicker(BuildContext context, WidgetRef ref, List<Track> tracks) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final controller = ref.read(devicePlaylistsProvider.notifier);
  final selected = await showModalBottomSheet<String>(
    context: context,
    builder: (sheet) => Consumer(builder: (context, ref, _) {
      final playlists = ref.watch(devicePlaylistsProvider);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: QodiTokens.orange,
                child: Icon(Icons.add_rounded, color: Colors.white),
              ),
              title: const Text('New device playlist', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () async {
                final name = await askPlaylistName(context);
                if (name == null) return;
                final p = await controller.create(name);
                if (sheet.mounted && p != null) Navigator.of(sheet).pop(p.id);
              },
            ),
            ...?playlists.value?.map((p) => ListTile(
                  leading: const Icon(Icons.queue_music_rounded),
                  title: Text(p.name),
                  subtitle: Text(songsLabel(p.trackIds.length)),
                  onTap: () => Navigator.of(sheet).pop(p.id),
                )),
          ],
        ),
      );
    }),
  );
  if (selected == null) return;
  try {
    await controller.addTracks(selected, tracks);
    messenger?.showSnackBar(SnackBar(
        content: Text(tracks.length == 1 ? 'Added to playlist' : 'Added ${tracks.length} songs')));
  } catch (_) {
    messenger?.showSnackBar(const SnackBar(content: Text('Could not add to playlist')));
  }
}
