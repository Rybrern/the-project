const fetch = require('node-fetch');
const { isAppropriateWallpaper } = require('../contentFilter');

const BASE_URL = 'https://api.giphy.com/v1/gifs';

function nsfwScoreFor(rating) {
  switch ((rating || '').toLowerCase()) {
    case 'g': return 0.0;
    case 'pg': return 0.2;
    case 'pg-13': return 0.3;
    case 'r': return 0.8;
    default: return 0.1;
  }
}

function qualityScoreFor(width, height) {
  const pixels = width * height;
  if (pixels < 130000) return 0.2;
  if (pixels < 480000) return 0.5;
  if (pixels < 2073600) return 0.8;
  return 1.0;
}

function extractVideoUrl(images) {
  for (const key of ['fixed_height_small', 'fixed_height', 'original']) {
    const mp4 = images[key]?.mp4;
    if (mp4) return mp4;
  }
  return null;
}

function extractPreviewUrl(images) {
  for (const key of ['fixed_height', 'fixed_width', 'original', 'downsized']) {
    const url = images[key]?.url;
    if (url) return url;
  }
  return null;
}

function extractDimensions(images) {
  for (const key of ['original', 'fixed_height', 'fixed_width', 'fixed_height_small', 'downsized']) {
    const item = images[key];
    if (item) {
      const width = parseInt(item.width, 10);
      const height = parseInt(item.height, 10);
      if (width && height) return { width, height };
    }
  }
  return null;
}

async function search(query, apiKey, limit = 24) {
  if (!apiKey) return [];
  try {
    const url = new URL(`${BASE_URL}/search`);
    url.searchParams.set('api_key', apiKey);
    url.searchParams.set('q', query);
    url.searchParams.set('limit', String(limit));
    url.searchParams.set('offset', '0');
    url.searchParams.set('rating', 'g');
    url.searchParams.set('lang', 'en');

    const res = await fetch(url, { timeout: 10000 });
    if (!res.ok) return [];
    const body = await res.json();
    const data = body.data || [];

    return data
      .map((gif) => {
        const id = gif.id;
        const title = gif.title || 'GIPHY GIF';
        const images = gif.images;
        const rating = gif.rating || 'g';
        const tags = Array.isArray(gif.tags) ? gif.tags : [];

        if (!id || !images) return null;

        const nsfwScore = nsfwScoreFor(rating);
        if (nsfwScore > 0.5) return null;

        const videoUrl = extractVideoUrl(images);
        const previewUrl = extractPreviewUrl(images);
        if (!videoUrl || !previewUrl) return null;

        const dimensions = extractDimensions(images);
        if (!dimensions) return null;

        if (!isAppropriateWallpaper({
          text: `${title.toLowerCase()} ${tags.join(' ')}`,
          width: dimensions.width,
          height: dimensions.height,
        })) {
          return null;
        }

        return {
          sourceId: id,
          source: 'giphy',
          url: videoUrl,
          thumbnailUrl: previewUrl,
          author: 'GIPHY',
          width: dimensions.width,
          height: dimensions.height,
          tags,
          qualityScore: qualityScoreFor(dimensions.width, dimensions.height),
          nsfwScore,
          isAnimated: true,
          license: null,
        };
      })
      .filter(Boolean);
  } catch (err) {
    console.error('[giphy] search error', err.message);
    return [];
  }
}

module.exports = { search };
