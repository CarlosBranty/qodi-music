import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qodi_music/core/api/api_error.dart';
import 'package:qodi_music/core/config/core_providers.dart';
import 'package:qodi_music/core/theme/app_theme.dart';
import 'package:qodi_music/features/auth/domain/auth_state.dart';
import 'package:qodi_music/features/auth/ui/auth_controller.dart';
import 'package:qodi_music/features/auth/ui/login_screen.dart';

import '../support/fakes.dart';

class FakeGateway implements AuthGateway {
  final calls = <List<String>>[];
  bool reject = false;

  @override
  Future<AuthSession> login(String serverUrl, String username, String password) async {
    calls.add([serverUrl, username, password]);
    if (reject) throw const InvalidCredentialsException();
    return AuthSession(serverUrl: serverUrl, token: 'jwt', user: AuthUser(id: 'u1', username: username));
  }
}

void main() {
  late FakeGateway gateway;
  late ProviderContainer container;

  Future<void> pumpLogin(WidgetTester tester) async {
    gateway = FakeGateway();
    container = ProviderContainer(
      overrides: [...await baseOverrides(), authGatewayProvider.overrideWithValue(gateway)],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.light(useGoogleFonts: false), home: const LoginScreen()),
    ));
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('login-submit')));
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('empty form shows a validation message per field', (tester) async {
    await pumpLogin(tester);
    await submit(tester);
    expect(find.text('Enter the server URL'), findsOneWidget);
    expect(find.text('Enter your username'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(gateway.calls, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('rejects a server URL without scheme', (tester) async {
    await pumpLogin(tester);
    await tester.enterText(find.byKey(const Key('login-server')), 'nas.local:4040');
    await tester.enterText(find.byKey(const Key('login-username')), 'sajra');
    await tester.enterText(find.byKey(const Key('login-password')), 'pw');
    await submit(tester);
    expect(find.text('Use a full URL like http://192.168.1.10:4040'), findsOneWidget);
    expect(gateway.calls, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('valid form logs in and persists the session', (tester) async {
    await pumpLogin(tester);
    await tester.enterText(find.byKey(const Key('login-server')), 'http://nas.local:4040');
    await tester.enterText(find.byKey(const Key('login-username')), 'sajra');
    await tester.enterText(find.byKey(const Key('login-password')), 'secret');
    await submit(tester);
    expect(gateway.calls, [
      ['http://nas.local:4040', 'sajra', 'secret']
    ]);
    expect(container.read(authControllerProvider)?.user.username, 'sajra');
    expect(container.read(settingsStoreProvider).token, 'jwt');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('wrong credentials show an error and stay logged out', (tester) async {
    await pumpLogin(tester);
    gateway.reject = true;
    await tester.enterText(find.byKey(const Key('login-server')), 'http://nas.local:4040');
    await tester.enterText(find.byKey(const Key('login-username')), 'sajra');
    await tester.enterText(find.byKey(const Key('login-password')), 'bad');
    await submit(tester);
    expect(find.text('Wrong username or password'), findsOneWidget);
    expect(container.read(authControllerProvider), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
