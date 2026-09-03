import { NextRequest } from 'next/server';

/// Rate limit en memoria del proceso. En serverless cada instancia tiene su
/// propio mapa y las instancias se reciclan, así que esto NO es una defensa
/// dura: un atacante distribuido o con suerte de scheduling puede superarlo.
/// Sirve para lo que importa acá — frenar un bucle de fuerza bruta contra
/// ADMIN_SECRET desde un origen, que es el escenario realista. La defensa
/// real sigue siendo la entropía del secreto (32 chars aleatorios).
const WINDOW_MS = 60_000;
const MAX_FAILURES = 10;

const failures = new Map<string, { count: number; resetAt: number }>();

function clientKey(req: NextRequest): string {
  // x-forwarded-for lo setea la plataforma; el primer valor es el cliente.
  const fwd = req.headers.get('x-forwarded-for') ?? '';
  return fwd.split(',')[0].trim() || 'desconocido';
}

/// true si este origen agotó su cupo de intentos fallidos.
export function isRateLimited(req: NextRequest): boolean {
  const entry = failures.get(clientKey(req));
  if (!entry) return false;
  if (Date.now() > entry.resetAt) {
    failures.delete(clientKey(req));
    return false;
  }
  return entry.count >= MAX_FAILURES;
}

/// Registra un intento con secreto incorrecto.
export function recordFailure(req: NextRequest): void {
  const key = clientKey(req);
  const now = Date.now();
  const entry = failures.get(key);

  if (!entry || now > entry.resetAt) {
    failures.set(key, { count: 1, resetAt: now + WINDOW_MS });
    return;
  }
  entry.count += 1;

  // Cota de memoria: sin esto, un atacante que rota IPs haría crecer el mapa
  // indefinidamente dentro de una misma instancia.
  if (failures.size > 5_000) {
    for (const [k, v] of failures) {
      if (now > v.resetAt) failures.delete(k);
    }
  }
}

/// Limpia el registro tras un acceso válido, para que un admin que se
/// equivocó unas veces no quede bloqueado después de acertar.
export function recordSuccess(req: NextRequest): void {
  failures.delete(clientKey(req));
}
