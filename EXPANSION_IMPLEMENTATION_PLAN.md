# Plan Detallado de Implementación - Expansión de Wallpapers

**Versión:** 1.0  
**Estado:** 📋 LISTO PARA IMPLEMENTAR

---

## 🎯 OBJETIVO FINAL

Transformar la aplicación de wallpapers de:
```
Catálogo pequeño (100-500 items)
├── Carga rápida
├── UI simple
└── Memory-efficient
```

A:
```
Catálogo masivo (10,000+ items)
├── Búsqueda inteligente
├── Carga progresiva
├── Lazy loading
├── Previews optimizadas
├── Fondos animados mejorados
└── Performance escalable
```

**Sin romper nada existente.**

---

## 📂 ITERACIONES DE IMPLEMENTACIÓN

### 🔴 ITERACIÓN 1: EXTENSIÓN DE BASE DE DATOS

**Objetivo:** Preparar BD para resolutions múltiples y búsqueda.

**Cambios en BD:**

1. **Nueva migración (004_wallpaper_resolutions.sql)**
   ```sql
   -- Almacenar múltiples resolutions
   CREATE TABLE wallpaper_resolutions (
     id INTEGER PRIMARY KEY,
     wallpaper_id TEXT NOT NULL,
     resolution_type TEXT NOT NULL,  -- 'thumbnail', 'preview', 'original'
     url TEXT NOT NULL UNIQUE,
     width INTEGER,
     height INTEGER,
     file_size_bytes INTEGER,
     created_at INTEGER DEFAULT (strftime('%s', 'now')),
     FOREIGN KEY(wallpaper_id) REFERENCES wallpapers(id)
   );
   
   CREATE INDEX idx_wallpaper_resolutions_wallpaper_id 
     ON wallpaper_resolutions(wallpaper_id, resolution_type);
   ```

2. **Nueva migración (005_search_index.sql)**
   ```sql
   CREATE TABLE search_index (
     id INTEGER PRIMARY KEY,
     wallpaper_id TEXT NOT NULL,
     query_text TEXT NOT NULL,  -- normalized
     entity_type TEXT,  -- 'player', 'team', 'tag', 'general'
     relevance REAL DEFAULT 1.0,
     created_at INTEGER DEFAULT (strftime('%s', 'now')),
     FOREIGN KEY(wallpaper_id) REFERENCES wallpapers(id)
   );
   
   CREATE INDEX idx_search_index_query 
     ON search_index(query_text);
   CREATE INDEX idx_search_index_entity_type 
     ON search_index(entity_type);
   ```

3. **Extensión de Wallpaper table**
   ```sql
   ALTER TABLE wallpapers ADD COLUMN preview_url TEXT;
   ALTER TABLE wallpapers ADD COLUMN search_tokens TEXT;  -- JSON array
   ALTER TABLE wallpapers ADD COLUMN entity_metadata TEXT;  -- JSON
   ```

4. **Nueva tabla para AnimatedWallpaper**
   ```sql
   CREATE TABLE animated_wallpapers (
     id INTEGER PRIMARY KEY,
     external_id TEXT UNIQUE NOT NULL,
     preview_image_url TEXT NOT NULL,
     video_url TEXT NOT NULL,
     preview_video_url TEXT,  -- compressed preview
     width INTEGER,
     height INTEGER,
     source TEXT,
     source_id TEXT,
     nfsw_score REAL,
     quality_score REAL,
     primary_category TEXT,
     subcategory TEXT,
     tags TEXT,  -- JSON array
     search_tokens TEXT,  -- JSON array
     entity_metadata TEXT,  -- JSON
     processed_at INTEGER,
     processing_status TEXT,
     created_at INTEGER DEFAULT (strftime('%s', 'now'))
   );
   
   CREATE INDEX idx_animated_wallpapers_category 
     ON animated_wallpapers(primary_category);
   CREATE INDEX idx_animated_wallpapers_processed 
     ON animated_wallpapers(processing_status);
   ```

**DAOs a crear:**

