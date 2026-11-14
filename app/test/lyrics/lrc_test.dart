import 'package:flutter_test/flutter_test.dart';
import 'package:qodi_music/features/lyrics/domain/lyrics.dart';

void main() {
  test('parses timed lines, multiple stamps and ignores header tags', () {
    final l = parseLrc('[ar:Someone]\n[ti:Song]\n[00:12.50]Hello\n[00:05.00][00:20.1]Chorus\n\n')!;
    expect(l.synced, isTrue);
    expect(l.lines.map((e) => e.text), ['Chorus', 'Hello', 'Chorus']);
    expect(l.lines.map((e) => e.time), [
      const Duration(seconds: 5),
      const Duration(seconds: 12, milliseconds: 500),
      const Duration(seconds: 20, milliseconds: 100),
    ]);
    expect(l.activeLineIndex(const Duration(seconds: 13)), 1);
  });

  test('text without stamps gives plain lyrics', () {
    final l = parseLrc('line one\r\nline two')!;
    expect(l.synced, isFalse);
    expect(l.lines.map((e) => e.text), ['line one', 'line two']);
  });

  test('empty or tag-only files give null', () {
    expect(parseLrc(''), isNull);
    expect(parseLrc('[ar:x]\n'), isNull);
  });
}
