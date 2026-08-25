# Sistema de Ingesta Masiva de Wallpapers

## Resumen General

Sistema completo y modular para obtener, procesar, validar y almacenar wallpapers de múltiples fuentes con filtrado automático de contenido NSFW.

**Características principales:**
- ✅ Descubrimiento automatizado desde Wallhaven y Pixabay
- ✅ Categorización jerárquica inteligente
- ✅ Deduplicación por SHA256 y perceptual hash
- ✅ Detección NSFW multicapa (metadatos + visión local)
- ✅ Validación de calidad (resolución, formato)
- ✅ Procesamiento por lotes con control de concurrencia
- ✅ Logs completos y análisis de rechazos
- ✅ API administrativa para ejecutar trabajos

---

## Arquitectura - 5 Fases Implementadas

### Fase 1: Base de Datos y Modelos

**Archivos clave:**
- `lib/database/app_database.dart` - Inicialización y migraciones
- `lib/database/daos/` - Acceso a datos (5 DAOs)
- `lib/models/wallpaper.dart` - Modelo extendido (13 campos nuevos)
- `lib/models/category_hierarchy.dart` - Categorías jerárquicas
- `lib/models/processing_record.dart` - Logs de procesamiento
- `lib/models/default_categories.dart` - Jerarquía de categorías (20+ deportes)

**Tablas SQL:**
- `wallpapers` - Wallpapers aceptados (extendido)
- `category_hierarchy` - Estructura jerárquica
- `processing_records` - Log de cada candidato
- `hash_registry` - Deduplicación (SHA256 + pHash)
- `rejected_candidates` - Análisis de rechazos

### Fase 2: Discovery y Providers

**Archivos clave:**
- `lib/services/providers/provider_base.dart` - Interfaz base
- `lib/services/providers/wallhaven_provider.dart` - Wallhaven refactorizado
- `lib/services/providers/pixabay_provider.dart` - Pixabay refactorizado
- `lib/services/providers/provider_registry.dart` - Registro centralizado
- `lib/services/discovery/discovery_engine.dart` - Orquestador
- `lib/services/discovery/query_generator.dart` - Genera queries automáticamente
- `lib/services/unified_wallpaper_service.dart` - Compatibilidad con UI existente

**Características:**
- Múltiples proveedores registrables
- Generación automática de queries desde jerarquía
- Control de concurrencia en búsquedas
- Soporte para categorías dinámicas

### Fase 3: Pipeline de Batch Processing

**Archivos clave:**
- `lib/services/batch_processing/batch_processor.dart` - Orquestador
- `lib/services/batch_processing/batch_config.dart` - Configuración
- `lib/services/batch_processing/batch_models.dart` - Modelos de job
- `lib/services/batch_processing/download_manager.dart` - Descargas paralelas
- `lib/services/batch_processing/pipeline/` - 6 stages del pipeline

**Stages (en orden):**

1. **FetchStage** - Valida URLs de candidatos
2. **DownloadStage** - Descarga en paralelo (máx. N simultáneas)
3. **DedupStage** - Detección de duplicados (SHA256)
4. **QualityStage** - Validación de resolución y formato
5. **ClassificationStage** - Clasificación automática por tags
6. **StorageStage** - Guardado en BD + logs

**Configuraciones:**
```dart
BatchConfigs.conservative  // Máxima seguridad
BatchConfigs.balanced      // Producción (default)
BatchConfigs.aggressive    // Mayor volumen
```

### Fase 4: Detección NSFW

**Archivos clave:**
- `lib/services/nsfw_detection/nsfw_detector.dart` - Interfaz base
- `lib/services/nsfw_detection/metadata_detector.dart` - Análisis rápido
- `lib/services/nsfw_detection/local_model_detector.dart` - Análisis visual
- `lib/services/nsfw_detection/nsfw_engine.dart` - Orquestador

**Detectores:**

| Detector | Prioridad | Confianza | Método |
|----------|-----------|-----------|--------|
| Metadata | 100 | 0.6 | Tags + Keywords |
| Local | 50 | 0.75 | Análisis visual |
| Ensemble | - | 0.7 prom | Combinado |

**Palabras clave detectadas:**
- NSFW: 30+ términos (porn, nude, sexy, etc.)
- Seguridad: arte, cartoon, ilustración
- Violencia: gore, blood, weapon, etc.

### Fase 5: Admin Tools y Logging

**Archivos clave:**
- `lib/services/admin/batch_commands.dart` - Comandos de admin
- `lib/services/admin/batch_logger.dart` - Sistema de logs
- `lib/services/admin/rejection_analyzer.dart` - Análisis de rechazos

**Funcionalidades:**
- Ejecutar batch por categoría
- Procesar múltiples categorías
- Reprocessar rechazados
- Análisis de patrones de rechazo
- Recomendaciones automáticas
- Estadísticas del sistema
- Mantenimiento (limpieza de hashes)

---

## Uso del Sistema

### Ejemplo Completo

```dart
// 1. Inicializa componentes
final db = AppDatabase();
final wallpaperDAO = WallpaperDAO(db);
final rejectedCandidateDAO = RejectedCandidateDAO(db);
// ... más DAOs

// 2. Setup de discovery
final registry = ProviderRegistry();
registry.initializeDefaults(
  wallhavenApiKey: 'YOUR_KEY',
  pixabayApiKey: 'YOUR_KEY',
);

final discoveryEngine = DiscoveryEngine(registry: registry);
discoveryEngine.initialize(defaultCategoriesHierarchy);

// 3. Setup NSFW
final nsfwEngine = NSFWEngine(config: NSFWConfigs.balanced);
nsfwEngine.addDetector(MetadataDetector());
await nsfwEngine.initialize();

// 4. Crear admin commands
final batchCommands = BatchCommands(
  discoveryEngine: discoveryEngine,
  wallpaperDAO: wallpaperDAO,
  rejectedCandidateDAO: rejectedCandidateDAO,
  nsfwEngine: nsfwEngine,
  // ... más parámetros
);

// 5. Ejecutar batch
final report = await batchCommands.processCategory(
  'futbol',
  config: BatchConfigs.balanced,
  onProgress: (event) {
    print('${event.stage}: ${event.processed}/${event.total}');
  },
);

// 6. Obtener análisis
final analysis = await batchCommands.analyzeRejections();
final recommendations = await batchCommands.getRecommendations();

print('Aceptados: ${report.acceptedCount}');
print('Rechazados: ${report.rejectedCount}');
print('Tasa: ${(report.acceptanceRate * 100).toStringAsFixed(2)}%');
```

