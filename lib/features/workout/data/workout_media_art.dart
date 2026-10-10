import 'dart:io';

import 'package:flutter/services.dart';

import '../domain/exercise_catalog.dart';

const restTimerArtAsset = 'assets/icons/app/rest_timer.jpg';
const fallbackArtAsset = 'assets/icons/app/barbell.jpg';

/// Копирует asset во временный файл для MediaItem.artUri (file://).
Future<Uri?> artUriForAsset(String assetPath) async {
  try {
    final safe = assetPath.hashCode.toRadixString(16);
    final file = File('${Directory.systemTemp.path}/gc_media_$safe.jpg');
    if (!await file.exists()) {
      final data = await rootBundle.load(assetPath);
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }
    return Uri.file(file.path);
  } catch (_) {
    return null;
  }
}

Future<Uri?> artUriForRest() => artUriForAsset(restTimerArtAsset);

Future<Uri?> artUriForExercise({String? exerciseId, String? name}) async {
  final path = ExerciseCatalog.iconAssetFor(
        exerciseId: exerciseId,
        name: name,
      ) ??
      fallbackArtAsset;
  final uri = await artUriForAsset(path);
  if (uri != null) return uri;
  return artUriForAsset(fallbackArtAsset);
}
