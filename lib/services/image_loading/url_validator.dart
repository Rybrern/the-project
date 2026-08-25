/// Caché de URLs que fallaron en esta sesión.
/// Evita reintentar URLs que sabemos que no funcionan.
class UrlFailureCache {
  static final UrlFailureCache _instance = UrlFailureCache._();

  factory UrlFailureCache() => _instance;

  UrlFailureCache._();

  /// URLs que fallaron (evita re-intentar en la misma sesión)
  final Set<String> _failedUrls = {};

  /// Marca una URL como fallida
  void markFailed(String url) {
    _failedUrls.add(url);
  }

  /// Retorna true si una URL falló previamente
  bool isFailed(String? url) {
    if (url == null || url.isEmpty) return true;
    return _failedUrls.contains(url);
  }

  /// Limpia la caché (útil para refresh manual o testing)
  void clearCache() {
    _failedUrls.clear();
  }

  /// Retorna la primera URL que NO ha fallado
  String? getFirstNotFailed(List<String?> urls) {
    for (final url in urls) {
      if (url == null || url.isEmpty) continue;
      if (!isFailed(url)) return url;
    }
    return null;
  }
}
