import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../domain/auth_state.dart';

/// Calls `POST /auth/login` against an explicit server URL.
class AuthApi implements AuthGateway {
  AuthApi({HttpClientAdapter? adapter}) : _adapter = adapter;
  final HttpClientAdapter? _adapter;

  @override
  Future<AuthSession> login(String serverUrl, String username, String password) async {
    final origin = ApiClient.normalizeServerUrl(serverUrl);
    final client = ApiClient(serverUrl: () => origin, token: () => null, adapter: _adapter);
    final body = asJson(await client.post('/auth/login',
        body: {'username': username, 'password': password}));
    final user = asJson(body['user']);
    return AuthSession(
      serverUrl: origin,
      token: asString(body['token']),
      user: AuthUser(id: asString(user['id']), username: asString(user['username'], username)),
    );
  }
}
