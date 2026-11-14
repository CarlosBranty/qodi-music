import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../library/data/library_mappers.dart';
import '../../library/domain/entities.dart';
import '../domain/favorites_repository.dart';

class FavoritesApi implements FavoritesRepository {
  FavoritesApi(this._api);
  final ApiClient _api;

  @override
  Future<List<Track>> list() async =>
      listItems(await _api.get('/favorites')).map(trackFromJson).toList();

  @override
  Future<void> add(String trackId) => _api.put('/favorites/$trackId');

  @override
  Future<void> remove(String trackId) => _api.delete('/favorites/$trackId');
}
