import 'package:qodi_music/features/library/domain/entities.dart';

Map<String, dynamic> trackJson({
  String id = '9f2c1a7b3d4e5f60',
  String title = 'Semestre de Otoño',
  bool nulls = false,
  bool quality = true,
}) =>
    {
      'id': id,
      'title': title,
      'artist': 'José Madero',
      'artist_id': 'a1',
      'album': 'Querido',
      'album_id': 'al1',
      'album_artist': 'José Madero',
      'track_number': nulls ? null : 3,
      'disc_number': nulls ? null : 1,
      'year': nulls ? null : 2023,
      'genre': nulls ? null : 'Pop',
      'duration_ms': 214000,
      'format': 'flac',
      'bitrate_kbps': nulls ? null : 900,
      if (quality) ...{
        'sample_rate_hz': nulls ? null : 44100,
        'bit_depth': nulls ? null : 16,
        'channels': nulls ? null : 2,
        'lossless': true,
      },
      'size_bytes': 25000000,
      'has_cover': true,
      'has_lyrics': false,
      'favorite': false,
      'updated_at': '2026-11-13T20:15:00Z',
    };

Track track(
  String id, {
  String? title,
  String artist = 'Artist',
  String format = 'mp3',
  int? bitrateKbps,
  int? sampleRateHz,
  int? bitDepth,
  int? channels,
  bool lossless = false,
  int sizeBytes = 1000,
}) =>
    Track(
      id: id,
      title: title ?? 'Song $id',
      artist: artist,
      artistId: 'ar-$artist',
      album: 'Album',
      albumId: 'al',
      albumArtist: artist,
      durationMs: 200000,
      format: format,
      bitrateKbps: bitrateKbps,
      sampleRateHz: sampleRateHz,
      bitDepth: bitDepth,
      channels: channels,
      lossless: lossless,
      sizeBytes: sizeBytes,
      hasCover: false,
      hasLyrics: false,
      favorite: false,
      updatedAt: '2026-11-13T20:15:00Z',
    );
