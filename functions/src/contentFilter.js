// Puerto de lib/utils/wallpaper_content_filter.dart: descarta memes,
// reaction GIFs/stickers y contenido de baja resolución.
const MIN_WIDTH = 360;
const MIN_HEIGHT = 360;

const BLOCKED_KEYWORDS = [
  'meme', 'memes', 'reaction', 'reacting', 'reacts', 'funny', 'lol', 'lmao',
  'rofl', 'wtf', 'omg', 'fail', 'facepalm', 'cringe', 'mood', 'sarcastic',
  'sarcasm', 'thumbs up', 'thumbs down', 'thumbsup', 'thumbsdown',
  'eye roll', 'eyeroll', 'side eye', 'sideeye', 'applause', 'clapping',
  'sticker', 'stickers', 'screenshot', 'tweet', 'texting', 'chat bubble',
  'when you', 'when i', 'me when', 'me trying', 'shocked', 'surprised face',
  'confused face', 'nope', 'no way', 'shut up', 'oh no', 'crying laughing',
  'laughing hard', 'mfw', 'mrw', 'still waiting', 'confused', 'surprise',
  'wow', 'hug', 'hugging', 'happy dance', 'upvote',
];

// Términos que delatan contenido fetish/inapropiado que se coló en
// resultados de búsquedas de nombres propios (ej. OpenVerse devolviendo
// fotos de Flickr sin relación real con la query, solo por matching débil
// de texto libre). No es un filtro NSFW completo — es una lista acotada
// de señales inequívocas para bloquear en el pipeline de ingesta.
const INAPPROPRIATE_KEYWORDS = [
  'diaper', 'diapers', 'humiliat', 'fetish', 'kink', 'ageplay', 'ddlg',
  'scat', 'watersports', 'bondage', 'bdsm',
];

function isMemeOrReaction(text) {
  if (!text) return false;
  const normalized = text.toLowerCase();
  return BLOCKED_KEYWORDS.some((kw) => normalized.includes(kw));
}

function isInappropriate(text) {
  if (!text) return false;
  const normalized = text.toLowerCase();
  return INAPPROPRIATE_KEYWORDS.some((kw) => normalized.includes(kw));
}

function hasEnoughResolution(width, height) {
  return width >= MIN_WIDTH && height >= MIN_HEIGHT;
}

// Formatos que el decoder de imágenes de Flutter (cached_network_image /
// Image.network) puede pintar. SVG, PDF y similares (comunes en Wikimedia
// Commons vía OpenVerse: mapas de circuitos, diagramas) descargan bien pero
// fallan al decodificar como bitmap — el tile queda con el ícono de "imagen
// rota" sin que medie ningún problema de red.
const RASTER_EXTENSIONS = /\.(jpe?g|png|gif|webp|bmp)(\?.*)?$/i;

function isRasterImageUrl(url) {
  if (!url) return false;
  return RASTER_EXTENSIONS.test(url);
}

function isAppropriateWallpaper({ text, width, height, url }) {
  if (isMemeOrReaction(text)) return false;
  if (isInappropriate(text)) return false;
  if (!hasEnoughResolution(width, height)) return false;
  if (url !== undefined && !isRasterImageUrl(url)) return false;
  return true;
}

// GIPHY aloja sus GIFs en baja resolución por diseño (para chats, no
// pantallas completas): confirmado en el catálogo real que ~94% mide menos
// de 600px de lado y ~67% es prácticamente cuadrado (stickers/reacciones,
// no animaciones panorámicas). MIN_WIDTH/MIN_HEIGHT (360) es demasiado
// permisivo para ese tipo de contenido — este chequeo adicional, solo para
// fondos animados, exige que el clip tenga forma rectangular real (no
// cuadrada) y una resolución mínima que se vea aceptable a pantalla
// completa.
const MIN_ANIMATED_LONG_SIDE = 600;
const SQUARE_ASPECT_TOLERANCE = 0.05;

function isWallpaperShaped(width, height) {
  const aspect = width / height;
  const isSquare = Math.abs(aspect - 1) < SQUARE_ASPECT_TOLERANCE;
  const maxSide = Math.max(width, height);
  return !isSquare && maxSide >= MIN_ANIMATED_LONG_SIDE;
}

module.exports = {
  isMemeOrReaction,
  isInappropriate,
  hasEnoughResolution,
  isRasterImageUrl,
  isWallpaperShaped,
  isAppropriateWallpaper,
};
