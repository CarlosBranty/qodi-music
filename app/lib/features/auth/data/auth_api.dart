import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../domain/auth_state.dart';

AuthUser userFromJson(Json j, {String fallbackName = ''}) => AuthUser(
      id: asString(j['id']),
      username: asString(j['username'], fallbackName),
      isAdmin: asBool(j['is_admin']),
    );

/// Calls `POST /auth/login` and `POST /auth/register` against an explicit
/// server URL.
class AuthApi implements AuthGateway, RegisterGateway {
  AuthApi({HttpClientAdapter? adapter}) : _adapter = adapter;
  final HttpClientAdapter? _adapter;

  @override
  Future<AuthSession> login(String serverUrl, String username, String password) =>
      _auth(serverUrl, '/auth/login', {'username': username, 'password': password}, username);

  @override
  Future<AuthSession> register(String serverUrl, String inviteCode, String username, String password) => _auth(
      serverUrl, '/auth/register', {'invite_code': inviteCode, 'username': username, 'password': password}, username);

  Future<AuthSession> _auth(String serverUrl, String path, Json payload, String username) async {
    final origin = ApiClient.normalizeServerUrl(serverUrl);
    final client = ApiClient(serverUrl: () => origin, token: () => null, adapter: _adapter);
    final body = asJson(await client.post(path, body: payload));
    return AuthSession(
      serverUrl: origin,
      token: asString(body['token']),
      user: userFromJson(asJson(body['user']), fallbackName: username),
    );
  }
}
