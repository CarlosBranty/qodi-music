import 'device_track.dart';

/// Port: music stored on the device itself.
abstract interface class DeviceMusicSource {
  /// Tracks cached from the last scan (no disk walk).
  Future<List<DeviceTrack>> tracks();

  /// Incremental rescan of [folders]: only new or changed files (size/mtime)
  /// are read again; files no longer present are dropped.
  Future<DeviceScanReport> rescan(List<String> folders);

  /// Absolute path of a device track, or null when unknown.
  String? pathOf(String trackId);

  /// Cover image path of a device track (after [tracks] or [rescan]).
  String? coverPathOf(String trackId);

  /// Contents of the sidecar `.lrc` file of a device track, if any.
  Future<String?> readLyrics(String trackId);
}

/// Persistence of the scan results (drift on native).
abstract interface class DeviceLibraryStore {
  Future<List<DeviceTrack>> loadTracks();

  /// Replaces [upserts] (by path) and deletes [removedPaths] atomically.
  Future<void> applyScan({required List<DeviceTrack> upserts, required List<String> removedPaths});
}

/// Reads the folders: returns the stamps of every audio file found.
abstract interface class DeviceFileScanner {
  /// Walks [folders] and reads the tags of the files whose stamp differs from
  /// [known]. Runs off the UI isolate.
  Future<DeviceScanResult> scan(List<String> folders, Map<String, FileStamp> known);

  /// Deletes extracted covers no track uses any more (files outside the
  /// scanner's cache, e.g. sidecar `cover.jpg`, are never touched).
  Future<void> deleteCovers(List<String> coverPaths);
}

class DeviceScanResult {
  const DeviceScanResult({
    required this.read,
    required this.unchanged,
    required this.removed,
    required this.newPaths,
    this.unreadableFolders = const [],
  });

  /// New or changed tracks with fresh metadata.
  final List<DeviceTrack> read;
  final List<String> unchanged;
  final List<String> removed;
  final Set<String> newPaths;
  final List<String> unreadableFolders;
}

/// Runtime storage permission state.
enum DevicePermission { granted, denied, permanentlyDenied, notRequired }

extension DevicePermissionX on DevicePermission {
  bool get allowed => this == DevicePermission.granted || this == DevicePermission.notRequired;
}

/// Platform capabilities used by the device music UI.
abstract interface class DeviceMusicPlatform {
  /// Folders scanned by default (e.g. `~/Music`, Android `Music` + `Download`).
  Future<List<String>> defaultFolders();

  Future<DevicePermission> permissionStatus();
  Future<DevicePermission> requestPermission();
  Future<void> openPermissionSettings();

  /// Whether the user can add arbitrary folders (false on iOS).
  bool get canPickFolders;

  /// Whether music has to be imported into the app (iOS).
  bool get importsFiles;

  /// Opens a folder picker; null when cancelled.
  Future<String?> pickFolder({String? dialogTitle});

  /// Copies user-picked audio files into the app (iOS). Returns the count.
  Future<int> importFiles({String? dialogTitle});
}

/// Device music adapters for the current platform (null on web).
class DeviceMusicServices {
  const DeviceMusicServices({required this.source, required this.collections, required this.platform});
  final DeviceMusicSource source;
  final DeviceCollections collections;
  final DeviceMusicPlatform platform;
}

/// A playlist of device tracks, stored on the device.
class DevicePlaylist {
  const DevicePlaylist({
    required this.id,
    required this.name,
    required this.trackIds,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final List<String> trackIds;
  final String createdAt;
  final String updatedAt;
}

/// Port: local favorites and playlists of device tracks.
abstract interface class DeviceCollections {
  Future<Set<String>> favoriteIds();
  Future<void> setFavorite(String trackId, bool favorite);

  Future<List<DevicePlaylist>> playlists();
  Future<DevicePlaylist> createPlaylist(String name);
  Future<void> renamePlaylist(String id, String name);
  Future<void> deletePlaylist(String id);

  /// Replaces the ordered track list.
  Future<void> setPlaylistTracks(String id, List<String> trackIds);
}
