import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/config/settings_store.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/ui/auth_controller.dart';
import 'features/library/ui/library_providers.dart';
import 'features/stats/ui/stats_providers.dart';
import 'core/config/core_providers.dart';
import 'features/settings/ui/settings_controllers.dart';

class QodiApp extends ConsumerStatefulWidget {
  const QodiApp({super.key});

  @override
  ConsumerState<QodiApp> createState() => _QodiAppState();
}

class _QodiAppState extends ConsumerState<QodiApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _backgroundSync);
    WidgetsBinding.instance.addPostFrameCallback((_) => _backgroundSync());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Flushes queued plays and (native) syncs the offline library cache.
  Future<void> _backgroundSync() async {
    if (ref.read(authControllerProvider) == null) return;
    await ref.read(playsReporterProvider).flush();
    if (ref.read(platformServicesProvider).supportsOffline) {
      try {
        await ref.read(librarySyncProvider).sync();
      } catch (_) {
        // Offline or server unavailable: keep the existing cache.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (prev, next) {
      if (prev == null && next != null) _backgroundSync();
    });
    final router = ref.watch(appRouterProvider);
    final pref = ref.watch(themePreferenceProvider);
    return MaterialApp.router(
      title: 'Qodi Music',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: switch (pref) {
        AppThemePreference.system => ThemeMode.system,
        AppThemePreference.light => ThemeMode.light,
        AppThemePreference.dark => ThemeMode.dark,
      },
      routerConfig: router,
    );
  }
}
