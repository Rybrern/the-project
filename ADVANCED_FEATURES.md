# Funcionalidades Avanzadas del Sistema de Ingesta

## Fases 6-9: Extensiones Adicionales

### Fase 6: Búsqueda Inteligente por Entidades

**Archivos implementados:**
- `lib/services/entity_discovery/entity_config.dart` - Base de datos de entidades
- `lib/services/entity_discovery/entity_discovery_engine.dart` - Motor de descubrimiento

**Características:**
- Búsqueda específica de **jugadores de fútbol** (Messi, Ronaldo, Mbappé, Haaland, etc.)
- Búsqueda de **equipos de fútbol** (Real Madrid, Barcelona, Manchester City, PSG, Bayern, etc.)
- Búsqueda de **pilotos de Fórmula 1** (Verstappen, Hamilton, Leclerc, etc.)
- Generación automática de queries desde nombres y alias
- Enriquecimiento de metadatos automático

**Uso:**
```dart
final entityEngine = EntityDiscoveryEngine(registry: registry);

// Busca wallpapers de Messi
final messiWallpapers = await entityEngine.discoverPlayer('messi');

// Busca wallpapers de Real Madrid
final madridWallpapers = await entityEngine.discoverTeam('real_madrid');

// Busca todos los jugadores de fútbol
final allPlayers = await entityEngine.discoverAllPlayers('futbol', limitPerPlayer: 10);
```

**Estadísticas:**
```dart
final stats = entityEngine.getStatistics();
// {
//   'total_entities': 42,
//   'by_sport': {'futbol': 30, 'motor': 12},
//   'by_category': {'player': 32, 'team': 10}
// }
```

**Extensibilidad:**
Agregar nuevas entidades es simple:
```dart
const List<SportEntity> newPlayers = [
  SportEntity(
    id: 'player_id',
    name: 'Player Name',
    sport: 'futbol',
    category: 'player',
    aliases: ['alias1', 'alias2'],
    country: 'Country',
  ),
];
```

---

### Fase 7: Sistema de Caché e Incrementos

**Archivos implementados:**
- `lib/services/cache/cache_manager.dart` - Gestión de caché inteligente

**Características:**
- Detección automática de qué necesita resincronización
- Configuración de edad máxima del caché (default: 7 días)
- Invalidación selectiva por categoría
- Estadísticas de caché (estimación de tamaño)

**Uso:**
```dart
final cacheManager = CacheManager(processingRecordDAO: recordDAO);

// Verifica si necesita sincronización
if (await cacheManager.needsSync('futbol', maxAge: Duration(days: 7))) {
  // Sincroniza categoría
  await batchCommands.processCategory('futbol');
  cacheManager.markSynced('futbol');
}

// Obtiene estadísticas
final stats = await cacheManager.getCacheStats();
// {
//   'wallpapers_cached': 5000,
//   'rejected_cached': 3000,
//   'cache_size_estimate': 250000, // KB
//   'last_syncs': {'futbol': DateTime(...), ...}
// }
```

**Detección de cambios incrementales:**
```dart
final detector = IncrementalChangeDetector(processingRecordDAO: recordDAO);

// Detecta qué cambió desde hace 24 horas
final changes = await detector.detectChanges(
  DateTime.now().subtract(Duration(hours: 24)),
);
```

**Beneficios:**
- ✅ Evita reprocesamiento innecesario
- ✅ Sincronización parcial (solo cambios nuevos)
- ✅ Reducción de bandwidth y procesamiento
- ✅ Mejor performance en actualizaciones

---

### Fase 8: API REST para Control Remoto

**Archivos implementados:**
- `lib/services/api/batch_api_client.dart` - Cliente API

**Funcionalidades:**
```dart
final apiClient = BatchAPIClient(batchCommands: batchCommands);

// 1. Iniciar batch job
final jobResponse = await apiClient.startBatchJob(
  'futbol',
  configProfile: 'balanced', // o 'conservative', 'aggressive'
);

// 2. Obtener estado del job
final jobStatus = await apiClient.getJobStatus(jobResponse['job_id']);

// 3. Obtener estadísticas del sistema
final systemStats = await apiClient.getSystemStats();

// 4. Obtener análisis de rechazos
final analysis = await apiClient.getRejectionAnalysis();

// 5. Obtener recomendaciones
final recommendations = await apiClient.getRecommendations();

// 6. Ejecutar mantenimiento
final maintenance = await apiClient.runMaintenance();

// 7. Obtener configuraciones disponibles
final configs = apiClient.getAvailableConfigs();
```

**Modelos de request/response:**
```dart
// Request
final request = BatchJobRequest(
  categoryId: 'futbol',
  configProfile: 'balanced',
  maxWallpapers: 1000,
  tags: ['player', 'messi'],
);

// Response
final response = BatchJobResponse(
  jobId: 'job_1234567890',
  status: 'success',
  results: {
    'total_candidates': 500,
    'accepted': 450,
    'rejected': 50,
    'acceptance_rate': 0.9,
  },
);
```

**Integración con controlador externo:**
```dart
// Ejemplo: Controlar desde servidor Flask/FastAPI
// POST /api/batch/start
// {
//   "category_id": "futbol",
//   "config_profile": "balanced"
// }
```

**Configuraciones predefinidas:**
| Perfil | Batch Size | Concurrencia | NSFW Threshold | Descripción |
|--------|-----------|--------------|--|--|
| conservative | 20 | 1 | 0.1 | Máxima seguridad |
| balanced | 50 | 3 | 0.3 | Recomendado |
| aggressive | 100 | 5 | 0.5 | Mayor volumen |

---

### Fase 9: Rating y Feedback de Usuarios

