import { NextRequest, NextResponse } from 'next/server';
import { isAuthorized } from '../../../lib/adminAuth';
import { supabaseAdmin } from '../../../lib/supabaseAdmin';

export async function POST(req: NextRequest) {
  if (!isAuthorized(req)) {
    return NextResponse.json({ error: 'No autorizado' }, { status: 403 });
  }

  const body = await req.json().catch(() => null);
  const id: string | undefined = body?.id;
  const action: string | undefined = body?.action;
  if (!id || (action !== 'approve' && action !== 'reject')) {
    return NextResponse.json({ error: 'Falta id o action inválida' }, { status: 400 });
  }

  const sb = supabaseAdmin();
  if (action === 'approve') {
    const { error } = await sb.from('wallpapers').update({ is_published: true }).eq('id', id);
    if (error) return NextResponse.json({ error: error.message }, { status: 500 });
  } else {
    const { error } = await sb.from('wallpapers').delete().eq('id', id);
    if (error) return NextResponse.json({ error: error.message }, { status: 500 });
  }
  return NextResponse.json({ ok: true });
}
