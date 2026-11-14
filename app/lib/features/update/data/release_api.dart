import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import '../../../core/api/json.dart';
import '../domain/app_update.dart';
import '../domain/update_ports.dart';

AndroidRelease releaseFromJson(Json j) => AndroidRelease(
      versionName: asString(j['version_name']),
      versionCode: asInt(j['version_code']),
      url: asString(j['url']),
      sha256: asString(j['sha256']),
      sizeBytes: asInt(j['size_bytes']),
      publishedAt: asStringOrNull(j['published_at']),
    );

/// `GET /api/v1/app/android` without a token (public endpoint, works in
/// device-only mode when a server URL is known).
class ReleaseApi implements ReleaseSource {
  ReleaseApi({HttpClientAdapter? adapter}) : _adapter = adapter;
  final HttpClientAdapter? _adapter;

  @override
  Future<AndroidRelease?> latest(String serverOrigin) async {
    final client = ApiClient(serverUrl: () => serverOrigin, token: () => null, adapter: _adapter);
    try {
      return releaseFromJson(asJson(await client.get('/app/android')));
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }
}
