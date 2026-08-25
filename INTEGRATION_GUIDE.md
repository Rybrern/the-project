# Guía de Integración Completa

## Architectura Final (9 Fases)

```
┌─────────────────────────────────────────────────────────────┐
│                    UI Existente                              │
│  (WallpaperDetailScreen, WallpapersTab, etc.)               │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│            UnifiedWallpaperService                           │
│  (Mantiene compatibilidad, expone nuevas capacidades)       │
└────────────────────┬────────────────────────────────────────┘
                     │
     ┌───────────────┼───────────────┐
     │               │               │
     ▼               ▼               ▼
┌──────────┐   ┌──────────┐   ┌──────────────────┐
│Discovery │   │ Entity   │   │ Cache Manager    │
│Engine    │   │ Discovery│   │ (Sincronización) │
└────┬─────┘   └──────────┘   └──────────────────┘
     │
     ▼
┌─────────────────────────────────────────┐
│         Batch Processor (Pipeline)      │
│  ┌─────────────────────────────────────┐│
│  │ 1. Fetch  2. Download  3. Dedup     ││
│  │ 4. Quality 5. NSFW   6. Classification│
│  │ 7. Storage                          ││
│  └─────────────────────────────────────┘│
└──────────────┬──────────────────────────┘
               │
     ┌─────────┼─────────┐
     ▼         ▼         ▼
┌─────────┐┌──────────┐┌──────────┐
│ Logging ││Admin     ││API       │
│ System  ││Commands  ││Client    │
└─────────┘└──────────┘└──────────┘
     │         │         │
     └─────────┼─────────┘
               ▼
        ┌────────────────┐
        │   SQLite BD    │
        │ (9 tablas)     │
        └────────────────┘
```

---

## Setup Paso a Paso

### 1. Inicializar Base de Datos
```dart
import 'database/app_database.dart';
import 'database/daos/daos.dart';

final db = AppDatabase();
final database = await db.database; // Ejecuta migraciones

// Crear DAOs
final wallpaperDAO = WallpaperDAO(db);
final processingRecordDAO = ProcessingRecordDAO(db);
final hashRegistryDAO = HashRegistryDAO(db);
final rejectedCandidateDAO = RejectedCandidateDAO(db);
final categoryHierarchyDAO = CategoryHierarchyDAO(db);
final ratingDAO = WallpaperRatingDAO(db);
```

### 2. Configurar Providers
```dart
import 'services/providers/providers.dart';

final registry = ProviderRegistry();
registry.initializeDefaults(
  wallhavenApiKey: 'YOUR_WALLHAVEN_KEY',
  pixabayApiKey: 'YOUR_PIXABAY_KEY',
);
```

### 3. Inicializar Discovery Engines
```dart
import 'services/discovery/discovery.dart';
import 'models/default_categories.dart';

final discoveryEngine = DiscoveryEngine(registry: registry);
discoveryEngine.initialize(defaultCategoriesHierarchy);

import 'services/entity_discovery/entity_discovery.dart';
final entityEngine = EntityDiscoveryEngine(registry: registry);
```

### 4. Configurar NSFW Detection
```dart
import 'services/nsfw_detection/nsfw_detection.dart';

final nsfwEngine = NSFWEngine(config: NSFWConfigs.balanced);
nsfwEngine.addDetector(MetadataDetector());
nsfwEngine.addDetector(LocalModelDetector(enabled: true));
await nsfwEngine.initialize();
```

### 5. Inicializar Cache
```dart
import 'services/cache/cache.dart';

final cacheManager = CacheManager(
  processingRecordDAO: processingRecordDAO,
);
```

### 6. Crear Admin Commands
```dart
import 'services/admin/admin_tools.dart';

final batchCommands = BatchCommands(
  discoveryEngine: discoveryEngine,
  wallpaperDAO: wallpaperDAO,
  hashRegistryDAO: hashRegistryDAO,
  processingRecordDAO: processingRecordDAO,
  rejectedCandidateDAO: rejectedCandidateDAO,
  nsfwEngine: nsfwEngine,
);
```

