import 'package:flutter_test/flutter_test.dart';
import 'package:qodi_music/features/device_music/domain/device_metadata.dart';
import 'package:qodi_music/features/library/data/library_mappers.dart';
import 'package:qodi_music/features/library/domain/audio_quality.dart';
import 'package:qodi_music/features/library/ui/quality_text.dart';
import 'package:qodi_music/shared/format.dart';

import '../support/fixtures.dart';
import '../support/l10n.dart';

void main() {
  group('Track quality parsing', () {
    test('reads sample rate, bit depth, channels and lossless', () {
      final t = trackFromJson(trackJson());
      expect((t.sampleRateHz, t.bitDepth, t.channels, t.lossless), (44100, 16, 2, true));
    });

    test('older servers without the fields: nulls, lossless derived from the format', () {
      final flac = trackFromJson(trackJson(quality: false));
      expect((flac.sampleRateHz, flac.bitDepth, flac.channels, flac.lossless), (null, null, null, true));
      final mp3 = trackFromJson({...trackJson(quality: false), 'format': 'mp3'});
      expect(mp3.lossless, isFalse);
    });

    test('explicit nulls are accepted', () {
      final t = trackFromJson(trackJson(nulls: true));
      expect((t.sampleRateHz, t.bitDepth, t.channels), (null, null, null));
    });

    test('round-trips through the local cache JSON', () {
      final t = trackFromJson(trackToJson(trackFromJson(trackJson())));
      expect((t.sampleRateHz, t.bitDepth, t.channels, t.lossless), (44100, 16, 2, true));
    });
  });

  group('quality label and badge', () {
    final cases = [
      (track('a', format: 'flac', lossless: true, bitDepth: 24, sampleRateHz: 96000), 'FLAC · 24/96', QualityTier.hiRes),
      (track('b', format: 'flac', lossless: true, bitDepth: 16, sampleRateHz: 44100), 'FLAC · 16/44.1', QualityTier.lossless),
      (track('c', format: 'flac', lossless: true, bitDepth: 16, sampleRateHz: 88200), 'FLAC · 16/88.2', QualityTier.hiRes),
      (track('d', format: 'wav', lossless: true, bitDepth: 24, sampleRateHz: 48000), 'WAV · 24/48', QualityTier.hiRes),
      (track('e', format: 'm4a', lossless: true, bitDepth: 16, sampleRateHz: 44100), 'ALAC · 16/44.1', QualityTier.lossless),
      (track('f', format: 'mp3', bitrateKbps: 320, sampleRateHz: 44100), 'MP3 · 320', QualityTier.lossy),
      (track('g', format: 'opus', bitrateKbps: 128, sampleRateHz: 48000), 'OPUS · 128', QualityTier.lossy),
      (track('h', format: 'flac', lossless: true), 'FLAC', QualityTier.lossless),
      (track('i', format: 'flac', lossless: true, sampleRateHz: 96000), 'FLAC · 96 kHz', QualityTier.hiRes),
      (track('j', format: 'ogg'), 'OGG', QualityTier.lossy),
    ];
    for (final (t, label, tier) in cases) {
      test('$label → ${tier.name}', () {
        expect(qualityLabel(t), label);
        expect(qualityTier(t), tier);
      });
    }

    test('badge text: Hi-Res, Lossless, none for lossy', () {
      expect(qualityBadgeText(en, QualityTier.hiRes), 'Hi-Res');
      expect(qualityBadgeText(en, QualityTier.lossless), 'Lossless');
      expect(qualityBadgeText(en, QualityTier.lossy), isNull);
    });

    test('transcoded stream says what is streamed and the source', () {
      final t = track('a', format: 'flac', lossless: true, bitDepth: 24, sampleRateHz: 96000);
      expect(streamedQualityLabel(en, t, transcodedOpusKbps: 128), 'OPUS 128 · from FLAC 24/96');
      expect(streamedQualityLabel(en, t), 'FLAC · 24/96');
    });

    test('track info rows: format, bitrate, sample rate, bit depth, channels, size', () {
      final t = track('a',
          format: 'flac', lossless: true, bitrateKbps: 900, bitDepth: 24, sampleRateHz: 96000, channels: 2, sizeBytes: 25 << 20);
      expect(trackInfoRows(en, t, formatSize: formatBytes), [
        ('Format', 'FLAC'),
        ('Bitrate', '900 kbps'),
        ('Sample rate', '96 kHz'),
        ('Bit depth', '24-bit'),
        ('Channels', 'Stereo'),
        ('Size', '25.0 MB'),
      ]);
      expect(trackInfoRows(en, track('b', format: 'mp3'), formatSize: formatBytes).sublist(1, 5).map((r) => r.$2),
          everyElement('—'));
    });
  });

  group('device tracks', () {
    test('sample rate from the tag reader; lossless from the extension', () {
      final flac = buildDeviceTrack(
          path: '/m/a.flac', mtimeMs: 1, sizeBytes: 10, tags: const RawTags(sampleRateHz: 96000)).track;
      expect((flac.sampleRateHz, flac.lossless, qualityLabel(flac)), (96000, true, 'FLAC · 96 kHz'));
      final mp3 = buildDeviceTrack(path: '/m/b.mp3', mtimeMs: 1, sizeBytes: 10).track;
      expect((mp3.lossless, qualityLabel(mp3)), (false, 'MP3'));
    });
  });
}
