'use client';
import { useState } from 'react';

export default function Admin() {
  const [secret, setSecret] = useState('');
  const [url, setUrl] = useState('');
  const [category, setCategory] = useState('naturaleza');
  const [tags, setTags] = useState('nature,4k');
  const [msg, setMsg] = useState('');

  async function publish() {
    if (!secret) { setMsg('Falta la contraseña de admin.'); return; }
    if (!url.startsWith('https://')) { setMsg('URL debe ser https://'); return; }
    if (url.toLowerCase().includes('.gif')) { setMsg('GIF no permitido (baja calidad)'); return; }

    setMsg('Publicando...');
    try {
      const res = await fetch('/api/publish', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-admin-secret': secret },
        body: JSON.stringify({
          url,
          category,
          tags: tags.split(',').map((s) => s.trim()).filter(Boolean),
        }),
      });

      // El cuerpo puede no ser JSON (un 500 de plataforma llega vacío o como
      // HTML); parsearlo a ciegas dejaría el mensaje clavado en "Publicando...".
      const text = await res.text().catch(() => '');
      let parsed: { id?: string; error?: string } = {};
      try { parsed = text ? JSON.parse(text) : {}; } catch { /* no era JSON */ }

      if (!res.ok) {
        setMsg(`Error: ${parsed.error ?? `el servidor respondió ${res.status} sin detalle.`}`);
        return;
      }
      setMsg(`Publicado ${parsed.id} — visible en la app al reiniciar`);
    } catch (e) {
      setMsg(`Error de red: ${e instanceof Error ? e.message : 'no se pudo contactar al servidor.'}`);
    }
  }

  return (
    <main style={{ maxWidth: 640, margin: '40px auto', padding: 24 }}>
      <h1>Admin — Subir fondo</h1>
      <p style={{ opacity: 0.7 }}>Pega link directo https (Supabase Storage, Catbox, Imgur). Se valida calidad ≥1080p en la app.</p>
      <label>Contraseña de admin<input value={secret} onChange={(e) => setSecret(e.target.value)} type="password" style={{ width: '100%', padding: 8, marginTop: 4 }} /></label>
      <div style={{ height: 12 }} />
      <label>URL imagen<input value={url} onChange={e => setUrl(e.target.value)} placeholder="https://..." style={{ width: '100%', padding: 8, marginTop: 4 }} /></label>
      <div style={{ display: 'flex', gap: 12, marginTop: 12 }}>
        <label>Categoría<select value={category} onChange={e => setCategory(e.target.value)} style={{ padding: 8 }}><option>naturaleza</option><option>abstracto</option><option>espacio</option><option>minimalista</option><option>arquitectura</option><option>animales</option><option>oscuro</option><option>arte</option></select></label>
        <label style={{ flex: 1 }}>Tags (coma)<input value={tags} onChange={e => setTags(e.target.value)} style={{ width: '100%', padding: 8 }} /></label>
      </div>
      <button onClick={publish} style={{ marginTop: 16, padding: '10px 20px', background: '#7c3aed', color: '#fff', border: 0, borderRadius: 8, cursor: 'pointer' }}>Publicar sin APK</button>
      {msg && <p style={{ marginTop: 12, background: '#1f1f1f', padding: 10, borderRadius: 8 }}>{msg}</p>}
      <p style={{ marginTop: 24, opacity: 0.5, fontSize: 12 }}>Para subir archivo en vez de link, usa Supabase Dashboard &gt; Storage &gt; wallpapers &gt; Upload, luego copia public URL aquí.</p>
      <p style={{ marginTop: 24 }}><a href="/admin/pendientes" style={{ color: '#a78bfa' }}>Ver fondos subidos por usuarios (moderación) →</a></p>
    </main>
  );
}
