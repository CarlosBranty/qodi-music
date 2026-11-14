import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/auth/ui/auth_controller.dart';
import '../../features/auth/ui/login_screen.dart';
import '../../features/home/ui/home_screen.dart';
import '../../features/library/ui/album_detail_screen.dart';
import '../../features/library/ui/library_screen.dart';
import '../../features/player/ui/mini_player.dart';
import '../../features/player/ui/now_playing_screen.dart';
import '../../features/playlists/ui/playlist_detail_screen.dart';
import '../../features/search/ui/explore_screen.dart';
import '../../features/settings/ui/settings_screen.dart';
import '../../features/stats/ui/stats_screen.dart';
import '../../shared/widgets/pill_nav_bar.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = ref.read(authControllerProvider) != null;
      final atLogin = state.matchedLocation == '/login';
      if (!loggedIn) return atLogin ? null : '/login';
      if (atLogin) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/now-playing', builder: (_, _) => const NowPlayingScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
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

/// Tab scaffold: content, mini player and the black pill nav bar.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  static const items = [
    PillNavItem(Icons.home_rounded, 'Home'),
    PillNavItem(Icons.explore_rounded, 'Explore'),
    PillNavItem(Icons.library_music_rounded, 'Library'),
    PillNavItem(Icons.insights_rounded, 'Stats'),
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
            items: items,
            currentIndex: shell.currentIndex,
            onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          ),
        ],
      ),
    );
  }
}
