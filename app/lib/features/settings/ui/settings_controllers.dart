import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/core_providers.dart';
import '../../../core/config/settings_store.dart';

final themePreferenceProvider =
    NotifierProvider<ThemePreferenceController, AppThemePreference>(ThemePreferenceController.new);

class ThemePreferenceController extends Notifier<AppThemePreference> {
  @override
  AppThemePreference build() => ref.read(settingsStoreProvider).theme;

  Future<void> set(AppThemePreference v) async {
    state = v;
    await ref.read(settingsStoreProvider).setTheme(v);
  }
}

final qualityProvider = NotifierProvider<QualityController, StreamQuality>(QualityController.new);

class QualityController extends Notifier<StreamQuality> {
  @override
  StreamQuality build() => ref.read(settingsStoreProvider).quality;

  Future<void> set(StreamQuality v) async {
    state = v;
    await ref.read(settingsStoreProvider).setQuality(v);
  }
}
