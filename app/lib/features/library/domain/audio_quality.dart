import 'entities.dart';

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
    if (rate != null) return '$name · ${formatKHz(rate)} kHz';
    return name;
  }
  final kbps = t.bitrateKbps;
  return kbps != null && kbps > 0 ? '$name · $kbps' : name;
}
