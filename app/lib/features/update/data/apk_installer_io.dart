import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/update_ports.dart';

ApkInstaller createApkInstaller() => IoApkInstaller();

/// Downloads into the app cache dir (served to the installer by open_filex's
/// FileProvider) and opens it with the system package installer.
class IoApkInstaller implements ApkInstaller {
  IoApkInstaller({Dio? dio}) : _dio = dio ?? Dio();
  final Dio _dio;

  static const apkMimeType = 'application/vnd.android.package-archive';

  @override
  Future<String> download(Uri url, String fileName, {void Function(double progress)? onProgress}) async {
    final dir = Directory(p.join((await getTemporaryDirectory()).path, 'updates'));
    await dir.create(recursive: true);
    final path = p.join(dir.path, fileName);
    final part = '$path.part';
    try {
      await _dio.downloadUri(url, part, onReceiveProgress: (received, total) {
        if (total > 0) onProgress?.call(received / total);
      });
      await File(part).rename(path);
    } catch (_) {
      await delete(part);
      rethrow;
    }
    return path;
  }

  @override
  Future<String> sha256Of(String path) async => (await sha256.bind(File(path).openRead()).first).toString();

  @override
  Future<void> delete(String path) async {
    try {
      await File(path).delete();
    } catch (_) {}
  }

  @override
  Future<InstallPermission> ensureInstallPermission() async {
    var status = await Permission.requestInstallPackages.status;
    if (!status.isGranted) status = await Permission.requestInstallPackages.request();
    return status.isGranted ? InstallPermission.granted : InstallPermission.denied;
  }

  @override
  Future<void> openInstallSettings() async {
    // Opens "Install unknown apps" for this app; falls back to app details.
    final status = await Permission.requestInstallPackages.request();
    if (!status.isGranted) await openAppSettings();
  }

  @override
  Future<bool> install(String path) async {
    final result = await OpenFilex.open(path, type: apkMimeType);
    return result.type == ResultType.done;
  }
}
