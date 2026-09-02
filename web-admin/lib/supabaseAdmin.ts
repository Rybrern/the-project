import { createClient } from '@supabase/supabase-js';

// Cliente server-only con la service_role key — bypassea RLS. Nunca debe
// llegar al bundle del cliente (por eso vive en lib/, importado solo desde
// Route Handlers, y la env var no lleva prefijo NEXT_PUBLIC_).
export function supabaseAdmin() {
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false } }
  );
}
