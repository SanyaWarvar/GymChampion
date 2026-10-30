import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/custom_exercise.dart';
import '../domain/exercise_catalog.dart';

class CustomExerciseRepository {
  CustomExerciseRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Нет авторизованного пользователя');
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _exercises =>
      _firestore.collection('users').doc(_uid).collection('customExercises');

  Stream<List<CustomExercise>> watchMine() {
    return _exercises
        .orderBy('name')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => CustomExercise.fromMap(doc.id, doc.data()))
              .where((e) => e.name.trim().isNotEmpty)
              .toList(),
        );
  }

  Future<CustomExercise> create({
    required String name,
    required MuscleGroup muscle,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw StateError('Пустое название');
    }
    final ref = _exercises.doc();
    final id = 'custom_${ref.id}';
    final exercise = CustomExercise(id: id, name: trimmed, muscle: muscle);
    await _exercises.doc(id).set({
      ...exercise.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return exercise;
  }

  Future<void> delete(String id) => _exercises.doc(id).delete();
}
