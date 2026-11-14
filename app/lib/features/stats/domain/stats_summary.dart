import '../../library/domain/entities.dart';

/// Labels are localized in the Stats screen (`statsRangeLabel`).
enum StatsRange {
  week('7d'),
  month('30d'),
  all('all');

  const StatsRange(this.apiValue);
  final String apiValue;
}

class TopTrack {
  const TopTrack(this.track, this.plays);
  final Track track;
  final int plays;
}

class TopArtist {
  const TopArtist({required this.artistId, required this.name, required this.plays});
  final String artistId;
  final String name;
  final int plays;
}

class DailyListening {
  const DailyListening(this.date, this.listenMs);
  final String date; // YYYY-MM-DD
  final int listenMs;
}

class StatsSummary {
  const StatsSummary({
    required this.range,
    required this.totalPlays,
    required this.totalListenMs,
    required this.uniqueTracks,
    required this.topTracks,
    required this.topArtists,
    required this.daily,
  });

  final String range;
  final int totalPlays;
  final int totalListenMs;
  final int uniqueTracks;
  final List<TopTrack> topTracks;
  final List<TopArtist> topArtists;
  final List<DailyListening> daily;

  /// Share of plays of the top artist, 0..1.
  double get topArtistShare {
    if (topArtists.isEmpty || totalPlays == 0) return 0;
    return (topArtists.first.plays / totalPlays).clamp(0.0, 1.0);
  }
}
