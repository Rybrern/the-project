# Phase 4: Tag Normalization and Entity Seeding

## Overview

This phase implements a comprehensive tag normalization and entity seeding system for the wallpaper app's v6 tag system. It enables automatic normalization of tags from various content providers (OpenVerse, Unsplash, GIPHY, Pixabay) and creates intelligent aliases for fuzzy matching.

## Key Features

### 1. **Text Normalization** (TagNormalizer)
- Converts text to lowercase
- Removes accents (é → e, ñ → n, etc.)
- Strips special characters
- Collapses whitespace
- Deduplicates similar tags

**Example:**
```
"Lionel Messi" → "lionel messi"
"São Paulo" → "sao paulo"
"Café ☕" → "cafe"
```

### 2. **Tag Extraction** (TagNormalizer.extractTags)
- Handles multiple input formats (List<String>, List<Map>, etc.)
- Extracts from API responses automatically
- Deduplicates during extraction
- Returns normalized tags

**Example:**
```dart
final tags = [
  {'name': 'Lionel Messi'},
  {'name': 'messi'},
  {'name': 'Football'},
];
normalizer.extractTags(tags) 
// Result: ["lionel messi", "messi", "football"]
```

### 3. **Entity Type Detection** (TagSeeder)
Automatically detects tag types:
- **PERSON**: Person names (e.g., "lionel messi")
- **TEAM**: Sports teams (e.g., "real madrid")
- **SPORT**: Sports names (e.g., "football")
- **COMPETITION**: Competitions (e.g., "champions league")
- **LOCATION**: Geographic locations (e.g., "barcelona")
- **THEME**: Visual themes (e.g., "minimalist")
- **STYLE**: Art/design styles (e.g., "cyberpunk")
- **CONCEPT**: Generic concepts (e.g., "nature")

### 4. **Confidence Scoring**
Confidence levels based on source:
- **1.0 (API-provided)**: Tags from content providers
- **0.95 (Manual seeding)**: Pre-populated canonical tags
- **0.8 (Inferred)**: Detected from visual analysis
- **0.5 (Fuzzy match)**: Result of fuzzy matching

### 5. **Alias Mapping** (TagAliasService)
Pre-populated common aliases for:
- Sports figures: "messi" → "lionel-messi"
- Teams: "barca" → "barcelona"
- Competitions: "f1" → "formula-1"
- Styles: "cyber punk" → "cyberpunk"

### 6. **Fuzzy Matching**
Uses Levenshtein distance for similar tag matching:
- "leo" ≈ "lionel messi" (score: 0.6)
- "cr7" ≈ "cristiano ronaldo" (score: 0.4)
- Confidence threshold: 0.7+

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Content Providers (OpenVerse, Unsplash, GIPHY, Pixabay)    │
│ ↓ API returns tags: ["messi", "lionel messi", "football"]  │
├─────────────────────────────────────────────────────────────┤
│ Classification Stage (Batch Pipeline)                       │
│ ↓ 1. Extract tags from metadata                            │
│ ↓ 2. Normalize text (lowercase, accent removal)            │
│ ↓ 3. Detect entity types                                   │
│ ↓ 4. Seed into database                                    │
├─────────────────────────────────────────────────────────────┤
│ Tag Database (v6 System)                                    │
│ ├─ tags: canonical_name, display_name, tag_type           │
│ ├─ tag_aliases: maps variations to canonical               │
│ └─ image_tags: links images to tags with confidence        │
├─────────────────────────────────────────────────────────────┤
│ Search & Resolution                                         │
│ ↓ User searches: "messi" → TagAliasService.resolveTag()   │
│ ↓ Returns: lionel-messi (PERSON type, high confidence)    │
└─────────────────────────────────────────────────────────────┘
```

## Usage

### Basic Text Normalization

```dart
final normalizer = TagNormalizer();

// Normalize text
final result = normalizer.normalizeText("Lionel Messi");
// Result: "lionel messi"

// Build canonical name
final canonical = normalizer.buildCanonicalName("Real Madrid");
// Result: "real-madrid"
```

### Extract Tags from API

```dart
final normalizer = TagNormalizer();

// From OpenVerse response
final apiTags = [
  {'name': 'Lionel Messi'},
  {'name': 'messi'},
  {'name': 'Football'},
];

final normalized = normalizer.extractTags(apiTags);
// Result: ["lionel messi", "messi", "football"]
```

### Seed Tags from Wallpaper

```dart
final seeder = TagSeeder(database);

