/// Fuzzy Matcher - provides typo tolerance using Levenshtein distance
/// Example: "aurorr" matches "aurora", "formul1" matches "formula-1"
class FuzzyMatcher {
  /// Calculates Levenshtein distance between two strings
  /// Distance = minimum number of single-character edits needed
  static int levenshteinDistance(String s1, String s2) {
    final m = s1.length;
    final n = s2.length;

    // Create DP table
    final dp = List<List<int>>.generate(
      m + 1,
      (i) => List<int>.filled(n + 1, 0),
    );

    // Initialize first row and column
    for (var i = 0; i <= m; i++) {
      dp[i][0] = i;
    }
    for (var j = 0; j <= n; j++) {
      dp[0][j] = j;
    }

    // Fill DP table
    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1, // deletion
          dp[i][j - 1] + 1, // insertion
          dp[i - 1][j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return dp[m][n];
  }

  /// Calculates maximum allowed distance for a query
  /// Short queries (1-3 chars): max distance = 1
  /// Medium queries (4-6 chars): max distance = 1
  /// Longer queries: max distance = query.length / 3 (rounded down)
  static int getMaxDistance(String query) {
    if (query.length <= 3) {
      return 1;
    } else if (query.length <= 6) {
      return 1;
    } else {
      return (query.length / 3).floor();
    }
  }

  /// Checks if a query matches a candidate with fuzzy matching
  /// Returns true if distance <= maxDistance
  static bool fuzzyMatch(
    String query,
    String candidate, {
    int? maxDistance,
  }) {
    final distance = levenshteinDistance(query.toLowerCase(), candidate.toLowerCase());
    final allowedDistance = maxDistance ?? getMaxDistance(query);
    return distance <= allowedDistance;
  }

  /// Finds all matching candidates with fuzzy matching
  /// Returns candidates sorted by distance (best matches first)
  static List<String> findMatches(
    String query,
    List<String> candidates, {
    int? maxDistance,
  }) {
    final allowedDistance = maxDistance ?? getMaxDistance(query);
    final matches = <MapEntry<String, int>>[];

    for (final candidate in candidates) {
      final distance = levenshteinDistance(query.toLowerCase(), candidate.toLowerCase());
      if (distance <= allowedDistance) {
        matches.add(MapEntry(candidate, distance));
      }
    }

    // Sort by distance (ascending)
    matches.sort((a, b) => a.value.compareTo(b.value));

    return matches.map((e) => e.key).toList();
  }

  /// Scores a candidate match (0.0-1.0)
  /// Higher score = better match (lower distance)
  static double matchScore(String query, String candidate) {
    final distance = levenshteinDistance(query.toLowerCase(), candidate.toLowerCase());
    final maxPossibleDistance = [query.length, candidate.length].reduce((a, b) => a > b ? a : b);

    if (maxPossibleDistance == 0) return 1.0;

    return (1.0 - (distance / maxPossibleDistance)).clamp(0.0, 1.0);
  }

  /// Performs prefix matching (simpler, faster than Levenshtein)
  /// Returns true if candidate starts with query
  static bool prefixMatch(String query, String candidate) {
    return candidate.toLowerCase().startsWith(query.toLowerCase());
  }

  /// Performs substring matching
  /// Returns true if query appears anywhere in candidate
  static bool substringMatch(String query, String candidate) {
    return candidate.toLowerCase().contains(query.toLowerCase());
  }

  /// Hybrid matching: tries prefix first, then fuzzy
  /// Prefix matches are considered better than fuzzy matches
  static List<MapEntry<String, double>> hybridMatch(
    String query,
    List<String> candidates, {
    int? maxFuzzyDistance,
  }) {
    final results = <MapEntry<String, double>>[];

    for (final candidate in candidates) {
      if (prefixMatch(query, candidate)) {
        // Prefix match: score 0.8-1.0 based on exact prefix length
        final score = query.length / candidate.length;
        results.add(MapEntry(candidate, score.clamp(0.8, 1.0)));
      } else if (fuzzyMatch(query, candidate, maxDistance: maxFuzzyDistance)) {
        // Fuzzy match: score 0.5-0.8 based on Levenshtein distance
        final score = matchScore(query, candidate);
        results.add(MapEntry(candidate, (score * 0.8).clamp(0.5, 0.8)));
      }
    }

    // Sort by score descending
    results.sort((a, b) => b.value.compareTo(a.value));

    return results;
  }

  /// Optimized fuzzy matching for large candidate lists
  /// Only applies fuzzy matching to candidates that pass substring test
  /// This reduces expensive Levenshtein computations
  static List<String> optimizedMatch(
    String query,
    List<String> candidates, {
    int? maxDistance,
  }) {
    final allowedDistance = maxDistance ?? getMaxDistance(query);

    // First pass: substring filter
    final filtered = candidates.where(
      (c) => c.toLowerCase().contains(query.toLowerCase().replaceAll(' ', '')),
    ).toList();

    if (filtered.isEmpty) {
      // Fallback: try fuzzy matching on all
      return findMatches(query, candidates, maxDistance: allowedDistance);
    }

    // Second pass: fuzzy matching on filtered set
    return findMatches(query, filtered, maxDistance: allowedDistance);
  }

  /// Phonetic similarity matching (Soundex-based)
  /// Useful for name/entity matching where spelling variants exist
  static bool soundexMatch(String s1, String s2) {
    final code1 = _soundex(s1);
    final code2 = _soundex(s2);
    return code1 == code2;
  }

  /// Soundex algorithm implementation
  static String _soundex(String text) {
    text = text.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    if (text.isEmpty) return '';

    final codes = <String, String>{
      'A': '', 'E': '', 'I': '', 'O': '', 'U': '', 'Y': '', 'H': '', 'W': '',
      'B': '1', 'F': '1', 'P': '1', 'V': '1',
      'C': '2', 'G': '2', 'J': '2', 'K': '2', 'Q': '2', 'S': '2', 'X': '2', 'Z': '2',
      'D': '3', 'T': '3',
      'L': '4',
      'M': '5', 'N': '5',
      'R': '6',
    };

    final result = <String>[text[0]];
    var lastCode = codes[text[0]] ?? '';

    for (var i = 1; i < text.length && result.length < 4; i++) {
      final code = codes[text[i]] ?? '';
      if (code.isNotEmpty && code != lastCode) {
        result.add(code);
        lastCode = code;
      } else if (code.isEmpty) {
        lastCode = '';
      }
    }

    while (result.length < 4) {
      result.add('0');
    }

    return result.join();
  }
}
