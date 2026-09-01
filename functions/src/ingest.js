const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const crypto = require('crypto');

const openverse = require('./providers/openverse');
const wallhaven = require('./providers/wallhaven');
const pixabay = require('./providers/pixabay');
const unsplash = require('./providers/unsplash');
const giphy = require('./providers/giphy');
const { normalizeTags, normalizeTag } = require('./tagNormalizer');
const { CATEGORY_QUERIES } = require('./categories');
const { isRasterImageUrl } = require('./contentFilter');

// Boosts de fuente, portados de lib/services/search/popularity_ranker.dart
const SOURCE_BOOST = {
  unsplash: 1.25,
  giphy: 1.20,
  pixabay: 1.15,
  wallhaven: 1.12,
  openverse: 1.10,
};

function popularityScore(item) {
  const base = item.qualityScore ?? 0.6;
  const boost = SOURCE_BOOST[item.source] ?? 1.0;
  return Math.round(base * boost * 1000) / 1000;
}

function docIdFor(item) {
  return `${item.source}_${item.sourceId}`;
}

function sha256Of(str) {
  return crypto.createHash('sha256').update(str).digest('hex');
}

// OpenVerse indexa contenido CC0 (Flickr Commons, Wikimedia, etc.) — para
// una persona o equipo específico casi no existe material CC0 real (las
// fotos de atletas/celebridades son casi siempre con copyright), así que
// el buscador cae en matches de texto libre débiles y devuelve resultados
// irrelevantes o directamente inapropiados (confirmado: "Messi" trajo una
// foto de contenido fetish sin ninguna relación). Para estas queries de
// nombre propio, se salta OpenVerse y se confía en Wallhaven/Pixabay/
// Unsplash, que tienen contenido curado/editorial con mejor matching.
const NAMED_ENTITY_QUERIES = new Set([
  'messi', 'ronaldo', 'mbappé', 'haaland', 'neymar', 'lewandowski', 'benzema',
  'real madrid', 'barcelona', 'manchester city', 'liverpool', 'bayern munich',
  'psg', 'juventus', 'chelsea', 'arsenal', 'ac milan',
  'lewis hamilton', 'max verstappen', 'fernando alonso', 'charles leclerc', 'lando norris',
  'marc márquez', 'jorge lorenzo', 'valentino rossi',
  'lebron james', 'michael jordan', 'giannis antetokounmpo', 'luka doncic',
  'djokovic', 'federer', 'conor mcgregor',
].map((s) => s.toLowerCase()));

function isNamedEntityQuery(query) {
  return NAMED_ENTITY_QUERIES.has(query.toLowerCase());
}

/** Corre `worker` sobre `items` con a lo sumo `concurrency` en paralelo. */
async function runWithConcurrency(items, concurrency, worker) {
  const queue = [...items];
  const runners = new Array(concurrency).fill(null).map(async () => {
    while (queue.length) {
      const item = queue.shift();
      await worker(item);
    }
  });
  await Promise.all(runners);
}

/**
 * Ejecuta una pasada de ingesta contra los 5 proveedores para cada query de
 * descubrimiento (portadas de lib/models/default_categories.dart —
 * "Messi", "Real Madrid", "F1", etc., no los ids de categoría) y escribe
 * los resultados aceptados en Firestore (colección `wallpapers`).
 * Idempotente: usa `source_sourceId` como ID de documento, así que
 * reingestar no duplica.
 *
 * Dedup: por ahora solo exacta (mismo doc id, o mismo sha256 de URL final
 * entre proveedores distintos). NO incluye pHash de contenido visual como
 * el pipeline Dart (fase 1-2) — eso requeriría descargar cada imagen y
 * correr un hash perceptual en la función, con el costo/tiempo que implica.
 * Queda como mejora futura si se necesita dedup entre proveedores distintos
 * que suban la misma foto.
 */
/** Borra todos los wallpapers cuya `category` esté en `categoryIds`. */
async function purgeCategories(categoryIds) {
  const db = getFirestore();
  let deleted = 0;
  for (const categoryId of categoryIds) {
    // eslint-disable-next-line no-await-in-loop
    const snapshot = await db.collection('wallpapers').where('category', '==', categoryId).get();
    if (snapshot.empty) continue;
    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    // eslint-disable-next-line no-await-in-loop
    await batch.commit();
    deleted += snapshot.size;
  }
  return deleted;
}

