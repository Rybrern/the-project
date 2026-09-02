# Compilar la app sin depender del asistente

## Requisitos (Windows)
- Flutter SDK 3.13+ (ya en `C:\Wallpaper App\flutter`)
- Android SDK (`C:\Users\tomas\AppData\Local\Android\sdk`)
- `android\key.properties` y `android\upload-keystore.jks` existentes (ya configurados)

## Comandos

### 1. Debug rápido (instala en celular conectado)
```powershell
flutter pub get
flutter run --dart-define=WALLHAVEN_API_KEY=tu_key --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJ...
# sin keys también funciona (usa defaults / Wallhaven sin key con rate limit)
flutter run
```

### 2. APK release (para compartir por APK)
```powershell
flutter clean
flutter pub get
flutter build apk --release --obfuscate --split-debug-info=build\symbols --split-per-abi `
  --dart-define=WALLHAVEN_API_KEY=xxx `
  --dart-define=SUPABASE_URL=https://xxx.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=eyJ...

# salida: build\app\outputs\flutter-apk\app-arm64-v8a-release.apk etc.
# o APK universal: flutter build apk --release
```

### 3. AAB para Play Store
```powershell
flutter build appbundle --release --obfuscate --split-debug-info=build\symbols `
  --dart-define=WALLHAVEN_API_KEY=xxx `
  --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
# salida: build\app\outputs\bundle\release\app-release.aab
# subir a Play Console > Producción
```

### 4. Versionado
Edita `pubspec.yaml:19` `version: 1.0.0+3` -> `1.0.1+4` (versionName + versionCode). El `versionCode` debe incrementar siempre para Play Store.

### 5. Firma
`android\key.properties` ya apunta a `upload-keystore.jks`. No commitear estos archivos (están en `.gitignore`). Para CI/CD en GitHub Actions, guardar `key.properties` y `upload-keystore.jks` como secrets y recrearlos en el workflow.

### 6. Verificar que no hay secretos en git
```powershell
git status
git diff --cached
# no debe aparecer google-services.json ni *_config.dart reales
```

### 7. Atajos creados
Si quieres un script: `scripts\build-release.ps1` (ver archivo incluido).
