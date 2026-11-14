import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qodi_music/app.dart';
import 'package:qodi_music/core/api/api_client.dart';
import 'package:qodi_music/core/config/core_providers.dart';
import 'package:qodi_music/core/theme/app_theme.dart';
import 'package:qodi_music/features/account/ui/account_providers.dart';
import 'package:qodi_music/features/account/ui/users_screen.dart';
import 'package:qodi_music/features/auth/ui/login_screen.dart';
import 'package:qodi_music/features/device_music/domain/device_music_source.dart';
import 'package:qodi_music/features/equalizer/ui/equalizer_controller.dart';
import 'package:qodi_music/features/equalizer/ui/equalizer_screen.dart';
import 'package:qodi_music/features/player/ui/now_playing_screen.dart';
import 'package:qodi_music/features/settings/ui/settings_screen.dart';

import '../support/fake_device.dart';
import '../support/fake_http.dart';
import '../support/fakes.dart';
import '../support/fixtures.dart';
import '../support/l10n.dart';

const _admin = {'server_url': 'http://nas:4040', 'token': 'tok', 'user_id': 'u1', 'username': 'sajra', 'is_admin': true};

final _adminRoutes = {
  'GET /api/v1/admin/users': const FakeResponse(200, {
    'items': [
      {'id': 'u1', 'username': 'sajra', 'is_admin': true, 'created_at': '2026-11-01T10:00:00Z'},
    ],
    'total': 1
  }),
  'GET /api/v1/admin/invites': const FakeResponse(200, {
    'items': [
      {'code': 'ACTIVE234567', 'created_at': '2026-11-14T00:00:00Z', 'expires_at': '2026-11-15T00:00:00Z', 'max_uses': 2, 'uses': 1},
    ],
    'total': 1
  }),
};

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pumps [home] under [locale] with the app's localization delegates.
Future<void> _pumpScreen(WidgetTester tester, Locale locale, Widget home,
    {Map<String, Object> prefs = const {}, List<Override> extra = const []}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final http = FakeHttpAdapter(_adminRoutes);
  final container = ProviderContainer(overrides: [
    ...await baseOverrides(prefs: prefs),
    playerOverride(FakePlayer(track('t1', title: 'Semestre de Otoño', artist: 'José Madero'))),
    clockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 14, 12)),
    apiClientProvider.overrideWith((ref) {
      final s = ref.watch(settingsStoreProvider);
      return ApiClient(serverUrl: () => s.serverUrl, token: () => s.token, adapter: http);
    }),
    ...extra,
  ], retry: (_, _) => null);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      theme: AppTheme.light(useGoogleFonts: false),
      home: home,
    ),
  ));
  await _settle(tester);
}

