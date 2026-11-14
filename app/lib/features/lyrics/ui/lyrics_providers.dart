import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/core_providers.dart';
import '../data/lyrics_api.dart';
import '../domain/lyrics.dart';

final lyricsApiProvider = Provider<LyricsApi>((ref) => LyricsApi(ref.watch(apiClientProvider)));

final lyricsProvider = FutureProvider.autoDispose.family<Lyrics?, String>(
    (ref, trackId) => ref.watch(lyricsApiProvider).get(trackId));
