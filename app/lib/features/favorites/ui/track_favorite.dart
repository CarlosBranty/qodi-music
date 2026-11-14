import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../device_music/domain/device_track.dart';
import '../../device_music/ui/device_music_providers.dart';
import '../../library/domain/entities.dart';
import 'favorites_controller.dart';

/// Favorite state of [track]: local (drift) for device tracks, server
/// favorites otherwise.
bool watchIsFavorite(WidgetRef ref, Track track) {
  if (isDeviceTrackId(track.id)) {
    return ref.watch(deviceFavoritesProvider).value?.contains(track.id) ?? false;
  }
  final loaded = ref.watch(favoritesControllerProvider).hasValue;
  return loaded ? ref.watch(favoriteIdsProvider).contains(track.id) : track.favorite;
}

/// Toggles the favorite in the right store (device or server).
Future<void> toggleTrackFavorite(WidgetRef ref, Track track) => isDeviceTrackId(track.id)
    ? ref.read(deviceFavoritesProvider.notifier).toggle(track.id)
    : ref.read(favoritesControllerProvider.notifier).toggle(track);
