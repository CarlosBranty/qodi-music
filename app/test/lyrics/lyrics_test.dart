import 'package:flutter_test/flutter_test.dart';
import 'package:qodi_music/features/lyrics/domain/lyrics.dart';

void main() {
  const synced = Lyrics(synced: true, lines: [
    LyricLine(Duration(seconds: 5), 'one'),
    LyricLine(Duration(seconds: 10), 'two'),
    LyricLine(null, 'untimed'),
    LyricLine(Duration(seconds: 20), 'three'),
  ]);

  test('no active line before the first timestamp', () {
    expect(synced.activeLineIndex(const Duration(seconds: 4)), -1);
  });

  test('active line is the last line whose time is <= position', () {
    expect(synced.activeLineIndex(const Duration(seconds: 5)), 0);
    expect(synced.activeLineIndex(const Duration(milliseconds: 9999)), 0);
    expect(synced.activeLineIndex(const Duration(seconds: 10)), 1);
    expect(synced.activeLineIndex(const Duration(seconds: 19)), 1, reason: 'untimed lines are skipped');
    expect(synced.activeLineIndex(const Duration(seconds: 20)), 3);
    expect(synced.activeLineIndex(const Duration(minutes: 5)), 3);
  });

  test('plain lyrics never highlight a line', () {
    const plain = Lyrics(synced: false, lines: [LyricLine(null, 'a'), LyricLine(null, 'b')]);
    expect(plain.activeLineIndex(const Duration(seconds: 30)), -1);
  });
}
