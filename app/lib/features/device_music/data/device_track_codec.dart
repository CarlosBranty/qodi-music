import 'dart:convert';

import '../../../core/api/json.dart';
import '../../library/data/library_mappers.dart';
import '../domain/device_track.dart';

String encodeDeviceTrack(DeviceTrack t) => jsonEncode({
      'track': trackToJson(t.track),
      'path': t.path,
      'mtime_ms': t.mtimeMs,
      'size_bytes': t.sizeBytes,
      'cover_path': t.coverPath,
      'lyrics_path': t.lyricsPath,
    });

DeviceTrack decodeDeviceTrack(String raw) {
  final j = asJson(jsonDecode(raw));
  return DeviceTrack(
    track: trackFromJson(asJson(j['track'])),
    path: asString(j['path']),
    mtimeMs: asInt(j['mtime_ms']),
    sizeBytes: asInt(j['size_bytes']),
    coverPath: asStringOrNull(j['cover_path']),
    lyricsPath: asStringOrNull(j['lyrics_path']),
  );
}
