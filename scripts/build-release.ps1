param(
  [string]$WallhavenKey = $env:WALLHAVEN_API_KEY,
  [string]$SupabaseUrl = $env:SUPABASE_URL,
  [string]$SupabaseAnonKey = $env:SUPABASE_ANON_KEY,
  [switch]$Aab
)
$ErrorActionPreference = "Stop"
Write-Host "== pub get ==" -ForegroundColor Cyan
flutter pub get
if ($Aab) {
  Write-Host "== build appbundle ==" -ForegroundColor Cyan
  flutter build appbundle --release --obfuscate --split-debug-info=build/symbols `
    --dart-define=WALLHAVEN_API_KEY=$WallhavenKey `
    --dart-define=SUPABASE_URL=$SupabaseUrl `
    --dart-define=SUPABASE_ANON_KEY=$SupabaseAnonKey
  Write-Host "AAB en build/app/outputs/bundle/release/app-release.aab" -ForegroundColor Green
} else {
  Write-Host "== build apk split-per-abi ==" -ForegroundColor Cyan
  flutter build apk --release --obfuscate --split-debug-info=build/symbols --split-per-abi `
    --dart-define=WALLHAVEN_API_KEY=$WallhavenKey `
    --dart-define=SUPABASE_URL=$SupabaseUrl `
    --dart-define=SUPABASE_ANON_KEY=$SupabaseAnonKey
  Write-Host "APKs en build/app/outputs/flutter-apk/" -ForegroundColor Green
}
