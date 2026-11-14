import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

class FakeResponse {
  const FakeResponse(this.status, [this.body]);
  final int status;
  final Object? body;
}

/// Records requests and answers from a route table keyed by "METHOD /path".
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.routes);

  final Map<String, FakeResponse> routes;
  final List<RequestOptions> requests = [];
  final List<Object?> bodies = [];
  bool offline = false;

  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    bodies.add(options.data);
    if (offline) {
      throw DioException.connectionError(requestOptions: options, reason: 'offline');
    }
    final key = '${options.method} ${options.uri.path}';
    final res = routes[key] ??
        const FakeResponse(404, {
          'error': {'code': 'not_found', 'message': 'no route'}
        });
    final body = res.body == null ? '' : jsonEncode(res.body);
    return ResponseBody.fromString(body, res.status, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}