### 7. API Client
```dart
import 'services/api/api.dart';

final apiClient = BatchAPIClient(batchCommands: batchCommands);
```

---

## Flujos de Uso

### A. Usuario Final (UI existente)
```dart
// 1. Busca wallpapers (compatible con UI actual)
final wallpapers = await unifiedService.fetchWallpapers();

// 2. Ve detalles y descarga
// (funcionalidad existente sin cambios)

// 3. NUEVO: Califica el wallpaper
await ratingDAO.rateWallpaper(
  wallpaperId,
  5,
  comment: 'Excelente calidad',
);

// 4. NUEVO: Reporta si hay problemas
await ratingDAO.reportWallpaper(
  wallpaperId,
  reason: 'nsfw',
  description: 'Contiene contenido inapropiado',
);
```

### B. Admin (Ingesta masiva)
```dart
// 1. Verificar caché
if (await cacheManager.needsSync('futbol')) {
  // 2. Procesar categoría
  final report = await batchCommands.processCategory(
    'futbol',
    config: BatchConfigs.balanced,
  );
  
  // 3. Marcar como sincronizado
  cacheManager.markSynced('futbol');
  
  print('Aceptados: ${report.acceptedCount}');
  print('Rechazados: ${report.rejectedCount}');
}
```

### C. Ingesta de Entidades Específicas
```dart
// 1. Buscar solo jugadores de fútbol
final messiWallpapers = await entityEngine.discoverPlayer('messi');

// 2. Procesar todos los jugadores
final allPlayers = await entityEngine.discoverAllPlayers('futbol');

// 3. Guardar en BD
for (final wallpaper in allPlayers) {
  await wallpaperDAO.insert(wallpaper);
}
```

### D. Control Remoto (API)
```dart
// Desde servidor externo
final job = await apiClient.startBatchJob(
  'futbol',
  configProfile: 'balanced',
);

// Monitorear
final status = await apiClient.getJobStatus(job['job_id']);

// Análisis
final analysis = await apiClient.getRejectionAnalysis();
final recommendations = await apiClient.getRecommendations();
```

### E. Análisis y Mejora
```dart
// Obtener estadísticas completas
final stats = await batchCommands.getStats();

// Analizar rechazos
final analysis = await batchCommands.analyzeRejections();

// Obtener recomendaciones
final recommendations = await batchCommands.getRecommendations();

// Ejecutar mantenimiento
final maintenance = await apiClient.runMaintenance();
```

---

## Configuraciones Recomendadas

### Para Desarrollo
```dart
final config = BatchConfigs.conservative.copyWith(
  batchSize: 20,
  maxConcurrentDownloads: 1,
);

final nsfwConfig = NSFWConfigs.permissive;
final cacheMaxAge = Duration(hours: 1);
```

### Para Producción
```dart
final config = BatchConfigs.balanced.copyWith(
  batchSize: 100,
  maxConcurrentDownloads: 3,
  maxNsfwScore: 0.25, // Más estricto
);

final nsfwConfig = NSFWConfigs.balanced;
final cacheMaxAge = Duration(days: 7);
```

### Para Alta Demanda
```dart
final config = BatchConfigs.aggressive.copyWith(
  batchSize: 200,
  maxConcurrentDownloads: 5,
  retryAttempts: 2,
);

final nsfwConfig = NSFWConfigs.permissive;
final cacheMaxAge = Duration(days: 14);
```

---

## Ejemplo Completo Mínimo

