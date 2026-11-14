import 'play_record.dart';

/// Decides when a listening session counts as a play.
///
/// Rule: a session (one track, from start until the track changes, stops or
/// completes) produces exactly one play when it was listened for at least
/// [threshold] or reached completion. Listened time only accumulates from
/// forward progress while playing; seeks are not counted.
class PlayRecorder {
  PlayRecorder({
    required String Function() newClientId,
    DateTime Function()? clock,
    this.threshold = const Duration(seconds: 30),
  })  : _newClientId = newClientId,
        _clock = clock ?? DateTime.now;

  final String Function() _newClientId;
  final DateTime Function() _clock;
  final Duration threshold;

  /// Largest position jump treated as continuous playback (larger = seek).
  static const _maxStep = Duration(seconds: 3);

  String? _trackId;
  DateTime? _startedAt;
  Duration _listened = Duration.zero;
  Duration? _lastPosition;
  bool _completed = false;
  bool _emitted = false;

  Duration get listened => _listened;

  /// Starts a new session for [trackId]. Returns the play of the previous
  /// session if it qualified.
  PlayRecord? start(String trackId) {
    final previous = finish();
    _trackId = trackId;
    _startedAt = _clock();
    _listened = Duration.zero;
    _lastPosition = null;
    _completed = false;
    _emitted = false;
    return previous;
  }

  /// Reports a position update for the current session.
  void progress(Duration position, {required bool playing}) {
    if (_trackId == null) return;
    final last = _lastPosition;
    _lastPosition = position;
    if (!playing || last == null) return;
    final delta = position - last;
    if (delta > Duration.zero && delta <= _maxStep) _listened += delta;
  }

  /// Marks the current session as completed and returns its play.
  PlayRecord? complete() {
    if (_trackId == null) return null;
    _completed = true;
    return finish();
  }

  /// Ends the current session. Returns its play if it qualified and was not
  /// already emitted.
  PlayRecord? finish() {
    final id = _trackId;
    if (id == null || _emitted) return null;
    if (!_completed && _listened < threshold) return null;
    _emitted = true;
    return PlayRecord(
      clientId: _newClientId(),
      trackId: id,
      playedAt: _startedAt ?? _clock(),
      listenedMs: _listened.inMilliseconds,
    );
  }
}
