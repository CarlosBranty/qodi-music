import '../../library/domain/entities.dart';
import 'play_queue.dart';

class PlayerSnapshot {
  const PlayerSnapshot({
    this.current,
    this.queue = const [],
    this.queuePosition = -1,
    this.playing = false,
    this.buffering = false,
    this.duration = Duration.zero,
    this.repeat = QueueRepeat.off,
    this.shuffle = false,
    this.error,
  });

  final Track? current;

  /// Tracks in play order.
  final List<Track> queue;
  final int queuePosition;
  final bool playing;
  final bool buffering;
  final Duration duration;
  final QueueRepeat repeat;
  final bool shuffle;
  final String? error;

  static const empty = PlayerSnapshot();

  PlayerSnapshot copyWith({
    Track? current,
    List<Track>? queue,
    int? queuePosition,
    bool? playing,
    bool? buffering,
    Duration? duration,
    QueueRepeat? repeat,
    bool? shuffle,
    String? error,
  }) =>
      PlayerSnapshot(
        current: current ?? this.current,
        queue: queue ?? this.queue,
        queuePosition: queuePosition ?? this.queuePosition,
        playing: playing ?? this.playing,
        buffering: buffering ?? this.buffering,
        duration: duration ?? this.duration,
        repeat: repeat ?? this.repeat,
        shuffle: shuffle ?? this.shuffle,
        error: error,
      );
}

/// Port the UI uses to control playback.
abstract interface class PlayerPort {
  PlayerSnapshot get snapshot;
  Stream<PlayerSnapshot> get snapshots;
  Duration get position;
  Stream<Duration> get positions;

  Future<void> playTracks(List<Track> tracks, {int startIndex = 0});
  Future<void> play();
  Future<void> pause();
  Future<void> togglePlay();
  Future<void> seek(Duration position);
  Future<void> next();
  Future<void> previous();

  /// Jumps to [position] in the play order.
  Future<void> jumpTo(int position);
  Future<void> setRepeat(QueueRepeat mode);
  Future<void> setShuffle(bool enabled);
  Future<void> enqueue(Track track);
  Future<void> playNext(Track track);
  Future<void> stop();
}
