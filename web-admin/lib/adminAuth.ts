import { NextRequest, NextResponse } from 'next/server';
import { isRateLimited, recordFailure, recordSuccess } from './rateLimit';

/// Compara con timing constante para no filtrar el secreto por diferencias
/// de tiempo de respuesta (comparación ingenua de strings es vulnerable a
/// timing attacks en un endpoint público).
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

export function isAuthorized(req: NextRequest): boolean {
  const expected = process.env.ADMIN_SECRET;
  if (!expected) return false; // Sin secreto configurado, denegar todo.
  const provided = req.headers.get('x-admin-secret') ?? '';
  return timingSafeEqual(provided, expected);
}

/// Gate único de los endpoints admin: devuelve la respuesta de rechazo, o
/// `null` si el pedido puede continuar. Combina el chequeo del secreto con
/// el rate limit para que un bucle de fuerza bruta se corte solo.
export function denyAdmin(req: NextRequest): NextResponse | null {
  if (isRateLimited(req)) {
    return NextResponse.json(
      { error: 'Demasiados intentos fallidos. Esperá un minuto.' },
      { status: 429 }
    );
  }
  if (!isAuthorized(req)) {
    recordFailure(req);
    return NextResponse.json({ error: 'No autorizado' }, { status: 403 });
  }
  recordSuccess(req);
  return null;
}