// Image from API with tags
final wallpaper = Wallpaper(
  id: 'openverse_12345',
  thumbnailUrl: '...',
  fullUrl: '...',
  author: 'John Doe',
  category: 'deportes',
  aspectRatio: 1.78,
  source: 'openverse',
  sourceId: '12345',
  tags: ['messi', 'lionel messi', 'football', 'argentina'],
);

// Seed tags
await seeder.seedTagsFromImage(wallpaper);

// Result:
// - Tags normalized and deduplicated
// - Entity types detected
// - Database entries created
// - Aliases created for variations
// - Image-tag links stored with confidence=1.0
```

### Bulk Seed Canonical Tags

```dart
final seeder = TagSeeder(database);

final tags = [
  TagDefinition(
    canonicalName: 'lionel-messi',
    displayName: 'Lionel Messi',
    entityType: 'PERSON',
    aliases: ['messi', 'leo messi', 'm10'],
    confidence: 0.95,
  ),
  // ... more tags
];

await seeder.seedCanonicalTags(tags);
```

### Resolve Tags with Alias Service

```dart
final aliasService = TagAliasService(database);

// Initialize cache (once at app startup)
await aliasService.initializeCache();
await aliasService.seedCommonAliases();

// Resolve user input
final resolution = await aliasService.resolveTag('messi');
if (resolution != null) {
  print('${resolution.tag.displayName}'); // "Lionel Messi"
  print('${resolution.matchType}');        // "exact_alias"
  print('${resolution.confidence}');       // 1.0
}

// Fuzzy matching
final fuzzy = await aliasService.resolveTag('messy'); // Typo
if (fuzzy != null && fuzzy.confidence > 0.8) {
  // Found with fuzzy match
}
```

## Integration with Batch Pipeline

### 1. ClassificationStage Initialization

```dart
// In batch_processor.dart or similar:
final pipeline = BatchPipeline([
  FetchStage(),
  DownloadStage(),
  DedupStage(),
  NSFWStage(),
  QualityStage(),
  ClassificationStage(appDatabase: database), // ← Add database
  ResolutionVariantStage(),
  SearchIndexStage(),
  StorageStage(),
]);
```

### 2. Automatic Tag Seeding

When an image passes through ClassificationStage:
1. Tags are extracted from metadata
2. Text is normalized (lowercase, accents removed)
3. Entity types are detected
4. Tags are seeded into database
5. Aliases are created
6. Image-tag links are stored with confidence scores

### 3. Workflow Example

```
API Response:
  image.tags = ["messi", "lionel messi", "leo messi", "football"]

Normalization:
  ["messi", "lionel messi", "leo messi", "football"]
  → [messi, lionel messi, messi, football]  (normalized)
  → [messi, lionel messi, football]         (deduplicated)

Type Detection:
  messi → PERSON (0.85 confidence)
  lionel messi → PERSON (0.85 confidence)
  football → SPORT (0.95 confidence)

Database Seeding:
  tags table:
    - canonical_name: "messi", display_name: "Messi", type: PERSON
    - canonical_name: "lionel-messi", display_name: "Lionel Messi", type: PERSON
    - canonical_name: "football", display_name: "Football", type: SPORT

  tag_aliases table:
    - "messi" → tag_id (1)
    - "leo messi" → tag_id (2)
    - "leo" → tag_id (2)

  image_tags table:
    - wallpaper_id → tag_id (1), confidence: 1.0
    - wallpaper_id → tag_id (2), confidence: 1.0
    - wallpaper_id → tag_id (3), confidence: 1.0
