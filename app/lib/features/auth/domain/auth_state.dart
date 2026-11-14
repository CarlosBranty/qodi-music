class AuthUser {
  const AuthUser({required this.id, required this.username});
  final String id;
  final String username;
}

class AuthSession {
  const AuthSession({required this.serverUrl, required this.token, required this.user});
  final String serverUrl;
  final String token;
  final AuthUser user;
}

/// Port for authentication against a server.
abstract interface class AuthGateway {
  Future<AuthSession> login(String serverUrl, String username, String password);
}
