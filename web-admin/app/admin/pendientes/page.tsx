'use client';
import { useState } from 'react';

type PendingWallpaper = {
  id: string;
  thumbnail_url: string;
  full_url: string;
  category: string;
  tags: string[];
  created_at: string;
};

export default function Pendientes() {
  const [secret, setSecret] = useState('');
  const [items, setItems] = useState<PendingWallpaper[] | null>(null);
  const [msg, setMsg] = useState('');

  async function load() {
    if (!secret) { setMsg('Falta la contraseña de admin.'); return; }
    setMsg('Cargando...');
    const res = await fetch('/api/pending', { headers: { 'x-admin-secret': secret } });
    const body = await res.json();
    if (!res.ok) { setMsg(`Error: ${body.error}`); return; }
    setItems(body.items);
    setMsg(body.items.length === 0 ? 'No hay fondos pendientes.' : '');
  }

  async function moderate(id: string, action: 'approve' | 'reject') {
    const res = await fetch('/api/moderate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-admin-secret': secret },
      body: JSON.stringify({ id, action }),
    });
    if (!res.ok) {
      const body = await res.json();
      setMsg(`Error: ${body.error}`);
      return;
    }
    setItems((prev) => prev?.filter((it) => it.id !== id) ?? null);
  }

  return (
    <main style={{ maxWidth: 900, margin: '40px auto', padding: 24 }}>
      <h1>Fondos pendientes de moderación</h1>
      <p style={{ opacity: 0.7 }}>Subidos por usuarios de la app — no son visibles en el catálogo hasta aprobarlos acá.</p>
      <div style={{ display: 'flex', gap: 12 }}>
        <input
          value={secret}
          onChange={(e) => setSecret(e.target.value)}
          type="password"
          placeholder="Contraseña de admin"
          style={{ flex: 1, padding: 8 }}
        />
        <button onClick={load} style={{ padding: '8px 16px', background: '#7c3aed', color: '#fff', border: 0, borderRadius: 8, cursor: 'pointer' }}>
          Cargar
        </button>
      </div>
      {msg && <p style={{ marginTop: 12 }}>{msg}</p>}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))', gap: 16, marginTop: 20 }}>
        {items?.map((item) => (
          <div key={item.id} style={{ background: '#1f1f1f', borderRadius: 8, overflow: 'hidden' }}>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={item.thumbnail_url} alt={item.id} style={{ width: '100%', height: 160, objectFit: 'cover' }} />
            <div style={{ padding: 10 }}>
              <div style={{ fontSize: 12, opacity: 0.7 }}>{item.category} — {item.tags?.join(', ')}</div>
              <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
                <button
                  onClick={() => moderate(item.id, 'approve')}
                  style={{ flex: 1, padding: 8, background: '#16a34a', color: '#fff', border: 0, borderRadius: 6, cursor: 'pointer' }}
                >
                  Aprobar
                </button>
                <button
                  onClick={() => moderate(item.id, 'reject')}
                  style={{ flex: 1, padding: 8, background: '#dc2626', color: '#fff', border: 0, borderRadius: 6, cursor: 'pointer' }}
                >
                  Rechazar
                </button>
              </div>
            </div>
          </div>
        ))}
      </div>
      <p style={{ marginTop: 24 }}><a href="/admin" style={{ color: '#a78bfa' }}>← Volver a publicar</a></p>
    </main>
  );
}
