import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/bento_card.dart';
import '../domain/equalizer.dart';
import 'equalizer_controller.dart';

String presetLabel(AppLocalizations l, EqualizerPreset p) => switch (p) {
      EqualizerPreset.flat => l.presetFlat,
      EqualizerPreset.bassBoost => l.presetBassBoost,
      EqualizerPreset.trebleBoost => l.presetTrebleBoost,
      EqualizerPreset.vocal => l.presetVocal,
      EqualizerPreset.rock => l.presetRock,
      EqualizerPreset.pop => l.presetPop,
      EqualizerPreset.electronic => l.presetElectronic,
      EqualizerPreset.acoustic => l.presetAcoustic,
    };

/// `+1.5 dB`, `-3.0 dB` (decimal separator of [locale]).
String formatGain(double db, {String? locale}) =>
    '${db > 0 ? '+' : ''}${NumberFormat('0.0', locale).format(db)} dB';

/// "60 Hz", "910 Hz", "3.6 kHz", "14 kHz".
String formatFrequency(double hz, {String? locale}) {
  if (hz < 1000) return '${hz.round()} Hz';
  final k = hz / 1000;
  final text = k >= 10 || k == k.roundToDouble() ? k.round().toString() : NumberFormat('0.0', locale).format(k);
  return '$text kHz';
}

class EqualizerScreen extends ConsumerWidget {
  const EqualizerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(equalizerControllerProvider);
    final controller = ref.read(equalizerControllerProvider.notifier);
    final c = QodiColors.of(context);
    final l = context.l10n;
    Widget label(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
          child: Text(t, style: TextStyle(color: c.textMuted, fontWeight: FontWeight.w700)),
        );
    return Scaffold(
      appBar: AppBar(
        title: Text(l.equalizer),
        actions: [
          if (state.supported)
            TextButton(
              key: const Key('eq-reset'),
              onPressed: controller.reset,
              child: Text(l.reset),
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
                    title: Text(l.equalizer, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(l.equalizerHint),
                    onChanged: controller.setEnabled,
                  ),
                ),
                label(l.presets),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in EqualizerPreset.values)
                      ChoiceChip(
                        label: Text(presetLabel(l, p)),
                        selected: state.settings.preset == p,
                        selectedColor: QodiTokens.orange,
                        labelStyle: TextStyle(
                            color: state.settings.preset == p ? Colors.white : c.text, fontWeight: FontWeight.w600),
                        onSelected: (_) => controller.selectPreset(p),
                      ),
                    if (state.settings.preset == null)
                      ChoiceChip(
                        key: const Key('eq-custom'),
                        label: Text(l.presetCustom),
                        selected: true,
                        selectedColor: QodiTokens.orange,
                        labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
                label(l.bands),
                BentoCard(
                  child: state.parameters == null
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(l.equalizerWaitingBands,
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
    final locale = context.l10n.localeName;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Row(
        children: [
          for (var i = 0; i < params.bandCount; i++)
            Expanded(
              child: Column(
                children: [
                  Text(formatGain(i < state.gains.length ? state.gains[i] : 0, locale: locale),
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
                  Text(formatFrequency(params.centerFrequencies[i], locale: locale),
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
    final l = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: BentoCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.equalizer_rounded, size: 48, color: QodiTokens.orange),
              const SizedBox(height: 12),
              Text(l.equalizerUnavailableTitle,
                  textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 6),
              Text(l.equalizerUnavailableBody,
                  textAlign: TextAlign.center, style: TextStyle(color: c.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