async function runIngestion({ categoryIds, perProviderLimit = 10, concurrency = 4, purge = false } = {}) {
  const db = getFirestore();
  const targetEntries = categoryIds && categoryIds.length
    ? CATEGORY_QUERIES.filter((c) => categoryIds.includes(c.id))
    : CATEGORY_QUERIES;

  if (purge) {
    await purgeCategories(targetEntries.map((e) => e.id));
  }

  // Aplana a pares (categoryId, query) — cada uno es una pasada de ingesta.
  const jobs = [];
  for (const entry of targetEntries) {
    for (const query of entry.queries) {
      jobs.push({ categoryId: entry.id, query });
    }
  }

  const seenUrlHashes = new Set();
  // Los `jobs` corren con concurrencia > 1, así que no pueden escribir
  // directo a un WriteBatch compartido (dos workers commiteando el mismo
  // batch en paralelo revienta con "WriteBatch that has been committed").
  // En cambio, cada worker acumula sus escrituras acá y el commit en
  // batches ocurre recién al final, en serie.
  const pendingWrites = [];
  let rejected = 0;

  await runWithConcurrency(jobs, concurrency, async ({ categoryId, query }) => {
    const [ov, wh, pb, us, gp] = await Promise.all([
      isNamedEntityQuery(query) ? Promise.resolve([]) : openverse.search(query, perProviderLimit),
      wallhaven.search(query, process.env.WALLHAVEN_API_KEY, perProviderLimit),
      pixabay.search(query, process.env.PIXABAY_API_KEY, perProviderLimit),
      unsplash.search(query, process.env.UNSPLASH_ACCESS_KEY, perProviderLimit),
      // GIPHY rechaza ~97% de sus resultados por forma/resolución
      // (isWallpaperShaped en contentFilter.js) — con el mismo límite de 10
      // candidatos crudos que el resto de proveedores, casi ninguna query
      // termina con un sobreviviente. Se pide el máximo que admite su API
      // (50 por página) para darle margen real al filtro.
      giphy.search(query, process.env.GIPHY_API_KEY, Math.max(perProviderLimit, 50)),
    ]);

    const combined = [...ov, ...wh, ...pb, ...us, ...gp];
    const queryTokens = query.split(/\s+/).map(normalizeTag).filter(Boolean);

    for (const item of combined) {
      if (!item.url || !item.width || !item.height) {
        rejected++;
        continue;
      }

      // Los estáticos deben ser un formato que el decoder de imágenes del
      // cliente pueda pintar (ver contentFilter.isRasterImageUrl) — los
      // animados usan `url` para el mp4 de reproducción, no aplica.
      if (!item.isAnimated && !isRasterImageUrl(item.url)) {
        rejected++;
        continue;
      }

      const urlHash = sha256Of(item.url);
      if (seenUrlHashes.has(urlHash)) {
        rejected++;
        continue;
      }
      seenUrlHashes.add(urlHash);

      const docId = docIdFor(item);
      const tags = normalizeTags([...(item.tags || []), categoryId, ...queryTokens]);

      const doc = {
        url: item.url,
        thumbnailUrl: item.thumbnailUrl,
        source: item.source,
        sourceId: item.sourceId,
        category: categoryId,
        tags,
        isAnimated: !!item.isAnimated,
        width: item.width,
        height: item.height,
        aspectRatio: item.width / item.height,
        author: item.author || null,
        qualityScore: item.qualityScore ?? 0.6,
        nsfwScore: item.nsfwScore ?? 0.0,
        popularityScore: popularityScore(item),
        sha256: urlHash,
        license: item.license || null,
        updatedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
      };

      pendingWrites.push({ ref: db.collection('wallpapers').doc(docId), doc });
    }
  });

  for (let i = 0; i < pendingWrites.length; i += 400) {
    const chunk = pendingWrites.slice(i, i + 400);
    const batch = db.batch();
    for (const { ref, doc } of chunk) {
      batch.set(ref, doc, { merge: true });
    }
    await batch.commit();
  }

  const accepted = pendingWrites.length;

  await db.collection('ingestion_meta').doc('last_run').set({
    finishedAt: FieldValue.serverTimestamp(),
    jobs: jobs.length,
    accepted,
    rejected,
  });

  return { accepted, rejected, jobs: jobs.length };
}

module.exports = { runIngestion, purgeCategories };
