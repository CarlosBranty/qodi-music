import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qodi_music/core/theme/app_theme.dart';
import 'package:qodi_music/features/library/ui/track_actions.dart';
import 'package:qodi_music/features/player/ui/now_playing_screen.dart';
import 'package:qodi_music/shared/widgets/track_tile.dart';

import '../support/fakes.dart';
import '../support/fixtures.dart';
import '../support/l10n.dart';

const _session = {'server_url': 'http://nas:4040', 'token': 'tok', 'username': 'alice'};
final _hiRes = track('t1',
    title: 'Semestre de Otoño',
    artist: 'José Madero',
    format: 'flac',
    lossless: true,
    bitDepth: 24,
    sampleRateHz: 96000,
    channels: 2,
    bitrateKbps: 2800,
    sizeBytes: 50 << 20);

Future<void> _pump(WidgetTester tester, Widget home, {Map<String, Object> prefs = _session}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [...await baseOverrides(prefs: prefs), playerOverride(FakePlayer(_hiRes))],
    retry: (_, _) => null,
    child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        theme: AppTheme.light(useGoogleFonts: false), home: home),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('track rows show the compact quality label next to the artist', (tester) async {
    await _pump(
        tester,
        Scaffold(
          body: Column(children: [
            TrackTile(track: _hiRes),
            TrackTile(track: track('t2', format: 'mp3', bitrateKbps: 320, artist: 'Band')),
          ]),
        ));
    expect(find.text('José Madero'), findsOneWidget, reason: 'artist line unchanged');
    expect(find.text('FLAC · 24/96'), findsOneWidget);
    expect(find.text('MP3 · 320'), findsOneWidget);
  });

  testWidgets('Now Playing: Hi-Res badge and the original quality', (tester) async {
    await _pump(tester, const NowPlayingScreen());
    expect(find.text('Hi-Res'), findsOneWidget);
    expect(find.text('FLAC · 24/96'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Now Playing with Opus 128: says what is streamed, no lossless badge', (tester) async {
    await _pump(tester, const NowPlayingScreen(), prefs: {..._session, 'quality': 'opus128'});
    expect(find.text('OPUS 128 · from FLAC 24/96'), findsOneWidget);
    expect(find.byKey(const Key('np-quality-badge')), findsNothing);
    expect(find.text('Semestre de Otoño'), findsOneWidget, reason: 'title still shown');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('track actions: Track info lists the audio properties', (tester) async {
    await _pump(
        tester,
        Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: TextButton(onPressed: () => showTrackActions(context, ref, _hiRes), child: const Text('open')),
            ),
          ),
        ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Play next'), findsOneWidget, reason: 'previous actions still there');
    await tester.ensureVisible(find.byKey(const Key('track-info')));
    await tester.tap(find.byKey(const Key('track-info')));
    await tester.pumpAndSettle();
    for (final text in ['Hi-Res', 'FLAC', '2800 kbps', '96 kHz', '24-bit', 'Stereo', '50.0 MB']) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
  });
}
