import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qodi_music/core/theme/app_theme.dart';
import 'package:qodi_music/features/equalizer/domain/equalizer.dart';
import 'package:qodi_music/features/equalizer/ui/equalizer_controller.dart';
import 'package:qodi_music/features/equalizer/ui/equalizer_screen.dart';
import 'package:qodi_music/features/settings/ui/settings_screen.dart';

import '../support/fakes.dart';

const _session = {'server_url': 'http://nas:4040', 'token': 'tok', 'username': 'sajra'};

Future<ProviderContainer> _pump(WidgetTester tester, Widget home, FakeEqualizer eq) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(overrides: [
    ...await baseOverrides(prefs: _session),
    equalizerPortProvider.overrideWithValue(eq),
  ], retry: (_, _) => null);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(theme: AppTheme.light(useGoogleFonts: false), home: home),
  ));
  await tester.pump();
  return container;
}

void main() {
  testWidgets('unsupported platform: "not available" state and no Settings entry', (tester) async {
    final eq = FakeEqualizer(supported: false);
    await _pump(tester, const EqualizerScreen(), eq);
    expect(find.text(EqualizerStrings.unavailableTitle), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.byKey(const Key('eq-enabled')), findsNothing);

    await _pump(tester, const SettingsScreen(), eq);
    expect(find.byKey(const Key('settings-equalizer')), findsNothing);
  });

  testWidgets('supported: switch, presets and one slider per reported band', (tester) async {
    final eq = FakeEqualizer();
    final c = await _pump(tester, const EqualizerScreen(), eq);
    expect(find.text(EqualizerStrings.waitingBands), findsOneWidget, reason: 'bands not reported yet');

    eq.reportBands(fiveBands);
    await tester.pump();
    await tester.pump();
    expect(find.byType(Slider), findsNWidgets(5));
    for (final label in ['60 Hz', '230 Hz', '910 Hz', '3.6 kHz', '14 kHz']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Bass boost'), findsOneWidget);

    await tester.tap(find.byKey(const Key('eq-enabled')));
    await tester.pump();
    expect(eq.enabledCalls.last, isTrue);

    await tester.tap(find.text('Rock'));
    await tester.pump();
    expect(eq.gainCalls.last, EqualizerPreset.rock.gainsFor(fiveBands));

    await tester.drag(find.byKey(const Key('eq-band-0')), const Offset(0, -60));
    await tester.pump();
    expect(find.byKey(const Key('eq-custom')), findsOneWidget, reason: 'moving a slider selects Custom');
    expect(c.read(equalizerControllerProvider).settings.preset, isNull);

    await tester.tap(find.byKey(const Key('eq-reset')));
    await tester.pump();
    expect(eq.gainCalls.last, [0, 0, 0, 0, 0]);
    expect(find.byKey(const Key('eq-custom')), findsNothing);
  });

  testWidgets('supported: Settings shows the Equalizer entry', (tester) async {
    await _pump(tester, const SettingsScreen(), FakeEqualizer());
    expect(find.byKey(const Key('settings-equalizer')), findsOneWidget);
  });

  test('frequency labels', () {
    expect(formatFrequency(60), '60 Hz');
    expect(formatFrequency(910), '910 Hz');
    expect(formatFrequency(3600), '3.6 kHz');
    expect(formatFrequency(14000), '14 kHz');
    expect(formatFrequency(1000), '1 kHz');
  });
}
