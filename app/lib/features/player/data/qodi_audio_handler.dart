import 'package:audio_service/audio_service.dart';

import '../../library/domain/entities.dart';
import '../domain/play_queue.dart';
import '../domain/player_port.dart';

/// Bridges [PlayerPort] to the OS media session (Android notification,
/// iOS lock screen, MPRIS on Linux, Media Session API on web).
class QodiAudioHandler extends BaseAudioHandler with SeekHandler {
  QodiAudioHandler(this._port, this._artUri) {
    _port.snapshots.listen(_sync);
    _sync(_port.snapshot);
  }

  final PlayerPort _port;
  final Uri? Function(Track track) _artUri;
  String? _lastQueueKey;

  MediaItem _toMediaItem(Track t) => MediaItem(
        id: t.id,
        title: t.title,
        artist: t.artist,
        album: t.album,
        duration: t.duration,
        artUri: t.hasCover ? _artUri(t) : null,
      );

  void _sync(PlayerSnapshot s) {
    final current = s.current;
    if (current != null && mediaItem.value?.id != current.id) {
      mediaItem.add(_toMediaItem(current));
    } else if (current != null && s.duration > Duration.zero &&
        mediaItem.value?.duration != s.duration) {
      mediaItem.add(_toMediaItem(current).copyWith(duration: s.duration));
    }
    final queueKey = s.queue.map((t) => t.id).join(',');
    if (queueKey != _lastQueueKey) {
      _lastQueueKey = queueKey;
      queue.add(s.queue.map(_toMediaItem).toList());
    }
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        s.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: current == null
          ? AudioProcessingState.idle
          : s.buffering
              ? AudioProcessingState.buffering
              : AudioProcessingState.ready,
      playing: s.playing,
      updatePosition: _port.position,
      queueIndex: s.queuePosition < 0 ? null : s.queuePosition,
      repeatMode: switch (s.repeat) {
        QueueRepeat.off => AudioServiceRepeatMode.none,
        QueueRepeat.all => AudioServiceRepeatMode.all,
        QueueRepeat.one => AudioServiceRepeatMode.one,
      },
      shuffleMode: s.shuffle ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
    ));
  }

  @override
  Future<void> play() => _port.play();

  @override
  Future<void> pause() => _port.pause();

  @override
  Future<void> stop() async {
    await _port.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _port.seek(position);

  @override
  Future<void> skipToNext() => _port.next();

  @override
  Future<void> skipToPrevious() => _port.previous();

  @override
  Future<void> skipToQueueItem(int index) => _port.jumpTo(index);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) => _port.setRepeat(switch (repeatMode) {
        AudioServiceRepeatMode.none => QueueRepeat.off,
        AudioServiceRepeatMode.one => QueueRepeat.one,
        _ => QueueRepeat.all,
      });

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) =>
      _port.setShuffle(shuffleMode != AudioServiceShuffleMode.none);
}
