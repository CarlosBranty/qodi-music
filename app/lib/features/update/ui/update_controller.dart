import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/config/core_providers.dart';
import '../data/apk_installer.dart';
import '../data/package_info_version.dart';
import '../data/release_api.dart';
import '../domain/app_update.dart';
import '../domain/update_ports.dart';

/// Android only (hidden on web, desktop and iOS). Tests override it.
final updatesSupportedProvider = Provider<bool>(
    (ref) => updatesSupportedOn(isWeb: kIsWeb, isAndroid: defaultTargetPlatform == TargetPlatform.android));

final releaseSourceProvider = Provider<ReleaseSource>((ref) => ReleaseApi());
final appVersionSourceProvider = Provider<AppVersionSource>((ref) => PackageInfoVersionSource());
final apkInstallerProvider = Provider<ApkInstaller>((ref) => createApkInstaller());
final updateClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

enum UpdateError { checksumMismatch, downloadFailed, permissionDenied, installFailed }

String updateErrorMessage(UpdateError e) => switch (e) {
      UpdateError.checksumMismatch => UpdateStrings.checksumMismatch,
      UpdateError.downloadFailed => UpdateStrings.downloadFailed,
      UpdateError.permissionDenied => UpdateStrings.installPermission,
      UpdateError.installFailed => UpdateStrings.installFailed,
    };

class UpdateState {
  const UpdateState({
    this.installed,
    this.checking = false,
    this.lastCheck,
    this.lastResult,
    this.result,
    this.progress,
    this.error,
  });

  final InstalledVersion? installed;
  final bool checking;
  final DateTime? lastCheck;

  /// Short text of the last check (persisted).
  final String? lastResult;
  final UpdateCheckResult? result;

  /// 0..1 while an update downloads, else null.
  final double? progress;
  final UpdateError? error;

  UpdateState copyWith({
    InstalledVersion? installed,
    bool? checking,
    DateTime? lastCheck,
    String? lastResult,
    UpdateCheckResult? result,
    double? Function()? progress,
    UpdateError? Function()? error,
  }) =>
      UpdateState(
        installed: installed ?? this.installed,
        checking: checking ?? this.checking,
        lastCheck: lastCheck ?? this.lastCheck,
        lastResult: lastResult ?? this.lastResult,
        result: result ?? this.result,
        progress: progress == null ? this.progress : progress(),
        error: error == null ? this.error : error(),
      );
}

final updateControllerProvider = NotifierProvider<UpdateController, UpdateState>(UpdateController.new);

/// Checks `GET /app/android` (automatically at most every 6 h, or on demand),
/// downloads the APK, verifies its SHA-256 and opens the system installer.
class UpdateController extends Notifier<UpdateState> {
  @override
  UpdateState build() {
    final settings = ref.read(settingsStoreProvider);
    return UpdateState(lastCheck: settings.updateLastCheck, lastResult: settings.updateLastResult);
  }

  bool get supported => ref.read(updatesSupportedProvider);

  Future<InstalledVersion> _installed() async {
    final known = state.installed;
    if (known != null) return known;
    final v = await ref.read(appVersionSourceProvider).installed();
    state = state.copyWith(installed: v);
    return v;
  }

  /// Loads the installed version for Settings.
  Future<void> loadInstalled() async {
    if (!supported) return;
    try {
      await _installed();
    } catch (_) {}
  }

  /// Returns null when skipped: unsupported platform, no known server, or
  /// (automatic) checked less than 6 h ago. Never throws.
  Future<UpdateCheckResult?> check({bool auto = false}) async {
    if (!supported || state.checking) return null;
    final settings = ref.read(settingsStoreProvider);
    final server = settings.serverUrl?.trim() ?? '';
    final now = ref.read(updateClockProvider)();
    if (server.isEmpty) {
      if (!auto) state = state.copyWith(lastResult: UpdateStrings.noServer);
      return null;
    }
    if (auto && !shouldAutoCheck(lastCheck: state.lastCheck, now: now)) return null;
    state = state.copyWith(checking: true);
    UpdateCheckResult result;
    try {
      final installed = await _installed();
      final release = await ref.read(releaseSourceProvider).latest(ApiClient.normalizeServerUrl(server));
      result = compareRelease(release, installed);
    } catch (e) {
      result = UpdateCheckFailed(e);
    }
    final text = describeResult(result);
    await settings.setUpdateCheck(now, text);
    state = state.copyWith(checking: false, lastCheck: now, lastResult: text, result: result);
    return result;
  }

  /// Downloads, verifies and installs [release]. On a checksum mismatch the
  /// file is deleted. Returns true when the installer was opened.
  Future<bool> downloadAndInstall(AndroidRelease release) async {
    if (!supported || state.progress != null) return false;
    final installer = ref.read(apkInstallerProvider);
    final origin = ApiClient.normalizeServerUrl(ref.read(settingsStoreProvider).serverUrl ?? '');
    state = state.copyWith(progress: () => 0, error: () => null);
    String path;
    try {
      path = await installer.download(
        release.downloadUri(origin),
        'qodi-music-${release.versionCode}.apk',
        onProgress: (p) => state = state.copyWith(progress: () => p.clamp(0.0, 1.0)),
      );
    } catch (_) {
      return _fail(UpdateError.downloadFailed);
    }
    try {
      if (!sha256Matches(await installer.sha256Of(path), release.sha256)) {
        await installer.delete(path);
        return _fail(UpdateError.checksumMismatch);
      }
    } catch (_) {
      await installer.delete(path);
      return _fail(UpdateError.checksumMismatch);
    }
    state = state.copyWith(progress: () => 1);
    if (await installer.ensureInstallPermission() != InstallPermission.granted) {
      return _fail(UpdateError.permissionDenied);
    }
    final opened = await installer.install(path).catchError((Object _) => false);
    if (!opened) return _fail(UpdateError.installFailed);
    state = state.copyWith(progress: () => null);
    return true;
  }

  bool _fail(UpdateError e) {
    state = state.copyWith(progress: () => null, error: () => e);
    return false;
  }

  Future<void> openInstallSettings() => ref.read(apkInstallerProvider).openInstallSettings();

  void clearError() => state = state.copyWith(error: () => null);
}
