import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../library/domain/entities.dart';

/// Prefix of every on-device track id. Server ids are plain hex strings, so a
/// device id can never collide with a server id.
const deviceTrackIdPrefix = 'device:';

/// Prefixes of the album/artist ids derived for device tracks (URL-safe, used
/// in routes).
const deviceAlbumIdPrefix = 'device-album-';
const deviceArtistIdPrefix = 'device-artist-';

bool isDeviceTrackId(String id) => id.startsWith(deviceTrackIdPrefix);

String _hash(String value) => sha1.convert(utf8.encode(value)).toString().substring(0, 24);

/// Stable id of a device file: `device:` + hash of its absolute path.
String deviceTrackId(String absolutePath) => '$deviceTrackIdPrefix${_hash(absolutePath)}';

String deviceAlbumId(String albumArtist, String album) =>
    '$deviceAlbumIdPrefix${_hash('${albumArtist.toLowerCase()}\n${album.toLowerCase()}')}';

String deviceArtistId(String artist) => '$deviceArtistIdPrefix${_hash(artist.toLowerCase())}';

/// A track found on the device: the shared [Track] entity plus where it lives
/// and the file stamp used for incremental rescans.
class DeviceTrack {
  const DeviceTrack({
    required this.track,
    required this.path,
    required this.mtimeMs,
    required this.sizeBytes,
    this.coverPath,
    this.lyricsPath,
  });

  final Track track;

  /// Absolute path of the audio file.
  final String path;
  final int mtimeMs;
  final int sizeBytes;

  /// Extracted embedded cover (app cache dir) or a sidecar image next to it.
  final String? coverPath;

  /// Sidecar `.lrc` file next to the audio file.
  final String? lyricsPath;

  String get id => track.id;
}

/// Size + modification time of a file; a changed stamp means "read again".
class FileStamp {
  const FileStamp(this.path, this.mtimeMs, this.sizeBytes);
  final String path;
  final int mtimeMs;
  final int sizeBytes;

  bool sameAs(FileStamp other) => other.mtimeMs == mtimeMs && other.sizeBytes == sizeBytes;
}

/// Result of a rescan.
class DeviceScanReport {
  const DeviceScanReport({
    required this.added,
    required this.updated,
    required this.removed,
    required this.unchanged,
    this.unreadableFolders = const [],
  });

  final int added;
  final int updated;
  final int removed;
  final int unchanged;

  /// Scan folders that do not exist or cannot be read.
  final List<String> unreadableFolders;

  int get total => added + updated + unchanged;
}

/// Audio extensions picked up by the scanner (lower case, without dot).
const deviceAudioExtensions = {
  'mp3', 'flac', 'm4a', 'mp4', 'aac', 'ogg', 'oga', 'opus', 'wav', 'aif', 'aiff', 'ape', 'wma', 'webm',
};
