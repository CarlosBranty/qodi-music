import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:just_audio/just_audio.dart';

import '../domain/equalizer.dart';

/// True where just_audio 0.10.x ships an equalizer effect. Only Android:
/// the package has no Darwin equalizer, and media_kit (Linux/Windows) and
/// the web player have no audio effects.
bool get equalizerPlatformSupported => !kIsWeb && Platform.isAndroid;

/// Audio pipeline for the app's [AudioPlayer]; empty without an equalizer.
AudioPipeline audioPipelineFor(AndroidEqualizer? equalizer) =>
    AudioPipeline(androidAudioEffects: [?equalizer]);

/// [EqualizerPort] adapter over just_audio's [AndroidEqualizer]. The effect
/// must be part of the player's [AudioPipeline] (see [audioPipelineFor]).
class JustAudioEqualizer implements EqualizerPort {
  JustAudioEqualizer(this._effect);

  final AndroidEqualizer _effect;

  @override
  bool get supported => true;

  @override
  Future<EqualizerParameters> get parameters async {
    final p = await _effect.parameters;
    return EqualizerParameters(
      minDb: p.minDecibels,
      maxDb: p.maxDecibels,
      centerFrequencies: [for (final b in p.bands) b.centerFrequency],
    );
  }

  @override
  Future<void> setEnabled(bool enabled) => _effect.setEnabled(enabled);

  @override
  Future<void> setGains(List<double> gains) async {
    final bands = (await _effect.parameters).bands;
    for (var i = 0; i < bands.length && i < gains.length; i++) {
      await bands[i].setGain(gains[i]);
    }
  }
}
