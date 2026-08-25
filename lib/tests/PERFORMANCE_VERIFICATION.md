# Performance Verification Guide

Esta guía documenta cómo verificar que el sistema de wallpapers expandido cumple con los objetivos de performance.

## Objetivos de Performance

### 1. Frame Rate (FPS)
- **Meta**: Mantener 60 FPS en desplazamiento de grilla
- **Verificación**: 
  - Ejecutar app en device real (no emulator)
  - Abrir CatalogTab con ~1000 items
  - Desplazar rápidamente hacia abajo
  - Verificar en DevTools → Performance que no haya jank (caídas de FPS)

### 2. Uso de Memoria
- **Meta**: < 100MB en memoria en operación normal con 1000 items
- **Componentes**:
  - Buffer de UI: ~20-30 items × ~1-2MB = 20-60MB
  - Cache de imágenes (CachedNetworkImage): ~30-40MB
  - Base de datos en memoria: ~5-10MB
  - Overhead general: ~10MB

- **Verificación**:
  ```bash
  flutter run --profile
  # En DevTools → Memory, capturar snapshots antes/después de cargar items
  # Verificar que memory no sube continuamente (leak)
  ```

### 3. Tiempo de Carga Inicial
- **Meta**: Mostrar primera pantalla en < 2 segundos
- **Verificación**:
  ```bash
  flutter run --profile
  # Medir tiempo desde cold start a primera pantalla visible
  # Esperado: 1-2 segundos
  ```

### 4. Tiempo de Búsqueda
- **Meta**: Completar búsqueda de 10K items en < 500ms
- **Componentes**:
  - Búsqueda en índice: ~50-100ms
  - Obtención de wallpapers por ID: ~200-300ms
  - Filtrado por orientación: ~50ms

- **Verificación**:
  ```dart
  final stopwatch = Stopwatch()..start();
  final results = await searchService.searchFuzzy('test');
  stopwatch.stop();
  print('Search took ${stopwatch.elapsedMilliseconds}ms');
  ```

### 5. Tamaño de Base de Datos
- **Meta**: < 50MB para 10K wallpapers
- **Componentes**:
  - Tabla wallpapers: ~30-40MB (metadata)
  - Tabla search_index: ~10-15MB (índice)
  - Tabla wallpaper_resolutions: ~5-10MB (URLs de variantes)

- **Verificación**:
  ```bash
  # En device, obtener tamaño del archivo DB
  adb shell ls -lah /data/data/com.example.the_project/databases/wallpaper_app.db
  ```

### 6. Carga Progresiva de Imágenes
- **Meta**: Mostrar thumbnail en < 1s, preview en 3-5s, original en 8-15s
- **Verificación**:
  - Abrir WallpaperDetailScreen con conexión 4G lenta
  - Medir tiempo de aparición de cada variante
  - Verificar que thumbnail aparece primero, luego preview, luego original

## Checklist de Verificación

### Búsqueda
- [ ] Búsqueda exacta devuelve resultados en < 100ms
- [ ] Búsqueda fuzzy devuelve resultados en < 500ms
- [ ] Autocomplete sugiere términos en < 50ms
- [ ] Índice de búsqueda tiene ~2-3 entradas por wallpaper
- [ ] Búsqueda por categoría retorna resultados correctos
- [ ] Búsqueda por tags retorna resultados correctos
- [ ] Búsqueda por entidades (jugadores, equipos) funciona

### Paginación
- [ ] Primera página carga sin lag
- [ ] Scroll es fluido (60 FPS)
- [ ] Prefetch de siguiente página ocurre en background
- [ ] No hay saltos visuales al cargar siguiente página
- [ ] Buffer mantiene < 100 items en memoria
- [ ] Desplazamiento a final de lista trabaja correctamente

### Carga Progresiva
- [ ] Thumbnail aparece primero (< 1s)
- [ ] Preview aparece segundop (1-5s)
- [ ] Original aparece tercero (5-15s)
- [ ] Transiciones son suaves
- [ ] Funciona con conexión lenta

### Performance General
- [ ] No hay crashes al cargar 10K items
- [ ] Memoria estable (sin leaks)
- [ ] No hay ANR (Application Not Responding)
- [ ] Database queries son rápidas (< 500ms)
- [ ] Batch processing completa en tiempo razonable

### Escalabilidad
- [ ] Sistema soporta 10K+ items sin degradación
- [ ] Escalable a 50K items (con memory cautions)
- [ ] Search index escala linealmente con items
- [ ] No hay O(n²) operations en UI

## Herramientas de Profiling

### DevTools Performance
```bash
flutter run --profile
# Abrir DevTools → Performance tab
# Grabar trace mientras desplazas
# Analizar frames, buscar jank
```

### Memory Profiling
```bash
flutter run --profile
# Abrir DevTools → Memory tab
# Capturar snapshots: antes, después carga items, después scroll
# Buscar memory leaks (memoria que no se libera)
```

### Database Analysis
```bash
# Obtener archivo DB desde device
adb pull /data/data/com.example.the_project/databases/wallpaper_app.db

# Abrir en SQLite
sqlite3 wallpaper_app.db

# Analizar índices
PRAGMA index_info(idx_search_index_query);
EXPLAIN QUERY PLAN SELECT * FROM search_index WHERE query_text LIKE '%test%';
```

## Resultados Esperados

Después de implementar todas las 8 iteraciones:

- **FPS**: 60 FPS constante al desplazar grilla
- **Memoria**: 60-80MB en operación normal (vs 200MB+ sin optimizaciones)
- **Búsqueda**: 100-500ms para 10K items
- **Carga inicial**: 1-2 segundos a primera pantalla
- **DB size**: 30-50MB para 10K wallpapers
- **Progresiva**: Thumbnail visible casi instantáneamente

## Regresión Testing

Después de cada cambio:

1. Ejecutar tests unitarios
2. Profiling de memory (snapshots before/after)
3. Profiling de performance (trace before/after)
4. Búsqueda manual: verificar resultado es igual

Si hay regresión, investigar:
- ¿Se agregó un nuevo query a un loop?
- ¿Se cambió el tamaño de buffer/cache?
- ¿Se removió una optimización de índice?
