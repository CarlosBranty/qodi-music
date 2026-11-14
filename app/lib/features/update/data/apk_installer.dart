import '../domain/update_ports.dart';
import 'apk_installer_stub.dart' if (dart.library.io) 'apk_installer_io.dart' as impl;

/// Native APK installer (Android); a stub on web.
ApkInstaller createApkInstaller() => impl.createApkInstaller();
