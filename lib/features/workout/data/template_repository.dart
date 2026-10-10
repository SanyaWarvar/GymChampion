import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/preset_templates.dart';
import '../domain/workout_template.dart';

class TemplateRepository {
  TemplateRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static final Set<String> _seededUids = <String>{};

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Нет авторизованного пользователя');
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _templates =>
      _firestore.collection('users').doc(_uid).collection('templates');

  /// Adds missing built-in workout variants (does not overwrite existing).
  Future<void> ensurePresets() async {
    final uid = _uid;
    if (_seededUids.contains(uid)) return;

    final missing = <WorkoutTemplate>[];
    for (final preset in PresetTemplates.all) {
      final snap = await _templates.doc(preset.id).get();
      if (!snap.exists) missing.add(preset);
    }

    if (missing.isNotEmpty) {
      final batch = _firestore.batch();
      final now = DateTime.now();
      for (var i = 0; i < missing.length; i++) {
        final preset = missing[i];
        batch.set(_templates.doc(preset.id), {
          ...preset.toMap(),
          'updatedAt': now.add(Duration(seconds: missing.length - i)).toIso8601String(),
          'isPreset': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }

    await _stripDeadliftFromPresets();
    _seededUids.add(uid);
  }

  Future<void> _stripDeadliftFromPresets() async {
    final snap = await _templates.get();
    final batch = _firestore.batch();
    var writes = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final isPreset =
          doc.id.startsWith('preset_') || data['isPreset'] == true;
      if (!isPreset) continue;
      final raw = data['exercises'] as List<dynamic>? ?? const [];
      final cleaned = raw.where((item) {
        if (item is! Map) return true;
        return !_isDeadlift(Map<String, dynamic>.from(item));
      }).toList();
      if (cleaned.length == raw.length) continue;
      batch.update(doc.reference, {
        'exercises': cleaned,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      writes += 1;
    }
    if (writes > 0) await batch.commit();
  }

  bool _isDeadlift(Map<String, dynamic> exercise) {
    final id = exercise['exerciseId'] as String?;
    final name = (exercise['name'] as String? ?? '').toLowerCase();
    return id == 'deadlift' ||
        name == 'становая тяга' ||
        name.contains('становая');
  }

  Stream<List<WorkoutTemplate>> watchTemplates() {
    // Fire-and-forget seed; stream will refresh when docs appear.
    unawaited(ensurePresets());
    return _templates.orderBy('updatedAt', descending: true).snapshots().map(
          (snap) => snap.docs
              .map((doc) => WorkoutTemplate.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<List<WorkoutTemplate>> fetchTemplates() async {
    final snap = await _templates.orderBy('updatedAt', descending: true).get();
    return snap.docs
        .map((doc) => WorkoutTemplate.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<WorkoutTemplate?> fetchTemplate(String id) async {
    final snap = await _templates.doc(id).get();
    if (!snap.exists || snap.data() == null) return null;
    return WorkoutTemplate.fromMap(snap.id, snap.data()!);
  }

  Future<String> saveTemplate(WorkoutTemplate template) async {
    final data = {
      ...template.toMap(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (template.id.isEmpty || template.id == 'new') {
      final doc = await _templates.add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return doc.id;
    }
    await _templates.doc(template.id).set(data, SetOptions(merge: true));
    return template.id;
  }

  Future<void> deleteTemplate(String id) async {
    await _templates.doc(id).delete();
  }
}
