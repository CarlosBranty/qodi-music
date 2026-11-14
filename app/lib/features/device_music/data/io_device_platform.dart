import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import '../domain/device_music_source.dart';
import '../domain/device_track.dart';

/// [DeviceMusicPlatform] for Android, iOS, Linux, Windows and macOS.
class IoDeviceMusicPlatform implements DeviceMusicPlatform {
  IoDeviceMusicPlatform({required this.importsDir});

  /// iOS only: folder inside the app documents dir that holds imported music
  /// (also visible in the Files app thanks to `UIFileSharingEnabled`).
  final String importsDir;

  @override
  bool get canPickFolders => !Platform.isIOS;

  @override
  bool get importsFiles => Platform.isIOS;

  @override
  Future<List<String>> defaultFolders() async {
    if (Platform.isAndroid) {
      return const ['/storage/emulated/0/Music', '/storage/emulated/0/Download'];
    }
    if (Platform.isIOS) {
      await Directory(importsDir).create(recursive: true);
      return [importsDir];
    }
    final env = Platform.environment;
    final home = Platform.isWindows ? env['USERPROFILE'] : env['HOME'];
    if (home == null || home.isEmpty) return const [];
    final folders = <String>{p.join(home, 'Music')};
    if (Platform.isLinux) {
      final xdg = _xdgMusicDir(home);
      if (xdg != null) folders.add(xdg);
    }
    return folders.toList();
  }

  /// `XDG_MUSIC_DIR` from `~/.config/user-dirs.dirs` (localized folder names).
  static String? _xdgMusicDir(String home) {
    try {
      final file = File(p.join(home, '.config', 'user-dirs.dirs'));
      if (!file.existsSync()) return null;
      for (final line in file.readAsLinesSync()) {
        final m = RegExp(r'^XDG_MUSIC_DIR="(.*)"').firstMatch(line.trim());
        if (m == null) continue;
        final value = m.group(1)!.replaceAll(r'$HOME', home);
        return value == home ? null : p.normalize(value);
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<DevicePermission> permissionStatus() async {
    if (!Platform.isAndroid) return DevicePermission.notRequired;
    return _combine([await Permission.audio.status, await Permission.storage.status]);
  }

  @override
  Future<DevicePermission> requestPermission() async {
    if (!Platform.isAndroid) return DevicePermission.notRequired;
    // READ_MEDIA_AUDIO on API 33+, READ_EXTERNAL_STORAGE up to API 32.
    final statuses = await [Permission.audio, Permission.storage].request();
    return _combine(statuses.values.toList());
  }

  static DevicePermission _combine(List<PermissionStatus> statuses) {
    if (statuses.any((s) => s.isGranted || s.isLimited)) return DevicePermission.granted;
    if (statuses.any((s) => s.isPermanentlyDenied)) return DevicePermission.permanentlyDenied;
    return DevicePermission.denied;
  }

  @override
  Future<void> openPermissionSettings() async {
    await openAppSettings();
  }

  @override
  Future<String?> pickFolder() => FilePicker.getDirectoryPath(dialogTitle: 'Choose a music folder');

  @override
  Future<int> importFiles() async {
    // Custom extensions use the document picker (Files app); FileType.audio
    // would open the Apple Music library, whose items are not plain files.
    final files = await FilePicker.pickFiles(
      dialogTitle: 'Import music',
      type: FileType.custom,
      allowedExtensions: deviceAudioExtensions.toList(),
    );
    if (files.isEmpty) return 0;
    await Directory(importsDir).create(recursive: true);
    var count = 0;
    for (final f in files) {
      final source = f.path;
      if (source == null) continue;
      final ext = p.extension(source).replaceFirst('.', '').toLowerCase();
      if (!deviceAudioExtensions.contains(ext)) continue;
      try {
        await File(source).copy(p.join(importsDir, p.basename(source)));
        count++;
      } catch (_) {}
    }
    return count;
  }
}
