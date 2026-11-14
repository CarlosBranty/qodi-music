import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:just_audio/just_audio.dart';

import '../../library/domain/entities.dart';
import '../../stats/domain/play_record.dart';
import '../../stats/domain/play_recorder.dart';
import '../domain/play_queue.dart';
import '../domain/player_port.dart';

/// Resolves the playable URI of a track (local download or stream URL).
typedef TrackSourceResolver = Future<Uri> Function(Track track);

/// [PlayerPort] adapter backed by just_audio (media_kit on Linux/Windows).
/// The queue, shuffle and repeat are handled by [PlayQueue]; just_audio only
/// ever plays a single source.
class JustAudioPlayerService implements PlayerPort {
  JustAudioPlayerService({
    required TrackSourceResolver resolveSource,
    required PlayRecorder recorder,
    void Function(PlayRecord play)? onPlay,
    void Function(Track track)? onTrackStarted,
    AudioPlayer? player,
    bool? resetBeforeLoad,
  })  : _resolve = resolveSource,
        _resetBeforeLoad = resetBeforeLoad ?? kIsWeb,
        _recorder = recorder,
        _onPlay = onPlay,
        _onTrackStarted = onTrackStarted,
        _player = player ?? AudioPlayer() {
    _subs.add(_player.playerStateStream.listen(_onPlayerState, onError: (Object _) {}));
    _subs.add(_player.durationStream.listen((d) {
      if (d != null) _emit(_snap.copyWith(duration: d));
    }));
    _subs.add(_player.positionStream.listen((p) {
      _recorder.progress(p, playing: _player.playing);
    }));
  }

  final TrackSourceResolver _resolve;
  final PlayRecorder _recorder;
  final void Function(PlayRecord)? _onPlay;
  final void Function(Track)? _onTrackStarted;
  final AudioPlayer _player;

  /// just_audio_web 0.4.x reuses its cached internal playlist when a new
  /// source replaces the current one, so the browser keeps playing the first
  /// track. Stopping first forces a fresh platform player. Not needed (and
  /// it would flicker the media notification) on native platforms.
  final bool _resetBeforeLoad;
  final PlayQueue<Track> _queue = PlayQueue<Track>();
  final _snapshots = StreamController<PlayerSnapshot>.broadcast();
  final List<StreamSubscription<dynamic>> _subs = [];
  PlayerSnapshot _snap = PlayerSnapshot.empty;
  int _loadToken = 0;
  bool _completing = false;

  @override
  PlayerSnapshot get snapshot => _snap;

  @override
  Stream<PlayerSnapshot> get snapshots => _snapshots.stream;

  @override
  Duration get position => _player.position;

  @override
  Stream<Duration> get positions => _player.positionStream;

  void _emit(PlayerSnapshot s) {
    _snap = s;
    if (!_snapshots.isClosed) _snapshots.add(s);
  }

  PlayerSnapshot _queueSnapshot({Track? current}) => PlayerSnapshot(
        current: current ?? _queue.current,
        queue: _queue.playOrder,
        queuePosition: _queue.position,
        playing: _player.playing,
        buffering: _snap.buffering,
        duration: _snap.duration,
        repeat: _queue.repeat,
        shuffle: _queue.shuffle,
      );

  void _report(PlayRecord? play) {
    if (play != null) _onPlay?.call(play);
  }

  void _onPlayerState(PlayerState state) {
    final buffering = state.processingState == ProcessingState.loading ||
        state.processingState == ProcessingState.buffering;
    _emit(_snap.copyWith(playing: state.playing, buffering: buffering));
    if (state.processingState == ProcessingState.completed) {
      _handleCompleted();
    }
  }

  Future<void> _handleCompleted() async {
    if (_completing) return;
    _completing = true;
    try {
      _report(_recorder.complete());
      final next = _queue.next(auto: true);
      if (next == null) {
        await _player.pause();
        await _player.seek(Duration.zero);
        _emit(_queueSnapshot().copyWith(playing: false));
      } else {
        await _load(next);
      }
    } finally {
      _completing = false;
    }
  }

  Future<void> _load(Track track, {bool autoplay = true}) async {
    final token = ++_loadToken;
    _report(_recorder.start(track.id));
    _onTrackStarted?.call(track);
    _emit(_queueSnapshot(current: track).copyWith(duration: track.duration, buffering: true));
    try {
      final uri = await _resolve(track);
      if (token != _loadToken) return;
      if (_resetBeforeLoad) {
        await _player.stop();
        if (token != _loadToken) return;
      }
      await _player.setAudioSource(AudioSource.uri(uri, tag: track.id));
      if (token != _loadToken) return;
      if (autoplay) unawaited(_player.play());
    } catch (e) {
      if (token != _loadToken) return;
      _emit(_snap.copyWith(buffering: false, playing: false, error: 'Cannot play "${track.title}"'));
    }
  }

  @override
  Future<void> playTracks(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    _queue.load(tracks, startIndex: startIndex);
    await _load(_queue.current!);
  }

  @override
  Future<void> play() async {
    if (_queue.current == null) return;
    unawaited(_player.play());
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> togglePlay() => _player.playing ? pause() : play();

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _emit(_snap.copyWith());
  }

  @override
  Future<void> next() async {
    final t = _queue.next();
    if (t != null) await _load(t);
  }

  @override
  Future<void> previous() async {
    if (_player.position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    }
    final before = _queue.position;
    final t = _queue.previous();
    if (t == null) return;
    if (_queue.position == before) {
      await seek(Duration.zero);
    } else {
      await _load(t);
    }
  }

  @override
  Future<void> jumpTo(int position) async {
    if (position == _queue.position) return;
    final t = _queue.jumpToPosition(position);
    if (t != null) await _load(t);
  }

  @override
  Future<void> setRepeat(QueueRepeat mode) async {
    _queue.repeat = mode;
    _emit(_snap.copyWith(repeat: mode));
  }

  @override
  Future<void> setShuffle(bool enabled) async {
    _queue.setShuffle(enabled);
    _emit(_queueSnapshot());
  }

  @override
  Future<void> enqueue(Track track) async {
    final wasEmpty = _queue.isEmpty;
    _queue.add(track);
    if (wasEmpty) {
      await _load(track);
    } else {
      _emit(_queueSnapshot());
    }
  }

  @override
  Future<void> playNext(Track track) async {
    final wasEmpty = _queue.isEmpty;
    _queue.playNext(track);
    if (wasEmpty) {
      await _load(track);
    } else {
      _emit(_queueSnapshot());
    }
  }

  @override
  Future<void> stop() async {
    _report(_recorder.finish());
    await _player.stop();
    _emit(_snap.copyWith(playing: false));
  }

  /// Ends the current listening session (e.g. when the app is closing).
  void flushSession() => _report(_recorder.finish());

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _player.dispose();
    await _snapshots.close();
  }
}
