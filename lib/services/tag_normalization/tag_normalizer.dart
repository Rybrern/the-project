/// Service for normalizing tag text: lowercasing, accent removal, special char stripping
/// Enables consistent tag matching across different inputs (API tags, user input, etc.)
class TagNormalizer {
  // Static map for common accent replacements
  static const Map<String, String> _accentMap = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
    'ñ': 'n', 'ç': 'c',
    'Á': 'a', 'À': 'a', 'Ä': 'a', 'Â': 'a', 'Ã': 'a',
    'É': 'e', 'È': 'e', 'Ë': 'e', 'Ê': 'e',
    'Í': 'i', 'Ì': 'i', 'Ï': 'i', 'Î': 'i',
    'Ó': 'o', 'Ò': 'o', 'Ö': 'o', 'Ô': 'o', 'Õ': 'o',
    'Ú': 'u', 'Ù': 'u', 'Ü': 'u', 'Û': 'u',
    'Ñ': 'n', 'Ç': 'c',
  };

  /// Normalizes text: lowercase, remove accents, strip special chars, collapse whitespace
  /// Example: "Lionel Messi" → "lionel messi"
  /// Example: "Café" → "cafe"
  String normalizeText(String text) {
    if (text.isEmpty) return '';

    // Step 1: Remove accents
    var result = _removeAccents(text);

    // Step 2: Convert to lowercase
    result = result.toLowerCase();

    // Step 3: Remove special characters (keep alphanumeric, hyphens, underscores, spaces)
    result = result.replaceAll(RegExp(r'[^\w\s\-]'), '');

    // Step 4: Collapse multiple spaces and trim
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();

    return result;
  }

  /// Removes accents from text
  /// Example: "Café" → "Cafe"
  String _removeAccents(String text) {
    var result = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      result.write(_accentMap[char] ?? char);
    }
    return result.toString();
  }

  /// Extracts and normalizes tags from API response
  /// Handles List<String>, List<Map>, or raw tag objects
  /// Returns deduplicated, normalized list
  List<String> extractTags(dynamic tagsFromAPI) {
    if (tagsFromAPI == null) return [];

    final normalized = <String, bool>{}; // Using map to track deduplication

    if (tagsFromAPI is List) {
      for (final tag in tagsFromAPI) {
        String? tagText;

        if (tag is String) {
          tagText = tag;
        } else if (tag is Map<String, dynamic>) {
          // Handle common tag object formats
          tagText = tag['name'] as String? ??
              tag['tag'] as String? ??
              tag['title'] as String? ??
              tag['value'] as String?;
        }

        if (tagText != null && tagText.isNotEmpty) {
          final norm = normalizeText(tagText);
          if (norm.isNotEmpty) {
            normalized[norm] = true;
          }
        }
      }
    }

    return normalized.keys.toList();
  }

  /// Builds a canonical name from a display name
  /// Example: "Lionel Messi" → "lionel-messi"
  /// Example: "Manchester City" → "manchester-city"
  String buildCanonicalName(String displayName) {
    final normalized = normalizeText(displayName);
    // Replace spaces with hyphens
    return normalized.replaceAll(RegExp(r'\s+'), '-');
  }

  /// Fuzzy match between two strings using Levenshtein distance
  /// Returns a confidence score between 0.0 and 1.0
  /// 0.8 or higher is considered a good match for most use cases
  double fuzzyMatchScore(String a, String b) {
    final normA = normalizeText(a);
    final normB = normalizeText(b);

    if (normA == normB) return 1.0;
    if (normA.isEmpty || normB.isEmpty) return 0.0;

    final distance = _levenshteinDistance(normA, normB);
    final maxLen = [normA.length, normB.length].reduce((a, b) => a > b ? a : b);

    return 1.0 - (distance / maxLen);
  }

  /// Calculates Levenshtein distance between two strings
  /// Used for fuzzy matching
  int _levenshteinDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final aLen = a.length;
    final bLen = b.length;
    final dp = List<List<int>>.generate(
      aLen + 1,
      (_) => List<int>.filled(bLen + 1, 0),
    );

    for (int i = 0; i <= aLen; i++) {
      dp[i][0] = i;
    }
    for (int j = 0; j <= bLen; j++) {
      dp[0][j] = j;
    }

    for (int i = 1; i <= aLen; i++) {
      for (int j = 1; j <= bLen; j++) {
        if (a[i - 1] == b[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1];
        } else {
          dp[i][j] = 1 + [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]]
              .reduce((a, b) => a < b ? a : b);
        }
      }
    }

    return dp[aLen][bLen];
  }

  /// Detects common variations (abbreviations, nicknames) and returns base form
  /// Example: "leo" → "lionel", "m10" → "messi"
  /// Uses a heuristic approach based on common patterns
  String? detectVariation(String input) {
    final norm = normalizeText(input);

    // Common abbreviations mapping
    const abbreviations = {
      'leo': 'lionel messi',
      'cr7': 'cristiano ronaldo',
      'm10': 'lionel messi',
      'messi10': 'lionel messi',
      'f1': 'formula 1',
      'f-1': 'formula 1',
      'ucl': 'champions league',
      'champs': 'champions league',
      'pl': 'premier league',
      'epl': 'english premier league',
      'nba': 'basketball',
      'nfl': 'american football',
      'mma': 'mixed martial arts',
    };

    return abbreviations[norm];
  }

  /// Splits a tag into potential component parts
  /// Example: "lionel-messi" → ["lionel", "messi"]
  /// Useful for multi-word entity matching
  List<String> splitTagComponents(String tag) {
    final norm = normalizeText(tag);
    // Split by hyphen or space
    return norm.split(RegExp(r'[\s\-]+'))
        .where((part) => part.isNotEmpty)
        .toList();
  }

  /// Checks if a tag looks like it's a person name (heuristic)
  /// Returns confidence score 0.0 - 1.0
  double personNameLikelihood(String tag) {
    final norm = normalizeText(tag);
    final parts = splitTagComponents(tag);

    // Heuristics:
    // - Single word names are less likely to be persons (usually 0.3)
    // - Multi-word names are likely persons (0.8+)
    // - Names with articles/prepositions are less likely (0.2)
    // - All caps after normalization might be acronyms (0.1)

    if (parts.isEmpty) return 0.0;

    // Single word: could be a person or not
    if (parts.length == 1) {
      return 0.3;
    }

    // Multiple words: likely a person name
    if (parts.length >= 2) {
      // Check for common prepositions that indicate NOT a person
      final words = norm.split(' ');
      final commonPrepositions = ['de', 'del', 'van', 'von', 'da', 'la', 'le'];
      final hasPreposition =
          words.any((w) => commonPrepositions.contains(w));

      if (hasPreposition) {
        return 0.7; // Could be a name with preposition (e.g., "Jose Maria de la Cruz")
      }

      return 0.85; // Multi-word, likely person
    }

    return 0.0;
  }

  /// Checks if a tag looks like it's a place/country
  bool isLikelyLocation(String tag) {
    final norm = normalizeText(tag);
    final parts = splitTagComponents(tag);

    // Locations are typically single words
    if (parts.length == 1) {
      // Common location keywords
      final locationKeywords = [
        'spain', 'england', 'france', 'germany', 'italy', 'argentina',
        'brazil', 'united states', 'japan', 'korea', 'china', 'india',
        'mexico', 'canada', 'australia', 'new zealand',
      ];

      return locationKeywords.contains(norm);
    }

    return false;
  }

  /// Checks if a tag looks like it's a sports team or competition
  bool isLikelySports(String tag) {
    final norm = normalizeText(tag);

    final sportKeywords = [
      'football', 'basketball', 'tennis', 'cricket', 'rugby',
      'soccer', 'nfl', 'nba', 'mls', 'f1', 'formula',
      'team', 'league', 'championship', 'cup', 'tournament',
      'sport', 'athlete', 'player', 'game', 'match',
    ];

    return sportKeywords.any((keyword) => norm.contains(keyword));
  }
}
