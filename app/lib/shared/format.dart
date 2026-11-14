String _two(int n) => n.toString().padLeft(2, '0');

/// `3:05` or `1:02:03`.
String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return h > 0 ? '$h:${_two(m)}:${_two(s)}' : '$m:${_two(s)}';
}

/// Now-playing clock style: `02.17`.
String formatClock(Duration d) => '${_two(d.inMinutes)}.${_two(d.inSeconds.remainder(60))}';

/// Listening time summary: `14 h 20 min`, `35 min`.
String formatListenTime(int ms) {
  final d = Duration(milliseconds: ms);
  if (d.inHours >= 1) return '${d.inHours} h ${d.inMinutes.remainder(60)} min';
  return '${d.inMinutes} min';
}

String formatBytes(int bytes) {
  if (bytes >= 1 << 30) return '${(bytes / (1 << 30)).toStringAsFixed(1)} GB';
  if (bytes >= 1 << 20) return '${(bytes / (1 << 20)).toStringAsFixed(1)} MB';
  return '${(bytes / 1024).toStringAsFixed(0)} KB';
}

String songsLabel(int n) => n == 1 ? '1 Song' : '$n Songs';