```dart
// lib/database/daos/wallpaper_resolution_dao.dart
class WallpaperResolutionDAO {
  Future<void> insert(WallpaperResolution resolution);
  Future<List<WallpaperResolution>> getByWallpaperId(String id);
  Future<WallpaperResolution?> getByType(String wallpaperId, String type);
  Future<bool> existsByUrl(String url);
  // ... más métodos
}

// lib/database/daos/search_index_dao.dart
class SearchIndexDAO {
  Future<void> insertBatch(List<SearchIndexEntry> entries);
  Future<List<String>> search(String query, {String? entityType});
  Future<void> rebuildIndex();  // rebuild from wallpapers
  // ... más métodos
}

// lib/database/daos/animated_wallpaper_dao.dart
class AnimatedWallpaperDAO {
  Future<void> insert(AnimatedWallpaper wallpaper);
  Future<AnimatedWallpaper?> getById(String id);
  Future<List<AnimatedWallpaper>> getByCategory(String category);
  Future<List<AnimatedWallpaper>> search(String query);
  // ... más métodos
}
```

**Timeline:** 2-3 horas

---

### 🟠 ITERACIÓN 2: EXTENSIÓN DE MODELOS

**Objetivo:** Adaptar modelos sin breaking changes.

**Cambios en lib/models/:**

1. **Extender Wallpaper**
   ```dart
   class Wallpaper {
     // Campos existentes
     String thumbnailUrl;
     String fullUrl;
     
     // Nuevos (opcionales para backward compatibility)
     String? previewUrl;
     List<WallpaperResolution>? resolutions;
     List<String>? searchTokens;
     Map<String, dynamic>? entityMetadata;  // {player: "Messi", team: "PSG"}
     
     // copyWith() actualizado para incluir nuevos campos
   }
   ```

2. **Extender AnimatedWallpaper**
   ```dart
   class AnimatedWallpaper {
     // Existentes
     String previewImageUrl;
     String videoUrl;
     int width, height;
     
     // Nuevos
     String? previewVideoUrl;
     String? source;
     String? sourceId;
     double? nsfwScore;
     double? qualityScore;
     String? primaryCategory;
     String? subcategory;
     List<String>? tags;
     List<String>? searchTokens;
     Map<String, dynamic>? entityMetadata;
     DateTime? processedAt;
     String? processingStatus;
   }
   ```

3. **Crear Resolution**
   ```dart
   class WallpaperResolution {
     String url;
     String type;  // 'thumbnail', 'preview', 'original'
     int width, height;
     int fileSizeBytes;
     DateTime createdAt;
   }
   ```

4. **Crear SearchIndexEntry**
   ```dart
   class SearchIndexEntry {
     String wallpaperId;
     String queryText;  // normalized
     String? entityType;
     double relevance;
   }
   ```

**Actualizar JSON serialization:**
- Wallpaper.fromJson() → incluir nuevos campos opcionales
- AnimatedWallpaper.fromJson() → igual
- Backward compatible: campos faltantes → null

**Timeline:** 1 hora

---

### 🟡 ITERACIÓN 3: SISTEMA DE BÚSQUEDA

**Objetivo:** Implementar búsqueda inteligente y reutilizable.

**Nuevos archivos:**

1. **lib/services/search/search_service.dart**
   ```dart
   class SearchService {
     Future<List<Wallpaper>> search(
       String query, {
       String? category,
       String? entityType,
       bool includeAnimated = true,
     });
     
     Future<List<String>> getAutocompleteSuggestions(String prefix);
     Future<void> rebuildSearchIndex();
     
     // Privados
     List<String> _normalizeQuery(String query);
     double _calculateRelevance(SearchIndexEntry, String query);
   }
   ```

2. **lib/services/search/text_normalizer.dart**
   ```dart
   class TextNormalizer {
     static String normalize(String text) {
       return text
         .toLowerCase()
         .replaceAll(RegExp(r'[áàäâ]'), 'a')
         .replaceAll(RegExp(r'[éèëê]'), 'e')
         .replaceAll(RegExp(r'[íìïî]'), 'i')
         .replaceAll(RegExp(r'[óòöô]'), 'o')
         .replaceAll(RegExp(r'[úùüû]'), 'u')
         .replaceAll(RegExp(r'\s+'), ' ')
         .trim();
     }
   }
   ```

