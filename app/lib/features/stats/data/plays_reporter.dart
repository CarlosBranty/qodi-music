import '../../device_music/domain/device_track.dart';
import '../domain/play_record.dart';
import 'stats_api.dart';

/// Queues plays locally and flushes them to `POST /plays`. Plays stay in the
/// outbox until the server answers 2xx; the server deduplicates by client_id
/// so resending is safe.
///
/// Device tracks (`device:` ids) are never queued nor sent. Without a server
/// session ([canFlush] false) plays stay queued and nothing is sent.
class PlaysReporter {
  PlaysReporter(this._api, this._outbox, {bool Function()? canFlush}) : _canFlush = canFlush ?? (() => true);

  final StatsApi _api;
  final PlaysOutbox _outbox;
  final bool Function() _canFlush;
  Future<void>? _inFlight;

  Future<void> record(PlayRecord play) async {
    if (isDeviceTrackId(play.trackId)) return;
    await _outbox.add(play);
    await flush();
  }

  Future<void> flush() {
    if (!_canFlush()) return Future.value();
    return _inFlight ??= _flush().whenComplete(() => _inFlight = null);
  }

  Future<void> _flush() async {
    final pending = await _outbox.pending();
    if (pending.isEmpty) return;
    try {
      await _api.submitPlays(pending);
      await _outbox.remove(pending.map((p) => p.clientId));
    } catch (_) {
      // Keep them queued; retried on next start / resume / play.
    }
  }
}
