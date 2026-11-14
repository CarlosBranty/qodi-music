import 'dart:async';
import 'dart:math' as math;

/// Bands reported by the audio engine. Gains are in decibels.
class EqualizerParameters {
  const EqualizerParameters({
    required this.minDb,
    required this.maxDb,
    required this.centerFrequencies,
  });

  final double minDb;
  final double maxDb;

  /// Center frequency of each band in hertz, low to high.
  final List<double> centerFrequencies;

  int get bandCount => centerFrequencies.length;

  double clamp(double db) => db.clamp(minDb, maxDb).toDouble();
}

/// Port to the platform equalizer.
abstract interface class EqualizerPort {
  /// False on platforms whose audio engine has no equalizer.
  bool get supported;

  /// Completes once the engine reports its bands (on Android only after the
  /// player has been prepared the first time). Never completes when
  /// unsupported.
  Future<EqualizerParameters> get parameters;

  Future<void> setEnabled(bool enabled);

  /// Applies one gain per band (same order as [EqualizerParameters]).
  Future<void> setGains(List<double> gains);
}

/// Null object for platforms without an equalizer (web, Linux, Windows, iOS,
/// macOS with just_audio 0.10.x).
class UnsupportedEqualizer implements EqualizerPort {
  const UnsupportedEqualizer();

  @override
  bool get supported => false;

  @override
  Future<EqualizerParameters> get parameters => Completer<EqualizerParameters>().future;

  @override
  Future<void> setEnabled(bool enabled) async {}

  @override
  Future<void> setGains(List<double> gains) async {}
}

/// Built-in presets, defined as dB curves over a 10-band reference
/// (31 Hz … 16 kHz) and interpolated onto whatever bands the device reports.
enum EqualizerPreset {
  flat([0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  bassBoost([6, 5.5, 4.5, 3, 1.5, 0, 0, 0, 0, 0]),
  trebleBoost([0, 0, 0, 0, 0, 0.5, 2, 3.5, 5, 6]),
  vocal([-2, -2, -1, 1, 3, 4, 3.5, 2, 0, -1]),
  rock([5, 4, 3, 1, -1, -1, 1, 3, 4, 5]),
  pop([-1, 0, 1.5, 3, 4, 3, 1.5, 0, -0.5, -1]),
  electronic([5, 4.5, 2, 0, -1.5, 1, 0.5, 2, 4, 5]),
  acoustic([3, 3, 2.5, 1, 1.5, 1.5, 2.5, 3, 2.5, 1.5]);

  const EqualizerPreset(this.curve);

  /// Gains at [referenceFrequencies].
  final List<double> curve;

  static const referenceFrequencies = <double>[31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];

  /// The preset's gain for each band of [params], interpolated on a
  /// logarithmic frequency axis and clamped to the device range.
  List<double> gainsFor(EqualizerParameters params) =>
      [for (final hz in params.centerFrequencies) params.clamp(_round(_gainAt(hz)))];

  double _gainAt(double hz) {
    const ref = referenceFrequencies;
    if (hz <= ref.first) return curve.first;
    if (hz >= ref.last) return curve.last;
    final x = math.log(hz);
    for (var i = 0; i < ref.length - 1; i++) {
      if (hz <= ref[i + 1]) {
        final x0 = math.log(ref[i]), x1 = math.log(ref[i + 1]);
        final t = (x - x0) / (x1 - x0);
        return curve[i] + (curve[i + 1] - curve[i]) * t;
      }
    }
    return curve.last;
  }

  static double _round(double v) => (v * 10).roundToDouble() / 10;
}

/// What the user chose; persisted in the settings store.
class EqualizerSettings {
  const EqualizerSettings({
    this.enabled = false,
    this.preset = EqualizerPreset.flat,
    this.customGains = const [],
  });

  final bool enabled;

  /// Null means "Custom" (the user moved a slider).
  final EqualizerPreset? preset;

  /// Per-band gains used when [preset] is null.
  final List<double> customGains;

  static const defaults = EqualizerSettings();

  /// Gains to apply for the device bands. Custom gains saved for a different
  /// band count fall back to flat.
  List<double> gainsFor(EqualizerParameters params) {
    final p = preset;
    if (p != null) return p.gainsFor(params);
    if (customGains.length != params.bandCount) return EqualizerPreset.flat.gainsFor(params);
    return [for (final g in customGains) params.clamp(g)];
  }

  EqualizerSettings copyWith({bool? enabled, EqualizerPreset? preset, bool custom = false, List<double>? customGains}) =>
      EqualizerSettings(
        enabled: enabled ?? this.enabled,
        preset: custom ? null : (preset ?? this.preset),
        customGains: customGains ?? this.customGains,
      );

  Map<String, Object?> toJson() => {
        'enabled': enabled,
        'preset': preset?.name ?? 'custom',
        'custom_gains': customGains,
      };

  static EqualizerSettings fromJson(Object? json) {
    if (json is! Map) return defaults;
    final presetName = json['preset'];
    final gains = json['custom_gains'];
    return EqualizerSettings(
      enabled: json['enabled'] == true,
      preset: presetName == 'custom'
          ? null
          : EqualizerPreset.values.firstWhere((p) => p.name == presetName, orElse: () => EqualizerPreset.flat),
      customGains: gains is List ? [for (final g in gains) if (g is num) g.toDouble()] : const [],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EqualizerSettings &&
      other.enabled == enabled &&
      other.preset == preset &&
      _listEquals(other.customGains, customGains);

  @override
  int get hashCode => Object.hash(enabled, preset, Object.hashAll(customGains));
}

bool _listEquals(List<double> a, List<double> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
