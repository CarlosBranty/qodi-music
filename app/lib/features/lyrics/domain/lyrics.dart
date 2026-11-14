class LyricLine {
  const LyricLine(this.time, this.text);

  /// Start time of the line; null for plain (unsynced) lyrics.
  final Duration? time;
  final String text;
}

class Lyrics {
  const Lyrics({required this.synced, required this.lines});

  final bool synced;
  final List<LyricLine> lines;

  /// Index of the line that should be highlighted at [position]: the last
  /// line whose time is <= position. Returns -1 before the first timed line
  /// and always for unsynced lyrics. Lines without a time are skipped.
  int activeLineIndex(Duration position) {
    if (!synced) return -1;
    var active = -1;
    for (var i = 0; i < lines.length; i++) {
      final t = lines[i].time;
      if (t == null) continue;
      if (t <= position) {
        active = i;
      } else {
        break;
      }
    }
    return active;
  }
}

final _lrcTime = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
final _lrcTag = RegExp(r'^\[[a-zA-Z#]+:.*\]$');

/// Parses an `.lrc` file. Timed lines (`[mm:ss.xx]text`, several stamps per
/// line allowed) give synced lyrics sorted by time; files without stamps give
/// plain lyrics. Header tags like `[ar:...]` are ignored. Returns null when
/// there is no text at all.
Lyrics? parseLrc(String source) {
  final timed = <LyricLine>[];
  final plain = <String>[];
  for (final raw in source.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final stamps = _lrcTime.allMatches(line).toList();
    if (stamps.isEmpty || stamps.first.start != 0) {
      if (!_lrcTag.hasMatch(line)) plain.add(line);
      continue;
    }
    final text = line.substring(stamps.last.end).trim();
    for (final m in stamps) {
      final frac = m.group(3) ?? '0';
      final ms = int.parse(frac.padRight(3, '0').substring(0, 3));
      timed.add(LyricLine(
        Duration(minutes: int.parse(m.group(1)!), seconds: int.parse(m.group(2)!), milliseconds: ms),
        text,
      ));
    }
  }
  if (timed.isNotEmpty) {
    timed.sort((a, b) => a.time!.compareTo(b.time!));
    return Lyrics(synced: true, lines: timed);
  }
  if (plain.isEmpty) return null;
  return Lyrics(synced: false, lines: [for (final l in plain) LyricLine(null, l)]);
}
