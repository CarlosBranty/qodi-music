/// Android self-update: release manifest, version comparison, throttling and
/// checksum rules. Pure Dart (no Flutter, no IO).
library;

/// User-facing copy of the update UI (kept together for translation).
abstract final class UpdateStrings {
  static const appUpdates = 'App updates';
  static const checkForUpdates = 'Check for updates';
  static String currentVersion(String version) => 'Current version $version';
  static const checking = 'Checking…';
  static const neverChecked = 'Not checked yet';
  static const upToDate = 'You have the latest version';
  static const noPublished = 'No update published on the server';
  static const checkFailed = 'Could not check for updates';
  static const noServer = 'Connect to a server to get updates';
  static String available(String version) => 'Version $version is available';
  static String lastChecked(String when, String result) => '$result · checked $when';
  static const updateAvailable = 'Update available';
  static String updateQuestion(String from, String to) => 'Update available (v$from → v$to)';
  static const update = 'Update';
  static const later = 'Later';
  static const downloading = 'Downloading update…';
  static const checksumMismatch = 'The download is corrupted (checksum mismatch). Please try again.';
  static const downloadFailed = 'The download failed. Check your connection and try again.';
  static const installPermission = 'Allow Qodi Music to install apps to update it.';
  static const openSettings = 'Open settings';
  static const installFailed = 'Could not open the installer.';
}

/// `GET /app/android`.
class AndroidRelease {
  const AndroidRelease({
    required this.versionName,
    required this.versionCode,
    required this.url,
    required this.sha256,
    required this.sizeBytes,
    this.publishedAt,
  });

  final String versionName;
  final int versionCode;

  /// Server-relative path, e.g. `/downloads/android/qodi-music.apk`.
  final String url;
  final String sha256;
  final int sizeBytes;
  final String? publishedAt;

  /// Absolute download URL on [serverOrigin] (absolute [url]s are kept).
  Uri downloadUri(String serverOrigin) => Uri.parse(serverOrigin).resolve(url);
}

/// Installed app version (`package_info_plus`).
class InstalledVersion {
  const InstalledVersion(this.name, this.buildNumber);
  final String name;
  final int buildNumber;
}

sealed class UpdateCheckResult {
  const UpdateCheckResult();
}

class UpdateAvailable extends UpdateCheckResult {
  const UpdateAvailable(this.release, this.installed);
  final AndroidRelease release;
  final InstalledVersion installed;
}

class UpToDate extends UpdateCheckResult {
  const UpToDate();
}

/// 404: the server has no APK published.
class NoPublishedUpdate extends UpdateCheckResult {
  const NoPublishedUpdate();
}

class UpdateCheckFailed extends UpdateCheckResult {
  const UpdateCheckFailed(this.error);
  final Object error;
}

/// Newer only when the published `version_code` is strictly greater than the
/// installed build number (same or older → up to date).
UpdateCheckResult compareRelease(AndroidRelease? release, InstalledVersion installed) {
  if (release == null) return const NoPublishedUpdate();
  return release.versionCode > installed.buildNumber ? UpdateAvailable(release, installed) : const UpToDate();
}

/// Automatic checks run at most once per [interval]; a clock that moved
/// backwards also allows a check.
const autoCheckInterval = Duration(hours: 6);

bool shouldAutoCheck({required DateTime? lastCheck, required DateTime now, Duration interval = autoCheckInterval}) {
  if (lastCheck == null) return true;
  final elapsed = now.difference(lastCheck);
  return elapsed.isNegative || elapsed >= interval;
}

/// Case-insensitive hex comparison; an empty expected value never matches.
bool sha256Matches(String actualHex, String expectedHex) {
  final expected = expectedHex.trim().toLowerCase();
  return expected.isNotEmpty && actualHex.trim().toLowerCase() == expected;
}

/// Self-update exists only in the Android app (not web/desktop/iOS).
bool updatesSupportedOn({required bool isWeb, required bool isAndroid}) => !isWeb && isAndroid;

/// Short text of a check result for Settings.
String describeResult(UpdateCheckResult r) => switch (r) {
      UpdateAvailable(:final release) => UpdateStrings.available(release.versionName),
      UpToDate() => UpdateStrings.upToDate,
      NoPublishedUpdate() => UpdateStrings.noPublished,
      UpdateCheckFailed() => UpdateStrings.checkFailed,
    };
