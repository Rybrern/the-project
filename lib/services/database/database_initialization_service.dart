import '../../database/app_database.dart';
import 'tag_seeding_service.dart';
import 'tag_alias_seeding_service.dart';

/// Servicio para inicializar y popular la base de datos
/// Orquesta el seeding de tags y aliases en el orden correcto
class DatabaseInitializationService {
  final AppDatabase _appDatabase;

  DatabaseInitializationService(this._appDatabase);

  /// Inicializa la base de datos completamente
  /// Ejecuta seeding de tags y aliases si es la primera vez
  /// Safe to call múltiples veces (solo seedea si está vacío)
  Future<void> initialize() async {
    try {
      print('🚀 Iniciando inicialización de base de datos...');

      // Paso 1: Seed tags principales
      final tagSeeding = TagSeedingService(_appDatabase);
      final tagsSeedingDone = await tagSeeding.seed();

      if (!tagsSeedingDone) {
        print('⚠️ Tags ya existen en la BD. Saltando seeding de tags.');
      }

      // Paso 2: Seed aliases (siempre ejecutar si hay tags)
      // En la versión actual, solo seedea si no hay aliases
      final aliasSeeding = TagAliasSeedingService(_appDatabase);
      await aliasSeeding.seed();

      print('✅ Inicialización de base de datos completada');
    } catch (e) {
      print('❌ Error durante inicialización de BD: $e');
      rethrow;
    }
  }
}
