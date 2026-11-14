/// Accounts, invites and their client-side rules. Pure Dart.
library;

/// Validation and server errors of the account screens; the UI turns them
/// into localized text (`accountErrorText`).
enum AccountError {
  enterUsername,
  usernameRule,
  enterPassword,
  passwordRule,
  passwordsDiffer,
  enterInvite,
  invalidInvite,
  usernameTaken,
  badRequest,
  wrongCurrentPassword,
}

final _usernamePattern = RegExp(r'^[a-z0-9_.-]{3,32}$');

/// The server lowercases usernames before validating and storing them.
String normalizeUsername(String raw) => raw.trim().toLowerCase();

/// Invite codes are upper case `[A-Z2-9]`; tolerate pasted spaces/lower case.
String normalizeInviteCode(String raw) => raw.replaceAll(RegExp(r'\s'), '').toUpperCase();

AccountError? validateUsername(String? v) {
  final value = normalizeUsername(v ?? '');
  if (value.isEmpty) return AccountError.enterUsername;
  if (!_usernamePattern.hasMatch(value)) return AccountError.usernameRule;
  return null;
}

AccountError? validateNewPassword(String? v) {
  final value = v ?? '';
  if (value.isEmpty) return AccountError.enterPassword;
  if (value.length < 8 || value.length > 128) return AccountError.passwordRule;
  return null;
}

AccountError? validatePasswordConfirmation(String? confirmation, String password) =>
    confirmation == password ? null : AccountError.passwordsDiffer;

AccountError? validateInviteCode(String? v) =>
    normalizeInviteCode(v ?? '').isEmpty ? AccountError.enterInvite : null;

/// Row of `GET /admin/users`.
class UserSummary {
  const UserSummary({required this.id, required this.username, required this.isAdmin, required this.createdAt});
  final String id;
  final String username;
  final bool isAdmin;
  final DateTime? createdAt;
}

enum InviteStatus { active, expired, usedUp }

/// Invite (`code` is 12 chars from `[A-Z2-9]`).
class Invite {
  const Invite({
    required this.code,
    required this.createdAt,
    required this.expiresAt,
    required this.maxUses,
    required this.uses,
  });

  final String code;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final int maxUses;
  final int uses;

  /// Used up wins over expired: once all uses are taken it never comes back.
  InviteStatus statusAt(DateTime now) {
    if (uses >= maxUses) return InviteStatus.usedUp;
    final exp = expiresAt;
    if (exp != null && !now.isBefore(exp)) return InviteStatus.expired;
    return InviteStatus.active;
  }
}

String _origin(String serverBaseUrl) {
  var url = serverBaseUrl.trim();
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  if (url.endsWith('/api/v1')) url = url.substring(0, url.length - 7);
  return url;
}

/// `<serverBaseUrl>/join?code=CODE` — opens the register screen pre-filled.
String inviteJoinLink(String serverBaseUrl, String code) =>
    '${_origin(serverBaseUrl)}/join?code=${Uri.encodeQueryComponent(code)}';

/// Public download of the latest Android build.
String androidApkLink(String serverBaseUrl) => '${_origin(serverBaseUrl)}/downloads/android/qodi-music.apk';

/// Pre-fill of the register screen from a join link such as
/// `https://music.example/join?code=K7Q2MX9RTA4P`: on web the page origin is
/// the server (the web build is served by it); elsewhere the saved server.
({String server, String code}) joinPrefill(Uri link, {required bool isWeb, String? savedServer}) => (
      server: isWeb && link.hasAuthority ? link.origin : (savedServer ?? ''),
      code: normalizeInviteCode(link.queryParameters['code'] ?? ''),
    );
