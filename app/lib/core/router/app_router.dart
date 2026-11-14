import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';
import '../../features/account/domain/account.dart';
import '../../features/account/ui/register_screen.dart';
import '../../features/account/ui/users_screen.dart';
import '../../features/auth/ui/auth_controller.dart';
import '../config/core_providers.dart';
import '../../features/auth/ui/login_screen.dart';
import '../../features/device_music/ui/device_detail_screens.dart';
import '../../features/home/ui/home_screen.dart';
import '../../features/library/ui/album_detail_screen.dart';
import '../../features/library/ui/library_screen.dart';
import '../../features/player/ui/mini_player.dart';
import '../../features/player/ui/now_playing_screen.dart';
import '../../features/playlists/ui/playlist_detail_screen.dart';
import '../../features/search/ui/explore_screen.dart';
import '../../features/settings/ui/settings_screen.dart';
import '../../features/equalizer/ui/equalizer_screen.dart';
import '../../features/stats/ui/stats_screen.dart';
import '../../shared/widgets/pill_nav_bar.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.listen(deviceOnlyProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: initialLocationFor(kIsWeb ? Uri.base : null),
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = ref.read(authControllerProvider) != null;
      final deviceOnly = ref.read(deviceOnlyProvider);
      // Sign-in pages: login, invite sign-up and invite deep links.
      final atLogin = const {'/login', '/register', '/join'}.contains(state.matchedLocation);
      if (!loggedIn && !deviceOnly) return atLogin ? null : '/login';
      // Device-only users may open /login to connect to a server.
      if (atLogin && loggedIn) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (_, _) => RegisterScreen(initialServer: _savedOrPageServer(ref)),
      ),
      // Invite link `<server>/join?code=XXXX`: on web the page origin is the server.
      GoRoute(
        path: '/join',
        builder: (_, s) {
          final prefill = joinPrefill(kIsWeb ? Uri.base.replace(query: s.uri.query) : s.uri,
              isWeb: kIsWeb, savedServer: ref.read(settingsStoreProvider).serverUrl);
          return RegisterScreen(initialServer: prefill.server, initialCode: prefill.code);
        },
      ),
      GoRoute(path: '/now-playing', builder: (_, _) => const NowPlayingScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/settings/users', builder: (_, _) => const UsersScreen()),
      GoRoute(path: '/equalizer', builder: (_, _) => const EqualizerScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/explore',
              builder: (_, _) => const ExploreScreen(),
              routes: [
                GoRoute(
                  path: 'album/:id',
                  builder: (_, s) => AlbumDetailScreen(albumId: s.pathParameters['id']!),
                ),
                GoRoute(
                  path: 'artist/:id',
                  builder: (_, s) => ArtistDetailScreen(artistId: s.pathParameters['id']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/library',
              builder: (_, s) => LibraryScreen(initialTab: s.uri.queryParameters['tab']),
              routes: [
                GoRoute(
                  path: 'playlist/:id',
                  builder: (_, s) => PlaylistDetailScreen(playlistId: s.pathParameters['id']!),
                ),
                GoRoute(
                  path: 'device/album/:id',
                  builder: (_, s) => DeviceAlbumScreen(albumId: s.pathParameters['id']!),
                ),
                GoRoute(
                  path: 'device/artist/:id',
                  builder: (_, s) => DeviceArtistScreen(artistId: s.pathParameters['id']!),
                ),
                GoRoute(
                  path: 'device/playlist/:id',
                  builder: (_, s) => DevicePlaylistScreen(playlistId: s.pathParameters['id']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/stats', builder: (_, _) => const StatsScreen()),
          ]),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// `/home`, or `/join?code=…` when the web app was opened from an invite link
/// (`<server>/join?code=XXXX`; the server serves the SPA for that path).
String initialLocationFor(Uri? pageUrl) {
  if (pageUrl != null && pageUrl.path == '/join') {
    return Uri(path: '/join', queryParameters: pageUrl.queryParameters.isEmpty ? null : pageUrl.queryParameters)
        .toString();
  }
  return '/home';
}

String _savedOrPageServer(Ref ref) =>
    ref.read(settingsStoreProvider).serverUrl ?? (kIsWeb ? Uri.base.origin : '');

/// Tab scaffold: content, mini player and the black pill nav bar.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  static List<PillNavItem> items(AppLocalizations l) => [
        PillNavItem(Icons.home_rounded, l.navHome),
        PillNavItem(Icons.explore_rounded, l.navExplore),
        PillNavItem(Icons.library_music_rounded, l.navLibrary),
        PillNavItem(Icons.insights_rounded, l.navStats),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(bottom: false, child: shell),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          PillNavBar(
            items: items(context.l10n),
            currentIndex: shell.currentIndex,
            onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          ),
        ],
      ),
    );
  }
}
