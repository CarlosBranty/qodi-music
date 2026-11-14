import 'package:flutter_test/flutter_test.dart';
import 'package:qodi_music/features/equalizer/domain/equalizer.dart';

EqualizerParameters bands(List<double> hz, {double min = -15, double max = 15}) =>
    EqualizerParameters(minDb: min, maxDb: max, centerFrequencies: hz);

void main() {
  group('preset → per-band gains', () {
    test('10 bands at the reference frequencies use the curve as is', () {
      final p = bands(EqualizerPreset.referenceFrequencies);
      for (final preset in EqualizerPreset.values) {
        expect(preset.gainsFor(p), preset.curve, reason: preset.name);
      }
    });

    test('5 bands (typical Android) are interpolated on a log axis', () {
      final p = bands([60, 230, 910, 3600, 14000]);
      expect(EqualizerPreset.bassBoost.gainsFor(p), [5.5, 3.2, 0.2, 0, 0]);
      expect(EqualizerPreset.trebleBoost.gainsFor(p), [0, 0, 0.4, 3.3, 5.8]);
      expect(EqualizerPreset.flat.gainsFor(p), [0, 0, 0, 0, 0]);
    });

    test('3 bands', () {
      final p = bands([100, 1000, 10000]);
      expect(EqualizerPreset.bassBoost.gainsFor(p), [4.8, 0, 0]);
      expect(EqualizerPreset.rock.gainsFor(p), hasLength(3));
    });

    test('gains are clamped to the device range', () {
      final p = bands(EqualizerPreset.referenceFrequencies, min: -3, max: 3);
      expect(EqualizerPreset.rock.gainsFor(p), [3, 3, 3, 1, -1, -1, 1, 3, 3, 3]);
    });
  });

  group('settings', () {
    test('JSON round-trip keeps enabled, preset and custom gains', () {
      const custom = EqualizerSettings(enabled: true, preset: null, customGains: [1, -2.5, 3]);
      expect(EqualizerSettings.fromJson(custom.toJson()), custom);
      const rock = EqualizerSettings(enabled: false, preset: EqualizerPreset.rock);
      expect(EqualizerSettings.fromJson(rock.toJson()), rock);
    });

    test('custom gains for another band count fall back to flat', () {
      const s = EqualizerSettings(preset: null, customGains: [1, 2, 3]);
      expect(s.gainsFor(bands([60, 230, 910, 3600, 14000])), [0, 0, 0, 0, 0]);
      expect(s.gainsFor(bands([100, 1000, 10000])), [1, 2, 3]);
    });

    test('unknown or broken JSON gives the defaults', () {
      expect(EqualizerSettings.fromJson('nope'), EqualizerSettings.defaults);
      expect(EqualizerSettings.fromJson({'preset': 'zzz'}).preset, EqualizerPreset.flat);
    });
  });
}
