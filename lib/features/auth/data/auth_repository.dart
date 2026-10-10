import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../domain/app_user.dart';

class AuthRepository {
  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return _requireProfile(credential.user!);
  }

  Future<AppUser> register({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;
    final profile = AppUser(uid: user.uid, email: user.email ?? email.trim());
    await _users.doc(user.uid).set({
      ...profile.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return profile;
  }

  Future<AppUser?> fetchProfile(String uid) async {
    final snap = await _users.doc(uid).get();
    if (!snap.exists || snap.data() == null) return null;
    return AppUser.fromMap(uid, snap.data()!);
  }

  Stream<AppUser?> watchProfile(String uid) {
    return _users.doc(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return AppUser.fromMap(uid, snap.data()!);
    });
  }

  Future<void> setDisplayName(String displayName) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Нет авторизованного пользователя');
    }
    final name = displayName.trim();
    await user.updateDisplayName(name);
    await _users.doc(user.uid).set(
      {
        'displayName': name,
        'email': user.email,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<String> uploadAvatar(Uint8List bytes, {String contentType = 'image/jpeg'}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Нет авторизованного пользователя');
    }
    var url = '';
    try {
      final ref = _storage.ref('users/${user.uid}/avatar.jpg');
      await ref.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      url = await ref.getDownloadURL();
    } catch (_) {
      final encoded = base64Encode(bytes);
      if (encoded.length > 700000) {
        throw StateError('Фото слишком большое, выбери другое');
      }
      url = 'data:$contentType;base64,$encoded';
    }
    try {
      await user.updatePhotoURL(url.startsWith('http') ? url : null);
    } catch (_) {}
    await _users.doc(user.uid).set({
      'photoUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return url;
  }

  Future<void> updatePrivacy({
    required bool hideWeights,
    required bool defaultWorkoutPrivate,
    required bool showOnLeaderboard,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Нет авторизованного пользователя');
    await _users.doc(user.uid).set({
      'hideWeights': hideWeights,
      'defaultWorkoutPrivate': defaultWorkoutPrivate,
      'showOnLeaderboard': showOnLeaderboard,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateNotificationPrefs({
    required bool notifyOvertaken,
    required bool notifySeason,
    required bool notifyChallenges,
    required bool notifyStreakReminder,
    required bool notifyChallengeDeadline,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Нет авторизованного пользователя');
    await _users.doc(user.uid).set({
      'notifyOvertaken': notifyOvertaken,
      'notifySeason': notifySeason,
      'notifyChallenges': notifyChallenges,
      'notifyStreakReminder': notifyStreakReminder,
      'notifyChallengeDeadline': notifyChallengeDeadline,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> signOut() => _auth.signOut();

  Future<AppUser> ensureProfile(User user) async {
    final existing = await fetchProfile(user.uid);
    if (existing != null) return existing;

    final profile = AppUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
    );
    await _users.doc(user.uid).set({
      ...profile.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return profile;
  }

  Future<AppUser> _requireProfile(User user) => ensureProfile(user);

  String mapAuthError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'Некорректный email';
        case 'user-disabled':
          return 'Аккаунт отключён';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Неверный email или пароль';
        case 'email-already-in-use':
          return 'Email уже занят';
        case 'weak-password':
          return 'Пароль слишком слабый (минимум 6 символов)';
        case 'network-request-failed':
          return 'Нет сети. Проверь интернет';
        default:
          return error.message ?? 'Ошибка авторизации';
      }
    }
    return 'Что-то пошло не так';
  }
}
