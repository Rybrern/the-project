import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/wallpaper.dart';

/// Fondos de la biblioteca pública de imágenes de la NASA
/// (https://images.nasa.gov). Alimenta la categoría "espacio".
///
/// A diferencia de los bancos de fotos comerciales (Pexels, Unsplash,
/// Pixabay), cuyos términos de API prohíben expresamente las apps de fondos
/// de pantalla, el material de la NASA es de dominio público y puede
/// redistribuirse, incluso comercialmente. Las condiciones que sí aplican:
/// no usar los logos de la NASA (insignia, logotipo, sello) y no dar a
/// entender que la NASA respalda la app — por eso el autor se acredita como
/// texto plano y no se incorpora ninguna marca gráfica.
///
/// No requiere API key. El límite de uso es por IP del dispositivo, como
/// Wallhaven, así que no se agota de forma compartida entre usuarios.
class NasaWallpaperService {
  static const _searchUrl = 'https://images-api.nasa.gov/search';

  /// Consultas astronómicas puras. Se descartaron dos que parecían obvias:
  /// "launch" traía casi solo operaciones en tierra (plataformas, ensamblaje,
  /// competencias estudiantiles) y "deep field" rendía 16 de 100 por venir
  /// mayormente de gráficas de conferencias de la sede central.
  static const _queries = [
    'nebula',
    'galaxy',
    'supernova',
    'star cluster',
    'saturn',
    'aurora',
  ];

  /// Centros cuyo material es imagen astronómica real, medido sobre 600
  /// resultados: JPL y GSFC (laboratorios de ciencia planetaria y
  /// astrofísica) rinden entre 82% y 100% de fotografía del espacio.
  ///
  /// Quedan fuera a propósito: KSC y MAF entregan hardware en banco de
  /// pruebas e instalaciones de ensamblaje, HQ entrega gráficas de
  /// conferencias y actos, y JSC/MSFC mezclan observación real con montajes
  /// de laboratorio y fotos protocolares.
  static const _scienceCenters = {'JPL', 'GSFC'};

  /// Descarte fino dentro de los centros científicos, para las pocas fotos
  /// de personas o de laboratorio que igual aparecen.
  ///
  /// La lista es deliberadamente corta y literal: probar con términos más
  /// amplios descartaba imágenes legítimas, porque la NASA titula el
  /// material astronómico con lenguaje figurado — "Portrait of a Galaxy
  /// Life" y "Spitzer Celebrates Fourth Anniversary" son fotos del espacio.
  static const _groundTerms = [
    'administrator',
    'ceremony',
    'briefing',
    'press conference',
    'employee',
    'award',
    'workshop',
    'technician',
    'cleanroom',
    'clean room',
    'work stand',
    'test stand',
    'groundbreaking',
    'town hall',
    'interview',
  ];

  /// Máximo que acepta la API por página.
  static const _pageSize = 100;

  /// Trae fondos verticales de la categoría espacio. Si una consulta falla,
  /// se descarta sola sin arrastrar al resto — mismo criterio que
  /// `WallhavenWallpaperService`.
  Future<List<Wallpaper>> fetchSpaceWallpapers() async {
    final results = await Future.wait(_queries.map(_fetchForQuery));
    final wallpapers = results.expand((list) => list).toList();

    // Un mismo objeto celeste aparece en varias consultas ("nebula" y
    // "galaxy" comparten resultados), así que se deduplica por id.
    final seen = <String>{};
    return wallpapers.where((w) => seen.add(w.id)).toList();
  }

