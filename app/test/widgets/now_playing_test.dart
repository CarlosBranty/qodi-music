import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qodi_music/core/theme/app_theme.dart';
import 'package:qodi_music/features/player/ui/now_playing_screen.dart';

import '../support/fakes.dart';
import '../support/fixtures.dart';
import '../support/l10n.dart';

void main() {
  testWidgets('renders title/artist and the play button toggles playback', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final player = FakePlayer(track('t1', title: 'Semestre de Otoño', artist: 'José Madero'));
    final overrides = await baseOverrides(prefs: {
      'server_url': 'http://nas:4040',
      'token': 'tok',
      'username': 'alice',
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [...overrides, playerOverride(player)],
      retry: (_, _) => null,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        theme: AppTheme.light(useGoogleFonts: false), home: const NowPlayingScreen()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Now Playing'), findsOneWidget);
    expect(find.text('Semestre de Otoño'), findsOneWidget);
    expect(find.text('José Madero'), findsOneWidget);
    expect(find.text('02.17'), findsOneWidget, reason: 'elapsed time from the player position');
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

    await tester.tap(find.byKey(const Key('play-pause')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(player.toggles, 1);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);

    await tester.tap(find.byKey(const Key('play-pause')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(player.toggles, 2);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

    // Unmount to stop the spinning vinyl before the test ends.
    await tester.pumpWidget(const SizedBox());
  });
}
