import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/config/settings_store.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/account/ui/account_providers.dart';
import 'features/auth/ui/auth_controller.dart';
import 'features/update/domain/app_update.dart';
import 'features/update/ui/update_controller.dart';
import 'features/update/ui/update_dialogs.dart';
import 'features/equalizer/ui/equalizer_controller.dart';
import 'features/library/ui/library_providers.dart';
import 'features/stats/ui/stats_providers.dart';
import 'core/config/core_providers.dart';
import 'features/settings/ui/settings_controllers.dart';
import 'l10n/l10n.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _backgroundSync();
      _autoUpdateCheck();
    });
  }

  /// Android: at most once per 6 h, never blocking start-up.
  Future<void> _autoUpdateCheck() async {
    final result = await ref.read(updateControllerProvider.notifier).check(auto: true);
    if (result is! UpdateAvailable || !mounted) return;
    final navigator = ref.read(appRouterProvider).routerDelegate.navigatorKey.currentContext;
    if (navigator != null && navigator.mounted) await showUpdateAvailableDialog(navigator, ref, result);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Flushes queued plays and (native) syncs the offline library cache.
  Future<void> _backgroundSync() async {
    if (ref.read(authControllerProvider) == null) return;
    // Refreshes `is_admin` (sessions saved by older versions lack it).
    ref.read(authControllerProvider.notifier).refreshUser(ref.read(accountApiProvider).me);
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
    // Keeps the equalizer alive so saved settings are applied on start and
    // as soon as the engine reports its bands.
    ref.listen(equalizerControllerProvider, (_, _) {});
    final router = ref.watch(appRouterProvider);
    final pref = ref.watch(themePreferenceProvider);
    final language = ref.watch(languagePreferenceProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      // Null follows the device/browser locale (resolved by resolveAppLocale).
      locale: language.locale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      localeListResolutionCallback: (locales, _) => resolveAppLocale(locales),
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
