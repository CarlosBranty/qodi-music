import '../../features/library/domain/entities.dart';
import '../config/settings_store.dart';
import 'api_client.dart';

/// Apple Lossless (ALAC in `.m4a`): Android (ExoPlayer) and browsers cannot
/// decode it, so the server transcodes it to FLAC, which is just as lossless.
bool needsLosslessTranscode(Track track) => track.format == 'm4a' && track.lossless;

/// File extension of the original-quality audio the server sends for [track].
String originalExtension(Track track) => needsLosslessTranscode(track) ? 'flac' : track.format;

/// Builds media URLs (with `?token=`) for covers and audio streams.
abstract interface class MediaUrls {
  /// Cover image URL of a track, or null when covers are unavailable.
  String? cover(String trackId);
  /// Original quality sends the file as is, except Apple Lossless (lossless FLAC).
  Uri stream(Track track, StreamQuality quality);
}

class ApiMediaUrls implements MediaUrls {
  ApiMediaUrls(this._api);
  final ApiClient _api;

  /// Null without a server session (device-only mode): no network requests.
  @override
  String? cover(String trackId) =>
      _api.hasSession ? _api.mediaUri('/tracks/$trackId/cover').toString() : null;

  @override
  Uri stream(Track track, StreamQuality quality) => switch (quality) {
        StreamQuality.original => _api.mediaUri('/tracks/${track.id}/stream',
            {'format': needsLosslessTranscode(track) ? 'flac' : 'original'}),
        StreamQuality.opus128 =>
          _api.mediaUri('/tracks/${track.id}/stream', {'format': 'opus', 'bitrate': '128'}),
      };
}
