// Renders phone-sized screenshots of the app into docs/screenshots/.
//
// Not part of `flutter test` (which only runs test/). Regenerate with:
//   cd app && flutter test screenshots --update-goldens
//
// Uses device-only mode with sample songs, so no server is needed.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qodi_music/core/router/app_router.dart';
import 'package:qodi_music/core/theme/app_theme.dart';
import 'package:qodi_music/features/device_music/domain/device_music_source.dart';

import '../test/support/fake_device.dart';
import '../test/support/fakes.dart';
import '../test/support/l10n.dart';

const _out = '../../docs/screenshots';

final _songs = [
  deviceTrack('/music/Neon Tides/01.flac', title: 'Midnight Drive', artist: 'Neon Tides', album: 'Afterglow'),
  deviceTrack('/music/Neon Tides/02.flac', title: 'Glass City', artist: 'Neon Tides', album: 'Afterglow'),
  deviceTrack('/music/Neon Tides/03.flac', title: 'Low Orbit', artist: 'Neon Tides', album: 'Afterglow'),
  deviceTrack('/music/Sajra/01.flac', title: 'Paper Planes', artist: 'Sajra', album: 'Home Demos'),
  deviceTrack('/music/Sajra/02.flac', title: 'Sunday Tape', artist: 'Sajra', album: 'Home Demos'),
  deviceTrack('/music/Lumen/01.flac', title: 'Quiet Morning', artist: 'Lumen', album: 'Quiet Hours'),
  deviceTrack('/music/Lumen/02.flac', title: 'Static Bloom', artist: 'Lumen', album: 'Quiet Hours'),
  deviceTrack('/music/Vega/01.flac', title: 'Northern Lines', artist: 'Vega', album: 'Atlas'),
];

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(File(f).readAsBytes().then((b) => ByteData.sublistView(b)));
    }
    await loader.load();
  }

  final flutterRoot = Platform.environment['FLUTTER_ROOT']!;
  final material = '$flutterRoot/bin/cache/artifacts/material_fonts';
  await load('Outfit', ['screenshots/fonts/Outfit-Regular.ttf']);
  await load('Roboto', ['$material/Roboto-Regular.ttf', '$material/Roboto-Medium.ttf', '$material/Roboto-Bold.ttf']);
  await load('MaterialIcons', ['$material/MaterialIcons-Regular.otf']);
}

ThemeData _withFont(ThemeData t) =>
    t.copyWith(textTheme: t.textTheme.apply(fontFamily: 'Outfit', fontFamilyFallback: const ['Roboto']));

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(_loadFonts);

  for (final dark in [false, true]) {
    final suffix = dark ? 'dark' : 'light';

    Future<ProviderContainer> pumpApp(WidgetTester tester, {required bool loggedIn}) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final base = await baseOverrides(
        prefs: loggedIn ? {'device_only': true} : {},
        device: DeviceMusicServices(
          source: FakeDeviceSource(_songs),
          collections: MemoryDeviceCollections(),
          platform: FakeDevicePlatform(),
        ),
      );
      final container = ProviderContainer(
        overrides: [...base, playerOverride(FakePlayer(_songs.first.track))],
        retry: (_, _) => null,
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          locale: const Locale('es'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          theme: _withFont(AppTheme.light(useGoogleFonts: false)),
          darkTheme: _withFont(AppTheme.dark(useGoogleFonts: false)),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          routerConfig: container.read(appRouterProvider),
        ),
      ));
      await _settle(tester);
      return container;
    }

    Future<void> shot(String name) =>
        expectLater(find.byType(MaterialApp), matchesGoldenFile('$_out/$name-$suffix.png'));

    testWidgets('login ($suffix)', (tester) async {
      await pumpApp(tester, loggedIn: false);
      await shot('login');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('home, library, now playing ($suffix)', (tester) async {
      final c = await pumpApp(tester, loggedIn: true);
      await shot('home');

      await tester.tap(find.byIcon(Icons.library_music_rounded));
      await _settle(tester);
      await shot('library');

      c.read(appRouterProvider).push('/now-playing');
      await _settle(tester);
      await shot('now-playing');

      c.read(appRouterProvider).pop();
      await _settle(tester);
      c.read(appRouterProvider).push('/equalizer');
      await _settle(tester);
      await shot('equalizer');
      await tester.pumpWidget(const SizedBox());
    });
  }
}