void main() {
  const english = Locale('en'), spanish = Locale('es');

  group('key screens render in the active language', () {
    testWidgets('Login', (tester) async {
      await _pumpScreen(tester, english, const LoginScreen());
      expect(find.text('Sign in to your music server'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());

      await _pumpScreen(tester, spanish, const LoginScreen());
      expect(find.text('Inicia sesión en tu servidor de música'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(find.text('URL del servidor'), findsOneWidget);
      expect(find.text('¿Tienes una invitación? Crea una cuenta'), findsOneWidget);
      // Validation messages are translated too.
      await tester.enterText(find.byKey(const Key('login-server')), '');
      await tester.ensureVisible(find.byKey(const Key('login-submit')));
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pump();
      expect(find.text('Ingresa la URL del servidor'), findsOneWidget);
      expect(find.text('Ingresa tu usuario'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Settings', (tester) async {
      await _pumpScreen(tester, english, const SettingsScreen(), prefs: _admin);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Log out'), 200);
      expect(find.text('Log out'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());

      await _pumpScreen(tester, spanish, const SettingsScreen(), prefs: _admin);
      expect(find.text('Ajustes'), findsOneWidget);
      expect(find.text('Idioma'), findsOneWidget);
      expect(find.text('Apariencia'), findsOneWidget);
      expect(find.text('Cambiar contraseña'), findsOneWidget);
      expect(find.text('Usuarios e invitaciones'), findsOneWidget);
      expect(find.text('Calidad de streaming'), findsOneWidget);
      expect(find.text('Sin pérdida / archivo original'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Cerrar sesión'), 200);
      expect(find.text('Cerrar sesión'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Now Playing', (tester) async {
      await _pumpScreen(tester, english, const NowPlayingScreen(), prefs: _admin);
      expect(find.text('Now Playing'), findsOneWidget);
      expect(find.text('Lyrics'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());

      await _pumpScreen(tester, spanish, const NowPlayingScreen(), prefs: _admin);
      expect(find.text('Reproduciendo'), findsOneWidget);
      expect(find.text('Letra'), findsOneWidget);
      expect(find.text('Semestre de Otoño'), findsOneWidget, reason: 'track data is never translated');
      expect(find.byTooltip('Siguiente'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Equalizer', (tester) async {
      Future<void> pumpEq(Locale locale) async {
        final eq = FakeEqualizer();
        await _pumpScreen(tester, locale, const EqualizerScreen(),
            prefs: _admin, extra: [equalizerPortProvider.overrideWithValue(eq)]);
        eq.reportBands(fiveBands);
        await _settle(tester);
      }

      await pumpEq(english);
      expect(find.text('Presets'), findsOneWidget);
      expect(find.text('Bass boost'), findsOneWidget);
      expect(find.text('3.6 kHz'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());

      await pumpEq(spanish);
      expect(find.text('Ecualizador'), findsNWidgets(2), reason: 'app bar and switch');
      expect(find.text('Preajustes'), findsOneWidget);
      expect(find.text('Refuerzo de graves'), findsOneWidget);
      expect(find.text('Restablecer'), findsOneWidget);
      expect(find.text('3,6 kHz'), findsOneWidget, reason: 'decimal comma in Spanish');
      expect(find.text('+0,0 dB'), findsNothing);
      expect(find.text('0,0 dB'), findsNWidgets(5));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Users & invites', (tester) async {
      await _pumpScreen(tester, english, const UsersScreen(), prefs: _admin);
      expect(find.text('Users & invites'), findsOneWidget);
      expect(find.textContaining('Active · Uses 1/2'), findsOneWidget);
      expect(find.textContaining(RegExp(r'Expires Nov 1[45], 2026 \d{1,2}:\d\d')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());

      await _pumpScreen(tester, spanish, const UsersScreen(), prefs: _admin);
      expect(find.text('Usuarios e invitaciones'), findsOneWidget);
      expect(find.text('Invitaciones'), findsOneWidget);
      expect(find.text('Crear invitación'), findsOneWidget);
      expect(find.textContaining('Activa · Usos 1/2'), findsOneWidget);
      expect(find.textContaining(RegExp(r'Vence 1[45] nov 2026 \d{1,2}:\d\d')), findsOneWidget,
          reason: 'dates in the Spanish format');
      expect(find.textContaining('Tú · Admin'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('language setting', () {
    Future<ProviderContainer> pumpApp(WidgetTester tester, {Map<String, Object> prefs = const {}}) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(overrides: [
        ...await baseOverrides(
          prefs: {'device_only': true, ...prefs},
          device: fakeDeviceServices(tracks: [deviceTrack('/music/A/a.flac', title: 'Alpha')]),
        ),
        playerOverride(FakePlayer(track('t1'))),
        equalizerPortProvider.overrideWithValue(FakeEqualizer(supported: false)),
      ], retry: (_, _) => null);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const QodiApp()));
      await _settle(tester);
      return container;
    }

    Locale appLocale(WidgetTester tester) => Localizations.localeOf(tester.element(find.byType(Scaffold).first));

    testWidgets('System follows the device language', (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('es', 'MX')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await pumpApp(tester);
      expect(appLocale(tester), const Locale('es'));
      expect(find.text('Modo sin conexión,'), findsOneWidget, reason: 'Home greeting in Spanish');
      await tester.pumpWidget(const SizedBox());

      tester.platformDispatcher.localesTestValue = const [Locale('fr', 'FR')];
      await pumpApp(tester);
      expect(appLocale(tester), const Locale('en'), reason: 'unsupported languages fall back to English');
      expect(find.text('Offline mode,'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('choosing Español switches immediately and persists; System goes back', (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final container = await pumpApp(tester);
      expect(find.text('Offline mode,'), findsOneWidget);

      await tester.tap(find.byTooltip('Settings'));
      await _settle(tester);
      expect(find.text('Settings'), findsOneWidget);
      await tester.tap(find.text('Español'));
      await _settle(tester);
      expect(appLocale(tester), const Locale('es'));
      expect(find.text('Ajustes'), findsOneWidget);
      expect(find.text('Idioma'), findsOneWidget);
      expect(container.read(settingsStoreProvider).prefs.getString('language'), 'es');

      await tester.tap(find.text('Sistema').last);
      await _settle(tester);
      expect(find.text('Settings'), findsOneWidget, reason: 'device language is English');
      expect(container.read(settingsStoreProvider).language, AppLanguage.system);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a saved language wins over the device language on start', (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await pumpApp(tester, prefs: {'language': 'es'});
      expect(appLocale(tester), const Locale('es'));
      expect(find.text('Modo sin conexión,'), findsOneWidget);
      expect(find.text('En este dispositivo'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  test('device music services fake still implements the platform port', () {
    // Guards the optional dialog titles added to DeviceMusicPlatform.
    final DeviceMusicPlatform p = FakeDevicePlatform();
    expect(p.pickFolder(dialogTitle: es.chooseMusicFolder), completion(isNull));
  });
}
