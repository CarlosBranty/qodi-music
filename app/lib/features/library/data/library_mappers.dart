import '../../../core/api/json.dart';
import '../domain/entities.dart';

Track trackFromJson(Json j) => Track(
      id: asString(j['id']),
      title: asString(j['title']),
      artist: asString(j['artist'], 'Unknown Artist'),
      artistId: asString(j['artist_id']),
      album: asString(j['album']),
      albumId: asString(j['album_id']),
      albumArtist: asString(j['album_artist'], asString(j['artist'])),
      trackNumber: asIntOrNull(j['track_number']),
      discNumber: asIntOrNull(j['disc_number']),
      year: asIntOrNull(j['year']),
      genre: asStringOrNull(j['genre']),
      durationMs: asInt(j['duration_ms']),
      format: asString(j['format']),
      bitrateKbps: asIntOrNull(j['bitrate_kbps']),
      sizeBytes: asInt(j['size_bytes']),
      hasCover: asBool(j['has_cover']),
      hasLyrics: asBool(j['has_lyrics']),
      favorite: asBool(j['favorite']),
      updatedAt: asString(j['updated_at']),
    );

Json trackToJson(Track t) => {
      'id': t.id,
      'title': t.title,
      'artist': t.artist,
      'artist_id': t.artistId,
      'album': t.album,
      'album_id': t.albumId,
      'album_artist': t.albumArtist,
      'track_number': t.trackNumber,
      'disc_number': t.discNumber,
      'year': t.year,
      'genre': t.genre,
      'duration_ms': t.durationMs,
      'format': t.format,
      'bitrate_kbps': t.bitrateKbps,
      'size_bytes': t.sizeBytes,
      'has_cover': t.hasCover,
      'has_lyrics': t.hasLyrics,
      'favorite': t.favorite,
      'updated_at': t.updatedAt,
    };

Album albumFromJson(Json j) => Album(
      id: asString(j['id']),
      title: asString(j['title']),
      artist: asString(j['artist']),
      artistId: asString(j['artist_id']),
      year: asIntOrNull(j['year']),
      trackCount: asInt(j['track_count']),
      durationMs: asInt(j['duration_ms']),
      coverTrackId: asStringOrNull(j['cover_track_id']),
    );

Artist artistFromJson(Json j) => Artist(
      id: asString(j['id']),
      name: asString(j['name']),
      albumCount: asInt(j['album_count']),
      trackCount: asInt(j['track_count']),
    );

LibraryChanges changesFromJson(Json j) => LibraryChanges(
      serverTime: asString(j['server_time']),
      tracks: asJsonList(j['tracks']).map(trackFromJson).toList(),
      removedTrackIds: (j['removed_track_ids'] is List)
          ? (j['removed_track_ids'] as List).whereType<String>().toList()
          : const [],
    );
