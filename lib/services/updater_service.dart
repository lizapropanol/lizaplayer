import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

final updateAvailableProvider = StateProvider<String?>((ref) => null);
final updateProgressProvider = StateProvider<double?>((ref) => null);
final updateStatusProvider = StateProvider<String?>((ref) => null);

final updaterServiceProvider = Provider((ref) => UpdaterService(ref));

class UpdaterService {
  final Ref ref;
  final Dio _dio = Dio();

  UpdaterService(this.ref);

  Future<void> checkForUpdates() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionStr = packageInfo.version;
      
      final response = await _dio.get('https://api.github.com/repos/lizapropanol/lizaplayer/releases/latest');
      if (response.statusCode == 200) {
        final data = response.data;
        String tagName = data['tag_name'] ?? '';
        if (tagName.startsWith('v')) tagName = tagName.substring(1);

        if (_isNewerVersion(currentVersionStr, tagName)) {
          ref.read(updateAvailableProvider.notifier).state = tagName;
        }
      }
    } catch (e) {
    }
  }

  bool _isNewerVersion(String current, String latest) {
    try {
      final currParts = current.split('.').map(int.parse).toList();
      final latestParts = latest.split('.').map(int.parse).toList();
      for (int i = 0; i < 3; i++) {
        final c = currParts.length > i ? currParts[i] : 0;
        final l = latestParts.length > i ? latestParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
    } catch (_) {}
    return false;
  }

  Future<void> downloadAndInstallUpdate() async {
    final version = ref.read(updateAvailableProvider);
    if (version == null) return;

    ref.read(updateStatusProvider.notifier).state = 'Downloading...';
    ref.read(updateProgressProvider.notifier).state = 0.0;

    try {
      final response = await _dio.get('https://api.github.com/repos/lizapropanol/lizaplayer/releases/latest');
      if (response.statusCode != 200) throw Exception('Failed to get release info');

      final assets = response.data['assets'] as List;
      String? downloadUrl;
      String? assetName;

      bool isDebInstall = Platform.isLinux && File('/usr/bin/dpkg').existsSync() && 
          (Platform.resolvedExecutable.startsWith('/opt/') || Platform.resolvedExecutable.startsWith('/usr/'));

      for (var asset in assets) {
        final name = asset['name'] as String;
        if (Platform.isWindows && name.endsWith('windows.zip')) {
          downloadUrl = asset['browser_download_url'];
          assetName = name;
          break;
        } else if (Platform.isLinux) {
          if (isDebInstall && name.endsWith('.deb')) {
            downloadUrl = asset['browser_download_url'];
            assetName = name;
            break;
          } else if (!isDebInstall && name.endsWith('linux.tar.gz')) {
            downloadUrl = asset['browser_download_url'];
            assetName = name;
            break;
          }
        }
      }

      if (downloadUrl == null || assetName == null) {
        ref.read(updateStatusProvider.notifier).state = 'No compatible release found';
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/$assetName';

      await _dio.download(
        downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            ref.read(updateProgressProvider.notifier).state = received / total;
          }
        },
      );

      ref.read(updateStatusProvider.notifier).state = assetName.endsWith('.deb') ? 'Installing...' : 'Extracting...';
      ref.read(updateProgressProvider.notifier).state = null;

      final installDir = File(Platform.resolvedExecutable).parent.path;
      
      await _extractArchive(savePath, installDir);

      try {
        await File(savePath).delete();
      } catch (_) {}

      ref.read(updateStatusProvider.notifier).state = 'Ready to restart';
    } catch (e) {
      ref.read(updateStatusProvider.notifier).state = 'Error updating';
      ref.read(updateProgressProvider.notifier).state = null;
    }
  }

  Future<void> _extractArchive(String archivePath, String installDir) async {
    if (archivePath.endsWith('.deb')) {
      final result = await Process.run('pkexec', ['dpkg', '-i', archivePath]);
      if (result.exitCode != 0) {
        throw Exception('Failed to install deb: ${result.stderr}');
      }
    } else if (archivePath.endsWith('.zip')) {
      final bytes = await File(archivePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      _extractFiles(archive, installDir);
    } else if (archivePath.endsWith('.tar.gz')) {
      if (Platform.isLinux) {
        await Process.run('tar', ['-xzf', archivePath, '--strip-components=1', '-C', installDir]);
      } else {
        final bytes = await File(archivePath).readAsBytes();
        final archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
        _extractFiles(archive, installDir);
      }
    }
  }

  void _extractFiles(Archive archive, String installDir) {
    for (final file in archive) {
      final parts = file.name.split('/');
      if (parts.length <= 1 && !file.isFile) continue;
      final destName = parts.length > 1 ? parts.skip(1).join('/') : parts.first;
      if (destName.isEmpty) continue;
      
      final destPath = '$installDir/$destName';
      
      if (file.isFile) {
        final data = file.content as List<int>;
        final outFile = File(destPath);
        try {
          outFile.createSync(recursive: true);
          outFile.writeAsBytesSync(data);
        } catch (e) {
          if (Platform.isWindows) {
            try {
              outFile.renameSync('${outFile.path}.old');
              outFile.createSync(recursive: true);
              outFile.writeAsBytesSync(data);
            } catch (_) {}
          }
        }
      } else {
        Directory(destPath).createSync(recursive: true);
      }
    }
  }

  Future<void> restartApp() async {
    if (Platform.isWindows) {
      Process.start(Platform.resolvedExecutable, Platform.executableArguments, mode: ProcessStartMode.detached);
    } else {
      Process.start(Platform.resolvedExecutable, Platform.executableArguments, mode: ProcessStartMode.detached);
    }
    exit(0);
  }
}
