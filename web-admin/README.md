# Fondos HD — Admin Web (Vercel + Supabase)

Plantilla mínima para cargar fondos sin actualizar APK, con cola de
moderación para los fondos que suben los usuarios desde la app.

## Deploy en Vercel (1 click)

1. Crear proyecto Supabase > SQL Editor > ejecutar `supabase/schema.sql`
   completo (crea la tabla `wallpapers`, RLS, la policy de subida de
   usuarios y el trigger anti-spam).
2. Storage > Create bucket `wallpapers` (public). Después, Storage >
   `wallpapers` > Policies > agregar una policy de **INSERT** para el rol
   `anon` con la condición:
   ```
   bucket_id = 'wallpapers' AND (storage.foldername(name))[1] = 'user-submitted'
   ```
   (así los usuarios solo pueden subir dentro de esa subcarpeta — no
   pueden tocar lo que subiste vos desde el panel).
3. En Vercel > New Project > importar este `web-admin/` (o todo el repo
   con Root Directory `web-admin`).
4. Variables de entorno en Vercel (ver `.env.example` para la lista
   completa — **nunca** commitear los valores reales):
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY` — solo server, da acceso total a la base.
     No lleva prefijo `NEXT_PUBLIC_` a propósito: si lo tuviera, quedaría
     expuesta en el bundle del cliente.
   - `ADMIN_SECRET` — contraseña propia del panel. Cualquier string largo
     y aleatorio; guardala en un gestor de contraseñas, no en el repo.
5. Deploy. La web queda en `https://tu-admin.vercel.app`.

## Uso

- **Publicar directo** (`/admin`): pegá la contraseña de admin, el link
  https de la imagen, categoría y tags, "Publicar sin APK". Queda
  publicado al instante.
- **Moderar subidas de usuarios** (`/admin/pendientes`): los fondos que
  suben los usuarios desde la app quedan como `is_published = false` —
  invisibles en el catálogo hasta que los apruebes acá. Cargá la lista con
  la contraseña, y Aprobá o Rechazá cada uno.
- La app Flutter lee `lib/services/supabase_catalog_service.dart` al
  iniciar y muestra los fondos publicados inmediatamente (sin update de
  APK).

## Seguridad

- La `service_role key` nunca toca el cliente — todo insert/update/delete
  pasa por los Route Handlers en `app/api/*` (`lib/supabaseAdmin.ts`),
  gateados por `ADMIN_SECRET` (`lib/adminAuth.ts`).
- Los usuarios de la app solo pueden insertar filas propias, no publicadas
  (`source = 'user', is_published = false`) — ver la policy RLS
  `"anon can submit pending"` en `supabase/schema.sql`. Un trigger limita a
  5 pendientes simultáneos por dispositivo para mitigar spam sin necesitar
  un sistema de login completo.
- `.env.local` está en `.gitignore` — nunca lo fuerces a commitear.

Local dev:
```bash
cd web-admin
npm install
cp .env.example .env.local  # completar con tus valores reales
npm run dev # http://localhost:3000
```
