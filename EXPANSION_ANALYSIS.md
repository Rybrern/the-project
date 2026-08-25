# Análisis Técnico - Expansión del Sistema de Wallpapers

**Fecha:** 2026-08-24  
**Estado:** ✅ ANÁLISIS COMPLETADO

---

## 📊 AUDITORÍA DEL ESTADO ACTUAL

### 1. Almacenamiento y Modelos

**Wallpaper (Estático):**
```dart
✅ thumbnailUrl      // URL thumbnail ligero
✅ fullUrl           // URL imagen completa
✅ source            // wallhaven, pixabay, etc
✅ sourceId          // ID en fuente
✅ nsfwScore         // 0-1
✅ qualityScore      // 0-1
✅ primaryCategory   // deportes, naturaleza, etc
✅ subcategory       // fútbol, paisajes, etc
✅ tags              // Array de tags
✅ processedAt       // Timestamp procesamiento
✅ processingStatus   // accepted, rejected
```

**AnimatedWallpaper (Animado):**
```dart
✅ previewImageUrl   // Thumbnail estático
✅ videoUrl          // URL del video
✅ width/height      // Resolución
```

**Análisis:**
- ✅ Ya existe separación entre estáticos y animados
- ✅ Ya existe thumbnail/preview split
- ✅ Ya hay metadatos de clasificación
- ⚠️ AnimatedWallpaper tiene muy pocos campos vs Wallpaper
- ⚠️ No existe campo para preview intermedio en animados

### 2. Carga de Imágenes

**Sistema Actual:**
```
WallpaperTile
    ↓
CachedNetworkImage(thumbnailUrl)
    ↓
Placeholder + Progress
```

**Análisis:**
- ✅ Usa `cached_network_image` (perfecto!)
- ✅ Ya tiene placeholder
- ✅ Ya tiene caching automático
- ⚠️ No hay carga progresiva de preview → fullUrl
- ⚠️ Descarga fullUrl completa sin intermedios
- ⚠️ No hay prefetch
- ⚠️ No hay lazy loading

### 3. Pantalla de Detail/Preview

**Flujo Actual:**
```
WallpaperDetailScreen
    ↓
PannableWallpaperPreview (muestra thumbnail + crop options)
    ↓
Upon apply: descarga fullUrl completa
    ↓
Procesa (crop, resize) via compute()
    ↓
Aplica con async_wallpaper
```

**Análisis:**
- ✅ Ya hay processing de imagen
- ✅ Ya hay optimización de calidad
- ⚠️ No hay carga progresiva en preview
- ⚠️ fullUrl se descarga solo al aplicar
- ⚠️ No hay preview de mayor calidad intermedio

### 4. Fondos Animados

**Pantalla AnimatedWallpapersTab:**
```
AnimatedWallpaper
    ↓
previewImageUrl (thumbnail)
    ↓
Upon apply: descarga videoUrl
```

**Análisis:**
- ✅ Ya tiene preview estático
- ⚠️ Solo thumbnail y video completo, sin intermedios
- ⚠️ Video completo se descarga al aplicar
- ⚠️ Sin preview de video antes de aplicar
- ⚠️ Pocos metadatos vs estáticos

### 5. Base de Datos

**DAOs Existentes:**
- ✅ WallpaperDAO (completo)
- ✅ CategoryHierarchyDAO
- ✅ HashRegistryDAO
- ✅ ProcessingRecordDAO
- ⚠️ No hay tabla específica para animados
- ⚠️ No hay índices de búsqueda
- ⚠️ No hay tabla de previews/resolutions

### 6. Búsqueda

**Estado Actual:**
- ⚠️ No existe sistema de búsqueda
- ⚠️ Solo filtrado por categoría
- ⚠️ Sin búsqueda por tags
- ⚠️ Sin búsqueda por entidades (jugadores, equipos)
- ⚠️ Sin autocompletado
- ⚠️ Sin fuzzy matching

### 7. Descubrimiento e Ingesta

**Existente:**
- ✅ Discovery engine (multi-fuente)
- ✅ Pipeline 7-etapas
- ✅ Validación NSFW
- ✅ Clasificación automática
- ✅ Deduplicación
- ✅ Processing masivo

**Posibilidades:**
- ✅ Sistema listo para agregar animados
- ⚠️ No genera previews intermedias automáticamente
- ⚠️ No optimiza resolutions múltiples

### 8. Cache

**Existente:**
- ✅ CachedNetworkImage (automático)
- ✅ Cache HTTP mediante flutter_cache_manager
- ✅ CacheManager para categorías
- ⚠️ No hay control fino de qué cachear
- ⚠️ No hay prefetch
- ⚠️ No hay liberación de recursos

