import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qodi_music/core/api/api_client.dart';
import 'package:qodi_music/core/api/api_error.dart';
import 'package:qodi_music/core/config/core_providers.dart';
import 'package:qodi_music/core/router/app_router.dart';
import 'package:qodi_music/core/theme/app_theme.dart';
import 'package:qodi_music/features/account/ui/account_providers.dart';
import 'package:qodi_music/features/account/ui/users_screen.dart';
import 'package:qodi_music/features/auth/domain/auth_state.dart';
import 'package:qodi_music/features/auth/ui/auth_controller.dart';
import 'package:qodi_music/features/settings/ui/settings_screen.dart';

import '../support/fake_http.dart';
import '../support/fakes.dart';
import '../support/fixtures.dart';
import '../support/l10n.dart';

class FakeRegister implements RegisterGateway {
  final calls = <List<String>>[];
  ApiException? error;
  @override
  Future<AuthSession> register(String serverUrl, String inviteCode, String username, String password) async {
    calls.add([serverUrl, inviteCode, username, password]);
    if (error != null) throw error!;
    return AuthSession(serverUrl: serverUrl, token: 'jwt', user: AuthUser(id: 'u9', username: username));
  }
}

const _admin = {'server_url': 'http://nas:4040', 'token': 'tok', 'user_id': 'u1', 'username': 'sajra', 'is_admin': true};
const _member = {'server_url': 'http://nas:4040', 'token': 'tok', 'user_id': 'u2', 'username': 'ana'};

