import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:qodi_music/core/api/media_urls.dart';
import 'package:qodi_music/core/config/core_providers.dart';
import 'package:qodi_music/core/config/settings_store.dart';
import 'package:qodi_music/core/platform/platform_services.dart';
import 'package:qodi_music/features/favorites/domain/favorites_repository.dart';
import 'package:qodi_music/features/favorites/ui/favorites_controller.dart';
import 'package:qodi_music/features/library/data/memory_library_cache.dart';
import 'package:qodi_music/features/library/domain/entities.dart';
import 'package:qodi_music/features/library/ui/library_providers.dart';
import 'package:qodi_music/features/player/domain/play_queue.dart';
import 'package:qodi_music/features/player/domain/player_port.dart';
import 'package:qodi_music/features/player/ui/player_providers.dart';
import 'package:qodi_music/features/stats/data/prefs_plays_outbox.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakePlayer implements PlayerPort {
  FakePlayer(Track track) : _snap = PlayerSnapshot(current: track, queue: [track], queuePosition: 0);

  PlayerSnapshot _snap;
  final _ctrl = StreamController<PlayerSnapshot>.broadcast();
  int toggles = 0;

  void _emit(PlayerSnapshot s) {
    _snap = s;
    _ctrl.add(s);
  }

  @override
  PlayerSnapshot get snapshot => _snap;
  @override
  Stream<PlayerSnapshot> get snapshots => _ctrl.stream;
  @override
  Duration get position => const Duration(seconds: 137);
  @override
  Stream<Duration> get positions => const Stream.empty();

  @override
  Future<void> togglePlay() async {
    toggles++;
    _emit(_snap.copyWith(playing: !_snap.playing));
  }

  @override
  Future<void> play() async => _emit(_snap.copyWith(playing: true));
  @override
  Future<void> pause() async => _emit(_snap.copyWith(playing: false));
  @override
  Future<void> playTracks(List<Track> tracks, {int startIndex = 0}) async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> next() async {}
  @override
  Future<void> previous() async {}
  @override
  Future<void> jumpTo(int position) async {}
  @override
  Future<void> setRepeat(QueueRepeat mode) async => _emit(_snap.copyWith(repeat: mode));
  @override
  Future<void> setShuffle(bool enabled) async {}
  @override
  Future<void> enqueue(Track track) async {}
  @override
  Future<void> playNext(Track track) async {}
  @override
  Future<void> stop() async {}
}

class NoCoverUrls implements MediaUrls {
  @override
  String? cover(String trackId) => null;
  @override
  Uri stream(String trackId, StreamQuality quality) => Uri.parse('http://test/$trackId');
}

class FakeFavorites implements FavoritesRepository {
  final List<Track> items = [];
  @override
  Future<void> add(String trackId) async {}
  @override
  Future<List<Track>> list() async => items;
  @override
  Future<void> remove(String trackId) async {}
}

Future<List<Override>> baseOverrides({Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final p = await SharedPreferences.getInstance();
  return [
    settingsStoreProvider.overrideWithValue(SettingsStore(p)),
    platformServicesProvider.overrideWithValue(PlatformServices(
      cache: MemoryLibraryCache(),
      outbox: PrefsPlaysOutbox(p),
      createDownloads: (_) => null,
    )),
    mediaUrlsProvider.overrideWithValue(NoCoverUrls()),
    favoritesRepositoryProvider.overrideWithValue(FakeFavorites()),
    waveformProvider.overrideWith((ref, id) async => List<double>.filled(120, 0.5)),
  ];
}

Override playerOverride(PlayerPort port) => playerPortProvider.overrideWithValue(port);
