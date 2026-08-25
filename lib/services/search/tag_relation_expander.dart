import '../../database/daos/daos.dart';

/// Tag Relation Expander - expands search queries by using tag relationships
/// Example: "Messi" → [Messi, Inter Miami, Barcelona, Argentina, Football, World Cup, etc.]
class TagRelationExpander {
  final TagDAO _tagDAO;
  final TagRelationDAO _tagRelationDAO;

  // Cache for expanded tags (tag_id -> expanded_tag_ids)
  final Map<int, Set<int>> _expansionCache = {};

  TagRelationExpander({
    required TagDAO tagDAO,
    required TagRelationDAO tagRelationDAO,
  })  : _tagDAO = tagDAO,
        _tagRelationDAO = tagRelationDAO;

  /// Expands a search tag to all related tags using BFS
  /// Example: expandTag("messi", maxDepth: 2)
  /// Returns: [Messi, Inter Miami, Barcelona, Argentina, etc.]
  Future<List<String>> expandTag(
    String canonicalName, {
    int maxDepth = 2,
  }) async {
    // Get the tag by canonical name
    final tag = await _tagDAO.getByCanonicalName(canonicalName);
    if (tag == null) {
      // If tag doesn't exist, return just the original query
      return [canonicalName];
    }

    // Check cache first
    if (_expansionCache.containsKey(tag.id)) {
      final expandedIds = _expansionCache[tag.id]!;
      final tags = <String>[];
      for (final id in expandedIds) {
        final t = await _tagDAO.getById(id);
        if (t != null) {
          tags.add(t.canonicalName);
        }
      }
      return tags;
    }

    // Perform BFS expansion
    final expanded = <int>{tag.id};
    final toProcess = <int>[tag.id];
    var currentDepth = 0;

    while (toProcess.isNotEmpty && currentDepth < maxDepth) {
      final nextLevel = <int>[];

      for (final currentTagId in toProcess) {
        // Get all tags related from this source tag
        final relations = await _tagRelationDAO.getBySourceTagId(currentTagId);

        for (final relation in relations) {
          if (!expanded.contains(relation.targetTagId)) {
            expanded.add(relation.targetTagId);
            nextLevel.add(relation.targetTagId);
          }
        }
      }

      toProcess.clear();
      toProcess.addAll(nextLevel);
      currentDepth++;
    }

    // Cache the result
    _expansionCache[tag.id] = expanded;

    // Convert IDs to canonical names
    final results = <String>[];
    for (final id in expanded) {
      final t = await _tagDAO.getById(id);
      if (t != null) {
        results.add(t.canonicalName);
      }
    }

    return results;
  }

  /// Expands multiple tags and returns union of all expansions
  /// Used when user searches "Messi Argentina" to expand all tags
  Future<Set<String>> expandMultipleTags(
    List<String> canonicalNames, {
    int maxDepth = 2,
  }) async {
    final expanded = <String>{};

    for (final name in canonicalNames) {
      final tags = await expandTag(name, maxDepth: maxDepth);
      expanded.addAll(tags);
    }

    return expanded;
  }

  /// Gets tags by relation type (e.g., "player_of_team")
  /// Useful for grouping related searches
  Future<List<String>> getTagsByRelationType(
    String sourceTagCanonical,
    String relationType,
  ) async {
    final sourceTag = await _tagDAO.getByCanonicalName(sourceTagCanonical);
    if (sourceTag == null) return [];

    final relations = await _tagRelationDAO.getBySourceTagId(sourceTag.id);
    final filtered = relations
        .where((r) => r.relationType == relationType)
        .toList();

    final results = <String>[];
    for (final relation in filtered) {
      final tag = await _tagDAO.getById(relation.targetTagId);
      if (tag != null) {
        results.add(tag.canonicalName);
      }
    }

    return results;
  }

  /// Clears the expansion cache (call periodically or on tag updates)
  void clearCache() {
    _expansionCache.clear();
  }

  /// Gets all available relation types
  Future<List<String>> getAvailableRelationTypes() async {
    return await _tagRelationDAO.getRelationTypes();
  }

  /// Checks if two tags are directly related
  Future<bool> areTagsRelated(
    String sourceCanonical,
    String targetCanonical,
  ) async {
    final sourceTag = await _tagDAO.getByCanonicalName(sourceCanonical);
    final targetTag = await _tagDAO.getByCanonicalName(targetCanonical);

    if (sourceTag == null || targetTag == null) return false;

    final relations = await _tagRelationDAO.getRelationsBetween(
      sourceTag.id,
      targetTag.id,
    );

    return relations.isNotEmpty;
  }

  /// Gets inverse relations: which tags point to this tag
  /// Example: get all teams that a player plays for
  Future<List<String>> getInverseRelations(String canonicalName) async {
    final tag = await _tagDAO.getByCanonicalName(canonicalName);
    if (tag == null) return [];

    final relations = await _tagRelationDAO.getByTargetTagId(tag.id);
    final results = <String>[];

    for (final relation in relations) {
      final sourceTag = await _tagDAO.getById(relation.sourceTagId);
      if (sourceTag != null) {
        results.add(sourceTag.canonicalName);
      }
    }

    return results;
  }
}