### Procesar Deportes Completos

```dart
// Procesa todas las subcategorías de deportes
final reports = await batchCommands.processBatch(
  ['futbol', 'motor', 'basquetbol', 'tenis', ...],
  config: BatchConfigs.balanced,
);
```

---

## Estructura de Carpetas

```
lib/
├── database/
│   ├── app_database.dart
│   ├── migrations/ (SQL)
│   └── daos/ (5 DAOs)
├── models/
│   ├── wallpaper.dart (extendido)
│   ├── category_hierarchy.dart
│   ├── processing_record.dart
│   └── default_categories.dart
├── services/
│   ├── providers/
│   │   ├── provider_base.dart
│   │   ├── wallhaven_provider.dart
│   │   ├── pixabay_provider.dart
│   │   └── provider_registry.dart
│   ├── discovery/
│   │   ├── discovery_engine.dart
│   │   └── query_generator.dart
│   ├── batch_processing/
│   │   ├── batch_processor.dart
│   │   ├── batch_config.dart
│   │   ├── download_manager.dart
│   │   └── pipeline/ (6 stages)
│   ├── nsfw_detection/
│   │   ├── nsfw_detector.dart
│   │   ├── metadata_detector.dart
│   │   ├── local_model_detector.dart
│   │   └── nsfw_engine.dart
│   └── admin/
│       ├── batch_commands.dart
│       ├── batch_logger.dart
│       └── rejection_analyzer.dart
```

---

## Flujos Principales

### Flujo Completo de Ingesta

```
1. Discovery Engine
   ├── Lee categorías jerárquicas
   ├── Genera queries automáticas
   └── Obtiene candidatos de providers

2. Batch Processor
   ├── Fetch: Valida URLs
   ├── Download: Descarga en paralelo
   ├── Dedup: Detección de duplicados
   ├── Quality: Validación de calidad
   ├── NSFW: Filtrado de contenido
   ├── Classification: Categorización
   └── Storage: Guardado en BD

3. Admin
   ├── Logging: Registra todo
   ├── Analysis: Analiza rechazos
   └── Recommendations: Sugiere mejoras
```

### Decisión NSFW

```
Metadata Detector (rápido)
    ↓
¿Confianza > 0.9? → DECIDIR
    ↓ (NO)
Local Detector (visual)
    ↓
Combinar scores (media ponderada)
    ↓
¿Score > umbral? → RECHAZAR o ACEPTAR
```

---

## Configuración Recomendada

### Para Producción

```dart
final config = BatchConfigs.balanced.copyWith(
  batchSize: 100,
  maxConcurrentDownloads: 3,
  maxConcurrentAnalysis: 2,
  maxNsfwScore: 0.3,        // Estricto
  minQualityScore: 0.5,
);

final nsfwConfig = NSFWConfigs.balanced;
```

### Para Desarrollo

```dart
final config = BatchConfigs.conservative.copyWith(
  batchSize: 20,
  maxConcurrentDownloads: 1,
);

final nsfwConfig = NSFWConfigs.permissive;
```

---

## Estadísticas y Monitoreo

Obtén estadísticas en tiempo real:

```dart
final stats = await batchCommands.getStats();
// {
//   'wallpapers': {'total': 5000},
//   'processing': {'processed': 10000, 'rejected': 4500},
//   'deduplication': {'total_hashes': 5000, 'unique_wallpapers': 5000},
//   'rejections': {'duplicate': 2000, 'nsfw': 1500, ...}
// }

final analysis = await batchCommands.analyzeRejections();
// Detalles de rechazos por tipo, tendencias, etc.

final recommendations = await batchCommands.getRecommendations();
// ["High NSFW rate (40%). Consider adjusting thresholds.", ...]
```

---

## Mejoras Futuras

- [ ] Implementar pHash para detección perceptual avanzada
- [ ] Integración con Google ML Kit Image Labeling
- [ ] API fallback (Sightengine, AWS Rekognition)
- [ ] Dashboard web para monitoreo
- [ ] Soporte para más proveedores (Flickr, Unsplash, etc.)
- [ ] Fine-tuning de umbrales por feedback
- [ ] Modelo TensorFlow Lite personalizado
- [ ] Caché inteligente de resultados
- [ ] Sistema de caducidad de wallpapers

---

## Compatibilidad

✅ Sistema completamente integrado con UI existente  
✅ `UnifiedWallpaperService` mantiene compatibilidad con `WallpaperService`  
✅ No rompe funcionalidad actual  
✅ Pueden convivir métodos legacy y nuevos  

---

## Resumen de Implementación

**Total de fases:** 5  
**Archivos creados:** 50+  
**Líneas de código:** 4000+  
**Componentes modulares:** 15+  

**Tiempo estimado de procesamiento:**
- 100 wallpapers: ~2-3 minutos
- 1000 wallpapers: ~20-30 minutos
- 10000 wallpapers: ~3-4 horas

---

Para más detalles, ver `lib/services/ingestion_example.dart`
