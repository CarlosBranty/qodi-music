import 'package:flutter_test/flutter_test.dart';
import 'package:qodi_music/features/player/domain/track_source.dart';

import '../support/fake_device.dart';
import '../support/fixtures.dart';

void main() {
  final device = deviceTrack('/home/u/Music/a song.flac').track;

  Future<Uri> resolve(t, {String? devicePath, String? download}) => resolveTrackSource(
        t,
        devicePath: (_) async => devicePath,
        downloadPath: (_) async => download,
        stream: (t) => Uri.parse('http://nas/stream/${t.id}'),
      );

  test('device track plays its local file', () async {
    final uri = await resolve(device, devicePath: '/home/u/Music/a song.flac');
    expect(uri.scheme, 'file');
    expect(uri.toFilePath(), '/home/u/Music/a song.flac');
  });

  test('device track never falls back to a server stream', () async {
    expect(() => resolve(device, devicePath: null, download: '/x'), throwsA(isA<DeviceTrackUnavailable>()));
  });

  test('server track keeps preferring the download, then the stream', () async {
    expect((await resolve(track('s1'), download: '/dl/s1.flac')).toFilePath(), '/dl/s1.flac');
    expect((await resolve(track('s1'))).toString(), 'http://nas/stream/s1');
  });
}
