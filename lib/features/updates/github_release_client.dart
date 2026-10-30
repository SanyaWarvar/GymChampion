import 'dart:convert';

import 'package:http/http.dart' as http;

import 'github_update_config.dart';

class ParsedReleaseTag {
  const ParsedReleaseTag({
    required this.versionName,
    required this.versionCode,
  });

  final String versionName;
  final int versionCode;

  String get label => 'v$versionName ($versionCode)';
}

/// Parses tags like `v1.6.0+17` or `1.6.0+17`.
ParsedReleaseTag? parseReleaseTag(String tag) {
  var raw = tag.trim();
  if (raw.isEmpty) return null;
  if (raw.startsWith('v') || raw.startsWith('V')) {
    raw = raw.substring(1);
  }
  final plus = raw.lastIndexOf('+');
  if (plus <= 0 || plus >= raw.length - 1) return null;
  final name = raw.substring(0, plus).trim();
  final code = int.tryParse(raw.substring(plus + 1).trim());
  if (name.isEmpty || code == null || code <= 0) return null;
  return ParsedReleaseTag(versionName: name, versionCode: code);
}

class GithubRelease {
  const GithubRelease({
    required this.tag,
    required this.apkDownloadUrl,
    required this.apkSizeBytes,
  });

  final ParsedReleaseTag tag;
  final String apkDownloadUrl;
  final int? apkSizeBytes;
}

class GithubReleaseClient {
  GithubReleaseClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<GithubRelease?> fetchLatest() async {
    if (!GithubUpdateConfig.isConfigured) return null;

    final response = await _client.get(
      Uri.parse(GithubUpdateConfig.latestReleaseUrl),
      headers: {
        'Accept': 'application/vnd.github+json',
        'User-Agent': GithubUpdateConfig.userAgent,
        'X-GitHub-Api-Version': '2022-11-28',
      },
    );

    if (response.statusCode == 404) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('GitHub releases HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) return null;

    if (body['draft'] == true || body['prerelease'] == true) return null;

    final tagName = body['tag_name'] as String?;
    if (tagName == null) return null;
    final tag = parseReleaseTag(tagName);
    if (tag == null) return null;

    final assets = body['assets'];
    if (assets is! List) return null;

    Map<String, dynamic>? apk;
    for (final item in assets) {
      if (item is! Map<String, dynamic>) continue;
      if (item['name'] == GithubUpdateConfig.apkAssetName) {
        apk = item;
        break;
      }
    }
    if (apk == null) return null;

    final url = apk['browser_download_url'] as String?;
    if (url == null || url.isEmpty) return null;

    final size = apk['size'];
    return GithubRelease(
      tag: tag,
      apkDownloadUrl: url,
      apkSizeBytes: size is int ? size : null,
    );
  }
}
