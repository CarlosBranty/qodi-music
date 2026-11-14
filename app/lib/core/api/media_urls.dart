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

  /// Null without a server session (device-only mode): no network requests.
  @override
  String? cover(String trackId) =>
      _api.hasSession ? _api.mediaUri('/tracks/$trackId/cover').toString() : null;

  @override
  Uri stream(String trackId, StreamQuality quality) => switch (quality) {
        StreamQuality.original => _api.mediaUri('/tracks/$trackId/stream', {'format': 'original'}),
        StreamQuality.opus128 =>
          _api.mediaUri('/tracks/$trackId/stream', {'format': 'opus', 'bitrate': '128'}),
      };
}
