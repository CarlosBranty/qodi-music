import '../domain/play_record.dart';
import 'stats_api.dart';

/// Queues plays locally and flushes them to `POST /plays`. Plays stay in the
/// outbox until the server answers 2xx; the server deduplicates by client_id
/// so resending is safe.
class PlaysReporter {
  PlaysReporter(this._api, this._outbox);

  final StatsApi _api;
  final PlaysOutbox _outbox;
  Future<void>? _inFlight;

  Future<void> record(PlayRecord play) async {
    await _outbox.add(play);
    await flush();
  }

  Future<void> flush() => _inFlight ??= _flush().whenComplete(() => _inFlight = null);

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