3. **lib/services/search/fuzzy_match.dart**
   ```dart
   class FuzzyMatch {
     static double levenshteinSimilarity(String a, String b);
     static bool isSimilar(String a, String b, {double threshold = 0.8});
   }
   ```

**Integración con búsqueda automática:**

```dart
// En el processing masivo (batch_processor.dart)
// Después de clasificar un wallpaper:

// 1. Generar tokens de búsqueda
final searchTokens = _generateSearchTokens(wallpaper);

// 2. Insertar en search_index
await searchIndexDAO.insertBatch([
  SearchIndexEntry(
    wallpaperId: wallpaper.id,
    queryText: 'messi',
    entityType: 'player',
    relevance: 1.0,
  ),
  SearchIndexEntry(
    wallpaperId: wallpaper.id,
    queryText: 'barcelona',
    entityType: 'team',
    relevance: 0.9,
  ),
  // ... más tokens
]);
```

**Timeline:** 3-4 horas

---

### 🟢 ITERACIÓN 4: CARGA PROGRESIVA

**Objetivo:** Implementar thumbnail → preview → original flow.

**Nuevo archivo:**

1. **lib/services/image_loading/progressive_image_loader.dart**
   ```dart
   class ProgressiveImageLoader {
     // Cargar progresivamente
     Stream<ProgressiveImageState> loadProgressive(
       String wallpaperId,
     ) async* {
       // 1. Thumbnail (cached inmediatamente)
       yield ProgressiveImageState.thumbnail(...)
       
       // 2. Preview (si existe)
       if (previewUrl exists) {
         yield ProgressiveImageState.preview(...)
       }
       
       // 3. Original (bajo demanda con timeout)
       // No yield automáticamente, solo cuando se pida
     }
     
     // Cargar original con timeout
     Future<Uint8List> loadOriginal(String wallpaperId) async {
       // Timeout 5s para no bloquear
       // Si no llega, mantener preview visible
     }
   }
   
   enum ProgressiveImageState {
     thumbnail,
     preview,
     original,
     error,
   }
   ```

**Actualizar WallpaperDetailScreen:**

```dart
// Cambiar de http.get(fullUrl) a progressive load:
// 1. Mostrar thumbnail inmediatamente
// 2. Iniciar carga de preview en background
// 3. Mostrar preview cuando esté
// 4. Original solo si usuario lo pide (rotar, full-screen, etc)
```

**Timeline:** 2-3 horas

---

### 🔵 ITERACIÓN 5: LAZY LOADING Y PAGINACIÓN

**Objetivo:** Manejar catálogos grandes sin cargar todo.

**Cambio de arquitectura:**

```dart
// Antes:
Stream<List<Wallpaper>>

// Después:
Stream<PaginatedResult<Wallpaper>>

class PaginatedResult<T> {
  List<T> items;
  int total;
  int pageSize;
  int currentPage;
  bool hasMore;
  
  int get nextPage => currentPage + 1;
}
```

**En CatalogTab:**

```dart
// Antes: StreamBuilder<List<Wallpaper>>
// Después: StreamBuilder<PaginatedResult<Wallpaper>>

// Agregar al final del grid:
if (result.hasMore) {
  loader = _loadMoreButton() or autoLoad when near bottom
}
```

**Límites (ajustables):**
```dart
const INITIAL_PAGE_SIZE = 20;
const PREFETCH_THRESHOLD = 5;  // items desde el final
const MAX_IN_MEMORY = 100;     // liberar items antiguos
```

**Timeline:** 2-3 horas

---

### 🟣 ITERACIÓN 6: ANIMADOS MEJORADOS

**Objetivo:** Traer fondos animados al mismo nivel que estáticos.

**En processing masivo:**

