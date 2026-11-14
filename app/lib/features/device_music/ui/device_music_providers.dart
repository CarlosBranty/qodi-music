import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/core_providers.dart';
import '../../library/domain/entities.dart';
import '../domain/device_library.dart';
import '../domain/device_music_source.dart';
import '../domain/device_track.dart';

/// Device music adapters, null when unsupported (web).
final deviceMusicProvider = Provider<DeviceMusicServices?>((ref) => ref.watch(platformServicesProvider).device);

final deviceMusicSupportedProvider = Provider<bool>((ref) => ref.watch(deviceMusicProvider) != null);

class DeviceLibraryState {
  const DeviceLibraryState({
    this.tracks = const [],
    this.permission = DevicePermission.notRequired,
    this.scanning = false,
    this.lastScan,
    this.error,
  });

  /// Device tracks sorted by title.
  final List<Track> tracks;
  final DevicePermission permission;
  final bool scanning;
  final DeviceScanReport? lastScan;
  final String? error;

  DeviceLibraryState copyWith({
    List<Track>? tracks,
    DevicePermission? permission,
    bool? scanning,
    DeviceScanReport? lastScan,
    String? error,
  }) =>
      DeviceLibraryState(
        tracks: tracks ?? this.tracks,
        permission: permission ?? this.permission,
        scanning: scanning ?? this.scanning,
        lastScan: lastScan ?? this.lastScan,
        error: error,
      );
}

/// Extra scan folders chosen by the user (persisted in settings).
final deviceFoldersProvider = NotifierProvider<DeviceFoldersController, List<String>>(DeviceFoldersController.new);

class DeviceFoldersController extends Notifier<List<String>> {
  @override
  List<String> build() => ref.read(settingsStoreProvider).deviceFolders;

  Future<void> add(String folder) async {
    if (state.contains(folder)) return;
    state = [...state, folder];
    await ref.read(settingsStoreProvider).setDeviceFolders(state);
  }

  Future<void> remove(String folder) async {
    state = state.where((f) => f != folder).toList();
    await ref.read(settingsStoreProvider).setDeviceFolders(state);
  }
}

/// Platform default scan folders (e.g. `~/Music`).
final deviceDefaultFoldersProvider = FutureProvider<List<String>>(
    (ref) async => await ref.watch(deviceMusicProvider)?.platform.defaultFolders() ?? const []);

/// Device tracks: cached scan results first, then an incremental rescan in
/// the background when the storage permission is already granted.
final deviceLibraryProvider =
    AsyncNotifierProvider<DeviceLibraryController, DeviceLibraryState>(DeviceLibraryController.new);

class DeviceLibraryController extends AsyncNotifier<DeviceLibraryState> {
  DeviceMusicServices? get _services => ref.read(deviceMusicProvider);

  @override
  Future<DeviceLibraryState> build() async {
    final services = ref.watch(deviceMusicProvider);
    if (services == null) return const DeviceLibraryState();
    final cached = await services.source.tracks();
    final permission = await services.platform.permissionStatus();
    if (permission.allowed) Future.microtask(() => rescan(request: false));
    return DeviceLibraryState(tracks: sortByTitle(cached.map((t) => t.track)), permission: permission);
  }

  /// Asks for the storage permission (Android) and rescans on success.
  Future<void> requestAccess() async {
    final services = _services;
    if (services == null) return;
    final permission = await services.platform.requestPermission();
    final current = state.value ?? const DeviceLibraryState();
    state = AsyncData(current.copyWith(permission: permission));
    if (permission.allowed) await rescan(request: false);
  }

  /// Incremental rescan of the default + user folders.
  Future<DeviceScanReport?> rescan({bool request = true}) async {
    final services = _services;
    if (services == null) return null;
    var current = state.value ?? const DeviceLibraryState();
    var permission = request ? await services.platform.requestPermission() : current.permission;
    if (!request && !permission.allowed) permission = await services.platform.permissionStatus();
    if (!permission.allowed) {
      state = AsyncData(current.copyWith(permission: permission));
      return null;
    }
    state = AsyncData(current.copyWith(permission: permission, scanning: true));
    try {
      final folders = {
        ...await ref.read(deviceDefaultFoldersProvider.future),
        ...ref.read(deviceFoldersProvider),
      }.toList();
      final report = await services.source.rescan(folders);
      final tracks = await services.source.tracks();
      current = state.value ?? current;
      state = AsyncData(current.copyWith(
        tracks: sortByTitle(tracks.map((t) => t.track)),
        permission: permission,
        scanning: false,
        lastScan: report,
      ));
      return report;
    } catch (e) {
      current = state.value ?? current;
      state = AsyncData(current.copyWith(scanning: false, error: 'Scan failed: $e'));
      return null;
    }
  }
}

