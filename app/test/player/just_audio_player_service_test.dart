import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:qodi_music/features/player/data/just_audio_player_service.dart';
import 'package:qodi_music/features/stats/domain/play_recorder.dart';

import '../support/fixtures.dart';

/// Records the calls the service makes on the underlying player.
class _RecordingPlayer implements AudioPlayer {
  final calls = <String>[];

  @override
  Stream<PlayerState> get playerStateStream => const Stream.empty();
  @override
  Stream<Duration?> get durationStream => const Stream.empty();
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  bool get playing => false;
  @override
  Duration get position => Duration.zero;

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<Duration?> setAudioSource(AudioSource source,
      {bool preload = true, int? initialIndex, Duration? initialPosition}) async {
    calls.add('load ${(source as UriAudioSource).uri.path}');
    return null;
  }

  @override
  Future<void> play() async => calls.add('play');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

JustAudioPlayerService _service(_RecordingPlayer player, {required bool reset}) =>
    JustAudioPlayerService(
      resolveSource: (t) async => Uri.parse('http://server/tracks/${t.id}/stream'),
      recorder: PlayRecorder(newClientId: () => 'c'),
      player: player,
      resetBeforeLoad: reset,
    );

void main() {
  test('web: stops the player before loading a different track', () async {
    final player = _RecordingPlayer();
    final service = _service(player, reset: true);

    await service.playTracks([track('a'), track('b')]);
    await service.playTracks([track('a'), track('b')], startIndex: 1);
    await pumpEventQueue();

    expect(player.calls, [
      'stop', 'load /tracks/a/stream', 'play',
      'stop', 'load /tracks/b/stream', 'play',
    ]);
  });

  test('native: loads the new track without stopping first', () async {
    final player = _RecordingPlayer();
    final service = _service(player, reset: false);

    await service.playTracks([track('a'), track('b')]);
    await service.playTracks([track('a'), track('b')], startIndex: 1);
    await pumpEventQueue();

    expect(player.calls, ['load /tracks/a/stream', 'play', 'load /tracks/b/stream', 'play']);
  });
}
