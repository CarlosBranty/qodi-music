import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/core_providers.dart';
import '../../device_music/domain/device_track.dart';
import '../data/lyrics_api.dart';
import '../domain/lyrics.dart';

final lyricsApiProvider = Provider<LyricsApi>((ref) => LyricsApi(ref.watch(apiClientProvider)));

/// Server lyrics, or the sidecar `.lrc` file for device tracks.
final lyricsProvider = FutureProvider.autoDispose.family<Lyrics?, String>((ref, trackId) async {
  if (isDeviceTrackId(trackId)) {
    final source = ref.watch(platformServicesProvider).device?.source;
    final text = await source?.readLyrics(trackId);
    return text == null ? null : parseLrc(text);
  }
  if (!ref.watch(apiClientProvider).hasSession) return null;
  return ref.watch(lyricsApiProvider).get(trackId);
});
