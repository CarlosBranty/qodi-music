import '../domain/update_ports.dart';

ApkInstaller createApkInstaller() => const _UnsupportedInstaller();

class _UnsupportedInstaller implements ApkInstaller {
  const _UnsupportedInstaller();
  Never _no() => throw UnsupportedError('APK updates are Android only');
  @override
  Future<String> download(Uri url, String fileName, {void Function(double progress)? onProgress}) async => _no();
  @override
  Future<String> sha256Of(String path) async => _no();
  @override
  Future<void> delete(String path) async {}
  @override
  Future<InstallPermission> ensureInstallPermission() async => InstallPermission.denied;
  @override
  Future<void> openInstallSettings() async {}
  @override
  Future<bool> install(String path) async => false;
}
