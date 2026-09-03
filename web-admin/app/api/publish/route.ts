import { NextRequest, NextResponse } from 'next/server';
import { denyAdmin } from '../../../lib/adminAuth';
import { MissingEnvError, supabaseAdmin } from '../../../lib/supabaseAdmin';

const ALLOWED_CATEGORIES = new Set([
  'naturaleza', 'abstracto', 'espacio', 'minimalista', 'arquitectura',
  'animales', 'oscuro', 'arte', 'tablets', 'manual', 'general',
]);

export async function POST(req: NextRequest) {
  const denied = denyAdmin(req);
  if (denied) return denied;

  const body = await req.json().catch(() => null);
  if (!body || typeof body.url !== 'string') {
    return NextResponse.json({ error: 'Falta url' }, { status: 400 });
  }

  const url: string = body.url;
  if (!url.startsWith('https://')) {
    return NextResponse.json({ error: 'La URL debe ser https://' }, { status: 400 });
  }
  if (url.toLowerCase().includes('.gif')) {
    return NextResponse.json({ error: 'GIF no permitido (baja calidad)' }, { status: 400 });
  }

  const category: string = typeof body.category === 'string' ? body.category : 'manual';
  if (!ALLOWED_CATEGORIES.has(category)) {
    return NextResponse.json({ error: 'Categoría inválida' }, { status: 400 });
  }

  const tags: string[] = Array.isArray(body.tags)
    ? body.tags.filter((t: unknown) => typeof t === 'string').slice(0, 15)
    : [];

  const id = 'manual_' + Date.now();
  try {
    const { error } = await supabaseAdmin().from('wallpapers').insert({
      id,
      full_url: url,
      thumbnail_url: url,
      category,
      tags,
      author: 'Admin Web',
      source: 'admin',
      is_published: true,
    });

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }
    return NextResponse.json({ ok: true, id });
  } catch (e) {
    const msg = e instanceof MissingEnvError ? e.message : 'Error inesperado del servidor.';
    return NextResponse.json({ error: msg }, { status: 500 });
  }
}