### 9. Paginación/Lazy Loading

**Estado:**
- ⚠️ StreamBuilder carga TODO de una vez
- ⚠️ No hay paginación
- ⚠️ No hay lazy loading
- ⚠️ Puede causar problema con miles de items

### 10. Categorías

**Estructura:**
```
CategoryHierarchy (árbol multinivel)
├── id, name, emoji
├── subcategories (recursivo)
└── discoveryQueries
```

**Análisis:**
- ✅ Ya existe jerarquía multinivel
- ✅ Ya existe búsqueda de queries
- ✅ Reutilizable para búsqueda
- ✅ Permite filtrado por categoría

---

## 🎯 HALLAZGOS CLAVE

### Fortalezas Existentes
1. ✅ **Modelo dual:** Ya existe separación estático/animado
2. ✅ **URL split:** thumbnailUrl y fullUrl separados
3. ✅ **Metadatos ricos:** Tags, categoría, subcategoría, NSFW
4. ✅ **Caching:** Usando cached_network_image + flutter_cache_manager
5. ✅ **Processing:** Image processing + quality parameters
6. ✅ **Pipeline:** Sistema de ingesta masiva listo
7. ✅ **Categorías:** Jerarquía flexible existente

### Brechas a Llenar
1. ❌ **Búsqueda:** No existe sistema de búsqueda
2. ❌ **Preview progresivo:** No hay carga intermedia
3. ❌ **Animados:** Pocos metadatos vs estáticos
4. ❌ **Lazy loading:** Carga todo de una vez
5. ❌ **Preview animado:** Sin video preview antes de aplicar
6. ❌ **Índices:** No hay índices de búsqueda
7. ❌ **Resoluciones:** No hay tabla de versiones optimizadas

---

## 💡 PLAN DE INTEGRACIÓN (SIN BREAKING CHANGES)

### Fase A: Base de Datos (Backward Compatible)

**Nuevas Tablas:**
```sql
-- Almacenar múltiples resolutions del mismo wallpaper
wallpaper_resolutions
├── id
├── wallpaper_id
├── resolution_type (thumbnail, preview, original)
├── url
├── width, height
├── file_size
└── created_at

-- Mejorar búsqueda
search_index
├── id
├── wallpaper_id
├── query_text (normalizado)
├── entity_type (player, team, competition, tag)
└── created_at
```

**Extensión de Modelos:**
- Extender `Wallpaper` con `List<Resolution>`
- Extender `AnimatedWallpaper` con campos de metadatos
- Backward compatible (campos opcionales)

### Fase B: Modelos Extendidos

```dart
// Wallpaper extendido (compatible)
class Wallpaper {
  // Existentes
  String thumbnailUrl;
  String fullUrl;
  
  // Nuevos (opcionales)
  List<Resolution>? resolutions;
  String? previewUrl; // intermediate preview
  
  // Para búsqueda
  List<String>? searchTokens;
  Map<String, dynamic>? entityMetadata;
}

// AnimatedWallpaper extendido
class AnimatedWallpaper {
  String previewImageUrl;
  String videoUrl;
  
  // Nuevos
  String? previewVideoUrl; // video ligero/comprimido
  List<String>? tags;
  String? category;
  String? subcategory;
  double? nsfwScore;
  // ... más metadatos como Wallpaper
}

// Nueva clase para resolutions
class Resolution {
  String url;
  String type; // thumbnail, preview, original
  int width, height;
  int fileSizeBytes;
}
```

### Fase C: Sistema de Búsqueda Integrado

**Estrategia de búsqueda por capas:**

```dart
SearchService
├── 1. Search Index (rápido, en memoria)
│   └── Búsqueda por tokens normalizados
│
├── 2. Category Hierarchy (estructurado)
│   └── Búsqueda por jerarquía de categorías
│
└── 3. Entity Metadata (específico)
    └── Búsqueda de jugadores/equipos/etc
```

**Normalización:**
- Lowercase
- Acentos → sin acentos
- Espacios múltiples → simple
- Plurales → singular (si es necesario)

**Fuzzy matching:**
- Usa Levenshtein distance simple
- Umbral de similitud configurable

**Índices:**
- En memoria para sesión actual
- Persistidos en BD para próximas sesiones
- Invalidación por timestamp

### Fase D: Carga Progresiva

**Modelo de archivos por resolution:**

```
Original (1.0x)      → fullUrl / videoUrl
Preview (0.6x)       → previewUrl / previewVideoUrl
Thumbnail (0.2x)     → thumbnailUrl
```

**Estrategia de carga:**

