import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qodi_music/core/config/core_providers.dart';
import 'package:qodi_music/features/update/data/release_api.dart';
import 'package:qodi_music/features/update/domain/app_update.dart';
import 'package:qodi_music/features/update/domain/update_ports.dart';
import 'package:qodi_music/features/update/ui/update_controller.dart';

import '../support/fake_http.dart';
import '../support/fakes.dart';
import '../support/l10n.dart';

const _release = AndroidRelease(
    versionName: '0.2.0', versionCode: 57, url: '/downloads/android/qodi-music.apk', sha256: 'ABC123', sizeBytes: 10);

class FakeReleases implements ReleaseSource {
  FakeReleases(this.release);
  AndroidRelease? release;
  Object? error;
  final List<String> calls = [];
  @override
  Future<AndroidRelease?> latest(String serverOrigin) async {
    calls.add(serverOrigin);
    if (error != null) throw error!;
    return release;
  }
}

class FakeVersion implements AppVersionSource {
  FakeVersion(this.build);
  final int build;
  @override
  Future<InstalledVersion> installed() async => InstalledVersion('0.1.0', build);
}

class FakeInstaller implements ApkInstaller {
  String hash = 'abc123';
  InstallPermission permission = InstallPermission.granted;
  bool failDownload = false;
  final List<Uri> downloads = [];
  final List<String> deleted = [];
  final List<String> installed = [];

  @override
  Future<String> download(Uri url, String fileName, {void Function(double progress)? onProgress}) async {
    downloads.add(url);
    if (failDownload) throw Exception('offline');
    onProgress?.call(0.5);
    onProgress?.call(1);
    return '/cache/updates/$fileName';
  }

  @override
  Future<String> sha256Of(String path) async => hash;
  @override
  Future<void> delete(String path) async => deleted.add(path);
  @override
  Future<InstallPermission> ensureInstallPermission() async => permission;
  @override
  Future<void> openInstallSettings() async {}
  @override
  Future<bool> install(String path) async {
    installed.add(path);
    return true;
  }
}

