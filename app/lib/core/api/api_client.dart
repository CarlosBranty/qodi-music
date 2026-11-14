import 'package:dio/dio.dart';

import 'api_error.dart';

/// Thin HTTP client for the Qodi Music API (`/api/v1`).
///
/// The server URL and token are read lazily through callbacks so a single
/// instance survives login/logout. Every request gets
/// `Authorization: Bearer <token>`; media URLs (stream, cover) carry the token
/// as `?token=` because `<audio>`/`<img>` cannot send headers on web.
class ApiClient {
  ApiClient({
    required String? Function() serverUrl,
    required String? Function() token,
    void Function()? onUnauthorized,
    HttpClientAdapter? adapter,
  })  : _serverUrl = serverUrl,
        _token = token,
        _onUnauthorized = onUnauthorized,
        dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
          responseType: ResponseType.json,
        )) {
    if (adapter != null) dio.httpClientAdapter = adapter;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      options.baseUrl = apiBase;
      final t = _token();
      if (t != null && t.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $t';
      }
      handler.next(options);
    }));
  }

  final String? Function() _serverUrl;
  final String? Function() _token;
  final void Function()? _onUnauthorized;
  final Dio dio;

  /// Normalized server origin without trailing slash, e.g. `http://nas:4040`.
  String get serverOrigin => normalizeServerUrl(_serverUrl() ?? '');

  String get apiBase => '$serverOrigin/api/v1';

  static String normalizeServerUrl(String raw) {
    var url = raw.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.endsWith('/api/v1')) url = url.substring(0, url.length - 7);
    return url;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => dio.get<dynamic>(path, queryParameters: _clean(query)));

  Future<dynamic> post(String path, {Object? body}) =>
      _send(() => dio.post<dynamic>(path, data: body));

  Future<dynamic> patch(String path, {Object? body}) =>
      _send(() => dio.patch<dynamic>(path, data: body));

  Future<dynamic> put(String path, {Object? body}) =>
      _send(() => dio.put<dynamic>(path, data: body));

  Future<dynamic> delete(String path) =>
      _send(() => dio.delete<dynamic>(path));

  /// Downloads [url] (absolute) to [savePath].
  Future<void> download(String url, String savePath,
      {void Function(int received, int total)? onProgress}) async {
    await _send(() => dio.download(url, savePath, onReceiveProgress: onProgress));
  }

  Uri mediaUri(String path, [Map<String, String>? query]) {
    final params = <String, String>{...?query};
    final t = _token();
    if (t != null && t.isNotEmpty) params['token'] = t;
    return Uri.parse('$apiBase$path')
        .replace(queryParameters: params.isEmpty ? null : params);
  }

  Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    final out = <String, dynamic>{};
    query.forEach((k, v) {
      if (v != null && v != '') out[k] = v;
    });
    return out;
  }

  Future<dynamic> _send(Future<Response<dynamic>> Function() call) async {
    try {
      final res = await call();
      return res.data;
    } on DioException catch (e) {
      final error = mapDioError(e);
      if (error is UnauthorizedException) _onUnauthorized?.call();
      throw error;
    }
  }

  /// Maps a [DioException] to an [ApiException] using the server error shape.
  static ApiException mapDioError(DioException e) {
    final res = e.response;
    if (res == null) {
      return ApiException('network', e.message ?? 'Cannot reach the server');
    }
    final status = res.statusCode ?? 0;
    String code = 'unknown';
    String message = 'Request failed ($status)';
    final data = res.data;
    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      code = (err['code'] as String?) ?? code;
      message = (err['message'] as String?) ?? message;
    }
    if (status == 401) {
      return code == 'invalid_credentials'
          ? InvalidCredentialsException(message)
          : UnauthorizedException(message);
    }
    return ApiException(code, message, statusCode: status);
  }
}
