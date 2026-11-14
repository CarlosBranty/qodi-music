import 'package:package_info_plus/package_info_plus.dart';

import '../domain/app_update.dart';
import '../domain/update_ports.dart';

class PackageInfoVersionSource implements AppVersionSource {
  @override
  Future<InstalledVersion> installed() async {
    final info = await PackageInfo.fromPlatform();
    return InstalledVersion(info.version, int.tryParse(info.buildNumber) ?? 0);
  }
}
