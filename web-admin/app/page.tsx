export default function Home() {
  return (
    <main style={{ maxWidth: 720, margin: '40px auto', padding: 24 }}>
      <h1>Fondos HD — Catálogo</h1>
      <p>Plantilla web para Vercel. La app Flutter consume Supabase directamente.</p>
      <p><a href="/admin" style={{ color: '#a78bfa' }}>Ir al Admin →</a></p>
      <ul>
        <li>Ver catálogo: tabla <code>wallpapers</code> en Supabase</li>
        <li>App lee sin actualizar APK vía <code>SupabaseCatalogService</code></li>
      </ul>
    </main>
  );
}
