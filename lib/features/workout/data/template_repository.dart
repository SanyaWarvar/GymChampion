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

  /// Adds built-in variants the user has not deleted.
  ///
  /// A deleted preset stays in Firestore as a tombstone. Seeding only fills
  /// ids that have no document, so a restart cannot bring a deletion back.
  Future<void> ensurePresets() async {
    final uid = _uid;
    if (_seededUids.contains(uid)) return;

    await _firestore.runTransaction((tx) async {
      final missing = <WorkoutTemplate>[];
      for (final preset in PresetTemplates.all) {
        final snap = await tx.get(_templates.doc(preset.id));
        if (snap.exists) continue;
        missing.add(preset);
      }
      if (missing.isEmpty) return;

      final now = DateTime.now();
      for (var i = 0; i < missing.length; i++) {
        final preset = missing[i];
        tx.set(_templates.doc(preset.id), {
          ...preset.toMap(),
          'updatedAt': now
              .add(Duration(seconds: missing.length - i))
              .toIso8601String(),
          'isPreset': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });

    await _stripDeadliftFromPresets();
    _seededUids.add(uid);
  }

  Future<void> _stripDeadliftFromPresets() async {
    final snap = await _templates.get();
    final batch = _firestore.batch();
    var writes = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['deleted'] == true) continue;
      if (!_isBuiltinTemplate(doc.id, data)) continue;
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
          (snap) => _visibleTemplates(snap.docs),
        );
  }

  Future<List<WorkoutTemplate>> fetchTemplates() async {
    final snap = await _templates.orderBy('updatedAt', descending: true).get();
    return _visibleTemplates(snap.docs);
  }

  Future<WorkoutTemplate?> fetchTemplate(String id) async {
    final snap = await _templates.doc(id).get();
    final data = snap.data();
    if (!snap.exists || data == null || data['deleted'] == true) return null;
    return WorkoutTemplate.fromMap(snap.id, data);
  }

  Future<String> saveTemplate(WorkoutTemplate template) async {
    final data = <String, dynamic>{
      ...template.toMap(),
      'updatedAt': DateTime.now().toIso8601String(),
      'programId': template.programId ?? FieldValue.delete(),
      'programTitle': template.programTitle ?? FieldValue.delete(),
      'dayLabel': template.dayLabel ?? FieldValue.delete(),
      'deleted': FieldValue.delete(),
    };
    if (template.id.isEmpty || template.id == 'new') {
      // Для нового дока delete не нужен — пишем только заданные поля.
      final create = <String, dynamic>{
        ...template.toMap(),
        'updatedAt': DateTime.now().toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
      };
      final doc = await _templates.add(create);
      return doc.id;
    }
    await _templates.doc(template.id).set(data, SetOptions(merge: true));
    return template.id;
  }

  /// Существующие группы пользователя (для подсказок в редакторе).
  Future<List<({String id, String title})>> fetchProgramGroups() async {
    final templates = await fetchTemplates();
    final seen = <String>{};
    final out = <({String id, String title})>[];
    for (final t in templates) {
      final id = t.programId?.trim();
      final title = t.programTitle?.trim();
      if (id == null || id.isEmpty || title == null || title.isEmpty) continue;
      if (!seen.add(id)) continue;
      out.add((id: id, title: title));
    }
    out.sort((a, b) => a.title.compareTo(b.title));
    return out;
  }

  Future<void> deleteTemplate(String id) async {
    final ref = _templates.doc(id);
    final snap = await ref.get();
    if (_isBuiltinTemplate(id, snap.data())) {
      // Hard-deleting a preset makes [ensurePresets] treat it as missing
      // and recreate it on the next launch.
      await ref.set(<String, dynamic>{
        'deleted': true,
        'isPreset': true,
      });
      return;
    }
    await ref.delete();
  }

  bool _isBuiltinTemplate(String id, Map<String, dynamic>? data) {
    return id.startsWith('preset_') || data?['isPreset'] == true;
  }

  List<WorkoutTemplate> _visibleTemplates(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return [
      for (final doc in docs)
        if (doc.data()['deleted'] != true)
          WorkoutTemplate.fromMap(doc.id, doc.data()),
    ];
  }
}
