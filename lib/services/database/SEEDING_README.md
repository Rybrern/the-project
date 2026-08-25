# Database Seeding - Tag System

Este documento explica cómo initializar la base de datos con tags y aliases después de crear las migraciones.

## Migraciones Creadas

- **Migration 006**: Crea tablas `tags`, `tag_aliases`, `tag_relations`, `image_tags`, `tag_types`

## Servicios de Seeding

### 1. TagSeedingService
Crea los tags base:
- Tags de categorías (desde defaultCategoriesHierarchy)
- Tags de deportes y subcategorías
- Tags de equipos principales
- Tags genéricos (estilos, géneros, conceptos)
- Relaciones iniciales entre tags

**Llamar una sola vez**

### 2. TagAliasSeedingService
Crea aliases (variaciones de búsqueda):
- "messi" → "leo messi" → "lionel messi" → todos apuntan al mismo tag
- "f1" → "formula 1" → "formula one" → mismo tag
- "man city" → "manchester city" → mismo tag

**Puede llamarse múltiples veces** (evita duplicados automáticamente)

### 3. DatabaseInitializationService
Orquestador que llama los dos servicios en orden

## Cómo Usar

### Opción A: Desde main()

```dart
import 'package:the_project/database/app_database.dart';
import 'package:the_project/services/database/database_initialization_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar base de datos
  final appDb = AppDatabase();
  final initService = DatabaseInitializationService(appDb);
  await initService.initialize();
  
  runApp(const MyApp());
}
```

### Opción B: Desde una pantalla de splash

```dart
class SplashScreen extends StatefulWidget {
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      final appDb = AppDatabase();
      final initService = DatabaseInitializationService(appDb);
      await initService.initialize();
      
      // Navegar a pantalla principal
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      print('Error inicializando: $e');
      // Mostrar error al usuario
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Inicializando base de datos...'),
          ],
        ),
      ),
    );
  }
}
```

### Opción C: Con logging real

Si quieres reemplazar los `print` statements con logging real:

```dart
import 'package:logger/logger.dart';

final logger = Logger();

// En TagSeedingService:
logger.i('Creando tags de categorías...');
logger.d('Total de tags creados: $finalCount');
logger.e('Error durante seeding', error: e);
```

## Qué se Crea

### Tags Iniciales
- ~30 tags de categorías
- ~20 tags de deportes y competiciones
- ~17 tags de equipos
- ~9 tags de países
- ~15 tags genéricos (estilos, géneros, conceptos)
- **Total: ~91 tags base**

### Aliases Iniciales
- ~50 aliases para búsqueda (variaciones de nombres)
- **Fácilmente extensible** agregando más en TagAliasSeedingService

### Relaciones
- Relaciones iniciales: Team → Sport, Team → Country, etc.
- **Estructura lista para expansión**

## Características de Seguridad

✅ **Idempotente**: Llamar initialize() múltiples veces es seguro
✅ **Evita duplicados**: Verifica si ya existen tags antes de insertar
✅ **Transaccional**: Usa batch operations para integridad
✅ **Loggeable**: Print statements para debugging (reemplazar con logger en prod)

## Próximos Pasos

1. **Fase 3**: Integrar seeding en la app
2. **Fase 4**: Crear script para agregar más tags/aliases
3. **Fase 5**: Integrar análisis visual para auto-tagging

## Datos Precargados

Los 21 tipos de tags se precarga automáticamente desde `tag_types` en la migración 006:

```
PERSON, TEAM, SPORT, COMPETITION, FRANCHISE, CHARACTER,
GAME, MOVIE, TV_SHOW, ANIME, COUNTRY, CITY, PLACE,
VEHICLE, BRAND, ANIMAL, GENRE, STYLE, COLOR, THEME, CONCEPT
```

Estos se pueden validar contra cualquier nuevo tag que se cree.

## Troubleshooting

### "Base de datos de tags ya poblada"
Normal. El seeding solo corre si está vacío.
Para resetear: `AppDatabase().reset()`

### Algunos tags no tienen aliases
Es normal. Se pueden agregar manualmente vía el DAO:
```dart
final aliasDAO = TagAliasDAO(appDb);
await aliasDAO.insert(TagAlias(...));
```

### Aliases no funcionan en búsqueda
Verifica que SearchService esté usando TagAliasDAO.resolveAlias()
