const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');

admin.initializeApp();

const wallhavenKey = defineSecret('WALLHAVEN_API_KEY');
const pixabayKey = defineSecret('PIXABAY_API_KEY');
const unsplashKey = defineSecret('UNSPLASH_ACCESS_KEY');
const giphyKey = defineSecret('GIPHY_API_KEY');
const triggerSecret = defineSecret('INGEST_TRIGGER_SECRET');

const SECRETS = [wallhavenKey, pixabayKey, unsplashKey, giphyKey];

// .trim() en los 4: al setearlos vía `echo ... | firebase functions:secrets:set`
// se coló un salto de línea final en al menos uno (confirmado en
// INGEST_TRIGGER_SECRET, y WALLHAVEN_API_KEY tenía el mismo síntoma: la
// key nunca dio un solo resultado porque Wallhaven la rechazaba silenciosamente).
function applySecretsToEnv() {
  process.env.WALLHAVEN_API_KEY = wallhavenKey.value().trim();
  process.env.PIXABAY_API_KEY = pixabayKey.value().trim();
  process.env.UNSPLASH_ACCESS_KEY = unsplashKey.value().trim();
  process.env.GIPHY_API_KEY = giphyKey.value().trim();
}

// Corre cada 12 horas: recorre todas las categorías, escribe en Firestore.
exports.scheduledIngestion = onSchedule(
  {
    schedule: 'every 12 hours',
    timeoutSeconds: 1800,
    memory: '512MiB',
    secrets: SECRETS,
  },
  async () => {
    applySecretsToEnv();
    const { runIngestion } = require('./src/ingest');
    const result = await runIngestion({});
    console.log('scheduledIngestion result', result);
  },
);

// Disparo manual (ej. para probar sin esperar las 12h). Protegido por un
// secreto compartido pasado como ?secret=... — no es autenticación de
// usuario real, solo evita que cualquiera en internet dispare ingestas
// (que cuestan cuota de API y facturación) con la URL pública.
exports.triggerIngestion = onRequest(
  {
    timeoutSeconds: 1800,
    memory: '512MiB',
    secrets: [...SECRETS, triggerSecret],
  },
  async (req, res) => {
    if (req.query.secret !== triggerSecret.value().trim()) {
      res.status(403).json({ error: 'forbidden' });
      return;
    }

    applySecretsToEnv();
    const { runIngestion } = require('./src/ingest');

    const categoriesParam = req.query.categories;
    const categoryIds = categoriesParam ? String(categoriesParam).split(',') : undefined;
    const purge = req.query.purge === 'true';

    try {
      const result = await runIngestion({ categoryIds, purge });
      res.json({ ok: true, ...result });
    } catch (err) {
      console.error('triggerIngestion error', err);
      res.status(500).json({ ok: false, error: err.message });
    }
  },
);
