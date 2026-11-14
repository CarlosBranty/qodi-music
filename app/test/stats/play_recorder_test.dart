import 'package:flutter_test/flutter_test.dart';
import 'package:qodi_music/features/stats/domain/play_record.dart';
import 'package:qodi_music/features/stats/domain/play_recorder.dart';

void main() {
  late int ids;
  late PlayRecorder recorder;
  final start = DateTime.utc(2026, 11, 13, 20);

  setUp(() {
    ids = 0;
    recorder = PlayRecorder(newClientId: () => 'c${++ids}', clock: () => start);
  });

  /// Simulates playback from [from] to [to] in 500 ms steps.
  void listen(Duration from, Duration to) {
    for (var p = from; p <= to; p += const Duration(milliseconds: 500)) {
      recorder.progress(p, playing: true);
    }
  }

  test('listening >= 30s records exactly one play when the session ends', () {
    recorder.start('t1');
    listen(Duration.zero, const Duration(seconds: 45));
    final play = recorder.start('t2');
    expect(play, isNotNull);
    expect(play!.trackId, 't1');
    expect(play.clientId, 'c1');
    expect(play.playedAt, start);
    expect(play.listenedMs, 45000);
    expect(recorder.finish(), isNull, reason: 't2 has not been listened');
  });

  test('less than 30s and not completed records nothing', () {
    recorder.start('t1');
    listen(Duration.zero, const Duration(seconds: 29));
    expect(recorder.start('t2'), isNull);
  });

  test('completion records one play even if shorter than 30s', () {
    recorder.start('short');
    listen(Duration.zero, const Duration(seconds: 12));
    final play = recorder.complete();
    expect(play?.trackId, 'short');
    expect(play?.listenedMs, 12000);
    // Further finish/start/complete calls do not duplicate it.
    expect(recorder.complete(), isNull);
    expect(recorder.finish(), isNull);
    expect(recorder.start('next'), isNull);
  });

  test('a session over 30s that also completes records exactly one play', () {
    final plays = <PlayRecord>[];
    recorder.start('t1');
    listen(Duration.zero, const Duration(seconds: 40));
    final p1 = recorder.complete();
    if (p1 != null) plays.add(p1);
    final p2 = recorder.start('t2');
    if (p2 != null) plays.add(p2);
    expect(plays.map((p) => p.trackId), ['t1']);
  });

  test('seeking forward does not count as listening', () {
    recorder.start('t1');
    listen(Duration.zero, const Duration(seconds: 5));
    recorder.progress(const Duration(minutes: 3), playing: true); // seek
    listen(const Duration(minutes: 3), const Duration(minutes: 3, seconds: 10));
    expect(recorder.listened, const Duration(seconds: 15));
    expect(recorder.finish(), isNull);
  });

  test('paused progress is not counted', () {
    recorder.start('t1');
    for (var s = 0; s <= 60; s++) {
      recorder.progress(Duration(seconds: s), playing: false);
    }
    expect(recorder.listened, Duration.zero);
  });
}
