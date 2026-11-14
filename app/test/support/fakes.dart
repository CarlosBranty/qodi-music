import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:qodi_music/core/api/media_urls.dart';
import 'package:qodi_music/core/config/core_providers.dart';
import 'package:qodi_music/core/config/settings_store.dart';
import 'package:qodi_music/core/platform/platform_services.dart';
import 'package:qodi_music/features/device_music/domain/device_music_source.dart';
import 'package:qodi_music/features/downloads/domain/download_store.dart';
import 'package:qodi_music/features/equalizer/domain/equalizer.dart';
import 'package:qodi_music/features/favorites/domain/favorites_repository.dart';
import 'package:qodi_music/features/favorites/ui/favorites_controller.dart';
import 'package:qodi_music/features/library/data/memory_library_cache.dart';
import 'package:qodi_music/features/library/domain/entities.dart';
import 'package:qodi_music/features/library/ui/library_providers.dart';
import 'package:qodi_music/features/player/domain/play_queue.dart';
import 'package:qodi_music/features/player/domain/player_port.dart';
import 'package:qodi_music/features/player/ui/player_providers.dart';
import 'package:qodi_music/features/stats/data/prefs_plays_outbox.dart';
import 'package:qodi_music/features/update/ui/update_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakePlayer implements PlayerPort {
  FakePlayer(Track track) : _snap = PlayerSnapshot(current: track, queue: [track], queuePosition: 0);

  PlayerSnapshot _snap;
  final _ctrl = StreamController<PlayerSnapshot>.broadcast();
  int toggles = 0;

  /// Queues passed to [playTracks] (with their start index).
  final List<(List<Track>, int)> played = [];

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
  Future<void> playTracks(List<Track> tracks, {int startIndex = 0}) async {
    played.add((tracks, startIndex));
    _emit(_snap.copyWith(current: tracks[startIndex], queue: tracks, queuePosition: startIndex, playing: true));
  }
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
  int listCalls = 0;
  @override
  Future<void> add(String trackId) async {}
  @override
  Future<List<Track>> list() async {
    listCalls++;
    return items;
  }
  @override
  Future<void> remove(String trackId) async {}
}

Future<List<Override>> baseOverrides({
  Map<String, Object> prefs = const {},
  DeviceMusicServices? device,
  FavoritesRepository? favorites,
  bool updatesSupported = false,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final p = await SharedPreferences.getInstance();
  return [
    settingsStoreProvider.overrideWithValue(SettingsStore(p)),
    platformServicesProvider.overrideWithValue(PlatformServices(
      cache: MemoryLibraryCache(),
      outbox: PrefsPlaysOutbox(p),
      createDownloads: (_) => null,
      device: device,
    )),
    mediaUrlsProvider.overrideWithValue(NoCoverUrls()),
    favoritesRepositoryProvider.overrideWithValue(favorites ?? FakeFavorites()),
    waveformProvider.overrideWith((ref, id) async => List<double>.filled(120, 0.5)),
    // flutter_test reports Android: keep self-update off unless a test opts in.
    updatesSupportedProvider.overrideWithValue(updatesSupported),
  ];
}

Override playerOverride(PlayerPort port) => playerPortProvider.overrideWithValue(port);

/// In-memory [DownloadStore]: [downloaded] ids are "on disk".
class FakeDownloadStore implements DownloadStore {
  FakeDownloadStore([Set<String>? downloaded]) : downloaded = downloaded ?? {};
  final Set<String> downloaded;

  @override
  Future<Set<String>> downloadedIds() async => {...downloaded};
  @override
  Future<String?> localPath(String trackId) async => downloaded.contains(trackId) ? '/music/$trackId' : null;
  @override
  Future<void> download(String trackId, Uri url, String extension, {void Function(double progress)? onProgress}) async =>
      downloaded.add(trackId);
  @override
  Future<void> delete(String trackId) async => downloaded.remove(trackId);
  @override
  Future<int> totalBytes() async => downloaded.length;
}

/// Scriptable [EqualizerPort]: [reportBands] simulates the engine reporting
/// its bands after the player is prepared.
class FakeEqualizer implements EqualizerPort {
  FakeEqualizer({this.supported = true});

  @override
  final bool supported;
  final _params = Completer<EqualizerParameters>();
  final List<bool> enabledCalls = [];
  final List<List<double>> gainCalls = [];

  void reportBands(EqualizerParameters p) => _params.complete(p);

  @override
  Future<EqualizerParameters> get parameters => _params.future;
  @override
  Future<void> setEnabled(bool enabled) async => enabledCalls.add(enabled);
  @override
  Future<void> setGains(List<double> gains) async => gainCalls.add(List.of(gains));
}

const fiveBands = EqualizerParameters(minDb: -15, maxDb: 15, centerFrequencies: [60, 230, 910, 3600, 14000]);
