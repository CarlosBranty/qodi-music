import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/core_providers.dart';
import '../data/auth_api.dart';
import '../domain/auth_state.dart';

final authGatewayProvider = Provider<AuthGateway>((ref) => AuthApi());

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

  Future<void> login(String serverUrl, String username, String password) async {
    final settings = ref.read(settingsStoreProvider);
    final previousServer = settings.serverUrl;
    final session = await ref.read(authGatewayProvider).login(serverUrl, username, password);
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
