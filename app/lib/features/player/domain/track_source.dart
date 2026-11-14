import '../../device_music/domain/device_track.dart';
import '../../library/domain/entities.dart';

/// Thrown when a device track's file is no longer known/available.
class DeviceTrackUnavailable implements Exception {
  const DeviceTrackUnavailable(this.trackId);
  final String trackId;
  @override
  String toString() => 'This song is no longer on the device';
}

/// Resolves the playable URI of [track]:
/// - device tracks play their local file (`file://`),
/// - server tracks prefer a downloaded copy, else the stream URL.
Future<Uri> resolveTrackSource(
  Track track, {
  required Future<String?> Function(String trackId) devicePath,
  required Future<String?> Function(String trackId) downloadPath,
  required Uri Function(Track track) stream,
}) async {
  if (isDeviceTrackId(track.id)) {
    final path = await devicePath(track.id);
    if (path == null) throw DeviceTrackUnavailable(track.id);
    return Uri.file(path);
  }
  final local = await downloadPath(track.id);
  if (local != null) return Uri.file(local);
  return stream(track);
}
