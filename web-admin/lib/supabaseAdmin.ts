import { createClient } from '@supabase/supabase-js';

// Cliente server-only con la service_role key — bypassea RLS. Nunca debe
// llegar al bundle del cliente (por eso vive en lib/, importado solo desde
// Route Handlers, y la env var no lleva prefijo NEXT_PUBLIC_).
/// Error de configuración del entorno, no del pedido — se distingue para
/// poder responder con un mensaje accionable en vez de un 500 vacío
/// (`createClient` con la key en undefined tira una excepción sin cuerpo,
/// que del lado del navegador se ve como un cuelgue infinito).
export class MissingEnvError extends Error {}

export function supabaseAdmin() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const missing = [
    !url && 'NEXT_PUBLIC_SUPABASE_URL',
    !key && 'SUPABASE_SERVICE_ROLE_KEY',
  ].filter(Boolean);

  if (missing.length > 0) {
    throw new MissingEnvError(
      `Faltan variables de entorno en este deploy: ${missing.join(', ')}. ` +
        'Cargalas en Vercel > Settings > Environment Variables (tildando el ' +
        'entorno correcto: Production y Preview) y volvé a desplegar.'
    );
  }

  return createClient(url!, key!, { auth: { persistSession: false } });
}
