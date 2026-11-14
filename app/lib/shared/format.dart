import 'package:intl/intl.dart' show NumberFormat;

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

/// `1.5 GB`, `12.0 MB`, `300 KB` (decimal separator of [locale]).
String formatBytes(int bytes, {String? locale}) {
  final one = NumberFormat('0.0', locale), none = NumberFormat('0', locale);
  if (bytes >= 1 << 30) return '${one.format(bytes / (1 << 30))} GB';
  if (bytes >= 1 << 20) return '${one.format(bytes / (1 << 20))} MB';
  return '${none.format(bytes / 1024)} KB';
}
