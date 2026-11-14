import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:qodi_music/features/equalizer/data/just_audio_equalizer.dart';
import 'package:qodi_music/features/equalizer/domain/equalizer.dart';
import 'package:qodi_music/features/equalizer/ui/equalizer_controller.dart';
import 'package:qodi_music/features/player/data/just_audio_player_service.dart';
import 'package:qodi_music/features/player/ui/player_providers.dart';

import '../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the Android equalizer is inserted into the audio pipeline', () {
    final eq = AndroidEqualizer();
    expect(audioPipelineFor(eq).androidAudioEffects, [eq]);
    expect(audioPipelineFor(null).androidAudioEffects, isEmpty);
    expect(audioPipelineFor(null).darwinAudioEffects, isEmpty);
  });

  test('host platforms without an equalizer use the null port', () async {
    final c = ProviderContainer(overrides: await baseOverrides(), retry: (_, _) => null);
    addTearDown(c.dispose);
    expect(c.read(androidEqualizerProvider), isNull);
    expect(c.read(equalizerPortProvider), isA<UnsupportedEqualizer>());
  });

  test('the player port is still a just_audio service (previous behavior)', () async {
    final c = ProviderContainer(overrides: await baseOverrides(), retry: (_, _) => null);
    addTearDown(c.dispose);
    expect(c.read(playerPortProvider), isA<JustAudioPlayerService>());
  });

  test('the player port builds with the equalizer in its pipeline (Android)', () async {
    final eq = AndroidEqualizer();
    final c = ProviderContainer(
        overrides: [...await baseOverrides(), androidEqualizerProvider.overrideWithValue(eq)],
        retry: (_, _) => null);
    addTearDown(c.dispose);
    expect(c.read(playerPortProvider), isA<JustAudioPlayerService>());
    expect(c.read(equalizerPortProvider), isA<JustAudioEqualizer>());
  });
}
