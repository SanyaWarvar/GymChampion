import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'github_release_client.dart';
import 'github_update_config.dart';

class AvailableUpdate {
  const AvailableUpdate({
    required this.release,
    required this.currentBuild,
  });

  final GithubRelease release;
  final int currentBuild;

  String get versionLabel => release.tag.label;
}

/// Checks GitHub Releases and installs APKs on Android.
class AppUpdateService {
  AppUpdateService({
    GithubReleaseClient? client,
    http.Client? httpClient,
  })  : _releases = client ?? GithubReleaseClient(client: httpClient),
        _http = httpClient ?? http.Client();

  static const _channel = MethodChannel('gymchampion/updates');

  final GithubReleaseClient _releases;
  final http.Client _http;

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<AvailableUpdate?> checkForUpdate() async {
    if (!isSupported || !GithubUpdateConfig.isConfigured) return null;

    final info = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(info.buildNumber) ?? 0;
    final release = await _releases.fetchLatest();
    if (release == null) return null;
    if (release.tag.versionCode <= currentBuild) return null;

    return AvailableUpdate(release: release, currentBuild: currentBuild);
  }

  Future<File> downloadApk(
    AvailableUpdate update, {
    void Function(double progress)? onProgress,
  }) async {
    final tmp = await getTemporaryDirectory();
    final dir = Directory('${tmp.path}/updates');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File('${dir.path}/gymchampion-update.apk');
    if (await file.exists()) {
      await file.delete();
    }

    final request = http.Request(
      'GET',
      Uri.parse(update.release.apkDownloadUrl),
    );
    request.headers['User-Agent'] = GithubUpdateConfig.userAgent;
    request.headers['Accept'] = 'application/octet-stream';

    final response = await _http.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('APK download HTTP ${response.statusCode}');
    }

    final total = response.contentLength ?? update.release.apkSizeBytes ?? 0;
    final sink = file.openWrite();
    var received = 0;

    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          onProgress?.call((received / total).clamp(0.0, 1.0));
        }
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    onProgress?.call(1.0);
    return file;
  }

  /// `opened_settings` if install permission was missing; otherwise `started_installer`.
  Future<String> installApk(File apk) async {
    if (!isSupported) {
      throw UnsupportedError('APK install is only supported on Android');
    }
    final result = await _channel.invokeMethod<String>(
      'installApk',
      {'path': apk.path},
    );
    return result ?? 'started_installer';
  }
}
