const fetch = require('node-fetch');

const BASE_URL = 'https://wallhaven.cc/api/v1/search';
const SAFETY_EXCLUSIONS =
  '-nsfw -sexy -cleavage -bikini -lingerie -underwear -swimsuit -ecchi ' +
  '-ahegao -upskirt -pinup -thighs -boobs -butt -ass -bra -panties';

async function search(query, apiKey, limit = 24) {
  if (!apiKey) return [];
  try {
    const url = new URL(BASE_URL);
    url.searchParams.set('apikey', apiKey);
    url.searchParams.set('q', `${query} ${SAFETY_EXCLUSIONS}`);
    url.searchParams.set('categories', '100');
    url.searchParams.set('purity', '100');
    url.searchParams.set('sorting', 'random');
    url.searchParams.set('per_page', String(limit));
    url.searchParams.set('page', '1');

    const res = await fetch(url, { timeout: 10000 });
    if (!res.ok) return [];
    const body = await res.json();
    const items = body.data || [];

    return items.map((item) => {
      const width = item.dimension_x;
      const height = item.dimension_y;
      const tags = (item.tags || []).map((t) => t.name).filter(Boolean);

      return {
        sourceId: String(item.id),
        source: 'wallhaven',
        url: item.path,
        thumbnailUrl: item.thumbs?.large || item.thumbs?.small,
        author: 'Wallhaven',
        width,
        height,
        tags,
        qualityScore: undefined,
        isAnimated: false,
        license: null,
      };
    });
  } catch (err) {
    console.error('[wallhaven] search error', err.message);
    return [];
  }
}

module.exports = { search };
