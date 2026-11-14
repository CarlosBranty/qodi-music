import 'app_update.dart';

/// Fetches the published Android release (`GET /app/android`, public).
abstract interface class ReleaseSource {
  /// Null when the server has no APK published (404).
  Future<AndroidRelease?> latest(String serverOrigin);
}

abstract interface class AppVersionSource {
  Future<InstalledVersion> installed();
}

enum InstallPermission { granted, denied }

/// Downloads and installs APKs (Android only).
abstract interface class ApkInstaller {
  /// Downloads [url] into the app cache dir and returns the file path.
  Future<String> download(Uri url, String fileName, {void Function(double progress)? onProgress});

  /// Lower-case hex SHA-256 of the file at [path].
  Future<String> sha256Of(String path);

  Future<void> delete(String path);

  /// Checks "install unknown apps"; asking opens the system setting.
  Future<InstallPermission> ensureInstallPermission();

  /// Opens the system "install unknown apps" setting for this app.
  Future<void> openInstallSettings();

  /// Launches the system package installer; false when it could not open.
  Future<bool> install(String path);
}
