import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/core_providers.dart';
import '../data/auth_api.dart';
import '../domain/auth_state.dart';

final authGatewayProvider = Provider<AuthGateway>((ref) => AuthApi());
final registerGatewayProvider = Provider<RegisterGateway>((ref) => AuthApi());

/// Current session (null = logged out).
final authControllerProvider =
    NotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends Notifier<AuthSession?> {
  @override
  AuthSession? build() {
    final sub = ref.read(sessionExpiredProvider).stream.listen((_) => logout());
    ref.onDispose(sub.cancel);
    return ref.read(settingsStoreProvider).session;
  }

  Future<void> login(String serverUrl, String username, String password) async =>
      _adopt(await ref.read(authGatewayProvider).login(serverUrl, username, password));

  /// Creates an account with an invite and signs in with it.
  Future<void> register(String serverUrl, String inviteCode, String username, String password) async =>
      _adopt(await ref.read(registerGatewayProvider).register(serverUrl, inviteCode, username, password));

  /// Re-reads `/me` (e.g. `is_admin` for sessions saved by older versions).
  /// Errors are ignored: offline keeps the stored user.
  Future<void> refreshUser(Future<AuthUser> Function() me) async {
    final current = state;
    if (current == null) return;
    try {
      final user = await me();
      if (state?.token != current.token) return;
      final next = current.withUser(user);
      await ref.read(settingsStoreProvider).saveSession(next);
      state = next;
    } catch (_) {}
  }

  Future<void> _adopt(AuthSession session) async {
    final settings = ref.read(settingsStoreProvider);
    final previousServer = settings.serverUrl;
    if (previousServer != null &&
        ApiClient.normalizeServerUrl(previousServer) != session.serverUrl) {
      await ref.read(platformServicesProvider).cache.clear();
    }
    await settings.saveSession(session);
    // Connected to a server: leave device-only mode (device music stays).
    if (settings.deviceOnly) await ref.read(deviceOnlyProvider.notifier).set(false);
    state = session;
  }

  Future<void> logout() async {
    if (state == null) return;
    await ref.read(settingsStoreProvider).clearSession();
    state = null;
  }
}

/// "Use without server" mode: no API calls, device music only. Persisted.
final deviceOnlyProvider = NotifierProvider<DeviceOnlyController, bool>(DeviceOnlyController.new);

class DeviceOnlyController extends Notifier<bool> {
  @override
  bool build() => ref.read(settingsStoreProvider).deviceOnly;

  Future<void> set(bool value) async {
    await ref.read(settingsStoreProvider).setDeviceOnly(value);
    state = value;
  }
}

/// True when the app has a server session (server sections are available).
final serverConnectedProvider = Provider<bool>((ref) => ref.watch(authControllerProvider) != null);

/// True when the user can use the app (server session or device-only mode).
final canUseAppProvider =
    Provider<bool>((ref) => ref.watch(serverConnectedProvider) || ref.watch(deviceOnlyProvider));
