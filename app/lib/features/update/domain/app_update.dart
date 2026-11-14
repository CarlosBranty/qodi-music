/// Android self-update: release manifest, version comparison, throttling and
/// checksum rules. Pure Dart (no Flutter, no IO).
library;

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

/// Persisted, language-independent summary of the last check; Settings
/// turns it into text in the active language.
abstract final class UpdateResultCode {
  static const upToDate = 'up_to_date';
  static const noPublished = 'no_published';
  static const failed = 'failed';
  static const noServer = 'no_server';
  static const availablePrefix = 'available:';
}

String resultCode(UpdateCheckResult r) => switch (r) {
      UpdateAvailable(:final release) => '${UpdateResultCode.availablePrefix}${release.versionName}',
      UpToDate() => UpdateResultCode.upToDate,
      NoPublishedUpdate() => UpdateResultCode.noPublished,
      UpdateCheckFailed() => UpdateResultCode.failed,
    };
