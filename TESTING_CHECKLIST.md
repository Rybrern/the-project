# Testing Checklist - Wallpaper App with 5 Providers

## Pre-Testing
- [ ] App instalada correctamente en dispositivo
- [ ] Dispositivo conectado a internet
- [ ] Espacio libre en dispositivo (>500MB)

## 1. App Launch & Basic Functionality
- [ ] App inicia sin crashes
- [ ] Pantalla principal carga correctamente
- [ ] Todos los tabs visibles: Home, Search, Favorites, Settings
- [ ] Navegación entre tabs funciona suavemente

## 2. Provider Functionality (5 Providers)

### OpenVerse (CC0 Images - 700M+)
- [ ] Búsqueda: "nature" retorna resultados
- [ ] Búsqueda: "landscape" retorna imágenes
- [ ] Búsqueda: "animals" retorna resultados variados
- [ ] Sin autenticación requerida
- [ ] Imágenes cargan correctamente

### Unsplash (Premium Photos - 4.5M)
- [ ] Búsqueda: "city" retorna fotos de alta calidad
- [ ] Búsqueda: "people" retorna retratos
- [ ] Metadatos: Fotógrafo visible
- [ ] Metadatos: Ubicación visible cuando aplique
- [ ] Imágenes >2048px dan boost de popularidad

### GIPHY (GIFs - 700M+)
- [ ] Búsqueda: "dance" retorna GIFs animados
- [ ] Búsqueda: "celebration" retorna animaciones
- [ ] NSFW filtering: "adult" NO retorna contenido explícito
- [ ] Soporte MP4 cuando disponible
- [ ] Animaciones reproducen correctamente

### Wallhaven (Specialty - 1M+)
- [ ] Búsqueda: "abstract" retorna wallpapers especializados
- [ ] Búsqueda: "minimalist" retorna diseños limpios
- [ ] Resoluciones altas disponibles
- [ ] Carga sin errores

### Pixabay (Libre de derechos - 4M+)
- [ ] Búsqueda: "sunset" retorna fotos
- [ ] Búsqueda: "flowers" retorna imágenes coloridas
- [ ] Categorización correcta
- [ ] Carga rápida

## 3. Search Features
- [ ] **Búsqueda Exacta**: Escribir "lion" encuentra "lion"
- [ ] **Búsqueda Fuzzy**: Escribir "laion" encuentra "lion" (tolera typos)
- [ ] **Búsqueda Parcial**: "land" encuentra "landscape"
- [ ] **Tag Normalization**: "Messi", "messi", "MESSI" dan mismo resultado
- [ ] **Tag Aliases**: "F1" resuelve a "Formula 1"
- [ ] **Autocompletar**: Sugerencias aparecen al escribir
- [ ] **Búsqueda Multi-palabra**: "sunset beach" retorna resultados relevantes
- [ ] **Búsqueda vacía**: Muestra categorías populares

## 4. Ranking & Quality
- [ ] Resultados ordenados por relevancia (mejor primero)
- [ ] Unsplash results tienen boost en ranking
- [ ] GIPHY results tienen menor boost que Unsplash
- [ ] Imágenes recientes obtienen pequeño boost
- [ ] Imágenes de alta resolución ranking más alto

## 5. NSFW Filtering
- [ ] Búsqueda: "explicit" NO retorna contenido inapropiado
- [ ] Búsqueda: "adult" NO retorna contenido inapropiado
- [ ] Búsqueda: "family" retorna contenido apropiado
- [ ] Búsqueda: "kids" retorna solo contenido apropiado
- [ ] Rating score visible en metadata cuando aplique

## 6. Tag System (Phase 4)
- [ ] Tags normalizados en formato "kebab-case"
- [ ] Entity detection: "Lionel Messi" detecta PERSON
- [ ] Entity detection: "Barcelona" detecta TEAM/LOCATION
- [ ] Entity detection: "sunset" detecta THEME
- [ ] Confianza mostrada en UI: API=100%, Inferred=80%, Fuzzy=50%
- [ ] Tags relacionados sugeridos en búsqueda

## 7. Duplicate Detection (Phase 2)
- [ ] Imágenes idénticas NO aparecen dos veces en resultados
- [ ] Imágenes muy similares detectadas (pHash)
- [ ] SHA256 exact match funciona correctamente
- [ ] Hamming distance <1% para duplicados visuales

## 8. Performance
- [ ] Búsqueda: Resultados en <500ms
- [ ] Scroll: 60 FPS sin lag
- [ ] Carga de imágenes: <2s por imagen
- [ ] Memoria: App usa <500MB
- [ ] CPU: Bajo consumo en reposo

## 9. UI/UX
- [ ] Grid layout responde bien a orientación
- [ ] Imágenes aspect ratio correcto
- [ ] Botón set as wallpaper funciona
- [ ] Thumbnail quality aceptable
- [ ] Preview quality bueno
- [ ] Final resolution alta calidad

## 10. Error Handling
- [ ] Red desconectada: Mensaje amable
- [ ] API down: Fallback a caché
- [ ] Imagen corrupta: Error manejado gracefully
- [ ] Rate limiting: Backoff automático
- [ ] Sin resultados: Mensaje útil

## 11. Features Originales (Regresión)
- [ ] Home tab: Wallpapers populares cargan
- [ ] Favorites: Agregar/quitar favorito funciona
- [ ] Settings: Cambios se guardan
- [ ] Orientación preference funciona
- [ ] Aspect ratio filter funciona

## 12. Database & Caching
- [ ] Tags se guardan en base de datos
- [ ] Search index se construye correctamente
- [ ] Caché de búsquedas recientes funciona
- [ ] Estadísticas se registran

## Critical Issues to Report
- [ ] App crashes
- [ ] Búsqueda sin resultados cuando debería haber
- [ ] NSFW content visible
- [ ] Rate limiting bloqueando búsquedas
- [ ] Performance <1s para búsquedas simples

## Session Summary
**Date**: 2026-08-25
**Tester**: User
**Device**: Android 13 (API 33)
**Build**: app-release.apk (59.2MB)
**Status**: [ ] PASS | [ ] FAIL | [ ] PARTIAL

**Issues Found**:
(List any problems encountered)

**Overall Assessment**:
- [ ] Ready for Production
- [ ] Minor Fixes Needed
- [ ] Major Fixes Required