```dart
import 'database/app_database.dart';
import 'database/daos/daos.dart';
import 'services/providers/providers.dart';
import 'services/discovery/discovery.dart';
import 'services/batch_processing/batch_processing.dart';
import 'services/nsfw_detection/nsfw_detection.dart';
import 'services/admin/admin_tools.dart';
import 'models/default_categories.dart';
import 'config/wallhaven_config.dart';
import 'config/media_api_config.dart';

Future<void> main() async {
  // 1. Setup
  final db = AppDatabase();
  final wallpaperDAO = WallpaperDAO(db);
  final hashRegistryDAO = HashRegistryDAO(db);
  final processingRecordDAO = ProcessingRecordDAO(db);
  final rejectedCandidateDAO = RejectedCandidateDAO(db);

  final registry = ProviderRegistry();
  registry.initializeDefaults(
    wallhavenApiKey: wallhavenApiKey,
    pixabayApiKey: pixabayApiKey,
  );

  final discoveryEngine = DiscoveryEngine(registry: registry);
  discoveryEngine.initialize(defaultCategoriesHierarchy);

  final nsfwEngine = NSFWEngine(config: NSFWConfigs.balanced);
  nsfwEngine.addDetector(MetadataDetector());
  await nsfwEngine.initialize();

  final batchCommands = BatchCommands(
    discoveryEngine: discoveryEngine,
    wallpaperDAO: wallpaperDAO,
    hashRegistryDAO: hashRegistryDAO,
    processingRecordDAO: processingRecordDAO,
    rejectedCandidateDAO: rejectedCandidateDAO,
    nsfwEngine: nsfwEngine,
  );

  // 2. Ejecutar ingesta
  print('Iniciando ingesta de fondos de fútbol...');
  final report = await batchCommands.processCategory(
    'futbol',
    config: BatchConfigs.balanced,
  );

  // 3. Resultados
  print('Aceptados: ${report.acceptedCount}');
  print('Rechazados: ${report.rejectedCount}');
  print('Tasa: ${(report.acceptanceRate * 100).toStringAsFixed(2)}%');
  print('Tiempo: ${report.duration.inSeconds}s');
}
```

---

## Testing

```dart
import 'package:test/test.dart';

void main() {
  group('Batch Processing', () {
    test('procesa correctamente una categoría', () async {
      // Setup
      final batchCommands = /* ... */;
      
      // Execute
      final report = await batchCommands.processCategory('futbol');
      
      // Assert
      expect(report.acceptedCount, greaterThan(0));
      expect(report.acceptanceRate, greaterThan(0.5));
      expect(report.rejectionRate, lessThan(0.5));
    });

    test('detecta duplicados correctamente', () async {
      // Setup
      final hashRegistry = /* ... */;
      final hash = 'abc123';
      
      // Act
      await hashRegistry.register(
        hash: hash,
        wallpaperId: 'wp1',
        source: 'wallhaven',
      );
      
      // Assert
      final isDuplicate = await hashRegistry.existsHash(hash);
      expect(isDuplicate, true);
    });
  });
}
```

---

## Monitoreo en Producción

```dart
// Ejecutar periódicamente
Future<void> monitoringLoop() async {
  while (true) {
    // Verificar caché
    for (final category in ['futbol', 'motor', 'basquetbol']) {
      if (await cacheManager.needsSync(category)) {
        print('Sincronizando $category...');
        await batchCommands.processCategory(category);
        cacheManager.markSynced(category);
      }
    }

    // Obtener estadísticas
    final stats = await batchCommands.getStats();
    print('Total wallpapers: ${stats['wallpapers']['total']}');

    // Procesar reportes
    final reports = await ratingDAO.getPendingReports();
    print('Reportes pendientes: ${reports.length}');

    // Esperar antes del siguiente ciclo
    await Future.delayed(Duration(hours: 6));
  }
}
```

---

## Migración desde Sistema Anterior

Si hay un sistema existente:

1. **Mantener compatibilidad**: `UnifiedWallpaperService` implementa `WallpaperService`
2. **BD coexiste**: Nuevas tablas no interfieren con existentes
3. **Rollout gradual**:
   - Fase 1: Agregar new code, mantener old funcionando
   - Fase 2: Dirigir nuevas peticiones al nuevo sistema
   - Fase 3: Migrar datos históricos
   - Fase 4: Remover código viejo

---

## Documentación Relacionada

- [BATCH_INGESTION_SYSTEM.md](BATCH_INGESTION_SYSTEM.md) - Sistema de ingesta (Fases 1-5)
- [ADVANCED_FEATURES.md](ADVANCED_FEATURES.md) - Funcionalidades avanzadas (Fases 6-9)
- [lib/services/ingestion_example.dart](lib/services/ingestion_example.dart) - Ejemplos de código

---

**Sistema listo para producción con 9 fases implementadas**
