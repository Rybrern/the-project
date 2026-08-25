const fetch = require('node-fetch');
const { isAppropriateWallpaper } = require('../contentFilter');

const BASE_URL = 'https://api.openverse.org/v1/images';

// OpenVerse agrega ~50 fuentes distintas; muchas (museos, archivos
// institucionales) bloquean hotlinking directo y devuelven 403/404 al
// pedir la imagen fuera de su propio sitio. Restringimos a fuentes que
// sí sirven la imagen sin restricción conocida.
const HOTLINK_FRIENDLY_SOURCES = new Set(['flickr', 'wikimedia', 'stocksnap', 'rawpixel']);

// OpenVerse no expone un thumbnail propio utilizable (ver comentario más
// abajo), así que la miniatura terminaba siendo un alias exacto de la URL
// completa: mismo peso (hasta ~1MB) y, crucialmente, cero redundancia — si
// esa única URL falla una vez (red lenta, hiccup del host), no queda ningún
// recurso alternativo al que caer, y el tile queda roto sin posibilidad de
// recuperación. Derivamos una miniatura real y más liviana desde el host
// original cuando conocemos su esquema de resize:
//  - Wikimedia Commons: Special:FilePath?width=N redirige a un thumb real.
//  - Flickr: los tamaños se codifican como sufijo antes de la extensión
//    (`_b` = grande/original, `_n` = 320px). Si no reconocemos el host,
//    devolvemos la URL original sin modificar (comportamiento previo).
function deriveThumbnailUrl(url) {
  try {
    const parsed = new URL(url);
    if (parsed.hostname === 'upload.wikimedia.org') {
      const filename = decodeURIComponent(parsed.pathname.split('/').pop());
      return `https://commons.wikimedia.org/wiki/Special:FilePath/${encodeURIComponent(filename)}?width=320`;
    }
    if (parsed.hostname === 'live.staticflickr.com') {
      return url.replace(/_[a-z](\.[a-z]+)$/i, '_n$1');
    }
  } catch {
    // URL inválida — dejar que el caller use la url original.
  }
  return url;
}

async function search(query, limit = 24) {
  try {
    const url = new URL(BASE_URL);
    url.searchParams.set('q', query);
    url.searchParams.set('page', '1');
    url.searchParams.set('page_size', String(limit));
    url.searchParams.set('license', 'cc0');

    const res = await fetch(url, { timeout: 10000 });
    if (!res.ok) return [];
    const body = await res.json();
    const results = body.results || [];

    return results
      .map((image) => {
        if (!HOTLINK_FRIENDLY_SOURCES.has(image.source)) return null;

        const width = image.width || 800;
        const height = image.height || 600;
        const title = image.title || 'Untitled';
        const tags = (image.tags || [])
          .map((t) => t.name)
          .filter(Boolean);

        if (!isAppropriateWallpaper({ text: `${title} ${tags.join(' ')}`, width, height })) {
          return null;
        }
        if (!image.url) return null;

        return {
          sourceId: String(image.id),
          source: 'openverse',
          url: image.url,
          // OJO: NO usar image.thumbnail (proxy api.openverse.org/.../thumb/)
          // como thumbnailUrl — ese endpoint tiene un rate limit propio muy
          // estricto y devuelve 429 apenas se cargan varias miniaturas en
          // paralelo (que es exactamente lo que hace un grid). Derivamos en
          // cambio una miniatura real desde el host original (ver
          // deriveThumbnailUrl) para no servir el original de alta
          // resolución como "miniatura" del grid.
          thumbnailUrl: deriveThumbnailUrl(image.url),
          author: image.creator || 'OpenVerse',
          width,
          height,
          tags,
          qualityScore: 1.0,
          isAnimated: false,
          license: 'cc0',
        };
      })
      .filter(Boolean);
  } catch (err) {
    console.error('[openverse] search error', err.message);
    return [];
  }
}

module.exports = { search, deriveThumbnailUrl };
