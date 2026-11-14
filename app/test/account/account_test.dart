import 'package:flutter_test/flutter_test.dart';
import 'package:qodi_music/core/api/api_client.dart';
import 'package:qodi_music/core/api/api_error.dart';
import 'package:qodi_music/core/router/app_router.dart';
import 'package:qodi_music/features/account/data/account_api.dart';
import 'package:qodi_music/features/account/domain/account.dart';
import 'package:qodi_music/features/account/ui/change_password_dialog.dart';
import 'package:qodi_music/features/account/ui/register_screen.dart';
import 'package:qodi_music/features/auth/data/auth_api.dart';

import '../support/fake_http.dart';

FakeResponse _err(int status, String code) => FakeResponse(status, {
      'error': {'code': code, 'message': 'server says $code'}
    });

void main() {
  group('client-side validation mirrors the contract', () {
    test('username: lowercased, ^[a-z0-9_.-]{3,32}\$', () {
      expect(validateUsername('Sajra.Music_1'), isNull);
      expect(normalizeUsername('  Sajra '), 'sajra');
      expect(validateUsername(''), AccountStrings.enterUsername);
      expect(validateUsername('ab'), AccountStrings.usernameRule);
      expect(validateUsername('a' * 33), AccountStrings.usernameRule);
      expect(validateUsername('a' * 32), isNull);
      expect(validateUsername('with space'), AccountStrings.usernameRule);
      expect(validateUsername('ñandu'), AccountStrings.usernameRule);
    });

    test('password: 8–128 chars; confirmation must match', () {
      expect(validateNewPassword(''), AccountStrings.enterPassword);
      expect(validateNewPassword('1234567'), AccountStrings.passwordRule);
      expect(validateNewPassword('12345678'), isNull);
      expect(validateNewPassword('x' * 128), isNull);
      expect(validateNewPassword('x' * 129), AccountStrings.passwordRule);
      expect(validatePasswordConfirmation('abc', 'abd'), AccountStrings.passwordsDiffer);
      expect(validatePasswordConfirmation('abc', 'abc'), isNull);
    });

    test('invite code is normalized (spaces, lower case)', () {
      expect(normalizeInviteCode(' k7q2 mx9r ta4p '), 'K7Q2MX9RTA4P');
      expect(validateInviteCode('  '), AccountStrings.enterInvite);
    });
  });

  group('invites', () {
    final now = DateTime.utc(2026, 11, 14, 12);
    Invite inv({int uses = 0, int max = 1, DateTime? exp}) => Invite(
        code: 'K7Q2MX9RTA4P', createdAt: now, expiresAt: exp ?? now.add(const Duration(hours: 1)), maxUses: max, uses: uses);

    test('status: active, expired, used up (used up wins)', () {
      expect(inv().statusAt(now), InviteStatus.active);
      expect(inv(exp: now).statusAt(now), InviteStatus.expired);
      expect(inv(uses: 1).statusAt(now), InviteStatus.usedUp);
      expect(inv(uses: 2, max: 2, exp: now.subtract(const Duration(days: 1))).statusAt(now), InviteStatus.usedUp);
      expect(inv(uses: 1, max: 3).statusAt(now), InviteStatus.active);
    });

    test('join and APK links from the server base URL', () {
      expect(inviteJoinLink('https://music.example.com/', 'K7Q2MX9RTA4P'), 'https://music.example.com/join?code=K7Q2MX9RTA4P');
      expect(inviteJoinLink('http://nas:4040/api/v1', 'ABC'), 'http://nas:4040/join?code=ABC');
      expect(androidApkLink('http://nas:4040'), 'http://nas:4040/downloads/android/qodi-music.apk');
    });
  });

  group('join deep link', () {
    test('web: server = page origin, code from the query', () {
      final p = joinPrefill(Uri.parse('https://music.example.com/join?code=k7q2mx9rta4p'), isWeb: true);
      expect(p, (server: 'https://music.example.com', code: 'K7Q2MX9RTA4P'));
    });

    test('native: saved server, code from the route', () {
      final p = joinPrefill(Uri.parse('/join?code=ABC'), isWeb: false, savedServer: 'http://nas:4040');
      expect(p, (server: 'http://nas:4040', code: 'ABC'));
    });

    test('initial location: /join keeps the code; anything else opens /home', () {
      expect(initialLocationFor(Uri.parse('https://m.example/join?code=ABC')), '/join?code=ABC');
      expect(initialLocationFor(Uri.parse('https://m.example/')), '/home');
      expect(initialLocationFor(null), '/home');
    });
  });

  group('API', () {
    late FakeHttpAdapter http;
    late int unauthorized;
    AccountApi api(Map<String, FakeResponse> routes) {
      http = FakeHttpAdapter(routes);
      unauthorized = 0;
      return AccountApi(ApiClient(
          serverUrl: () => 'http://nas:4040', token: () => 'tok', onUnauthorized: () => unauthorized++, adapter: http));
    }

    test('change password: PUT /me/password with both passwords', () async {
      final a = api({'PUT /api/v1/me/password': const FakeResponse(204)});
      await a.changePassword('old-secret', 'new-secret');
      expect(http.bodies.single, {'current_password': 'old-secret', 'new_password': 'new-secret'});
    });

    test('change password with a wrong current password: typed error, session kept', () async {
      final a = api({'PUT /api/v1/me/password': _err(401, 'invalid_credentials')});
      await expectLater(a.changePassword('bad', 'new-secret'), throwsA(isA<InvalidCredentialsException>()));
      expect(unauthorized, 0, reason: 'a wrong current password must not log out');
      expect(changePasswordErrorMessage(const InvalidCredentialsException()), AccountStrings.wrongCurrentPassword);
    });

    test('403 forbidden maps to ForbiddenException with a friendly message', () async {
      final a = api({'GET /api/v1/admin/users': _err(403, 'forbidden')});
      Object? error;
      try {
        await a.users();
      } catch (e) {
        error = e;
      }
      expect(error, isA<ForbiddenException>());
      expect(friendlyApiError(error!), ApiErrorStrings.forbidden);
      expect(unauthorized, 0);
    });

    test('users, invites, create and revoke', () async {
      final a = api({
        'GET /api/v1/admin/users': const FakeResponse(200, {
          'items': [
            {'id': 'u1', 'username': 'sajra', 'is_admin': true, 'created_at': '2026-11-01T10:00:00Z'},
            {'id': 'u2', 'username': 'ana', 'is_admin': false, 'created_at': '2026-11-02T10:00:00Z'},
          ],
          'total': 2
        }),
        'GET /api/v1/admin/invites': const FakeResponse(200, {
          'items': [
            {'code': 'K7Q2MX9RTA4P', 'created_at': '2026-11-13T20:15:00Z', 'expires_at': '2026-11-16T20:15:00Z', 'max_uses': 2, 'uses': 1}
          ],
          'total': 1
        }),
        'POST /api/v1/admin/invites': const FakeResponse(201,
            {'code': 'ABCDEFGHJKLM', 'created_at': '2026-11-14T00:00:00Z', 'expires_at': '2026-11-15T00:00:00Z', 'max_uses': 3, 'uses': 0}),
        'DELETE /api/v1/admin/invites/ABCDEFGHJKLM': const FakeResponse(204),
        'DELETE /api/v1/admin/users/u2': const FakeResponse(204),
      });
      final users = await a.users();
      expect(users.map((u) => (u.username, u.isAdmin)), [('sajra', true), ('ana', false)]);
      final invites = await a.invites();
      expect((invites.single.code, invites.single.uses, invites.single.maxUses), ('K7Q2MX9RTA4P', 1, 2));
      expect(invites.single.expiresAt, DateTime.utc(2026, 11, 16, 20, 15));
      final created = await a.createInvite(expiresInHours: 24, maxUses: 3);
      expect(http.bodies.last, {'expires_in_hours': 24, 'max_uses': 3});
      expect(created.code, 'ABCDEFGHJKLM');
      await a.revokeInvite(created.code);
      await a.deleteUser('u2');
      expect(http.requests.map((r) => '${r.method} ${r.uri.path}').skip(3),
          ['DELETE /api/v1/admin/invites/ABCDEFGHJKLM', 'DELETE /api/v1/admin/users/u2']);
    });

    test('register: POST /auth/register, session with is_admin', () async {
      final http = FakeHttpAdapter({
        'POST /api/v1/auth/register': const FakeResponse(201, {
          'token': 'jwt',
          'user': {'id': 'u9', 'username': 'ana', 'is_admin': false}
        }),
        'POST /api/v1/auth/login': const FakeResponse(200, {
          'token': 'jwt2',
          'user': {'id': 'u1', 'username': 'sajra', 'is_admin': true}
        }),
      });
      final auth = AuthApi(adapter: http);
      final s = await auth.register('http://nas:4040/', 'K7Q2MX9RTA4P', 'ana', 'secret123');
      expect(http.bodies.single, {'invite_code': 'K7Q2MX9RTA4P', 'username': 'ana', 'password': 'secret123'});
      expect((s.serverUrl, s.token, s.user.id, s.user.isAdmin), ('http://nas:4040', 'jwt', 'u9', false));
      final admin = await auth.login('http://nas:4040', 'sajra', 'pw');
      expect(admin.user.isAdmin, isTrue);
    });

    test('register error mapping', () {
      expect(registerErrorMessage(const ApiException('invalid_invite', 'x', statusCode: 400)), AccountStrings.invalidInvite);
      expect(registerErrorMessage(const ApiException('username_taken', 'x', statusCode: 409)), AccountStrings.usernameTaken);
      expect(registerErrorMessage(const ApiException('bad_request', 'x', statusCode: 400)), AccountStrings.badRequest);
      expect(registerErrorMessage(const ApiException('network', 'x')), ApiErrorStrings.network);
    });
  });
}
