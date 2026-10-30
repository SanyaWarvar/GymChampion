import 'package:flutter_test/flutter_test.dart';
import 'package:gym_champion/features/updates/github_release_client.dart';

void main() {
  group('parseReleaseTag', () {
    test('parses v-prefixed tag with build', () {
      final tag = parseReleaseTag('v1.6.0+17');
      expect(tag, isNotNull);
      expect(tag!.versionName, '1.6.0');
      expect(tag.versionCode, 17);
      expect(tag.label, 'v1.6.0 (17)');
    });

    test('parses tag without v prefix', () {
      final tag = parseReleaseTag('2.0.1+42');
      expect(tag, isNotNull);
      expect(tag!.versionName, '2.0.1');
      expect(tag.versionCode, 42);
    });

    test('returns null without build number', () {
      expect(parseReleaseTag('v1.6.0'), isNull);
      expect(parseReleaseTag('v1.6.0+'), isNull);
      expect(parseReleaseTag('+17'), isNull);
      expect(parseReleaseTag(''), isNull);
      expect(parseReleaseTag('v1.6.0+abc'), isNull);
    });

    test('rejects non-positive build', () {
      expect(parseReleaseTag('v1.0.0+0'), isNull);
      expect(parseReleaseTag('v1.0.0+-1'), isNull);
    });
  });
}
