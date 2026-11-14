import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/bento_card.dart';
import '../domain/equalizer.dart';
import 'equalizer_controller.dart';

/// User-facing copy of the equalizer (kept together for translation).
abstract final class EqualizerStrings {
  static const title = 'Equalizer';
  static const reset = 'Reset';
  static const enabled = 'Equalizer';
  static const enabledHint = 'Shape the sound with presets or your own curve';
  static const presets = 'Presets';
  static const bands = 'Bands';
  static const custom = 'Custom';
  static const unavailableTitle = 'Not available on this platform';
  static const unavailableBody = 'The equalizer works on Android. On this device the audio engine has no equalizer.';
  static const waitingBands = 'Play a song to load the equalizer bands of this device.';

  static String preset(EqualizerPreset p) => switch (p) {
        EqualizerPreset.flat => 'Flat',
        EqualizerPreset.bassBoost => 'Bass boost',
        EqualizerPreset.trebleBoost => 'Treble boost',
        EqualizerPreset.vocal => 'Vocal',
        EqualizerPreset.rock => 'Rock',
        EqualizerPreset.pop => 'Pop',
        EqualizerPreset.electronic => 'Electronic',
        EqualizerPreset.acoustic => 'Acoustic',
      };

  static String gain(double db) => '${db > 0 ? '+' : ''}${db.toStringAsFixed(1)} dB';
}

/// "60 Hz", "910 Hz", "3.6 kHz", "14 kHz".
String formatFrequency(double hz) {
  if (hz < 1000) return '${hz.round()} Hz';
  final k = hz / 1000;
  final text = k >= 10 || k == k.roundToDouble() ? k.round().toString() : k.toStringAsFixed(1);
  return '$text kHz';
}

class EqualizerScreen extends ConsumerWidget {
  const EqualizerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(equalizerControllerProvider);
    final controller = ref.read(equalizerControllerProvider.notifier);
    final c = QodiColors.of(context);
    Widget label(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
          child: Text(t, style: TextStyle(color: c.textMuted, fontWeight: FontWeight.w700)),
        );
    return Scaffold(
      appBar: AppBar(
        title: const Text(EqualizerStrings.title),
        actions: [
          if (state.supported)
            TextButton(
              key: const Key('eq-reset'),
              onPressed: controller.reset,
              child: const Text(EqualizerStrings.reset),
            ),
        ],
      ),
      body: !state.supported
          ? const _Unavailable()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                BentoCard(
                  padding: EdgeInsets.zero,
                  child: SwitchListTile(
                    key: const Key('eq-enabled'),
                    value: state.settings.enabled,
                    activeThumbColor: QodiTokens.orange,
                    secondary: const Icon(Icons.equalizer_rounded, color: QodiTokens.orange),
                    title: const Text(EqualizerStrings.enabled, style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text(EqualizerStrings.enabledHint),
                    onChanged: controller.setEnabled,
                  ),
                ),
                label(EqualizerStrings.presets),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in EqualizerPreset.values)
                      ChoiceChip(
                        label: Text(EqualizerStrings.preset(p)),
                        selected: state.settings.preset == p,
                        selectedColor: QodiTokens.orange,
                        labelStyle: TextStyle(
                            color: state.settings.preset == p ? Colors.white : c.text, fontWeight: FontWeight.w600),
                        onSelected: (_) => controller.selectPreset(p),
                      ),
                    if (state.settings.preset == null)
                      const ChoiceChip(
                        key: Key('eq-custom'),
                        label: Text(EqualizerStrings.custom),
                        selected: true,
                        selectedColor: QodiTokens.orange,
                        labelStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
                label(EqualizerStrings.bands),
                BentoCard(
                  child: state.parameters == null
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(EqualizerStrings.waitingBands,
                              textAlign: TextAlign.center, style: TextStyle(color: c.textMuted)),
                        )
                      : _Bands(state: state, onChanged: controller.setBandGain),
                ),
              ],
            ),
    );
  }
}

class _Bands extends StatelessWidget {
  const _Bands({required this.state, required this.onChanged});
  final EqualizerState state;
  final void Function(int band, double db) onChanged;

  @override
  Widget build(BuildContext context) {
    final params = state.parameters!;
    final c = QodiColors.of(context);
    final enabled = state.settings.enabled;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Row(
        children: [
          for (var i = 0; i < params.bandCount; i++)
            Expanded(
              child: Column(
                children: [
                  Text(EqualizerStrings.gain(i < state.gains.length ? state.gains[i] : 0),
                      style: TextStyle(color: c.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
                  SizedBox(
                    height: 220,
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Slider(
                        key: Key('eq-band-$i'),
                        value: params.clamp(i < state.gains.length ? state.gains[i] : 0),
                        min: params.minDb,
                        max: params.maxDb,
                        activeColor: QodiTokens.orange,
                        inactiveColor: c.waveRest,
                        onChanged: enabled ? (v) => onChanged(i, (v * 10).roundToDouble() / 10) : null,
                      ),
                    ),
                  ),
                  Text(formatFrequency(params.centerFrequencies[i]),
                      maxLines: 1,
                      style: TextStyle(color: c.text, fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    final c = QodiColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: BentoCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.equalizer_rounded, size: 48, color: QodiTokens.orange),
              const SizedBox(height: 12),
              const Text(EqualizerStrings.unavailableTitle,
                  textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 6),
              Text(EqualizerStrings.unavailableBody,
                  textAlign: TextAlign.center, style: TextStyle(color: c.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
