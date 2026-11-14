import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qodi_music/core/api/api_client.dart';
import 'package:qodi_music/core/config/core_providers.dart';
import 'package:qodi_music/core/router/app_router.dart';
import 'package:qodi_music/core/theme/app_theme.dart';
import 'package:qodi_music/features/auth/domain/auth_state.dart';
import 'package:qodi_music/features/auth/ui/auth_controller.dart';
import 'package:qodi_music/features/device_music/domain/device_music_source.dart';
import 'package:qodi_music/features/device_music/domain/device_track.dart';
import 'package:qodi_music/shared/widgets/track_tile.dart';

import '../support/fake_device.dart';
import '../support/fake_http.dart';
import '../support/fakes.dart';
import '../support/l10n.dart';

/// Fails the test if a login is attempted.
class NoLoginGateway implements AuthGateway {
  int calls = 0;
  @override
  Future<AuthSession> login(String serverUrl, String username, String password) {
    calls++;
    throw StateError('no server must be contacted');
  }
}

void main() {
  late FakeHttpAdapter http;
  late NoLoginGateway gateway;
  late FakePlayer player;
  late ProviderContainer container;
  late FakeDevicePlatform platform;
  final songs = [
    deviceTrack('/music/Album/b.flac', title: 'Bravo', artist: 'Band', album: 'Album'),
    deviceTrack('/music/Album/a.flac', title: 'Alpha', artist: 'Band', album: 'Album'),
  ];

  Future<void> pumpApp(WidgetTester tester,
      {Map<String, Object> prefs = const {}, FakeDevicePlatform? devicePlatform, List<DeviceTrack>? tracks}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    http = FakeHttpAdapter({});
    gateway = NoLoginGateway();
    player = FakePlayer(songs.first.track);
    platform = devicePlatform ?? FakeDevicePlatform();
    final base = await baseOverrides(
      prefs: prefs,
      device: DeviceMusicServices(source: FakeDeviceSource(tracks ?? songs), collections: MemoryDeviceCollections(), platform: platform),
    );
    container = ProviderContainer(overrides: [
      ...base,
      playerOverride(player),
      authGatewayProvider.overrideWithValue(gateway),
      apiClientProvider.overrideWith((ref) {
        final s = ref.watch(settingsStoreProvider);
        return ApiClient(serverUrl: () => s.serverUrl, token: () => s.token, adapter: http);
      }),
    ], retry: (_, _) => null);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        theme: AppTheme.light(useGoogleFonts: false),
        routerConfig: container.read(appRouterProvider),
      ),
    ));
    await settle(tester);
  }

  testWidgets('logged out without device-only mode still lands on login (previous behavior)', (tester) async {
    await pumpApp(tester);
    expect(find.text('Sign in to your music server'), findsOneWidget);
    expect(find.byKey(const Key('login-device-only')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a stored session still opens Home (previous behavior)', (tester) async {
    await pumpApp(tester, prefs: {'server_url': 'http://nas:4040', 'token': 'tok', 'username': 'alice'});
    expect(find.text('Welcome back,'), findsOneWidget);
    expect(find.text('alice'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('"Use without server" lands on Home with no API calls and plays device music', (tester) async {
    await pumpApp(tester);
    await tester.ensureVisible(find.byKey(const Key('login-device-only')));
    await tester.tap(find.byKey(const Key('login-device-only')));
    await settle(tester);

    expect(find.text('Offline mode,'), findsOneWidget);
    expect(find.text('On this device'), findsOneWidget);
    expect(container.read(settingsStoreProvider).deviceOnly, isTrue);

    // Server-only tabs show a clear empty state.
    await tester.tap(find.byIcon(Icons.explore_rounded));
    await settle(tester);
    expect(find.byKey(const Key('connect-server')), findsOneWidget);
    await tester.tap(find.byIcon(Icons.insights_rounded));
    await settle(tester);
    expect(find.text('Stats live on your server'), findsOneWidget);

    // Library shows only the device section with the scanned songs.
    await tester.tap(find.byIcon(Icons.library_music_rounded));
    await settle(tester);
    expect(find.text('On this device'), findsOneWidget, reason: 'the only Library tab');
    expect(find.text('Downloads'), findsNothing);
    expect(find.text('Songs'), findsOneWidget, reason: 'device filter pill');
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Bravo'), findsWidgets);

    await tester.tap(find.text('Alpha'));
    await settle(tester);
    final (queue, start) = player.played.single;
    expect(queue[start].title, 'Alpha');
    expect(isDeviceTrackId(queue[start].id), isTrue);

    // Search within device music.
    await tester.enterText(find.byKey(const Key('device-search')), 'brav');
    await settle(tester);
    expect(find.widgetWithText(TrackTile, 'Alpha'), findsNothing);
    expect(find.widgetWithText(TrackTile, 'Bravo'), findsOneWidget);

    expect(http.requests, isEmpty, reason: 'device-only mode never calls the API');
    expect(gateway.calls, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('permanently denied permission offers to open settings', (tester) async {
    final denied = FakeDevicePlatform(status: DevicePermission.permanentlyDenied);
    await pumpApp(tester, prefs: {'device_only': true}, devicePlatform: denied, tracks: []);
    expect(find.text('Allow access to play your music files'), findsOneWidget, reason: 'Home shortcut card');
    await tester.tap(find.byIcon(Icons.library_music_rounded));
    await settle(tester);
    expect(find.text('Open settings'), findsOneWidget);
    await tester.tap(find.byKey(const Key('device-permission')));
    await settle(tester);
    expect(denied.settingsOpened, 1);
    await tester.pumpWidget(const SizedBox());
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