void main() {
  group('rules', () {
    test('newer / same / older version code', () {
      expect(compareRelease(_release, const InstalledVersion('0.1.0', 56)), isA<UpdateAvailable>());
      expect(compareRelease(_release, const InstalledVersion('0.2.0', 57)), isA<UpToDate>());
      expect(compareRelease(_release, const InstalledVersion('0.3.0', 60)), isA<UpToDate>());
      expect(compareRelease(null, const InstalledVersion('0.1.0', 1)), isA<NoPublishedUpdate>());
    });

    test('auto check throttled to once per 6 h', () {
      final now = DateTime(2026, 11, 14, 12);
      expect(shouldAutoCheck(lastCheck: null, now: now), isTrue);
      expect(shouldAutoCheck(lastCheck: now.subtract(const Duration(hours: 5, minutes: 59)), now: now), isFalse);
      expect(shouldAutoCheck(lastCheck: now.subtract(const Duration(hours: 6)), now: now), isTrue);
      expect(shouldAutoCheck(lastCheck: now.add(const Duration(hours: 1)), now: now), isTrue, reason: 'clock moved back');
    });

    test('sha256 comparison is case-insensitive and never matches empty', () {
      expect(sha256Matches('abc123', 'ABC123'), isTrue);
      expect(sha256Matches('abc124', 'abc123'), isFalse);
      expect(sha256Matches('', ''), isFalse);
    });

    test('Android only', () {
      expect(updatesSupportedOn(isWeb: false, isAndroid: true), isTrue);
      expect(updatesSupportedOn(isWeb: true, isAndroid: true), isFalse);
      expect(updatesSupportedOn(isWeb: false, isAndroid: false), isFalse);
    });

    test('download URL resolves the server-relative path', () {
      expect(_release.downloadUri('http://nas:4040').toString(), 'http://nas:4040/downloads/android/qodi-music.apk');
    });
  });

  group('ReleaseApi', () {
    test('parses the manifest without sending a token', () async {
      final http = FakeHttpAdapter({
        'GET /api/v1/app/android': const FakeResponse(200, {
          'version_name': '0.2.0',
          'version_code': 57,
          'url': '/downloads/android/qodi-music.apk',
          'sha256': 'abc',
          'size_bytes': 123,
          'published_at': '2026-11-14T00:00:00Z'
        })
      });
      final r = await ReleaseApi(adapter: http).latest('http://nas:4040');
      expect((r!.versionName, r.versionCode, r.sha256, r.sizeBytes), ('0.2.0', 57, 'abc', 123));
      expect(http.requests.single.headers.containsKey('Authorization'), isFalse);
    });

    test('404 means no update published', () async {
      final http = FakeHttpAdapter({});
      expect(await ReleaseApi(adapter: http).latest('http://nas:4040'), isNull);
    });
  });

  group('UpdateController', () {
    late FakeReleases releases;
    late FakeInstaller installer;
    late DateTime now;

    Future<ProviderContainer> make({Map<String, Object> prefs = const {'server_url': 'http://nas:4040'}, bool supported = true, int build = 50}) async {
      releases = FakeReleases(_release);
      installer = FakeInstaller();
      now = DateTime(2026, 11, 14, 12);
      final c = ProviderContainer(overrides: [
        ...await baseOverrides(prefs: prefs, updatesSupported: supported),
        releaseSourceProvider.overrideWithValue(releases),
        appVersionSourceProvider.overrideWithValue(FakeVersion(build)),
        apkInstallerProvider.overrideWithValue(installer),
        updateClockProvider.overrideWithValue(() => now),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('auto check runs once per 6 h and persists the result', () async {
      final c = await make();
      final ctl = c.read(updateControllerProvider.notifier);
      expect(await ctl.check(auto: true), isA<UpdateAvailable>());
      now = now.add(const Duration(hours: 2));
      expect(await ctl.check(auto: true), isNull);
      expect(releases.calls, ['http://nas:4040']);
      expect(c.read(settingsStoreProvider).updateLastResult, 'available:0.2.0', reason: 'stored as a language-independent code');
      expect(describeUpdateResult(en, c.read(settingsStoreProvider).updateLastResult!), 'Version 0.2.0 is available');
      // A manual check is never throttled.
      expect(await ctl.check(), isA<UpdateAvailable>());
      // The manual check also restarts the 6 h window.
      now = now.add(const Duration(hours: 4));
      expect(await ctl.check(auto: true), isNull);
      now = now.add(const Duration(hours: 2));
      expect(await ctl.check(auto: true), isA<UpdateAvailable>());
      expect(releases.calls.length, 3);
    });

    test('throttle survives restarts (stored in prefs)', () async {
      final c = await make(prefs: {
        'server_url': 'http://nas:4040',
        'update_last_check': DateTime(2026, 11, 14, 10).millisecondsSinceEpoch,
      });
      expect(await c.read(updateControllerProvider.notifier).check(auto: true), isNull);
      expect(releases.calls, isEmpty);
    });

    test('same version is up to date; 404 is no update; errors are reported', () async {
      final c = await make(build: 57);
      final ctl = c.read(updateControllerProvider.notifier);
      expect(await ctl.check(), isA<UpToDate>());
      releases.release = null;
      expect(await ctl.check(), isA<NoPublishedUpdate>());
      releases.error = Exception('offline');
      expect(await ctl.check(), isA<UpdateCheckFailed>());
      expect(c.read(updateControllerProvider).lastResult, UpdateResultCode.failed);
    });

    test('skipped without a known server URL or off Android', () async {
      final noServer = await make(prefs: const {});
      expect(await noServer.read(updateControllerProvider.notifier).check(auto: true), isNull);
      final desktop = await make(supported: false);
      expect(await desktop.read(updateControllerProvider.notifier).check(), isNull);
      expect(releases.calls, isEmpty);
    });

    test('download, verify and install', () async {
      final c = await make();
      expect(await c.read(updateControllerProvider.notifier).downloadAndInstall(_release), isTrue);
      expect(installer.downloads.single.toString(), 'http://nas:4040/downloads/android/qodi-music.apk');
      expect(installer.installed, ['/cache/updates/qodi-music-57.apk']);
      expect(installer.deleted, isEmpty);
      expect(c.read(updateControllerProvider).error, isNull);
    });

    test('checksum mismatch: error, file deleted, installer not opened', () async {
      final c = await make();
      installer.hash = 'ffff';
      expect(await c.read(updateControllerProvider.notifier).downloadAndInstall(_release), isFalse);
      expect(c.read(updateControllerProvider).error, UpdateError.checksumMismatch);
      expect(installer.deleted, ['/cache/updates/qodi-music-57.apk']);
      expect(installer.installed, isEmpty);
    });

    test('no permission to install unknown apps / network errors', () async {
      final c = await make();
      final ctl = c.read(updateControllerProvider.notifier);
      installer.permission = InstallPermission.denied;
      expect(await ctl.downloadAndInstall(_release), isFalse);
      expect(c.read(updateControllerProvider).error, UpdateError.permissionDenied);
      installer.failDownload = true;
      expect(await ctl.downloadAndInstall(_release), isFalse);
      expect(c.read(updateControllerProvider).error, UpdateError.downloadFailed);
      expect(c.read(updateControllerProvider).progress, isNull);
    });
  });
}
