import '../../library/domain/entities.dart';

abstract interface class FavoritesRepository {
  /// Most recently favorited first.
  Future<List<Track>> list();
  Future<void> add(String trackId);
  Future<void> remove(String trackId);
}
