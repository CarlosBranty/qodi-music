import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/domain/auth_state.dart';
import '../domain/account.dart';

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

UserSummary userSummaryFromJson(Json j) => UserSummary(
      id: asString(j['id']),
      username: asString(j['username']),
      isAdmin: asBool(j['is_admin']),
      createdAt: _date(j['created_at']),
    );

Invite inviteFromJson(Json j) => Invite(
      code: asString(j['code']),
      createdAt: _date(j['created_at']),
      expiresAt: _date(j['expires_at']),
      maxUses: asInt(j['max_uses'], 1),
      uses: asInt(j['uses']),
    );

/// Signed-in account (`/me`) and admin endpoints (`/admin/*`).
class AccountApi {
  AccountApi(this._api);
  final ApiClient _api;

  Future<AuthUser> me() async => userFromJson(asJson(await _api.get('/me')));

  /// 401 `invalid_credentials` (→ [InvalidCredentialsException]) when the
  /// current password is wrong.
  Future<void> changePassword(String current, String next) =>
      _api.put('/me/password', body: {'current_password': current, 'new_password': next});

  Future<List<UserSummary>> users() async => listItems(await _api.get('/admin/users')).map(userSummaryFromJson).toList();

  Future<void> deleteUser(String id) => _api.delete('/admin/users/$id');

  Future<List<Invite>> invites() async => listItems(await _api.get('/admin/invites')).map(inviteFromJson).toList();

  Future<Invite> createInvite({int? expiresInHours, int? maxUses}) async => inviteFromJson(asJson(await _api.post(
        '/admin/invites',
        body: {
          'expires_in_hours': ?expiresInHours,
          'max_uses': ?maxUses,
        },
      )));

  Future<void> revokeInvite(String code) => _api.delete('/admin/invites/$code');
}
