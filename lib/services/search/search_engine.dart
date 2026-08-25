import 'package:flutter/foundation.dart';

/// Motor de búsqueda full-text
class SearchEngine {
  static final SearchEngine _instance = SearchEngine._internal();

  final Map<String, List<String>> _index = {}; // word -> [ids]
  final Map<String, Map<String, dynamic>> _documents = {};

  factory SearchEngine() => _instance;

  SearchEngine._internal();

  /// Indexa un documento
  void indexDocument(String id, Map<String, dynamic> doc) {
    _documents[id] = doc;

    // Extraer palabras de todos los campos
    doc.forEach((key, value) {
      if (value is String) {
        final words = value.toLowerCase().split(RegExp(r'[^\w]+'));
        for (final word in words) {
          if (word.isNotEmpty) {
            _index.putIfAbsent(word, () => []).add(id);
          }
        }
      }
    });

    debugPrint('SearchEngine: Indexed document "$id"');
  }

  /// Busca documentos
  Future<SearchResults> search(String query, {int limit = 50}) async {
    final words = query.toLowerCase().split(RegExp(r'[^\w]+'));
    final results = <String, int>{};

    // Buscar documentos que contengan palabras
    for (final word in words) {
      final docs = _index[word] ?? [];
      for (final docId in docs) {
        results[docId] = (results[docId] ?? 0) + 1;
      }
    }

    // Ordenar por relevancia
    final sorted = results.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final items = sorted
        .take(limit)
        .map((e) => SearchResultItem(id: e.key, score: e.value.toDouble()))
        .toList();

    return SearchResults(items: items, totalCount: sorted.length);
  }

  /// Búsqueda con filtros
  Future<SearchResults> searchWithFilters(
    String query, {
    Map<String, dynamic>? filters,
    int limit = 50,
  }) async {
    var results = await search(query, limit: limit * 2);

    // Aplicar filtros
    if (filters != null && filters.isNotEmpty) {
      results = SearchResults(
        items: results.items
            .where((item) {
              final doc = _documents[item.id];
              if (doc == null) return false;

              return filters.entries.every((filter) =>
                  doc[filter.key]?.toString().contains(filter.value.toString()) ?? false);
            })
            .take(limit)
            .toList(),
        totalCount: results.totalCount,
      );
    }

    return results;
  }

  /// Autocompletado
  Future<List<String>> autocomplete(String prefix, {int limit = 10}) async {
    final suggestions = <String>{};

    for (final word in _index.keys) {
      if (word.startsWith(prefix.toLowerCase())) {
        suggestions.add(word);
        if (suggestions.length >= limit) break;
      }
    }

    return suggestions.toList();
  }

  int get documentCount => _documents.length;
}

class SearchResults {
  const SearchResults({
    required this.items,
    required this.totalCount,
  });

  final List<SearchResultItem> items;
  final int totalCount;
}

class SearchResultItem {
  const SearchResultItem({
    required this.id,
    required this.score,
  });

  final String id;
  final double score;
}
