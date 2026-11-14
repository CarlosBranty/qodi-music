import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/format.dart';
import '../../library/domain/entities.dart';
import 'playlists_controller.dart';

/// Asks for a playlist name. Returns null when cancelled.
Future<String?> askPlaylistName(BuildContext context,
    {String title = 'New playlist', String initial = '', String action = 'Create'}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Playlist name'),
        onSubmitted: (v) => Navigator.of(ctx).pop(v.trim().isEmpty ? null : v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final v = controller.text.trim();
            Navigator.of(ctx).pop(v.isEmpty ? null : v);
          },
          child: Text(action),
        ),
      ],
    ),
  );
}

/// Lets the user pick (or create) a playlist and appends [tracks] to it.
Future<void> showPlaylistPicker(BuildContext context, WidgetRef ref, List<Track> tracks) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final controller = ref.read(playlistsControllerProvider.notifier);
  final selected = await showModalBottomSheet<String>(
    context: context,
    builder: (sheet) => Consumer(builder: (context, ref, _) {
      final playlists = ref.watch(playlistsControllerProvider);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: QodiTokens.orange,
                child: Icon(Icons.add_rounded, color: Colors.white),
              ),
              title: const Text('New playlist', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () async {
                final name = await askPlaylistName(context);
                if (name == null) return;
                final p = await controller.create(name);
                if (sheet.mounted) Navigator.of(sheet).pop(p.id);
              },
            ),
            ...?playlists.value?.map((p) => ListTile(
                  leading: const Icon(Icons.queue_music_rounded),
                  title: Text(p.name),
                  subtitle: Text(songsLabel(p.trackCount)),
                  onTap: () => Navigator.of(sheet).pop(p.id),
                )),
            if (playlists.isLoading) const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
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
