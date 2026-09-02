# Catálogo Manual — Guía para cargar fondos via links

Esta implementación permite que subas fondos manualmente sin depender solo de Wallhaven, manteniendo el filtro de calidad.

## Opción implementada (activa en `test-1`): Asset JSON local

**Archivos:**
- `assets/manual_catalog.json` — catálogo real (ignorado si vacío)
- `assets/manual_catalog.example.json` — ejemplo
- `lib/services/manual_catalog_service.dart` — loader + validación
- `lib/services/hybrid_wallpaper_service.dart` — fusiona Wallhaven + manual

**Cómo agregar un fondo:**
1. Subí la imagen a un host con link directo `https://`:
   - **Recomendados testeo:** Imgur (direct link `i.imgur.com/...jpg`), Catbox (`files.catbox.moe/...`), Firebase Storage, Cloudinary, tu VPS con nginx.
   - Debe permitir CORS y terminar en `.jpg/.png/.webp` (no `.gif` — filtrado por calidad).
   - Resolución mínima **1920x1080** (lado corto >=1080). Si es menor, se descarta automáticamente para evitar pixelado en pantalla completa.

2. Editá `assets/manual_catalog.json`:
```json
{
  "id": "manual_002",
  "fullUrl": "https://i.imgur.com/TU_IMAGEN_4K.jpg",
  "thumbnailUrl": "https://i.imgur.com/TU_IMAGEN_400.jpg",
  "category": "naturaleza",
  "author": "Vos",
  "tags": ["nature", "mountain", "4k"],
  "width": 3840,
  "height": 2160
}
```
`category` debe ser uno de `lib/services/wallpaper_service.dart:18` (naturaleza, abstracto, espacio, minimalista, arquitectura, animales, oscuro, arte, tablets).

3. `flutter pub get && flutter run` — aparece arriba en la grilla con badge "Manual".

**Validaciones automáticas:**
- Rechaza `http://` (solo https), `.gif`, resoluciones <1080p.
- Deduplica por `fullUrl`.

## Opciones a futuro (asesoría)

### A) Firebase Remote Config / Firestore (recomendado para producción sin update de APK)
- Crear colección `manual_wallpapers` en Firestore:
  `id, fullUrl, thumbnailUrl, category, tags[], width, height, createdAt`
- Cambiar `ManualCatalogService` para leer de Firestore en vez de asset:
  ```dart
  FirebaseFirestore.instance.collection('manual_wallpapers').get()
  ```
- **Panel admin:** Firebase Console o simple página web con form para pegar link → valida → `addDoc()`. Sin necesidad de recompilar app. Costo mínimo, updates instantáneos.

### B) Google Sheet + Apps Script (no-code para vos)
- Sheet con columnas `id|fullUrl|tags|category` → publicar como JSON via Apps Script → app hace `http.get(sheetJsonUrl)`.
- Muy rápido para cargar 50+ links copiando filas.

### C) Admin interno en la app (solo para tu device)
- Agregar `AdminManualUploadScreen` protegida por PIN, con `TextField` para pegar URL + `head` request para verificar `content-type: image/*` y `content-length`.
- Guarda en `SharedPreferences` o `sqflite` local. Útil para pruebas rápidas en el celular.

### D) Pipeline completo (como `test-4` branch)
- `test-4` ya tiene `functions/src/ingest.js` + providers (Pixabay, OpenVerse) + batch processing con `quality_stage`, `nsfw_stage`, `perceptual_hash` deduplication. Si el catálogo crece a +1000 imágenes, conviene migrar a ese pipeline.

## Tags oficiales de Wallhaven

Ya indexados en `Wallpaper.tags` (`lib/models/wallpaper.dart:33`) y parseados en `wallhaven_wallpaper_service.dart:122-125`:
```dart
tags = (item['tags'] as List)?.map((t) => t['name']).toList()
```
Se muestran en `wallpaper_detail_screen.dart` como Chips y están disponibles para búsqueda:
```dart
wallpaper.searchTokens // tags + category lowercased
```
Puedes filtrar futuro `CatalogTab` con `where((w) => w.searchTokens.contains(query.toLowerCase()))`.

## Filtro de baja calidad Giphy eliminado

- Wallhaven query ahora incluye `atleast=1920x1080` server-side.
- Client-side `_isHighQuality` rechaza `file_type gif`, `<1080p` lado corto, `<300KB`.
- `ManualCatalogService` aplica misma regla. No hay provider Giphy activo en `test-1`; si se re-agrega, deberá pasar por el mismo filtro o mover a `AnimatedWallpaper` separado (como en `test-4`).

## Próximos pasos sugeridos
1. Probar con 2-3 links reales en `manual_catalog.json`.
2. Si funciona, migrar a Firestore (opción A) para no requerir update de Play Store cada vez.
3. Agregar búsqueda por tags en `CatalogTab` usando `searchTokens`.
