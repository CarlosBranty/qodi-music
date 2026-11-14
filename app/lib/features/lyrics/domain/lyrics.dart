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
