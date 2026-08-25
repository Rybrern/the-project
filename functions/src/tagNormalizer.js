// Normalización básica de tags: minúsculas, sin acentos, kebab-case.
// No incluye fuzzy matching, alias graph ni detección de entidades —
// esa lógica completa vive en lib/services/tag_normalization (Dart) y
// queda pendiente de portar si hace falta más adelante.
function normalizeTag(raw) {
  if (!raw) return '';
  return raw
    .toString()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9\s-]/g, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');
}

function normalizeTags(rawTags) {
  const seen = new Set();
  const result = [];
  for (const raw of rawTags || []) {
    const normalized = normalizeTag(raw);
    if (normalized && !seen.has(normalized)) {
      seen.add(normalized);
      result.push(normalized);
    }
  }
  return result;
}

module.exports = { normalizeTag, normalizeTags };
