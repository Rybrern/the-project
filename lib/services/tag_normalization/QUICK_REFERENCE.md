# Tag Normalization - Quick Reference

## Core Classes

### TagNormalizer
Text normalization and fuzzy matching.

```dart
final normalizer = TagNormalizer();

// Text normalization
normalizer.normalizeText('Lionel Messi')  // → "lionel messi"

// Extract and deduplicate tags
normalizer.extractTags(['Messi', 'messi', 'MESSI'])  // → ["messi"]

// Build canonical name
normalizer.buildCanonicalName('Real Madrid')  // → "real-madrid"

// Fuzzy matching
normalizer.fuzzyMatchScore('messi', 'messy')  // → 0.8 (80% match)

// Entity detection
normalizer.personNameLikelihood('lionel messi')  // → 0.85
normalizer.isLikelySports('football')             // → true
normalizer.isLikelyLocation('barcelona')          // → false (also a team)
```

### TagSeeder
Seed tags from API responses into the database.

```dart
final seeder = TagSeeder(database);

// Seed tags from a wallpaper
await seeder.seedTagsFromImage(wallpaper);

// Bulk seed canonical tags
await seeder.seedCanonicalTags([
  TagDefinition(
    canonicalName: 'lionel-messi',
    displayName: 'Lionel Messi',
    entityType: 'PERSON',
    aliases: ['messi', 'leo', 'm10'],
  ),
]);
```

### TagAliasService
Resolve user input to canonical tags.

```dart
final aliasService = TagAliasService(database);

// Initialize (once at startup)
await aliasService.initializeCache();
await aliasService.seedCommonAliases();

// Resolve tag
final result = await aliasService.resolveTag('messi');
if (result != null) {
  print(result.tag.displayName);  // "Lionel Messi"
  print(result.confidence);        // 1.0
}

// Add new alias
await aliasService.addAlias(tagId, 'leo', source: 'user_input');

// Get all aliases for a tag
final aliases = await aliasService.getTagAliases(tagId);
```

## Common Workflows

### Extract and Normalize API Tags

```dart
final normalizer = TagNormalizer();
final tags = normalizer.extractTags([
  {'name': 'Lionel Messi'},
  {'name': 'messi'},
  {'name': 'Football'},
]);
// Result: ["lionel messi", "messi", "football"]
```

### Seed Tags from Wallpaper

```dart
final seeder = TagSeeder(database);
final wallpaper = Wallpaper(
  id: 'image_123',
  tags: ['messi', 'football', 'argentina'],
  source: 'openverse',
  // ... other fields
);
await seeder.seedTagsFromImage(wallpaper);
```

### Search with Tag Resolution

```dart
final aliasService = TagAliasService(database);
final userInput = 'messi';  // User search

final resolution = await aliasService.resolveTag(userInput);
if (resolution != null) {
  // Get images with this tag
  final images = await imageTagDAO.getWallpapersByTagId(resolution.tagId);
}
```

## Database Methods

### TagDAO

```dart
final tagDAO = TagDAO(database);

// Upsert (insert or update)
final tagId = await tagDAO.upsertCanonical(
  canonicalName: 'lionel-messi',
  displayName: 'Lionel Messi',
  tagType: 'PERSON',
);

// Get by name
final tag = await tagDAO.getByCanonicalName('lionel-messi');

// Get by type
final persons = await tagDAO.getByType('PERSON');

// Get popular tags
final popular = await tagDAO.getPopularTags(limit: 20);
```

### ImageTagDAO

```dart
final imageTagDAO = ImageTagDAO(database);

// Link image to tag
await imageTagDAO.linkWithConfidence(
  wallpaperId: 'wall_123',
  tagId: 42,
  confidence: 1.0,
  source: 'api_metadata',
);

// Get tags for image
final tags = await imageTagDAO.getByWallpaperId('wall_123');

// Get images with tag
final images = await imageTagDAO.getWallpapersByTagId(42);

// Update confidence
await imageTagDAO.updateConfidence('wall_123', 42, 0.9);
```

### TagAliasDAO

```dart
final aliasDAO = TagAliasDAO(database);

// Upsert alias
final aliasId = await aliasDAO.upsertAlias(
  tagId: 42,
  aliasText: 'messi',
  normalizedAlias: 'messi',
  confidence: 1.0,
);

// Resolve normalized alias to tag ID
final tagId = await aliasDAO.resolveAlias('messi');

// Get aliases for tag
final aliases = await aliasDAO.getByTagId(42);

// Search aliases
final results = await aliasDAO.searchByText('mess');
```

## Entity Types

