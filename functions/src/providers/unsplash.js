const fetch = require('node-fetch');

const BASE_URL = 'https://api.unsplash.com/search/photos';

function qualityScoreFor(width, height) {
  const maxSide = Math.max(width, height);
  if (maxSide >= 2048) return 0.95;
  if (maxSide >= 1440) return 0.8;
  if (maxSide >= 1080) return 0.65;
  return 0.5;
}

async function search(query, accessKey, limit = 24) {
  if (!accessKey) return [];
  try {
    const url = new URL(BASE_URL);
    url.searchParams.set('client_id', accessKey);
    url.searchParams.set('query', query);
    url.searchParams.set('page', '1');
    url.searchParams.set('per_page', String(Math.min(Math.max(limit, 1), 30)));
    url.searchParams.set('order_by', 'relevant');
    url.searchParams.set('content_filter', 'high');

    const res = await fetch(url, { timeout: 10000 });
    if (!res.ok) return [];
    const body = await res.json();
    const results = body.results || [];

    return results
      .map((photo) => {
        const width = photo.width || 0;
        const height = photo.height || 0;
        if (width < 360 || height < 360) return null;

        const urls = photo.urls;
        if (!urls) return null;
        const thumbnailUrl = urls.thumb;
        const fullUrl = urls.regular || urls.full;
        if (!thumbnailUrl || !fullUrl) return null;

        const tags = (photo.tags || [])
          .map((t) => t.title)
          .filter(Boolean);

        return {
          sourceId: photo.id,
          source: 'unsplash',
          url: fullUrl,
          thumbnailUrl,
          author: photo.user?.name || 'Unsplash',
          width,
          height,
          tags,
          qualityScore: qualityScoreFor(width, height),
          isAnimated: false,
          license: null,
        };
      })
      .filter(Boolean);
  } catch (err) {
    console.error('[unsplash] search error', err.message);
    return [];
  }
}

module.exports = { search };
