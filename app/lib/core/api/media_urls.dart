import '../config/settings_store.dart';
import 'api_client.dart';

/// Builds media URLs (with `?token=`) for covers and audio streams.
abstract interface class MediaUrls {
  /// Cover image URL of a track, or null when covers are unavailable.
  String? cover(String trackId);
  Uri stream(String trackId, StreamQuality quality);
}

class ApiMediaUrls implements MediaUrls {
  ApiMediaUrls(this._api);
  final ApiClient _api;

  @override
  String? cover(String trackId) => _api.mediaUri('/tracks/$trackId/cover').toString();

  @override
  Uri stream(String trackId, StreamQuality quality) => switch (quality) {
        StreamQuality.original => _api.mediaUri('/tracks/$trackId/stream', {'format': 'original'}),
        StreamQuality.opus128 =>
          _api.mediaUri('/tracks/$trackId/stream', {'format': 'opus', 'bitrate': '128'}),
      };
}
