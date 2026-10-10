import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/appearance/appearance_prefs.dart';
import 'core/theme/app_colors.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/notifications/data/local_notification_service.dart';
import 'features/workout/data/workout_media_handler.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
    ),
  );

  await Future.wait([
    Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ),
    AppearancePrefs.load(),
    LocalNotificationService.instance.init(),
    initWorkoutMediaService(),
  ]);

  final auth = AuthController();
  runApp(GymChampionApp(auth: auth));
}
