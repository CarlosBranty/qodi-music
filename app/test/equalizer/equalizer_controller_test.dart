import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qodi_music/core/config/core_providers.dart';
import 'package:qodi_music/core/config/settings_store.dart';
import 'package:qodi_music/features/equalizer/domain/equalizer.dart';
import 'package:qodi_music/features/equalizer/ui/equalizer_controller.dart';

import '../support/fakes.dart';

void main() {
  Future<ProviderContainer> make(FakeEqualizer eq, {Map<String, Object> prefs = const {}}) async {
    final c = ProviderContainer(overrides: [
      ...await baseOverrides(prefs: prefs),
      equalizerPortProvider.overrideWithValue(eq),
    ], retry: (_, _) => null);
    addTearDown(c.dispose);
    return c;
  }

  test('settings persist and are re-applied when the bands become available on the next start', () async {
    final first = FakeEqualizer();
    final c1 = await make(first);
    final ctrl = c1.read(equalizerControllerProvider.notifier);
    first.reportBands(fiveBands);
    await pumpEventQueue();

    await ctrl.setEnabled(true);
    await ctrl.selectPreset(EqualizerPreset.bassBoost);
    await ctrl.setBandGain(4, 6);
    expect(c1.read(equalizerControllerProvider).settings.preset, isNull, reason: 'moving a slider means Custom');
    expect(first.gainCalls.last, [5.5, 3.2, 0.2, 0, 6]);
    expect(first.enabledCalls.last, isTrue);

    // "Restart": a new container over the same preferences.
    final store = c1.read(settingsStoreProvider);
    final second = FakeEqualizer();
    final c2 = await make(second, prefs: {'equalizer': store.prefs.getString('equalizer')!});
    final state = c2.read(equalizerControllerProvider);
    expect(state.settings, const EqualizerSettings(enabled: true, preset: null, customGains: [5.5, 3.2, 0.2, 0, 6]));
    await pumpEventQueue();
    expect(second.enabledCalls, [true], reason: 'enabled flag applied on start');
    expect(second.gainCalls, isEmpty, reason: 'no bands yet (Android: before the player is prepared)');

    second.reportBands(fiveBands);
    await pumpEventQueue();
    expect(second.gainCalls, [
      [5.5, 3.2, 0.2, 0, 6]
    ]);
    expect(c2.read(equalizerControllerProvider).gains, [5.5, 3.2, 0.2, 0, 6]);
  });

  test('a preset chosen before the bands are known is applied once they arrive', () async {
    final eq = FakeEqualizer();
    final c = await make(eq);
    await c.read(equalizerControllerProvider.notifier).selectPreset(EqualizerPreset.trebleBoost);
    expect(eq.gainCalls, isEmpty);
    eq.reportBands(fiveBands);
    await pumpEventQueue();
    expect(eq.gainCalls.single, EqualizerPreset.trebleBoost.gainsFor(fiveBands));
  });

  test('reset goes back to flat', () async {
    final eq = FakeEqualizer();
    final c = await make(eq);
    eq.reportBands(fiveBands);
    await pumpEventQueue();
    final ctrl = c.read(equalizerControllerProvider.notifier);
    await ctrl.setBandGain(0, 9);
    await ctrl.reset();
    expect(c.read(equalizerControllerProvider).settings.preset, EqualizerPreset.flat);
    expect(eq.gainCalls.last, [0, 0, 0, 0, 0]);
  });

  test('unsupported platform: nothing is sent to the engine', () async {
    final eq = FakeEqualizer(supported: false);
    final c = await make(eq);
    expect(c.read(equalizerControllerProvider).supported, isFalse);
    await pumpEventQueue();
    expect(eq.enabledCalls, isEmpty);
  });

  test('equalizer settings do not disturb the other preferences (previous behavior)', () async {
    final c = await make(FakeEqualizer(), prefs: {'theme': 'dark', 'quality': 'opus128'});
    final store = c.read(settingsStoreProvider);
    expect(store.equalizer, EqualizerSettings.defaults);
    await store.setEqualizer(const EqualizerSettings(enabled: true, preset: EqualizerPreset.pop));
    expect(store.theme, AppThemePreference.dark);
    expect(store.quality, StreamQuality.opus128);
    await store.setQuality(StreamQuality.original);
    expect(store.quality, StreamQuality.original);
    expect(store.equalizer.preset, EqualizerPreset.pop);
  });
}
