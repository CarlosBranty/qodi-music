import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/config/core_providers.dart';
import '../data/just_audio_equalizer.dart';
import '../domain/equalizer.dart';

/// The Android equalizer effect inserted into the player's pipeline; null on
/// platforms without one. Read by `playerPortProvider`.
final androidEqualizerProvider =
    Provider<AndroidEqualizer?>((ref) => equalizerPlatformSupported ? AndroidEqualizer() : null);

/// Tests override it with a fake port.
final equalizerPortProvider = Provider<EqualizerPort>((ref) {
  final effect = ref.watch(androidEqualizerProvider);
  return effect == null ? const UnsupportedEqualizer() : JustAudioEqualizer(effect);
});

class EqualizerState {
  const EqualizerState({required this.supported, required this.settings, this.parameters, this.gains = const []});

  final bool supported;
  final EqualizerSettings settings;

  /// Null until the engine reports its bands.
  final EqualizerParameters? parameters;

  /// Gains currently applied, one per band.
  final List<double> gains;

  EqualizerState copyWith({EqualizerSettings? settings, EqualizerParameters? parameters, List<double>? gains}) =>
      EqualizerState(
        supported: supported,
        settings: settings ?? this.settings,
        parameters: parameters ?? this.parameters,
        gains: gains ?? this.gains,
      );
}

final equalizerControllerProvider =
    NotifierProvider<EqualizerController, EqualizerState>(EqualizerController.new);

/// Keeps the persisted equalizer settings and the engine in sync: applies them
/// on start and again as soon as the bands become available.
class EqualizerController extends Notifier<EqualizerState> {
  EqualizerPort get _port => ref.read(equalizerPortProvider);

  @override
  EqualizerState build() {
    final port = ref.watch(equalizerPortProvider);
    final settings = ref.read(settingsStoreProvider).equalizer;
    if (!port.supported) return EqualizerState(supported: false, settings: settings);
    unawaited(port.setEnabled(settings.enabled));
    port.parameters.then((params) {
      if (!ref.mounted) return;
      final gains = state.settings.gainsFor(params);
      state = state.copyWith(parameters: params, gains: gains);
      unawaited(port.setGains(gains));
    });
    return EqualizerState(supported: true, settings: settings);
  }

  Future<void> setEnabled(bool enabled) async {
    await _save(state.settings.copyWith(enabled: enabled));
    await _port.setEnabled(enabled);
  }

  Future<void> selectPreset(EqualizerPreset preset) =>
      _apply(state.settings.copyWith(preset: preset, customGains: const []));

  /// Moves one slider; the selection becomes "Custom".
  Future<void> setBandGain(int band, double db) async {
    final params = state.parameters;
    if (params == null || band < 0 || band >= params.bandCount) return;
    final gains = List<double>.of(state.gains.length == params.bandCount
        ? state.gains
        : state.settings.gainsFor(params));
    gains[band] = params.clamp(db);
    await _apply(state.settings.copyWith(custom: true, customGains: gains));
  }

  /// Back to flat.
  Future<void> reset() => selectPreset(EqualizerPreset.flat);

  Future<void> _apply(EqualizerSettings settings) async {
    await _save(settings);
    final params = state.parameters;
    if (params == null) return;
    final gains = settings.gainsFor(params);
    state = state.copyWith(gains: gains);
    await _port.setGains(gains);
  }

  Future<void> _save(EqualizerSettings settings) async {
    state = state.copyWith(settings: settings);
    await ref.read(settingsStoreProvider).setEqualizer(settings);
  }
}