  Future<List<Wallpaper>> _fetchForQuery(String query) async {
    try {
      final uri = Uri.parse(_searchUrl).replace(queryParameters: {
        'q': query,
        'media_type': 'image',
        'page_size': '$_pageSize',
      });

      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('NASA devolvió ${response.statusCode} para "$query"');
      }
      if (response.bodyBytes.length > 4 * 1024 * 1024) {
        throw Exception('Respuesta NASA demasiado grande');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final collection = body['collection'] as Map<String, dynamic>?;
      final items = (collection?['items'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();

      return items.map(_mapItem).whereType<Wallpaper>().toList();
    } on TimeoutException {
      debugPrint('NasaWallpaperService: timeout para "$query"');
      return const [];
    } catch (error) {
      debugPrint('NasaWallpaperService: falló "$query": $error');
      return const [];
    }
  }

  /// Distingue fotografía astronómica del resto del archivo de la NASA, que
  /// mezcla documentos, instalaciones, hardware de laboratorio y actos
  /// institucionales con las imágenes del espacio.
  ///
  /// El campo `center` resultó ser la señal decisiva — mucho más confiable
  /// que buscar palabras en el título, porque el criterio no depende de cómo
  /// esté redactado sino de qué centro produjo el material.
  bool _isSpaceImagery(Map<String, dynamic> data) {
    final center = (data['center'] as String?)?.trim().toUpperCase();
    if (center == null || !_scienceCenters.contains(center)) return false;

    final haystack = [
      data['title'] as String? ?? '',
      data['description'] as String? ?? '',
    ].join(' ').toLowerCase();
    return !_groundTerms.any(haystack.contains);
  }

  Wallpaper? _mapItem(Map<String, dynamic> item) {
    final data = (item['data'] as List<dynamic>?)?.firstOrNull as Map<String, dynamic>?;
    final links = (item['links'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    if (data == null || links.isEmpty) return null;

    final nasaId = data['nasa_id'] as String?;
    if (nasaId == null || nasaId.isEmpty) return null;

    if (!_isSpaceImagery(data)) return null;

    // La variante más grande con dimensiones declaradas: sirve de miniatura y
    // da la proporción real, que se conserva en la original.
    Map<String, dynamic>? best;
    for (final link in links) {
      if (link['render'] != 'image') continue;
      final w = (link['width'] as num?)?.toInt();
      final h = (link['height'] as num?)?.toInt();
      if (w == null || h == null || w <= 0 || h <= 0) continue;
      final bestW = (best?['width'] as num?)?.toInt() ?? 0;
      if (w > bestW) best = link;
    }
    if (best == null) return null;

    final width = (best['width'] as num).toInt();
    final height = (best['height'] as num).toInt();

    // Solo vertical: es una app de fondos de teléfono, y apenas ~20% del
    // material de la NASA lo es. Dejar pasar las panorámicas llenaría la
    // categoría de imágenes que solo se ven recortadas.
    if (height <= width) return null;

    final thumbnailUrl = best['href'] as String?;
    if (thumbnailUrl == null) return null;

    final keywords = (data['keywords'] as List<dynamic>?)
        ?.map((k) => k as String?)
        .whereType<String>()
        .take(15)
        .toList();

    return Wallpaper(
      id: 'nasa_$nasaId',
      thumbnailUrl: thumbnailUrl,
      // La original no viene listada en la búsqueda, pero el nombrado de los
      // assets es consistente (`<nasa_id>~orig.jpg`) y es la única variante
      // con resolución de fondo de pantalla; las listadas llegan hasta 1280px.
      fullUrl: 'https://images-assets.nasa.gov/image/$nasaId/$nasaId~orig.jpg',
      author: data['secondary_creator'] as String? ?? 'NASA',
      category: 'espacio',
      aspectRatio: width / height,
      source: 'nasa',
      sourceId: nasaId,
      originalUrl: 'https://images.nasa.gov/details/$nasaId',
      tags: keywords,
      fileType: 'image/jpeg',
      // Sin width/height ni qualityScore: la búsqueda solo informa las
      // medidas de las variantes reducidas, no las de la original que se
      // sirve. Declararlas sería inventar el dato. El nulo hereda el 0.8
      // (Full HD) que ya asume `filterByQuality`, criterio razonable para
      // originales de la NASA, que practicamente siempre lo superan.
      previewUrl: thumbnailUrl,
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
