/// Filtro de contenido para el catálogo de fondos animados (Pixabay Video).
/// La API devuelve de todo en sus endpoints de trending y búsqueda,
/// incluyendo clips pensados para reaccionar o compartir en redes que no
/// sirven como fondo de pantalla aunque técnicamente sean un video.
///
/// Criterio: se prioriza contenido decorativo y visualmente atractivo
/// (paisajes, espacio, autos, anime, ciudades, etc.) y se excluye todo lo
/// creado principalmente para comunicar, reaccionar o compartirse en redes
/// sociales (memes, reaction GIFs, stickers, capturas de pantalla, texto con
/// mensaje, contenido de baja resolución).
class WallpaperContentFilter {
  WallpaperContentFilter._();

  static const int minWidth = 360;
  static const int minHeight = 360;

  // Términos que casi siempre delatan un meme, reacción o sticker de chat en
  // vez de contenido decorativo. Se buscan como texto libre dentro de los
  // tags de Pixabay (en inglés).
  static const _blockedKeywords = <String>[
    'meme',
    'memes',
    'reaction',
    'reacting',
    'reacts',
    'funny',
    'lol',
    'lmao',
    'rofl',
    'wtf',
    'omg',
    'fail',
    'facepalm',
    'cringe',
    'mood',
    'sarcastic',
    'sarcasm',
    'thumbs up',
    'thumbs down',
    'thumbsup',
    'thumbsdown',
    'eye roll',
    'eyeroll',
    'side eye',
    'sideeye',
    'applause',
    'clapping',
    'sticker',
    'stickers',
    'screenshot',
    'tweet',
    'texting',
    'chat bubble',
    'when you',
    'when i',
    'me when',
    'me trying',
    'shocked',
    'surprised face',
    'confused face',
    'nope',
    'no way',
    'shut up',
    'oh no',
    'crying laughing',
    'laughing hard',
    'mfw',
    'mrw',
    'still waiting',
    'confused',
    'surprise',
    'wow',
    'hug',
    'hugging',
    'happy dance',
    'upvote',
  ];

  static bool isMemeOrReaction(String? text) {
    if (text == null || text.isEmpty) return false;
    final normalized = text.toLowerCase();
    return _blockedKeywords.any(normalized.contains);
  }

  static bool hasEnoughResolution(int width, int height) =>
      width >= minWidth && height >= minHeight;

  /// `text` es cualquier metadato textual disponible (título o tags) que
  /// pueda delatar contenido de meme/reacción.
  static bool isAppropriateWallpaper({
    required String? text,
    required int width,
    required int height,
  }) {
    if (isMemeOrReaction(text)) return false;
    if (!hasEnoughResolution(width, height)) return false;
    return true;
  }
}