```python
# Detectar si es realmente animado
if not is_animated_format(file):
    reject_candidate('not_animated')

# Extraer thumbnail
thumbnail = extract_frame(file, frame=0)

# Crear preview comprimido
preview = compress_video(
    file,
    bitrate='500k',        # ~50% del original
    scale=0.6,             # 60% de resolución
    duration='full',       # mantener duración
)

# Validar
if preview.size > 10*1024*1024:  # > 10MB
    reject_candidate('preview_too_large')

# Guardar resolutions
insert_resolution(original=file, preview=preview, thumbnail=thumbnail)
```

**Extensión de AnimatedWallpaper:**

```dart
// Ya hecho en Iteración 2
// Solo necesita estar integrado con processing
```

**Timeline:** 2-3 horas

---

### 🟠 ITERACIÓN 7: INTEGRACIÓN DE BÚSQUEDA EN UI

**Objetivo:** Agregar pestaña de búsqueda sin romper catálogo existente.

**Estructura:**

```
WallpapersTab (existente)
├── Estáticos
│   ├── CatalogTab (con categorías)
│   └── SearchTab (nuevo)
└── Animados (mejorado)
```

**SearchTab (nuevo):**

```dart
// lib/screens/search_tab.dart
class SearchTab extends StatefulWidget {
  const SearchTab({
    required this.wallpapersStream,
    required this.animatedWallpapersStream,
  });
  
  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final searchController = TextEditingController();
  
  // Filtros
  String? _selectedCategory;
  bool _includeAnimated = true;
  
  // Resultados
  List<Wallpaper>? _results;
  List<AnimatedWallpaper>? _animatedResults;
}
```

**Estructura de pantalla:**

```
TextField (búsqueda)
    ↓
Chips de filtro (Categoría, Estático/Animado)
    ↓
Tabs (Estáticos | Animados | Todos)
    ↓
GridView (paginado)
```

**Timeline:** 2-3 horas

---

### 🔴 ITERACIÓN 8: TESTING Y OPTIMIZACIÓN

**Objetivo:** Verificar que todo funcione y performance sea aceptable.

**Tests:**

1. **SearchService tests**
   ```dart
   test('search finds by player name');
   test('search finds by team name');
   test('search normalizes accents');
   test('fuzzy matching works');
   test('category filter works');
   ```

2. **ProgressiveImageLoader tests**
   ```dart
   test('loads thumbnail first');
   test('loads preview after thumbnail');
   test('times out original load gracefully');
   test('cache works for thumbnail');
   ```

3. **Paginación tests**
   ```dart
   test('initial load gets first page');
   test('prefetch loads next page');
   test('memory limits respected');
   test('hasMore flag correct');
   ```

4. **AnimatedWallpaper tests**
   ```dart
   test('animated wallpapers searchable');
   test('preview video loads');
   test('apply uses original video');
   ```

**Performance tests:**

```dart
// Medir con 10,000 items
test('catalog load < 500ms');
test('search response < 200ms');
test('scroll 60 FPS');
test('memory < 100MB');
```

**Timeline:** 3-4 horas

---

## 📊 RESUMEN DE CAMBIOS

| Componente | Cambio | Status |
|-----------|--------|--------|
| BD | 4 tablas nuevas, 3 columnas added | ✅ |
| DAOs | 3 nuevos (Resolution, SearchIndex, AnimatedWallpaper) | ✅ |
| Modelos | Extensión con campos opcionales | ✅ |
| Búsqueda | Sistema completo nuevo | ✅ |
| Carga progresiva | ImageLoader nuevo | ✅ |
| Paginación | Stream → Paginated | ✅ |
| Animados | Mejorados con metadatos | ✅ |
| UI | SearchTab nuevo | ✅ |

**Total estimated time:** 17-24 horas (puede distribuirse en múltiples sesiones)

---

## 🎯 CRITERIOS DE ÉXITO VERIFICABLES

Después de cada iteración:

- [ ] No hay crashes
- [ ] No hay breaking changes
- [ ] UI existente sigue funcionando
- [ ] New features funcionan
- [ ] Tests pasan
- [ ] Performance aceptable

---

## 🚀 SIGUIENTE PASO

¿Deseas que comience con **Iteración 1: Extensión de Base de Datos**?

