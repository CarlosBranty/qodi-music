import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qodi_music/core/config/core_providers.dart';
import 'package:qodi_music/features/auth/domain/auth_state.dart';
import 'package:qodi_music/features/auth/ui/auth_controller.dart';
import 'package:qodi_music/features/device_music/ui/device_music_providers.dart';
import 'package:qodi_music/features/favorites/ui/favorites_controller.dart';
import 'package:qodi_music/features/playlists/domain/playlist.dart';
import 'package:qodi_music/features/playlists/ui/playlists_controller.dart';

import '../support/fake_device.dart';
import '../support/fakes.dart';
import '../support/fixtures.dart';

const session = {'server_url': 'http://nas:4040', 'token': 'tok', 'username': 'sajra', 'user_id': 'u1'};

class CountingPlaylists implements PlaylistRepository {
  int lists = 0;
  @override
  Future<List<Playlist>> list() async {
    lists++;
    return const [];
  }

  @override
  Future<Playlist> create(String name) => throw UnimplementedError();
  @override
  Future<void> delete(String id) => throw UnimplementedError();
  @override
  Future<PlaylistDetail> get(String id) => throw UnimplementedError();
  @override
  Future<Playlist> rename(String id, String name) => throw UnimplementedError();
  @override
  Future<Playlist> setTracks(String id, List<String> trackIds) => throw UnimplementedError();
}

void main() {
  Future<(ProviderContainer, FakeFavorites, CountingPlaylists)> make(Map<String, Object> prefs,
      {MemoryDeviceCollections? collections}) async {
    final favorites = FakeFavorites()..items.add(track('s1'));
    final playlists = CountingPlaylists();
    final c = ProviderContainer(overrides: [
      ...await baseOverrides(prefs: prefs, device: fakeDeviceServices(collections: collections), favorites: favorites),
      playlistRepositoryProvider.overrideWithValue(playlists),
      authGatewayProvider.overrideWithValue(_Gateway()),
    ], retry: (_, _) => null);
    addTearDown(c.dispose);
    return (c, favorites, playlists);
  }

  test('settings store keeps the session and history (previous behavior)', () async {
    final (c, _, _) = await make(session);
    final store = c.read(settingsStoreProvider);
    expect(store.session?.user.username, 'sajra');
    await store.pushHistory(track('a'));
    expect(store.history.single.id, 'a');
    expect(store.deviceOnly, isFalse);
  });

  test('device-only mode and scan folders are persisted', () async {
    final (c, _, _) = await make(const {});
    await c.read(deviceOnlyProvider.notifier).set(true);
    await c.read(deviceFoldersProvider.notifier).add('/media/usb/Music');
    final store = c.read(settingsStoreProvider);
    expect(store.deviceOnly, isTrue);
    expect(store.deviceFolders, ['/media/usb/Music']);
    expect(c.read(canUseAppProvider), isTrue);
  });

  test('logging in leaves device-only mode', () async {
    final (c, _, _) = await make(const {'device_only': true});
    expect(c.read(deviceOnlyProvider), isTrue);
    await c.read(authControllerProvider.notifier).login('http://nas:4040', 'sajra', 'pw');
    expect(c.read(settingsStoreProvider).deviceOnly, isFalse);
    expect(c.read(deviceOnlyProvider), isFalse);
    expect(c.read(serverConnectedProvider), isTrue);
  });

  test('server favorites/playlists still load with a session (previous behavior)', () async {
    final (c, favorites, playlists) = await make(session);
    expect((await c.read(favoritesControllerProvider.future)).single.id, 's1');
    await c.read(playlistsControllerProvider.future);
    expect(favorites.listCalls, 1);
    expect(playlists.lists, 1);
  });

  test('device-only mode never asks the server for favorites/playlists', () async {
    final (c, favorites, playlists) = await make(const {'device_only': true});
    expect(await c.read(favoritesControllerProvider.future), isEmpty);
    expect(await c.read(playlistsControllerProvider.future), isEmpty);
    expect(favorites.listCalls, 0);
    expect(playlists.lists, 0);
  });

  test('local device favorites and playlists go to the device repository', () async {
    final repo = MemoryDeviceCollections();
    final (c, favorites, _) = await make(const {'device_only': true}, collections: repo);
    await c.read(deviceFavoritesProvider.future);
    await c.read(deviceFavoritesProvider.notifier).toggle('device:a');
    expect(repo.favorites, {'device:a'});
    await c.read(deviceFavoritesProvider.notifier).toggle('device:a');
    expect(repo.favorites, isEmpty);

    await c.read(devicePlaylistsProvider.future);
    final p = await c.read(devicePlaylistsProvider.notifier).create('Mix');
    await c.read(devicePlaylistsProvider.notifier).addTracks(p!.id, [deviceTrack('/m/a.mp3').track]);
    expect(repo.lists[p.id]!.trackIds.single, startsWith('device:'));
    expect(c.read(devicePlaylistsProvider).value!.single.name, 'Mix');
    expect(favorites.listCalls, 0, reason: 'server favorites untouched');
  });
}

class _Gateway implements AuthGateway {
  @override
  Future<AuthSession> login(String serverUrl, String username, String password) async =>
      AuthSession(serverUrl: serverUrl, token: 'jwt', user: AuthUser(id: 'u1', username: username));
}