/// Device tracks (empty while loading / unsupported).
final deviceTracksProvider =
    Provider<List<Track>>((ref) => ref.watch(deviceLibraryProvider).value?.tracks ?? const []);

final deviceAlbumsProvider = Provider<List<Album>>((ref) => deviceAlbums(ref.watch(deviceTracksProvider)));

final deviceArtistsProvider = Provider<List<Artist>>((ref) => deviceArtists(ref.watch(deviceTracksProvider)));

final deviceTrackByIdProvider = Provider<Map<String, Track>>(
    (ref) => {for (final t in ref.watch(deviceTracksProvider)) t.id: t});

/// Cover image path of a device track.
final deviceCoverPathProvider = Provider.family<String?, String>((ref, trackId) {
  ref.watch(deviceTracksProvider);
  return ref.watch(deviceMusicProvider)?.source.coverPathOf(trackId);
});

// ---- local favorites ----

final deviceFavoritesProvider =
    AsyncNotifierProvider<DeviceFavoritesController, Set<String>>(DeviceFavoritesController.new);

class DeviceFavoritesController extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async =>
      await ref.watch(deviceMusicProvider)?.collections.favoriteIds() ?? const {};

  bool isFavorite(String trackId) => state.value?.contains(trackId) ?? false;

  /// Optimistic toggle; reverts on failure.
  Future<void> toggle(String trackId) async {
    final collections = ref.read(deviceMusicProvider)?.collections;
    if (collections == null) return;
    final before = state.value ?? const <String>{};
    final fav = before.contains(trackId);
    state = AsyncData(fav ? ({...before}..remove(trackId)) : {trackId, ...before});
    try {
      await collections.setFavorite(trackId, !fav);
    } catch (_) {
      state = AsyncData(before);
      rethrow;
    }
  }
}

/// Favorite device tracks that are still on the device (most recent first).
final deviceFavoriteTracksProvider = Provider<List<Track>>((ref) {
  final ids = ref.watch(deviceFavoritesProvider).value ?? const <String>{};
  final byId = ref.watch(deviceTrackByIdProvider);
  return [for (final id in ids) ?byId[id]];
});

// ---- local playlists ----

final devicePlaylistsProvider =
    AsyncNotifierProvider<DevicePlaylistsController, List<DevicePlaylist>>(DevicePlaylistsController.new);

class DevicePlaylistsController extends AsyncNotifier<List<DevicePlaylist>> {
  DeviceCollections? get _repo => ref.read(deviceMusicProvider)?.collections;

  @override
  Future<List<DevicePlaylist>> build() async =>
      await ref.watch(deviceMusicProvider)?.collections.playlists() ?? const [];

  Future<void> _reload() async {
    state = AsyncData(await _repo?.playlists() ?? const []);
  }

  Future<DevicePlaylist?> create(String name) async {
    final p = await _repo?.createPlaylist(name);
    await _reload();
    return p;
  }

  Future<void> rename(String id, String name) async {
    await _repo?.renamePlaylist(id, name);
    await _reload();
  }

  Future<void> delete(String id) async {
    await _repo?.deletePlaylist(id);
    await _reload();
  }

  Future<void> addTracks(String id, List<Track> tracks) async {
    final current = state.value?.where((p) => p.id == id).firstOrNull;
    final ids = [...?current?.trackIds, ...tracks.map((t) => t.id)];
    await _repo?.setPlaylistTracks(id, ids);
    await _reload();
  }

  Future<void> setTracks(String id, List<Track> tracks) async {
    await _repo?.setPlaylistTracks(id, tracks.map((t) => t.id).toList());
    await _reload();
  }
}

/// Resolves the tracks of a device playlist (missing files are skipped).
List<Track> resolvePlaylistTracks(DevicePlaylist p, Map<String, Track> byId) =>
    [for (final id in p.trackIds) ?byId[id]];

/// Whether [trackId] belongs to the device (helper for shared widgets).
bool isDeviceTrack(Track t) => isDeviceTrackId(t.id);
