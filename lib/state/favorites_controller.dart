import 'package:flutter/foundation.dart';

class FavoritesController extends ChangeNotifier {
  final Set<String> _favoriteIds = {};

  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);

  bool isFavorite(String id) => _favoriteIds.contains(id);

  void toggle(String id) {
    if (!_favoriteIds.remove(id)) {
      _favoriteIds.add(id);
    }
    notifyListeners();
  }
}
