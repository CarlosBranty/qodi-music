/// Accounts, invites and their client-side rules. Pure Dart.
library;

/// User-facing copy of the account screens (kept together for translation).
abstract final class AccountStrings {
  // Validation
  static const enterUsername = 'Enter a username';
  static const usernameRule = 'Use 3–32 characters: letters, numbers, _ . -';
  static const enterPassword = 'Enter a password';
  static const passwordRule = 'Use 8–128 characters';
  static const passwordsDiffer = 'The passwords do not match';
  static const enterInvite = 'Enter your invite code';

  // Server errors
  static const invalidInvite = 'This invite code is not valid, expired or already used.';
  static const usernameTaken = 'That username is already taken.';
  static const badRequest = 'Check the username and password rules.';
  static const wrongCurrentPassword = 'The current password is wrong.';

  // Register
  static const haveInvite = 'Have an invite? Create account';
  static const createAccount = 'Create account';
  static const createAccountSubtitle = 'Join a Qodi Music server with an invite';
  static const serverUrl = 'Server URL';
  static const inviteCode = 'Invite code';
  static const username = 'Username';
  static const password = 'Password';
  static const confirmPassword = 'Confirm password';
  static const haveAccount = 'Already have an account? Sign in';

  // Account / change password
  static const account = 'Account';
  static const admin = 'Admin';
  static const changePassword = 'Change password';
  static const currentPassword = 'Current password';
  static const newPassword = 'New password';
  static const confirmNewPassword = 'Confirm new password';
  static const passwordChanged = 'Password changed';
  static const cancel = 'Cancel';
  static const save = 'Save';

  // Users & invites
  static const usersAndInvites = 'Users & invites';
  static const usersSubtitle = 'Manage who can listen';
  static const users = 'Users';
  static const invites = 'Invites';
  static const you = 'You';
  static const deleteUser = 'Delete user';
  static const cannotDeleteSelf = "You can't delete yourself";
  static String deleteUserQuestion(String name) =>
      'Delete $name? Their playlists, favorites and plays are removed and they are signed out.';
  static const delete = 'Delete';
  static String userDeleted(String name) => '$name deleted';
  static const createInvite = 'Create invite';
  static const expiresInHours = 'Expires in (hours)';
  static const maxUses = 'Max uses';
  static const expiryRule = 'Between 1 and 720 hours';
  static const usesRule = 'Between 1 and 50';
  static const create = 'Create';
  static const inviteCreated = 'Invite created';
  static const shareInviteHint = 'Send the join link. Android users can install the app from the APK link.';
  static const joinLink = 'Join link';
  static const apkLink = 'Android app (APK)';
  static const copy = 'Copy';
  static const copyCode = 'Copy code';
  static const copied = 'Copied to the clipboard';
  static const done = 'Done';
  static const revoke = 'Revoke';
  static const revokeInvite = 'Revoke invite';
  static String revokeInviteQuestion(String code) => 'Revoke invite $code? It can no longer be used.';
  static const inviteRevoked = 'Invite revoked';
  static const noInvites = 'No invites yet';
  static const statusActive = 'Active';
  static const statusExpired = 'Expired';
  static const statusUsedUp = 'Used up';
  static String uses(int used, int max) => 'Uses $used/$max';
  static String expiresOn(String date) => 'Expires $date';
  static String expiredOn(String date) => 'Expired $date';
  static const loadFailed = 'Could not load. Pull to retry.';
}

final _usernamePattern = RegExp(r'^[a-z0-9_.-]{3,32}$');

/// The server lowercases usernames before validating and storing them.
String normalizeUsername(String raw) => raw.trim().toLowerCase();

/// Invite codes are upper case `[A-Z2-9]`; tolerate pasted spaces/lower case.
String normalizeInviteCode(String raw) => raw.replaceAll(RegExp(r'\s'), '').toUpperCase();

String? validateUsername(String? v) {
  final value = normalizeUsername(v ?? '');
  if (value.isEmpty) return AccountStrings.enterUsername;
  if (!_usernamePattern.hasMatch(value)) return AccountStrings.usernameRule;
  return null;
}

String? validateNewPassword(String? v) {
  final value = v ?? '';
  if (value.isEmpty) return AccountStrings.enterPassword;
  if (value.length < 8 || value.length > 128) return AccountStrings.passwordRule;
  return null;
}

String? validatePasswordConfirmation(String? confirmation, String password) =>
    confirmation == password ? null : AccountStrings.passwordsDiffer;

String? validateInviteCode(String? v) =>
    normalizeInviteCode(v ?? '').isEmpty ? AccountStrings.enterInvite : null;

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

String inviteStatusLabel(InviteStatus s) => switch (s) {
      InviteStatus.active => AccountStrings.statusActive,
      InviteStatus.expired => AccountStrings.statusExpired,
      InviteStatus.usedUp => AccountStrings.statusUsedUp,
    };

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
