import 'package:qodi_music/features/device_music/domain/device_metadata.dart';
import 'package:qodi_music/features/device_music/domain/device_music_source.dart';
import 'package:qodi_music/features/device_music/domain/device_track.dart';

DeviceTrack deviceTrack(String path, {String? title, String? artist, String? album}) => buildDeviceTrack(
      path: path,
      mtimeMs: 1000,
      sizeBytes: 2000,
      tags: RawTags(title: title, artist: artist, album: album, durationMs: 180000),
    );

class FakeDeviceSource implements DeviceMusicSource {
  FakeDeviceSource([List<DeviceTrack>? items]) : items = items ?? [];
  List<DeviceTrack> items;
  final List<List<String>> rescans = [];

  @override
  Future<List<DeviceTrack>> tracks() async => items;

  @override
  Future<DeviceScanReport> rescan(List<String> folders) async {
    rescans.add(folders);
    return DeviceScanReport(added: 0, updated: 0, removed: 0, unchanged: items.length);
  }

  @override
  String? pathOf(String trackId) => items.where((t) => t.id == trackId).firstOrNull?.path;

  @override
  String? coverPathOf(String trackId) => null;

  @override
  Future<String?> readLyrics(String trackId) async => null;
}

class MemoryDeviceCollections implements DeviceCollections {
  final Set<String> favorites = {};
  final Map<String, DevicePlaylist> lists = {};
  int _next = 0;

  @override
  Future<Set<String>> favoriteIds() async => {...favorites};

  @override
  Future<void> setFavorite(String trackId, bool favorite) async =>
      favorite ? favorites.add(trackId) : favorites.remove(trackId);

  @override
  Future<List<DevicePlaylist>> playlists() async => lists.values.toList();

  @override
  Future<DevicePlaylist> createPlaylist(String name) async {
    final p = DevicePlaylist(id: 'p${_next++}', name: name, trackIds: const [], createdAt: 't', updatedAt: 't');
    lists[p.id] = p;
    return p;
  }

  @override
  Future<void> renamePlaylist(String id, String name) async {
    final p = lists[id]!;
    lists[id] = DevicePlaylist(id: id, name: name, trackIds: p.trackIds, createdAt: p.createdAt, updatedAt: 't');
  }

  @override
  Future<void> deletePlaylist(String id) async => lists.remove(id);

  @override
  Future<void> setPlaylistTracks(String id, List<String> trackIds) async {
    final p = lists[id]!;
    lists[id] = DevicePlaylist(id: id, name: p.name, trackIds: trackIds, createdAt: p.createdAt, updatedAt: 't');
  }
}

class FakeDevicePlatform implements DeviceMusicPlatform {
  FakeDevicePlatform({this.status = DevicePermission.notRequired, this.onRequest});
  DevicePermission status;
  DevicePermission? onRequest;
  int requests = 0;
  int settingsOpened = 0;

  @override
  bool get canPickFolders => true;
  @override
  bool get importsFiles => false;
  @override
  Future<List<String>> defaultFolders() async => const ['/music'];
  @override
  Future<int> importFiles() async => 0;
  @override
  Future<void> openPermissionSettings() async => settingsOpened++;
  @override
  Future<DevicePermission> permissionStatus() async => status;
  @override
  Future<String?> pickFolder() async => null;
  @override
  Future<DevicePermission> requestPermission() async {
    requests++;
    if (onRequest != null) status = onRequest!;
    return status;
  }
}

DeviceMusicServices fakeDeviceServices({
  List<DeviceTrack>? tracks,
  FakeDevicePlatform? platform,
  MemoryDeviceCollections? collections,
}) =>
    DeviceMusicServices(
      source: FakeDeviceSource(tracks),
      collections: collections ?? MemoryDeviceCollections(),
      platform: platform ?? FakeDevicePlatform(),
    );