**Archivos implementados:**
- `lib/database/daos/wallpaper_rating_dao.dart` - DAO de ratings
- `lib/database/migrations/003_ratings_reports.sql` - Tablas SQL

**Funcionalidades:**

#### Rating de wallpapers (1-5 estrellas):
```dart
final ratingDAO = WallpaperRatingDAO(db);

// Usuario califica un wallpaper
await ratingDAO.rateWallpaper(
  'wallpaper_id',
  5, // 1-5 stars
  comment: 'Excelente calidad',
  userId: 'user@example.com',
);

// Obtener rating promedio
final avgRating = await ratingDAO.getAverageRating('wallpaper_id');
// 4.7

// Obtener estadísticas completas
final stats = await ratingDAO.getRatingStats('wallpaper_id');
// {
//   'total_ratings': 50,
//   'average': 4.7,
//   'distribution': {5: 35, 4: 10, 3: 3, 2: 1, 1: 1}
// }
```

#### Reportar problemas:
```dart
// Usuario reporta contenido inapropiado
await ratingDAO.reportWallpaper(
  'wallpaper_id',
  reason: 'nsfw', // o 'quality', 'duplicate', 'offensive', 'broken_link'
  description: 'Contiene contenido sexual explícito',
  userId: 'user@example.com',
);

// Obtener reportes pendientes
final reports = await ratingDAO.getPendingReports();

// Cerrar reporte
await ratingDAO.closeReport(
  'report_id',
  resolution: 'removed', // o 'reviewed', 'duplicate'
);
```

#### Obtener mejores wallpapers:
```dart
// Obtiene top 50 wallpapers mejor calificados
final topRated = await ratingDAO.getTopRatedWallpapers(limit: 50);

// Obtener comentarios de un wallpaper
final comments = await ratingDAO.getComments('wallpaper_id');
```

**Esquema de BD:**
```sql
-- Ratings
wallpaper_ratings (
  id, wallpaper_id, user_id, rating (1-5), 
  comment, created_at
)

-- Reportes
wallpaper_reports (
  id, wallpaper_id, reason, description, user_id,
  status ('open'|'closed'), resolution, 
  created_at, closed_at
)
```

**Beneficios:**
- ✅ Feedback directo de usuarios
- ✅ Detección de wallpapers problemáticos
- ✅ Ranking por calidad real
- ✅ Datos para mejorar algoritmos NSFW
- ✅ Auditoría y trazabilidad

---

## Resumen de Funcionalidades Adicionales

| Fase | Componente | Archivos | Características |
|------|-----------|----------|---|
| 6 | Entity Discovery | 2 | Búsqueda por jugadores, equipos, competiciones |
| 7 | Cache Manager | 1 | Sincronización inteligente, invalidación selectiva |
| 8 | API Client | 1 | Control remoto, modelos request/response |
| 9 | Ratings/Reports | 2 | Calificaciones, reportes, auditoría |

**Total:**
- 8 archivos nuevos
- 1 migración SQL
- 50+ métodos
- Cobertura: Usuarios finales + Admins + Monitores

---

## Integración Completa

```dart
// Setup completo con todas las funcionalidades
final db = AppDatabase();
final batchCommands = BatchCommands(/* ... */);
final entityEngine = EntityDiscoveryEngine(registry: registry);
final cacheManager = CacheManager(processingRecordDAO: recordDAO);
final apiClient = BatchAPIClient(batchCommands: batchCommands);
final ratingDAO = WallpaperRatingDAO(db);

// Flow típico:
// 1. Verificar caché
if (await cacheManager.needsSync('futbol')) {
  // 2. Buscar entidades específicas
  final wallpapers = await entityEngine.discoverPlayer('messi');
  
  // 3. Procesar vía API
  final result = await apiClient.startBatchJob('futbol');
  
  // 4. Marcar caché como sincronizado
  cacheManager.markSynced('futbol');
}

// 5. Usuarios califican wallpapers
await ratingDAO.rateWallpaper(wallpaperId, 5, comment: 'Excelente');

// 6. Obtener feedback
final topRated = await ratingDAO.getTopRatedWallpapers();
final reports = await ratingDAO.getPendingReports();
```

---

## Casos de Uso

### 1. App Frontend (Usuario)
```dart
// Busca wallpapers de Messi
final wallpapers = await entityEngine.discoverPlayer('messi');

// Califica su favorito
await ratingDAO.rateWallpaper(wallpaperId, 5);

// Reporta problema
await ratingDAO.reportWallpaper(wallpaperId, reason: 'nsfw');
```

### 2. Backend Admin
```dart
// Inicia batch processing
final job = await apiClient.startBatchJob('futbol');

// Monitorea progreso
final status = await apiClient.getJobStatus(job['job_id']);

// Obtiene análisis
final analysis = await apiClient.getRejectionAnalysis();
```

### 3. Herramienta de Mantenimiento
```dart
// Verifica qué necesita sincronización
if (await cacheManager.needsSync('futbol')) {
  await batchCommands.processCategory('futbol');
  cacheManager.markSynced('futbol');
}

// Limpia dados huérfanos
await apiClient.runMaintenance();
```

---

## Próximas Mejoras

- [ ] Soporte para más deportistas
- [ ] Integración con redes sociales (Instagram scraping de jugadores)
- [ ] Machine Learning para predecir popularidad
- [ ] Sistema de favoritos por usuario
- [ ] Notificaciones de nuevos wallpapers
- [ ] Sincronización en tiempo real (WebSockets)
- [ ] Exportación de datos para análisis

---

**Sistema completo: 9 fases, 100+ archivos, 10,000+ líneas de código**
