import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/auth_repository.dart';
import '../domain/app_user.dart';
import '../../notifications/data/notification_scheduler.dart';
import '../../rank/data/streak_repository.dart';

enum AuthStatus {
  loading,
  unauthenticated,
  needsDisplayName,
  authenticated,
}

class AuthController extends ChangeNotifier {
  AuthController({AuthRepository? repository})
      : _repository = repository ?? AuthRepository() {
    _authSub = _repository.authStateChanges().listen(_onAuthChanged);
  }

  final AuthRepository _repository;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<AppUser?>? _profileSub;

  AuthStatus status = AuthStatus.loading;
  AppUser? profile;
  String? errorMessage;
  bool busy = false;

  AuthRepository get repository => _repository;

  Future<void> _onAuthChanged(User? user) async {
    await _profileSub?.cancel();
    _profileSub = null;

    if (user == null) {
      profile = null;
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    status = AuthStatus.loading;
    notifyListeners();

    try {
      final loaded = await _repository.ensureProfile(user);
      profile = loaded;
      status = loaded.hasDisplayName
          ? AuthStatus.authenticated
          : AuthStatus.needsDisplayName;
      notifyListeners();

      unawaited(StreakRepository().ensureSynced());
      unawaited(NotificationScheduler.syncForProfile(loaded));

      _profileSub = _repository.watchProfile(user.uid).listen((value) {
        if (value == null) return;
        profile = value;
        status = value.hasDisplayName
            ? AuthStatus.authenticated
            : AuthStatus.needsDisplayName;
        notifyListeners();
      });
    } catch (error) {
      errorMessage = _repository.mapAuthError(error);
      status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) {
    return _run(() async {
      await _repository.signIn(email: email, password: password);
    });
  }

  Future<bool> register({
    required String email,
    required String password,
  }) {
    return _run(() async {
      await _repository.register(email: email, password: password);
    });
  }

  Future<bool> saveDisplayName(String name) {
    return _run(() async {
      await _repository.setDisplayName(name);
    });
  }

  Future<bool> uploadAvatar(Uint8List bytes) {
    return _run(() async {
      await _repository.uploadAvatar(bytes);
    });
  }

  Future<void> signOut() => _repository.signOut();

  Future<bool> _run(Future<void> Function() action) async {
    busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (error) {
      errorMessage = _repository.mapAuthError(error);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}
