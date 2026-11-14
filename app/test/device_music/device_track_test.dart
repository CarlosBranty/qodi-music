import 'package:flutter_test/flutter_test.dart';
import 'package:qodi_music/features/device_music/data/device_track_codec.dart';
import 'package:qodi_music/features/device_music/domain/device_library.dart';
import 'package:qodi_music/features/device_music/domain/device_metadata.dart';
import 'package:qodi_music/features/device_music/domain/device_track.dart';

import '../support/fixtures.dart';

void main() {
  group('device track id', () {
    test('is stable, prefixed and distinct per path', () {
      final a = deviceTrackId('/home/u/Music/a.flac');
      expect(a, startsWith('device:'));
      expect(deviceTrackId('/home/u/Music/a.flac'), a);
      expect(deviceTrackId('/home/u/Music/b.flac'), isNot(a));
      expect(isDeviceTrackId(a), isTrue);
    });

    test('never matches a server id', () {
      final serverId = trackJson()['id'] as String;
      expect(isDeviceTrackId(serverId), isFalse);
      expect(deviceTrackId('/x/$serverId'), isNot(serverId));
    });

    test('album and artist ids are URL-safe and case-insensitive', () {
      expect(deviceAlbumId('Artist', 'Album'), deviceAlbumId('artist', 'ALBUM'));
      expect(deviceArtistId('José'), startsWith(deviceArtistIdPrefix));
      expect(Uri.encodeComponent(deviceAlbumId('a', 'b')), deviceAlbumId('a', 'b'));
    });
  });

  group('metadata fallback', () {
    test('untagged file uses file name, Unknown Artist and folder name', () {
      final t = buildDeviceTrack(path: '/m/Querido/03 Semestre.flac', mtimeMs: 5, sizeBytes: 10).track;
      expect(t.title, '03 Semestre');
      expect(t.artist, unknownArtist);
      expect(t.album, 'Querido');
      expect(t.albumArtist, unknownArtist);
      expect(t.format, 'flac');
      expect(t.sizeBytes, 10);
      expect(t.hasCover, isFalse);
      expect(t.hasLyrics, isFalse);
      expect(t.id, deviceTrackId('/m/Querido/03 Semestre.flac'));
    });

    test('tags win; blank tags are ignored; album artist defaults to artist', () {
      final t = buildDeviceTrack(
        path: '/m/x/file.mp3',
        mtimeMs: 5,
        sizeBytes: 10,
        tags: const RawTags(title: '  Song ', artist: 'Band', album: '   ', trackNumber: 0, durationMs: 1234),
        coverPath: '/cache/c.cover',
        lyricsPath: '/m/x/file.lrc',
      ).track;
      expect(t.title, 'Song');
      expect(t.artist, 'Band');
      expect(t.album, 'x', reason: 'blank album falls back to the folder');
      expect(t.albumArtist, 'Band');
      expect(t.trackNumber, isNull, reason: 'non-positive numbers are dropped');
      expect(t.durationMs, 1234);
      expect(t.hasCover, isTrue);
      expect(t.hasLyrics, isTrue);
    });

    test('file at the root of a folder with no name falls back to Unknown Album', () {
      expect(buildDeviceTrack(path: '/song.ogg', mtimeMs: 1, sizeBytes: 1).track.album, unknownAlbum);
    });

    test('codec round-trips a device track', () {
      final d = buildDeviceTrack(path: '/m/a/b.mp3', mtimeMs: 7, sizeBytes: 9, coverPath: '/c', lyricsPath: '/l');
      final back = decodeDeviceTrack(encodeDeviceTrack(d));
      expect(back.path, d.path);
      expect(back.mtimeMs, 7);
      expect(back.coverPath, '/c');
      expect(back.lyricsPath, '/l');
      expect(back.track.id, d.track.id);
      expect(back.track.album, 'a');
    });
  });

  group('scan plan', () {
    test('detects new, changed, unchanged and removed files', () {
      const known = {
        '/a': FileStamp('/a', 1, 10),
        '/b': FileStamp('/b', 1, 10),
        '/gone': FileStamp('/gone', 1, 10),
      };
      final plan = planScan(const [
        FileStamp('/a', 1, 10), // unchanged
        FileStamp('/b', 2, 10), // changed mtime
        FileStamp('/new', 1, 1), // new
        FileStamp('/new', 1, 1), // duplicate (overlapping folders)
      ], known);
      expect(plan.unchanged, ['/a']);
      expect(plan.toRead.map((f) => f.path), ['/b', '/new']);
      expect(plan.newPaths, {'/new'});
      expect(plan.removed, ['/gone']);
    });
  });

  group('grouping and search', () {
    final tracks = [
      buildDeviceTrack(path: '/m/A/2.mp3', mtimeMs: 1, sizeBytes: 1, tags: const RawTags(title: 'Two', artist: 'X', album: 'A', trackNumber: 2)).track,
      buildDeviceTrack(path: '/m/A/1.mp3', mtimeMs: 1, sizeBytes: 1, tags: const RawTags(title: 'One', artist: 'X', album: 'A', trackNumber: 1)).track,
      buildDeviceTrack(path: '/m/B/1.mp3', mtimeMs: 1, sizeBytes: 1, tags: const RawTags(title: 'Other', artist: 'Y', album: 'B')).track,
    ];

    test('albums, artists and album track order', () {
      final albums = deviceAlbums(tracks);
      expect(albums.map((a) => a.title), ['A', 'B']);
      expect(albums.first.trackCount, 2);
      expect(albumTracks(tracks, albums.first.id).map((t) => t.title), ['One', 'Two']);
      expect(deviceArtists(tracks).map((a) => a.name), ['X', 'Y']);
    });

    test('search matches every word across title, artist and album', () {
      expect(searchTracks(tracks, 'two x').map((t) => t.title), ['Two']);
      expect(searchTracks(tracks, 'y b').map((t) => t.title), ['Other']);
      expect(searchTracks(tracks, '  ').length, 3);
      expect(searchTracks(tracks, 'nothing'), isEmpty);
    });
  });
}
