import 'entities.dart';

/// User-facing copy of the audio quality labels (kept together for translation).
abstract final class QualityStrings {
  static const hiRes = 'Hi-Res';
  static const lossless = 'Lossless';
  static const trackInfo = 'Track info';
  static const format = 'Format';
  static const bitrate = 'Bitrate';
  static const sampleRate = 'Sample rate';
  static const bitDepth = 'Bit depth';
  static const channels = 'Channels';
  static const size = 'Size';
  static const unknown = '—';
  static const mono = 'Mono';
  static const stereo = 'Stereo';
  static String channelCount(int n) => '$n channels';
  static String kbps(int n) => '$n kbps';
  static String kHz(String n) => '$n kHz';
  static String bits(int n) => '$n-bit';

  /// Now Playing while transcoding, e.g. `OPUS 128 · from FLAC 24/96`.
  static String transcodedFrom(String streamed, String source) => '$streamed · from $source';
}

/// Formats whose files are lossless whatever the server/tag reader says
/// (used when an older server omits `lossless`, and for device files).
const losslessFormats = {'flac', 'wav', 'aif', 'aiff', 'ape', 'alac', 'wv'};

bool isLosslessFormat(String format) => losslessFormats.contains(format.toLowerCase());

enum QualityTier { hiRes, lossless, lossy }

/// Hi-Res: lossless and (≥ 24-bit or > 48 kHz). Lossless: any other lossless file.
QualityTier qualityTier(Track t) {
  if (!t.lossless) return QualityTier.lossy;
  final hiRes = (t.bitDepth ?? 0) >= 24 || (t.sampleRateHz ?? 0) > 48000;
  return hiRes ? QualityTier.hiRes : QualityTier.lossless;
}

/// Badge text for a tier, or null for lossy files (no badge).
String? qualityBadgeText(QualityTier tier) => switch (tier) {
      QualityTier.hiRes => QualityStrings.hiRes,
      QualityTier.lossless => QualityStrings.lossless,
      QualityTier.lossy => null,
    };

/// `44100` → `44.1`, `96000` → `96`, `88200` → `88.2`.
String formatKHz(int hz) {
  final khz = hz / 1000;
  final text = khz.toStringAsFixed(1);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

/// Display name of a format: `FLAC`, `MP3`; lossless `m4a` is `ALAC`.
String formatName(Track t) {
  final f = t.format.toLowerCase();
  if ((f == 'm4a' || f == 'mp4') && t.lossless) return 'ALAC';
  return f.isEmpty ? '?' : f.toUpperCase();
}

/// Compact label for track rows: `FLAC · 24/96`, `FLAC · 16/44.1`,
/// `MP3 · 320`, `OPUS · 128`; just the format when nothing else is known.
String qualityLabel(Track t) {
  final name = formatName(t);
  final rate = t.sampleRateHz, depth = t.bitDepth;
  if (t.lossless) {
    if (rate != null && depth != null) return '$name · $depth/${formatKHz(rate)}';
    if (rate != null) return '$name · ${QualityStrings.kHz(formatKHz(rate))}';
    return name;
  }
  final kbps = t.bitrateKbps;
  return kbps != null && kbps > 0 ? '$name · $kbps' : name;
}

/// What Now Playing shows: the file's label, or — when the server transcodes
/// to Opus — what is actually streamed plus the source quality.
String streamedQualityLabel(Track t, {int? transcodedOpusKbps}) {
  if (transcodedOpusKbps == null) return qualityLabel(t);
  // The source reads as one phrase: `FLAC 24/96`, `MP3 320`.
  return QualityStrings.transcodedFrom('OPUS $transcodedOpusKbps', qualityLabel(t).replaceAll(' · ', ' '));
}

String channelsLabel(int n) => switch (n) {
      1 => QualityStrings.mono,
      2 => QualityStrings.stereo,
      _ => QualityStrings.channelCount(n),
    };

/// Rows of the "Track info" section of the track actions sheet.
List<(String, String)> trackInfoRows(Track t, {required String Function(int bytes) formatSize}) {
  String or(Object? v, String Function() f) => v == null ? QualityStrings.unknown : f();
  return [
    (QualityStrings.format, formatName(t)),
    (QualityStrings.bitrate, or(t.bitrateKbps, () => QualityStrings.kbps(t.bitrateKbps!))),
    (QualityStrings.sampleRate, or(t.sampleRateHz, () => QualityStrings.kHz(formatKHz(t.sampleRateHz!)))),
    (QualityStrings.bitDepth, or(t.bitDepth, () => QualityStrings.bits(t.bitDepth!))),
    (QualityStrings.channels, or(t.channels, () => channelsLabel(t.channels!))),
    (QualityStrings.size, t.sizeBytes > 0 ? formatSize(t.sizeBytes) : QualityStrings.unknown),
  ];
}
