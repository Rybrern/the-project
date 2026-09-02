# Fondos HD — Admin Web (Vercel + Supabase)

Plantilla mínima para cargar fondos sin actualizar APK.

## Deploy en Vercel (1 click)

1. Crear proyecto Supabase > SQL Editor > ejecutar `supabase/schema.sql` (crea tabla `wallpapers` + RLS).
2. Storage > Create bucket `wallpapers` (public).
3. En Vercel > New Project > importar este `web-admin/` (o todo el repo con Root Directory `web-admin`).
4. Variables de entorno en Vercel:
   - `NEXT_PUBLIC_SUPABASE_URL=https://xxx.supabase.co`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...` (anon)
   - `SUPABASE_SERVICE_ROLE_KEY=eyJ...` (solo server, para insert)
5. Deploy. La web queda en `https://tu-admin.vercel.app`.

## Uso
- Abrir `/admin` > pegar `fullUrl` (https directo o subir archivo a Storage) > elegir categoría/tags > Publish.
- La app Flutter lee `supabase_catalog_service.dart` al iniciar y muestra el fondo inmediatamente (sin update).

Local dev:
```bash
cd web-admin
npm install
npm run dev # http://localhost:3000
```
