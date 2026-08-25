const fetch = require('node-fetch');
const { isAppropriateWallpaper } = require('../contentFilter');

const BASE_URL = 'https://pixabay.com/api/';

async function search(query, apiKey, limit = 24) {
  if (!apiKey) return [];
  try {
    const url = new URL(BASE_URL);
    url.searchParams.set('key', apiKey);
    url.searchParams.set('q', query);
    url.searchParams.set('safesearch', 'true');
    url.searchParams.set('per_page', String(limit));
    url.searchParams.set('image_type', 'photo');
    url.searchParams.set('min_width', '800');
    url.searchParams.set('min_height', '600');

    const res = await fetch(url, { timeout: 10000 });
    if (!res.ok) return [];
    const body = await res.json();
    const hits = body.hits || [];

    return hits
      .map((hit) => {
        const width = hit.imageWidth;
        const height = hit.imageHeight;
        const tagsText = hit.tags || '';
        const tags = tagsText.split(',').map((t) => t.trim()).filter(Boolean);

        if (!isAppropriateWallpaper({ text: tagsText, width, height })) return null;

        return {
          sourceId: String(hit.id),
          source: 'pixabay',
          url: hit.largeImageURL || hit.webformatURL,
          thumbnailUrl: hit.previewURL,
          author: hit.user || 'Pixabay',
          width,
          height,
          tags,
          qualityScore: undefined,
          isAnimated: false,
          license: null,
        };
      })
      .filter(Boolean);
  } catch (err) {
    console.error('[pixabay] search error', err.message);
    return [];
  }
}

module.exports = { search };
