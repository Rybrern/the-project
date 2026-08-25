import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/animated_wallpaper.dart';

/// Catálogo de fondos animados desde Firestore (colección `wallpapers`,
/// filtrado por isAnimated == true). Reemplaza a PixabayVideoService.trending()
/// que solo mostraba el pool fijo de "trending" de Pixabay (siempre el
/// mismo contenido) — este catálogo incluye además GIPHY y se actualiza
/// con cada corrida de la Cloud Function de ingesta.
class RemoteAnimatedService {
  RemoteAnimatedService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<AnimatedWallpaper>> trending({int limit = 60}) async {
    final snapshot = await _firestore
        .collection('wallpapers')
        .where('isAnimated', isEqualTo: true)
        .orderBy('popularityScore', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map(_fromDoc).toList();
  }

  AnimatedWallpaper _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final width = (data['width'] as num?)?.toInt() ?? 720;
    final height = (data['height'] as num?)?.toInt() ?? 1280;

    return AnimatedWallpaper(
      id: doc.id,
      previewImageUrl: data['thumbnailUrl'] as String? ?? data['url'] as String,
      videoUrl: data['url'] as String,
      width: width,
      height: height,
      source: data['source'] as String?,
      sourceId: data['sourceId'] as String?,
      nsfwScore: (data['nsfwScore'] as num?)?.toDouble(),
      qualityScore: (data['qualityScore'] as num?)?.toDouble(),
      primaryCategory: data['category'] as String?,
      tags: (data['tags'] as List<dynamic>?)?.cast<String>(),
    );
  }
}