void main() {
  late FakeHttpAdapter http;
  late FakeRegister register;
  late ProviderContainer container;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pump(WidgetTester tester,
      {Map<String, Object> prefs = const {},
      Widget? home,
      String? location,
      Map<String, FakeResponse> routes = const {},
      bool updates = false}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    http = FakeHttpAdapter(routes);
    register = FakeRegister();
    container = ProviderContainer(overrides: [
      ...await baseOverrides(prefs: prefs, updatesSupported: updates),
      playerOverride(FakePlayer(track('t1'))),
      registerGatewayProvider.overrideWithValue(register),
      clockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 14, 12)),
      apiClientProvider.overrideWith((ref) {
        final s = ref.watch(settingsStoreProvider);
        return ApiClient(serverUrl: () => s.serverUrl, token: () => s.token, adapter: http);
      }),
    ], retry: (_, _) => null);
    addTearDown(container.dispose);
    final theme = AppTheme.light(useGoogleFonts: false);
    if (home != null) {
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container, child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        theme: theme, home: home)));
    } else {
      final router = container.read(appRouterProvider);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container, child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        theme: theme, routerConfig: router)));
      if (location != null) router.go(location);
    }
    await settle(tester);
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.tap(find.byKey(Key(key)));
    await settle(tester);
  }

  String fieldText(WidgetTester tester, String key) =>
      tester.widget<EditableText>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(EditableText))).controller.text;

  group('register', () {
    testWidgets('login shows the invite link and opens the register screen', (tester) async {
      await pump(tester);
      expect(find.text('Sign in to your music server'), findsOneWidget, reason: 'previous login screen');
      expect(find.byKey(const Key('qodi-wordmark')), findsOneWidget);
      await tapKey(tester, 'login-register');
      expect(find.byKey(const Key('register-code')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('join deep link pre-fills the invite code while logged out', (tester) async {
      await pump(tester, prefs: {'server_url': 'http://nas:4040'}, location: '/join?code=k7q2mx9rta4p');
      expect(fieldText(tester, 'register-code'), 'K7Q2MX9RTA4P');
      expect(fieldText(tester, 'register-server'), 'http://nas:4040');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('validation mirrors the contract and nothing is sent', (tester) async {
      await pump(tester, location: '/register');
      await tester.enterText(find.byKey(const Key('register-server')), 'http://nas:4040');
      await tester.enterText(find.byKey(const Key('register-code')), 'K7Q2MX9RTA4P');
      await tester.enterText(find.byKey(const Key('register-username')), 'a b');
      await tester.enterText(find.byKey(const Key('register-password')), 'short');
      await tester.enterText(find.byKey(const Key('register-confirm')), 'other');
      await tapKey(tester, 'register-submit');
      expect(find.text(en.usernameRule), findsOneWidget);
      expect(find.text(en.passwordRule), findsOneWidget);
      expect(find.text(en.passwordsDiffer), findsOneWidget);
      expect(register.calls, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });

    Future<void> fillValid(WidgetTester tester) async {
      await tester.enterText(find.byKey(const Key('register-server')), 'http://nas:4040');
      await tester.enterText(find.byKey(const Key('register-code')), 'k7q2mx9rta4p');
      await tester.enterText(find.byKey(const Key('register-username')), 'Ana');
      await tester.enterText(find.byKey(const Key('register-password')), 'secret123');
      await tester.enterText(find.byKey(const Key('register-confirm')), 'secret123');
      await tapKey(tester, 'register-submit');
    }

    for (final (code, message) in [
      ('invalid_invite', en.invalidInvite),
      ('username_taken', en.usernameTaken),
      ('bad_request', en.badRequest),
    ]) {
      testWidgets('server error $code is explained', (tester) async {
        await pump(tester, location: '/register');
        register.error = ApiException(code, 'raw', statusCode: 400);
        await fillValid(tester);
        expect(find.text(message), findsOneWidget);
        expect(container.read(authControllerProvider), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('success: lowercased username, normalized code, signed in', (tester) async {
      await pump(tester, location: '/register');
      await fillValid(tester);
      expect(register.calls.single, ['http://nas:4040', 'K7Q2MX9RTA4P', 'ana', 'secret123']);
      expect(container.read(authControllerProvider)?.user.username, 'ana');
      expect(container.read(settingsStoreProvider).token, 'jwt');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a stored session still opens Home and /login redirects there (previous behavior)', (tester) async {
      await pump(tester, prefs: _member, location: '/login');
      expect(find.text('What do you want\nto listen today?'), findsOneWidget);
      expect(find.byKey(const Key('qodi-wordmark')), findsOneWidget, reason: 'wordmark in the Home header');
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('settings', () {
    testWidgets('admin: badge and Users entry; previous sections still there', (tester) async {
      await pump(tester, prefs: _admin, home: const SettingsScreen());
      expect(find.byKey(const Key('settings-admin-badge')), findsOneWidget);
      expect(find.byKey(const Key('settings-users')), findsOneWidget);
      expect(find.byKey(const Key('settings-change-password')), findsOneWidget);
      expect(find.text('Streaming quality'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Log out'), 200);
      expect(find.text('Log out'), findsOneWidget);
      expect(find.byKey(const Key('settings-check-updates')), findsNothing, reason: 'not Android');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('non-admin: no badge, no Users entry', (tester) async {
      await pump(tester, prefs: _member, home: const SettingsScreen());
      expect(find.text('ana'), findsOneWidget);
      expect(find.byKey(const Key('settings-admin-badge')), findsNothing);
      expect(find.byKey(const Key('settings-users')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Android: App updates section with "Check for updates"', (tester) async {
      await pump(tester, prefs: _member, home: const SettingsScreen(), updates: true);
      await tester.scrollUntilVisible(find.byKey(const Key('settings-check-updates')), 200);
      expect(find.byKey(const Key('settings-check-updates')), findsOneWidget);
      expect(find.text('Not checked yet'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    Future<void> changePassword(WidgetTester tester, String current) async {
      await tapKey(tester, 'settings-change-password');
      await tester.enterText(find.byKey(const Key('pw-current')), current);
      await tester.enterText(find.byKey(const Key('pw-new')), 'new-secret');
      await tester.enterText(find.byKey(const Key('pw-confirm')), 'new-secret');
      await tapKey(tester, 'pw-save');
    }

    testWidgets('change password: success closes with a confirmation', (tester) async {
      await pump(tester,
          prefs: _member, home: const SettingsScreen(), routes: {'PUT /api/v1/me/password': const FakeResponse(204)});
      await changePassword(tester, 'old-secret');
      expect(http.bodies.single, {'current_password': 'old-secret', 'new_password': 'new-secret'});
      expect(find.byKey(const Key('pw-save')), findsNothing);
      expect(find.text(en.passwordChanged), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('change password: wrong current password keeps the dialog and the session', (tester) async {
      await pump(tester, prefs: _member, home: const SettingsScreen(), routes: {
        'PUT /api/v1/me/password': const FakeResponse(401, {
          'error': {'code': 'invalid_credentials', 'message': 'wrong'}
        })
      });
      await changePassword(tester, 'bad-secret');
      expect(find.text(en.wrongCurrentPassword), findsOneWidget);
      expect(container.read(authControllerProvider), isNotNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('users & invites', () {
    final routes = {
      'GET /api/v1/admin/users': const FakeResponse(200, {
        'items': [
          {'id': 'u1', 'username': 'sajra', 'is_admin': true, 'created_at': '2026-11-01T10:00:00Z'},
          {'id': 'u2', 'username': 'ana', 'is_admin': false, 'created_at': '2026-11-02T10:00:00Z'},
        ],
        'total': 2
      }),
      'GET /api/v1/admin/invites': const FakeResponse(200, {
        'items': [
          {'code': 'ACTIVE234567', 'created_at': '2026-11-14T00:00:00Z', 'expires_at': '2026-11-15T00:00:00Z', 'max_uses': 2, 'uses': 1},
          {'code': 'EXPIRED23456', 'created_at': '2026-11-01T00:00:00Z', 'expires_at': '2026-11-02T00:00:00Z', 'max_uses': 1, 'uses': 0},
          {'code': 'USEDUP234567', 'created_at': '2026-11-13T00:00:00Z', 'expires_at': '2026-11-20T00:00:00Z', 'max_uses': 1, 'uses': 1},
        ],
        'total': 3
      }),
      'POST /api/v1/admin/invites': const FakeResponse(201,
          {'code': 'NEWCODE23456', 'created_at': '2026-11-14T12:00:00Z', 'expires_at': '2026-11-17T12:00:00Z', 'max_uses': 1, 'uses': 0}),
      'DELETE /api/v1/admin/users/u2': const FakeResponse(204),
    };

    testWidgets('lists users (self not deletable) and invites with status', (tester) async {
      await pump(tester, prefs: _admin, home: const UsersScreen(), routes: routes);
      final self = tester.widget<IconButton>(find.byKey(const Key('user-delete-u1')));
      final other = tester.widget<IconButton>(find.byKey(const Key('user-delete-u2')));
      expect(self.onPressed, isNull);
      expect(other.onPressed, isNotNull);
      expect(find.textContaining('Active · Uses 1/2'), findsOneWidget);
      expect(find.textContaining('Expired · Uses 0/1'), findsOneWidget);
      expect(find.textContaining('Used up · Uses 1/1'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('delete asks for confirmation', (tester) async {
      await pump(tester, prefs: _admin, home: const UsersScreen(), routes: routes);
      await tapKey(tester, 'user-delete-u2');
      expect(http.requests.where((r) => r.method == 'DELETE'), isEmpty);
      await tapKey(tester, 'confirm-action');
      expect(http.requests.where((r) => r.method == 'DELETE').single.uri.path, '/api/v1/admin/users/u2');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('create invite shows the code, join link and APK link', (tester) async {
      await pump(tester, prefs: _admin, home: const UsersScreen(), routes: routes);
      await tapKey(tester, 'invite-create');
      await tester.enterText(find.byKey(const Key('invite-hours')), '48');
      await tester.enterText(find.byKey(const Key('invite-uses')), '3');
      await tapKey(tester, 'invite-submit');
      expect(http.bodies.whereType<Map>().last, {'expires_in_hours': 48, 'max_uses': 3});
      expect(find.text('NEWCODE23456'), findsWidgets);
      expect(find.text('http://nas:4040/join?code=NEWCODE23456'), findsOneWidget);
      expect(find.text('http://nas:4040/downloads/android/qodi-music.apk'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('403 forbidden shows a friendly message', (tester) async {
      await pump(tester, prefs: _admin, home: const UsersScreen(), routes: {
        'GET /api/v1/admin/users': const FakeResponse(403, {
          'error': {'code': 'forbidden', 'message': 'nope'}
        }),
      });
      expect(find.text(en.errorForbidden), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('non-admins opening the screen see no admin data', (tester) async {
      await pump(tester, prefs: _member, home: const UsersScreen(), routes: routes);
      expect(find.byKey(const Key('users-forbidden')), findsOneWidget);
      expect(http.requests, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