```

## Database Schema Integration

### Tags Table (v6)
```sql
CREATE TABLE tags (
  id INTEGER PRIMARY KEY,
  canonical_name TEXT UNIQUE NOT NULL,  -- "lionel-messi"
  display_name TEXT NOT NULL,            -- "Lionel Messi"
  tag_type TEXT NOT NULL,                -- "PERSON", "TEAM", etc.
  description TEXT,
  parent_tag_id INTEGER,
  confidence REAL DEFAULT 0.95,
  created_at INTEGER NOT NULL
);
```

### Tag Aliases Table
```sql
CREATE TABLE tag_aliases (
  id INTEGER PRIMARY KEY,
  tag_id INTEGER NOT NULL,
  alias_text TEXT NOT NULL,              -- "messi"
  normalized_alias TEXT NOT NULL,        -- "messi" (searchable)
  source TEXT,                           -- "api_metadata", "manual_seeding"
  confidence REAL DEFAULT 0.8,
  created_at INTEGER NOT NULL,
  FOREIGN KEY(tag_id) REFERENCES tags(id)
);
```

### Image Tags Table
```sql
CREATE TABLE image_tags (
  id INTEGER PRIMARY KEY,
  wallpaper_id TEXT NOT NULL,
  tag_id INTEGER NOT NULL,
  confidence REAL DEFAULT 0.95,          -- API: 1.0, Inferred: 0.8
  source TEXT,                           -- "api_metadata", "visual_analysis"
  created_at INTEGER NOT NULL,
  FOREIGN KEY(tag_id) REFERENCES tags(id)
);
```

## DAO Methods

### TagDAO
- `upsertCanonical()`: Insert or update canonical tag
- `getByCanonicalName()`: Lookup tag by canonical name
- `getByType()`: Get all tags of specific type
- `getPopularTags()`: Get most-used tags

### TagAliasDAO
- `upsertAlias()`: Insert or update alias
- `resolveAlias()`: Resolve normalized alias to tag ID
- `getByTagId()`: Get all aliases for a tag
- `getByNormalizedAlias()`: Lookup aliases by normalized text

### ImageTagDAO
- `linkWithConfidence()`: Link image to tag with confidence
- `upsertImageTag()`: Insert or update image-tag link
- `getByWallpaperId()`: Get all tags for an image
- `getWallpapersByTagId()`: Get all images with a tag

## Confidence Scoring Reference

| Source | Confidence | Meaning |
|--------|-----------|---------|
| API (OpenVerse, Unsplash, etc.) | 1.0 | Direct from content provider metadata |
| Manual Seeding | 0.95 | Pre-populated canonical tags |
| Visual Analysis | 0.8 | Detected from image content |
| Fuzzy Match | 0.5 | Result of fuzzy string matching |
| Generic Tag | 0.7 | Inferred from context |

## Performance Optimization

### Caching
```dart
// Initialize cache once at app startup
final aliasService = TagAliasService(database);
await aliasService.initializeCache(); // Loads all aliases into memory
```

### Bulk Operations
```dart
// Seed multiple tags at once
await seeder.seedCanonicalTags(tags); // Uses batch operations

// Bulk insert aliases
await aliasDAO.insertBatch(aliases);
```

### Query Optimization
- Use indexed lookups by canonical_name
- Use normalized_alias for search
- Limit results with pagination

## Testing Checklist

- [ ] Text normalization handles accents correctly
- [ ] Tag extraction deduplicates properly
- [ ] Entity type detection matches expected types
- [ ] Confidence scores are assigned correctly
- [ ] Aliases are created for variations
- [ ] Fuzzy matching returns similar tags
- [ ] Database operations are transactional
- [ ] Cache is populated and used correctly
- [ ] Bulk operations perform efficiently
- [ ] Integration with ClassificationStage works
- [ ] Tags persist across app restarts
- [ ] Search resolves through aliases

## Future Enhancements

1. **ML-based Entity Detection**: Use ML models for better entity type detection
2. **Relationship Mapping**: Create hierarchies (Messi → Real Madrid → Spain)
3. **Tag Expansion**: Automatically suggest related tags
4. **User Contributions**: Allow users to suggest aliases
5. **Analytics**: Track tag usage patterns
6. **A/B Testing**: Compare different normalization strategies
7. **Internationalization**: Support non-Latin scripts

## Troubleshooting

### Tags Not Appearing
- Check if database initialization ran
- Verify API response contains tags
- Ensure ClassificationStage has appDatabase parameter

### Fuzzy Matching Not Working
- Verify TagAliasService.initializeCache() was called
- Check confidence threshold (default: 0.7)
- Inspect normalized text output

### Performance Issues
- Enable caching with initializeCache()
- Use bulk operations for many tags
- Consider pagination for large result sets

## References

- **TagNormalizer**: Text normalization and fuzzy matching
- **TagSeeder**: Seed tags from API responses into database
- **TagAliasService**: Resolve tags and manage aliases
- **ClassificationStage**: Integration point in batch pipeline
- **Example File**: tag_normalization_example.dart

## Support

For issues or questions, refer to:
1. Example file: `tag_normalization_example.dart`
2. Test cases (when added)
3. Integration documentation in each DAO
