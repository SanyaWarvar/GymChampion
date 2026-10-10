import 'package:shared_preferences/shared_preferences.dart';

import 'splash_themes.dart';

class AppearancePrefs {
  AppearancePrefs._();

  static const _splashKey = 'splashThemeId';
  static const _iconKey = 'preferredAppIconId';

  static String _splashId = SplashThemes.classic.id;
  static String _iconId = AppIconVariants.bolt.id;
  static bool _ready = false;

  static String get splashId => _splashId;
  static String get iconId => _iconId;
  static SplashTheme get splash => SplashThemes.byId(_splashId);
  static AppIconVariant get icon => AppIconVariants.byId(_iconId);

  static Future<void> load() async {
    if (_ready) return;
    final prefs = await SharedPreferences.getInstance();
    _splashId = prefs.getString(_splashKey) ?? SplashThemes.classic.id;
    _iconId = prefs.getString(_iconKey) ?? AppIconVariants.bolt.id;
    _ready = true;
  }

  static Future<void> setSplash(String id) async {
    _splashId = SplashThemes.byId(id).id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_splashKey, _splashId);
  }

  static Future<void> setIcon(String id) async {
    _iconId = AppIconVariants.byId(id).id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_iconKey, _iconId);
  }
}
