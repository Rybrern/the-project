import { NextRequest, NextResponse } from 'next/server';
import { denyAdmin } from '../../../lib/adminAuth';
import { MissingEnvError, supabaseAdmin } from '../../../lib/supabaseAdmin';

export async function POST(req: NextRequest) {
  const denied = denyAdmin(req);
  if (denied) return denied;

  const body = await req.json().catch(() => null);
  const id: string | undefined = body?.id;
  const action: string | undefined = body?.action;
  if (!id || (action !== 'approve' && action !== 'reject')) {
    return NextResponse.json({ error: 'Falta id o action inválida' }, { status: 400 });
  }

  try {
    const sb = supabaseAdmin();
    if (action === 'approve') {
      const { error } = await sb.from('wallpapers').update({ is_published: true }).eq('id', id);
      if (error) return NextResponse.json({ error: error.message }, { status: 500 });
    } else {
      const { error } = await sb.from('wallpapers').delete().eq('id', id);
      if (error) return NextResponse.json({ error: error.message }, { status: 500 });
    }
    return NextResponse.json({ ok: true });
  } catch (e) {
    const msg = e instanceof MissingEnvError ? e.message : 'Error inesperado del servidor.';
    return NextResponse.json({ error: msg }, { status: 500 });
  }
}
