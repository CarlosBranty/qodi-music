import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/media_urls.dart';
import '../platform/platform_services.dart';
import 'settings_store.dart';

/// Overridden in `main()` with the loaded instance.
final settingsStoreProvider = Provider<SettingsStore>(
    (ref) => throw UnimplementedError('settingsStoreProvider must be overridden'));

/// Overridden in `main()` with the platform adapters.
final platformServicesProvider = Provider<PlatformServices>(
    (ref) => throw UnimplementedError('platformServicesProvider must be overridden'));

/// Emits when the server rejects the stored token (401 `unauthorized`).
final sessionExpiredProvider = Provider<StreamController<void>>((ref) {
  final c = StreamController<void>.broadcast();
  ref.onDispose(c.close);
  return c;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final settings = ref.watch(settingsStoreProvider);
  final expired = ref.watch(sessionExpiredProvider);
  return ApiClient(
    serverUrl: () => settings.serverUrl,
    token: () => settings.token,
    onUnauthorized: () => expired.add(null),
  );
});

final mediaUrlsProvider = Provider<MediaUrls>((ref) => ApiMediaUrls(ref.watch(apiClientProvider)));
