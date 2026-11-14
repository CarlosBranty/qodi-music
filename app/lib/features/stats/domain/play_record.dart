/// One listening session reported to `POST /plays`.
class PlayRecord {
  const PlayRecord({
    required this.clientId,
    required this.trackId,
    required this.playedAt,
    required this.listenedMs,
  });

  final String clientId;
  final String trackId;
  final DateTime playedAt;
  final int listenedMs;
}

/// Port for the local queue of plays not yet accepted by the server.
abstract interface class PlaysOutbox {
  Future<void> add(PlayRecord play);
  Future<List<PlayRecord>> pending();
  Future<void> remove(Iterable<String> clientIds);
}
