/// Public GitHub repo that hosts APK releases.
abstract final class GithubUpdateConfig {
  static const String owner = 'SanyaWarvar';
  static const String repo = 'GymChampion';
  static const String apkAssetName = 'app-release.apk';
  static const String userAgent = 'GymChampion';

  static bool get isConfigured => owner.isNotEmpty && repo.isNotEmpty;

  static String get latestReleaseUrl =>
      'https://api.github.com/repos/$owner/$repo/releases/latest';
}
