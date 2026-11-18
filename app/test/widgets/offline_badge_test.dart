import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qodi_music/core/theme/app_theme.dart';
import 'package:qodi_music/features/downloads/ui/downloads_controller.dart';
import 'package:qodi_music/features/downloads/ui/offline_status.dart';
import 'package:qodi_music/features/library/domain/entities.dart';
import 'package:qodi_music/features/library/ui/album_detail_screen.dart';
import 'package:qodi_music/features/library/ui/track_actions.dart';
import 'package:qodi_music/features/player/ui/mini_player.dart';
import 'package:qodi_music/shared/widgets/now_playing_indicator.dart';

import '../support/fakes.dart';
import '../support/fixtures.dart';
import '../support/l10n.dart';

void main() {
  final downloadedServer = track('srv-done', title: 'Downloaded song');
  final device = track('device:abc', title: 'Device song');
  final remote = track('srv-remote', title: 'Remote song');

  Future<ProviderContainer> pump(WidgetTester tester, Widget child,
      {FakeDownloadStore? store, bool withStore = true, FakePlayer? player}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final c = ProviderContainer(overrides: [
      ...await baseOverrides(),
      if (withStore) downloadStoreProvider.overrideWithValue(store ?? FakeDownloadStore({downloadedServer.id})),
      playerOverride(player ?? FakePlayer(remote)),
    ], retry: (_, _) => null);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        theme: AppTheme.light(useGoogleFonts: false),
        home: Scaffold(body: child),
      ),
    ));
    await tester.pump();
    await tester.pump();
    return c;
  }

  Widget rows(List<Track> tracks) => ListView(children: [
        for (var i = 0; i < tracks.length; i++) ConnectedTrackTile(track: tracks[i], queue: tracks, index: i),
      ]);

  Finder badgeIn(String title) =>
      find.descendant(of: find.widgetWithText(ConnectedTrackTile, title), matching: find.byType(OfflineBadge));

  testWidgets('track rows: badge for a downloaded server track and a device track only', (tester) async {
    await pump(tester, rows([downloadedServer, device, remote]));
    expect(badgeIn('Downloaded song'), findsOneWidget);
    expect(badgeIn('Device song'), findsOneWidget);
    expect(badgeIn('Remote song'), findsNothing);
  });

  testWidgets('track rows: only the playing track shows the now-playing indicator', (tester) async {
    await pump(tester, rows([downloadedServer, remote, device]));
    Finder indicatorIn(String title) => find.descendant(
        of: find.widgetWithText(ConnectedTrackTile, title), matching: find.byType(NowPlayingIndicator));
    expect(indicatorIn('Remote song'), findsOneWidget);
    expect(indicatorIn('Downloaded song'), findsNothing);
    expect(indicatorIn('Device song'), findsNothing);
  });

  testWidgets('track rows: a download in progress still shows a spinner (previous behavior)', (tester) async {
    final c = await pump(tester, rows([remote]));
    // Never completes while the test looks at the row.
    c.read(downloadsControllerProvider.notifier).state =
        DownloadsState(ids: const {}, progress: {remote.id: 0.4});
    await tester.pump();
    expect(find.descendant(of: find.byType(ConnectedTrackTile), matching: find.byType(CircularProgressIndicator)),
        findsOneWidget);
    expect(find.byType(OfflineBadge), findsNothing);
  });

  testWidgets('web (no download store): no badge for server tracks and no download action', (tester) async {
    await pump(
        tester,
        ListView(children: [
          CollectionHeader(seed: 'al', title: 'Album', subtitle: 'x', tracks: [downloadedServer, remote]),
          ConnectedTrackTile(track: downloadedServer, queue: [downloadedServer], index: 0),
        ]),
        withStore: false);
    expect(find.byType(OfflineBadge), findsNothing);
    expect(find.byTooltip('Download all'), findsNothing);
  });

  testWidgets('album header: "N of M downloaded", then "Downloaded"', (tester) async {
    final store = FakeDownloadStore({downloadedServer.id});
    final tracks = [downloadedServer, remote, track('srv-3')];
    final c = await pump(tester,
        ListView(children: [CollectionHeader(seed: 'al', title: 'Album', subtitle: 'x', tracks: tracks)]),
        store: store);
    expect(find.text('1 of 3 downloaded'), findsOneWidget);
    expect(find.byTooltip('Download all'), findsOneWidget);

    c.read(downloadsControllerProvider.notifier).state =
        DownloadsState(ids: {downloadedServer.id}, progress: {remote.id: 0.5});
    await tester.pump();
    expect(find.byKey(const Key('collection-download-progress')), findsOneWidget);

    store.downloaded.addAll(tracks.map((t) => t.id));
    c.read(downloadsControllerProvider.notifier).state = DownloadsState(ids: {...store.downloaded});
    await tester.pump();
    expect(find.text('Downloaded'), findsOneWidget);
    expect(find.byTooltip('Downloaded'), findsOneWidget);
  });

  testWidgets('mini player: badge on the cover only for offline tracks', (tester) async {
    await pump(tester, const MiniPlayer(), player: FakePlayer(device));
    expect(find.byType(OfflineBadge), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await pump(tester, const MiniPlayer(), player: FakePlayer(remote));
    expect(find.byType(OfflineBadge), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  test('offline summary counts device tracks and partial downloads', () {
    final s = OfflineSummary.of(
      [downloadedServer, device, remote, track('x')],
      DownloadsState(ids: {downloadedServer.id}, progress: {remote.id: 0.5}),
    );
    expect(s.available, 2);
    expect(s.downloading, 1);
    expect(s.progress, closeTo(2.5 / 4, 1e-9));
    expect(s.label(en), '2 of 4 downloaded');
  });
}
