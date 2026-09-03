import 'dart:math';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

class WallpaperUploadException implements Exception {
  WallpaperUploadException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Sube un fondo elegido por el usuario a Supabase (Storage + fila en
/// `wallpapers` con `is_published: false`), para que quede pendiente de
/// moderación en el panel admin (`web-admin/app/admin/pendientes`).
///
/// Nunca usa la `service_role key` — solo el cliente `anon` ya configurado
/// en toda la app (`supabase_flutter`), acotado por la policy RLS
/// `"anon can submit pending"` (ver `supabase/schema.sql`): solo puede
/// insertar filas propias no publicadas.
class WallpaperUploadService {
  static const _minShortSide = 1080;
  static const _minLongSide = 1920;

  final ImagePicker _picker = ImagePicker();

  Future<XFile?> pickImage() {
    return _picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
  }

  /// Devuelve el id de usuario emitido por Supabase, creando una sesión
  /// anónima la primera vez. `supabase_flutter` persiste la sesión, así que
  /// el mismo dispositivo conserva su id entre reinicios.
  ///
  /// Reemplaza al identificador que antes generaba el propio cliente: ese
  /// viajaba en el cuerpo del request y podía inventarse en cada envío,
  /// dejando inútil el tope de pendientes. Este viene firmado dentro del JWT.
  Future<String> _requireUserId() async {
    final auth = Supabase.instance.client.auth;
    final existing = auth.currentSession?.user.id;
    if (existing != null) return existing;

    try {
      final res = await auth.signInAnonymously();
      final id = res.user?.id;
      if (id == null) throw WallpaperUploadException('No se pudo iniciar la sesión.');
      return id;
    } on AuthException catch (e) {
      throw WallpaperUploadException(
        e.message.toLowerCase().contains('disabled')
            ? 'La subida no está habilitada en este momento.'
            : 'No se pudo iniciar la sesión para subir el fondo.',
      );
    }
  }

  Future<void> submit({
    required XFile image,
    required String category,
    required List<String> tags,
  }) async {
    if (!isSupabaseConfigured) {
      throw WallpaperUploadException('La subida no está disponible en este momento.');
    }

    final bytes = await image.readAsBytes();
    if (bytes.length > 25 * 1024 * 1024) {
      throw WallpaperUploadException('La imagen es demasiado grande (máx. 25MB).');
    }

    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw WallpaperUploadException('No se pudo leer la imagen elegida.');
    }
    final shortSide = min(decoded.width, decoded.height);
    final longSide = max(decoded.width, decoded.height);
    if (shortSide < _minShortSide || longSide < _minLongSide) {
      throw WallpaperUploadException(
        'La imagen es de baja resolución (mínimo Full HD) y se vería pixelada como fondo.',
      );
    }

    final userId = await _requireUserId();
    final id = _generateId('user');
    // La carpeta debe ser exactamente auth.uid(): la policy de Storage
    // compara el segundo segmento de la ruta contra el id del JWT.
    final storagePath = 'user-submitted/$userId/$id.jpg';

    final storage = Supabase.instance.client.storage.from('wallpapers');
    try {
      await storage.uploadBinary(
        storagePath,
        bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );
    } catch (_) {
      throw WallpaperUploadException('No se pudo subir la imagen. Probá de nuevo.');
    }
    final publicUrl = storage.getPublicUrl(storagePath);

    try {
      await Supabase.instance.client.from('wallpapers').insert({
        'id': id,
        'full_url': publicUrl,
        'thumbnail_url': publicUrl,
        'category': category,
        'tags': tags,
        'author': 'Usuario',
        'source': 'user',
        'device_id': userId,
        'is_published': false,
        'width': decoded.width,
        'height': decoded.height,
        'file_type': 'image/jpeg',
      });
    } on PostgrestException catch (e) {
      // El trigger de límite de pendientes lanza una excepción de Postgres
      // que llega acá — es el único caso esperable de rechazo legítimo.
      throw WallpaperUploadException(
        e.message.contains('Demasiados fondos pendientes')
            ? 'Ya tenés fondos esperando moderación. Esperá a que se revisen antes de subir más.'
            : 'No se pudo enviar el fondo a moderación.',
      );
    } catch (_) {
      throw WallpaperUploadException('No se pudo enviar el fondo a moderación.');
    }
  }

  /// Id único no-criptográfico — mismo nivel de unicidad que ya usa
  /// `web-admin/app/admin/page.tsx` para sus propios ids (timestamp +
  /// sufijo aleatorio). No hace falta un paquete de UUID para esto.
  String _generateId(String prefix) {
    final random = Random();
    final suffix = List.generate(8, (_) => random.nextInt(36).toRadixString(36)).join();
    return '${prefix}_${DateTime.now().millisecondsSinceEpoch}_$suffix';
  }
}
