class AuthUser {
  const AuthUser({required this.id, required this.username, this.isAdmin = false});
  final String id;
  final String username;

  /// Admins manage users and invites (`/admin/*`).
  final bool isAdmin;
}

class AuthSession {
  const AuthSession({required this.serverUrl, required this.token, required this.user});
  final String serverUrl;
  final String token;
  final AuthUser user;

  AuthSession withUser(AuthUser user) => AuthSession(serverUrl: serverUrl, token: token, user: user);
}

/// Port for authentication against a server.
abstract interface class AuthGateway {
  Future<AuthSession> login(String serverUrl, String username, String password);
}

/// Port for invite-based registration (`POST /auth/register`).
abstract interface class RegisterGateway {
  Future<AuthSession> register(String serverUrl, String inviteCode, String username, String password);
}
