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

function isAppropriateWallpaper({ text, width, height }) {
  if (isMemeOrReaction(text)) return false;
  if (isInappropriate(text)) return false;
  if (!hasEnoughResolution(width, height)) return false;
  return true;
}

module.exports = { isMemeOrReaction, isInappropriate, hasEnoughResolution, isAppropriateWallpaper };
