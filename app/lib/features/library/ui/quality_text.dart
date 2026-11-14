import '../../../l10n/l10n.dart';
import '../domain/audio_quality.dart';
import '../domain/entities.dart';

/// Badge text for a tier, or null for lossy files (no badge).
String? qualityBadgeText(AppLocalizations l, QualityTier tier) => switch (tier) {
      QualityTier.hiRes => l.qualityHiRes,
      QualityTier.lossless => l.qualityLossless,
      QualityTier.lossy => null,
    };

/// What Now Playing shows: the file's label, or — when the server transcodes
/// to Opus — what is actually streamed plus the source quality, e.g.
/// `OPUS 128 · from FLAC 24/96`.
String streamedQualityLabel(AppLocalizations l, Track t, {int? transcodedOpusKbps}) {
  if (transcodedOpusKbps == null) return qualityLabel(t);
  // The source reads as one phrase: `FLAC 24/96`, `MP3 320`.
  return l.transcodedFrom('OPUS $transcodedOpusKbps', qualityLabel(t).replaceAll(' · ', ' '));
}

String channelsLabel(AppLocalizations l, int n) => switch (n) {
      1 => l.channelsMono,
      2 => l.channelsStereo,
      _ => l.channelCount(n),
    };

/// Rows of the "Track info" dialog.
List<(String, String)> trackInfoRows(AppLocalizations l, Track t, {required String Function(int bytes) formatSize}) {
  const unknown = '—';
  String or(Object? v, String Function() f) => v == null ? unknown : f();
  return [
    (l.infoFormat, formatName(t)),
    (l.infoBitrate, or(t.bitrateKbps, () => l.kbpsValue(t.bitrateKbps!))),
    (l.infoSampleRate, or(t.sampleRateHz, () => l.kHzValue(formatKHz(t.sampleRateHz!)))),
    (l.infoBitDepth, or(t.bitDepth, () => l.bitsValue(t.bitDepth!))),
    (l.infoChannels, or(t.channels, () => channelsLabel(l, t.channels!))),
    (l.infoSize, t.sizeBytes > 0 ? formatSize(t.sizeBytes) : unknown),
  ];
}
