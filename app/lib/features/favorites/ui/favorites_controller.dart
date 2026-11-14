import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/core_providers.dart';
import '../../auth/ui/auth_controller.dart';
import '../../library/domain/entities.dart';
import '../data/favorites_api.dart';
import '../domain/favorites_repository.dart';

final favoritesRepositoryProvider =
    Provider<FavoritesRepository>((ref) => FavoritesApi(ref.watch(apiClientProvider)));

final favoritesControllerProvider =
    AsyncNotifierProvider<FavoritesController, List<Track>>(FavoritesController.new);

/// Ids of favorite tracks (empty while loading).
final favoriteIdsProvider = Provider<Set<String>>((ref) =>
    ref.watch(favoritesControllerProvider).value?.map((t) => t.id).toSet() ?? const {});

class FavoritesController extends AsyncNotifier<List<Track>> {
  @override
  Future<List<Track>> build() async {
    // Device-only mode: server favorites are unavailable, no API call.
    if (ref.watch(authControllerProvider) == null) return const [];
    return ref.read(favoritesRepositoryProvider).list();
  }

  bool isFavorite(Track t) {
    final list = state.value;
    return list == null ? t.favorite : list.any((e) => e.id == t.id);
  }

  /// Optimistic toggle; reverts on failure.
  Future<void> toggle(Track track) async {
    final before = state.value ?? const <Track>[];
    final fav = isFavorite(track);
    state = AsyncData(fav
        ? before.where((t) => t.id != track.id).toList()
        : [track.copyWith(favorite: true), ...before]);
    try {
      final repo = ref.read(favoritesRepositoryProvider);
      fav ? await repo.remove(track.id) : await repo.add(track.id);
    } catch (_) {
      state = AsyncData(before);
      rethrow;
    }
  }
}