Automatically detected:
- **PERSON**: "lionel messi", "cristiano ronaldo"
- **TEAM**: "real madrid", "barcelona"
- **SPORT**: "football", "basketball"
- **COMPETITION**: "champions league", "formula 1"
- **LOCATION**: "spain", "argentina"
- **THEME**: "dark", "minimalist"
- **STYLE**: "cyberpunk", "abstract"
- **CONCEPT**: "nature", "animals"

## Confidence Levels

| Level | Source | Usage |
|-------|--------|-------|
| 1.0 | API provider | Direct from OpenVerse/Unsplash/etc |
| 0.95 | Manual seeding | Pre-populated canonical tags |
| 0.8 | Inferred | Detected from context/analysis |
| 0.5 | Fuzzy match | Result of similarity search |

## Integration with Pipeline

```dart
// In batch processor initialization:
final pipeline = BatchPipeline([
  // ... other stages
  ClassificationStage(appDatabase: database),  // Enable tag seeding
  // ... other stages
]);
```

## Performance Tips

### 1. Initialize Cache at Startup
```dart
final aliasService = TagAliasService(database);
await aliasService.initializeCache();  // One-time setup
```

### 2. Bulk Operations for Many Tags
```dart
// Better: Bulk seed
await seeder.seedCanonicalTags(manyTags);

// Instead of: Seeding one at a time
for (final tag in manyTags) {
  await seeder.seedTagsFromImage(wallpaper);
}
```

### 3. Use Pagination for Large Datasets
```dart
final tags = await tagDAO.getAllPaginated(limit: 100, offset: 0);
```

## Common Issues

### Tags Not Appearing
- Check database initialization
- Verify ClassificationStage has appDatabase parameter
- Confirm API response contains tags

### Fuzzy Matching Not Working
- Call `initializeCache()` first
- Check fuzzy match confidence (default: 0.7)
- Verify normalized text is correct

### Performance Slow
- Enable caching with `initializeCache()`
- Use pagination for large queries
- Check database indexes on canonical_name

## File Structure

```
lib/services/tag_normalization/
├── tag_normalizer.dart           ← Text normalization
├── tag_seeder.dart               ← Database seeding
├── tag_alias_service.dart        ← Alias resolution
├── tag_normalization.dart        ← Exports
├── QUICK_REFERENCE.md            ← This file
├── TAG_NORMALIZATION_GUIDE.md    ← Full documentation
├── tag_normalization_example.dart ← Examples
└── tag_normalization_test.dart   ← Tests
```

## Example: Complete Workflow

```dart
// 1. Initialize services
final normalizer = TagNormalizer();
final seeder = TagSeeder(database);
final aliasService = TagAliasService(database);

// 2. Setup (once at app startup)
await aliasService.initializeCache();
await aliasService.seedCommonAliases();

// 3. Process API response
final apiTags = [
  {'name': 'Lionel Messi'},
  {'name': 'Football'},
  {'name': 'Argentina'},
];

// 4. Create wallpaper from API
final wallpaper = Wallpaper(
  id: 'openverse_123',
  tags: apiTags.map((t) => t['name']).toList(),
  source: 'openverse',
  // ... other fields
);

// 5. Seed tags (automatic in ClassificationStage)
await seeder.seedTagsFromImage(wallpaper);

// 6. Later: Search with tag resolution
final resolution = await aliasService.resolveTag('messi');
// Now you can use resolution.tag for database queries
```

## API Reference Summary

| Class | Method | Purpose |
|-------|--------|---------|
| TagNormalizer | normalizeText() | Normalize text |
| TagNormalizer | extractTags() | Extract from API |
| TagNormalizer | buildCanonicalName() | Create tag name |
| TagNormalizer | fuzzyMatchScore() | Compare strings |
| TagSeeder | seedTagsFromImage() | Seed from wallpaper |
| TagSeeder | seedCanonicalTags() | Bulk seed |
| TagAliasService | resolveTag() | Find canonical tag |
| TagAliasService | addAlias() | Add new alias |
| TagAliasService | seedCommonAliases() | Pre-populate aliases |
| TagDAO | upsertCanonical() | Insert/update tag |
| ImageTagDAO | linkWithConfidence() | Link image to tag |
| TagAliasDAO | upsertAlias() | Insert/update alias |

## Next Steps

1. Read [TAG_NORMALIZATION_GUIDE.md](TAG_NORMALIZATION_GUIDE.md) for details
2. Check [tag_normalization_example.dart](tag_normalization_example.dart) for examples
3. Review [tag_normalization_test.dart](tag_normalization_test.dart) for test cases
4. Integrate with ClassificationStage in batch processor
5. Monitor tag seeding in production
