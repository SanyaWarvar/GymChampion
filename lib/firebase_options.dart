// Generated from Firebase project gymchampion-60f6d
// ignore_for_file: type=lint

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCDfmyfeKaolOl6U0QuoB8vegMI0Qz8i8I',
    appId: '1:217193431849:web:b27acd23c7c60d7a17ad38',
    messagingSenderId: '217193431849',
    projectId: 'gymchampion-60f6d',
    authDomain: 'gymchampion-60f6d.firebaseapp.com',
    storageBucket: 'gymchampion-60f6d.firebasestorage.app',
    measurementId: 'G-S88Q38RQLL',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB2U7VIYzARh8Z58BenXcWUyK1ozoe-g8c',
    appId: '1:217193431849:android:465b3dc39da9ec7917ad38',
    messagingSenderId: '217193431849',
    projectId: 'gymchampion-60f6d',
    storageBucket: 'gymchampion-60f6d.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDkrHnY4Mn6--qlvP5BjUmmnmkv4UIQrAk',
    appId: '1:217193431849:ios:2d2c0c156daee59517ad38',
    messagingSenderId: '217193431849',
    projectId: 'gymchampion-60f6d',
    storageBucket: 'gymchampion-60f6d.firebasestorage.app',
    iosBundleId: 'com.gymchampion.gymChampion',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDkrHnY4Mn6--qlvP5BjUmmnmkv4UIQrAk',
    appId: '1:217193431849:ios:2d2c0c156daee59517ad38',
    messagingSenderId: '217193431849',
    projectId: 'gymchampion-60f6d',
    storageBucket: 'gymchampion-60f6d.firebasestorage.app',
    iosBundleId: 'com.gymchampion.gymChampion',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCDfmyfeKaolOl6U0QuoB8vegMI0Qz8i8I',
    appId: '1:217193431849:web:50aa9c7349fc912117ad38',
    messagingSenderId: '217193431849',
    projectId: 'gymchampion-60f6d',
    authDomain: 'gymchampion-60f6d.firebaseapp.com',
    storageBucket: 'gymchampion-60f6d.firebasestorage.app',
    measurementId: 'G-DY0R4RD954',
  );
}
