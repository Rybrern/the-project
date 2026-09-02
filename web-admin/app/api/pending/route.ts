import { NextRequest, NextResponse } from 'next/server';
import { isAuthorized } from '../../../lib/adminAuth';
import { MissingEnvError, supabaseAdmin } from '../../../lib/supabaseAdmin';

export async function GET(req: NextRequest) {
  if (!isAuthorized(req)) {
    return NextResponse.json({ error: 'No autorizado' }, { status: 403 });
  }

  try {
    const { data, error } = await supabaseAdmin()
      .from('wallpapers')
      .select()
      .eq('is_published', false)
      .order('created_at', { ascending: false });

    if (error) {
      return NextResponse.json({ error: error.message }, { status: 500 });
    }
    return NextResponse.json({ items: data });
  } catch (e) {
    const msg = e instanceof MissingEnvError ? e.message : 'Error inesperado del servidor.';
    return NextResponse.json({ error: msg }, { status: 500 });
  }
}