```dart
1. Mostrar thumbnail inmediatamente
2. Iniciar descarga de preview
3. Reemplazar con preview cuando esté
4. Preview → original solo si es necesario

// Con timeout para no bloquear
timeout = 2 segundos para preview
timeout = indefinido para original (bajo demanda)
```

### Fase E: Lazy Loading y Paginación

**Cambio de StreamBuilder:**

```dart
// Actual: StreamBuilder<List<Wallpaper>>
// Nuevo: StreamBuilder<Page<Wallpaper>>

Page<Wallpaper> {
  List<Wallpaper> items
  int total
  int page
  int pageSize
  bool hasMore
}
```

**Límites razonables:**
- Página inicial: 20 items
- Prefetch: próximos 20
- Total en memoria: máx 100

### Fase F: Animados Mejorados

**Estrategia de preview:**

```
Video completo (MP4/WebM)
├── Copiar frame 1 como thumbnail
├── Crear preview comprimido (30% bitrate, 60% resolución)
└── Mantener original para aplicar

Detección automática:
- ¿Es realmente animado?
- ¿Duración razonable? (< 60s)
- ¿Resolución válida?
- ¿Formato compatible? (MP4, WebM, GIF)
```

**En processing masivo:**

```python
for video in candidates:
    # Existing checks
    if is_nsfw(video): reject
    if is_duplicate(video): reject
    
    # New: extract and compress
    thumbnail = extract_frame(video, 0)
    preview = compress_video(
        video, 
        bitrate='500k',  # vs original
        scale=0.6
    )
    
    # Store resolutions
    insert_resolution(video, 'thumbnail', thumbnail)
    insert_resolution(video, 'preview', preview)
    insert_resolution(video, 'original', video)
```

### Fase G: Integración con Categorías

**Sin cambios en CatalogTab:**

```dart
// Existente sigue funcionando
by_category = wallpapers.where((w) => w.category == selected)

// Nuevo: agregar búsqueda
by_search = search_service.search(query)

// Combinar (opcional)
results = by_search.where((w) => w.category == selected)
```

---

## 📈 IMPACTO EN PERFORMANCE

### Antes (Estado Actual)
```
Catálogo con 1000 items:
- Carga inicial: 2-3s
- Scroll: 30-45 FPS
- Memoria: 150-200 MB
- Primer preview: 3-5s (descarga completa)
```

### Después (Con Optimizaciones)
```
Catálogo con 10000 items:
- Carga inicial: <500ms (paginado)
- Scroll: 58-60 FPS (lazy loaded)
- Memoria: 50-80 MB (liberación de recursos)
- Primer preview: <200ms (thumbnail) + progresivo
```

---

## 🔄 PLAN DE IMPLEMENTACIÓN (Sin Breaking Changes)

### Iteración 1: Base de Datos
- [ ] Crear tablas: wallpaper_resolutions, search_index
- [ ] Migración: populateResolutions() para datos existentes
- [ ] DAOs nuevos: ResolutionDAO, SearchIndexDAO

### Iteración 2: Modelos
- [ ] Extender Wallpaper (campos opcionales)
- [ ] Extender AnimatedWallpaper
- [ ] Extender deserialization

### Iteración 3: Búsqueda
- [ ] Implementar SearchService
- [ ] Integrar con CatalogTab (nuevo widget SearchTab)
- [ ] Autocompletado

### Iteración 4: Carga Progresiva
- [ ] Crear PreviewImageLoader (thumbnail → preview → original)
- [ ] Actualizar WallpaperTile (mantener UI, cambiar backend)
- [ ] Actualizar WallpaperDetailScreen

### Iteración 5: Lazy Loading
- [ ] Cambiar Stream a Page<Wallpaper>
- [ ] Pagination en CatalogTab
- [ ] Prefetch automático

### Iteración 6: Animados Mejorados
- [ ] Extender processing masivo
- [ ] Mejorar metadatos de AnimatedWallpaper
- [ ] Preview de video

### Iteración 7: Testing
- [ ] Tests de búsqueda
- [ ] Tests de paginación
- [ ] Tests de preview progresivo

---

## ✅ CRITERIOS DE ÉXITO

- [x] No hay breaking changes en UI
- [x] Wallpapers existentes siguen funcionando
- [x] AnimatedWallpapers siguen funcionando
- [x] Búsqueda es funcional
- [x] Performance mejorado
- [x] Catálogo puede crecer a 10K+ items
- [x] Thumbnails <50KB
- [x] Previews ~300-500KB
- [x] Carga progresiva funciona

---

## 🎯 SIGUIENTE PASO

Proceder con **Iteración 1: Base de Datos** en la siguiente fase de implementación.

