import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/wallpaper.dart';

/// Búsqueda contra el catálogo pre-poblado en Firestore (colección
/// `wallpapers`), llenado por la Cloud Function de ingesta programada.
/// Reemplaza a [SearchService] (que dependía de una base local que nunca
/// se poblaba en el dispositivo) para la pantalla de Búsqueda.
class RemoteSearchService {
  RemoteSearchService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const _maxWhereInClauses = 10;

  String _normalizeToken(String raw) {
    return raw
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9áéíóúñü\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-');
  }

  List<String> _tokenize(String query) {
    final allTokens = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map(_normalizeToken)
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();

    // Los tokens de 1 carácter (p. ej. el "1" de "formula 1") son demasiado
    // genéricos para `arrayContainsAny`: hacen match OR contra cualquier tag
    // corto no relacionado (números de camiseta, "Ligue 1", etc.) e inundan
    // los resultados con contenido irrelevante. Se descartan salvo que sean
    // el único token de la query, para no dejar la búsqueda vacía.
    final meaningful = allTokens.where((t) => t.length > 1).toList();
    final tokens = meaningful.isNotEmpty ? meaningful : allTokens;

    return tokens.take(_maxWhereInClauses).toList();
  }

  /// Busca wallpapers estáticos (no animados) cuyos tags coincidan con al menos
  /// uno de los tokens de la query, y los ordena por cantidad de tokens
  /// coincidentes y luego por popularityScore (calculado en la Cloud Function).
  Future<List<Wallpaper>> search(String query, {int limit = 60}) async {
    final tokens = _tokenize(query);
    if (tokens.isEmpty) return [];

    final snapshot = await _firestore
        .collection('wallpapers')
        .where('isAnimated', isEqualTo: false)
        .where('tags', arrayContainsAny: tokens)
        .orderBy('popularityScore', descending: true)
        .limit(limit)
        .get();

    final results = snapshot.docs.map((doc) => _fromDoc(doc, tokens)).toList();

    results.sort((a, b) {
      final byMatch = b.$2.compareTo(a.$2);
      if (byMatch != 0) return byMatch;
      return (b.$1.qualityScore ?? 0).compareTo(a.$1.qualityScore ?? 0);
    });

    return results.map((r) => r.$1).toList();
  }

  (Wallpaper, int) _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc, List<String> tokens) {
    final data = doc.data();
    final tags = (data['tags'] as List<dynamic>? ?? []).cast<String>();
    final matchCount = tags.where(tokens.contains).length;

    final wallpaper = Wallpaper(
      id: doc.id,
      thumbnailUrl: data['thumbnailUrl'] as String? ?? data['url'] as String,
      fullUrl: data['url'] as String,
      author: data['author'] as String? ?? '',
      category: data['category'] as String? ?? 'general',
      aspectRatio: (data['aspectRatio'] as num?)?.toDouble() ??
          ((data['width'] as num?)?.toDouble() ?? 1) / ((data['height'] as num?)?.toDouble() ?? 1),
      source: data['source'] as String?,
      sourceId: data['sourceId'] as String?,
      qualityScore: (data['qualityScore'] as num?)?.toDouble(),
      nsfwScore: (data['nsfwScore'] as num?)?.toDouble(),
      tags: tags,
    );

    return (wallpaper, matchCount);
  }
}
