import { NextRequest } from 'next/server';

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
