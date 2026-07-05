# Política de Privacidad — Looped

**Última actualización:** 4 de julio de 2026

Looped ("la app", "nosotros") es una aplicación social de baile que convierte el movimiento en una competencia con amigos. Esta política describe qué datos recopilamos, para qué, y qué control tenés sobre ellos.

> ⚠️ **Plantilla**: revisá y completá los campos marcados antes de publicar. Las tiendas exigen que esta política esté publicada en una URL accesible (por ejemplo GitHub Pages) y enlazada en la ficha de la app.

## 1. Datos que recopilamos

| Dato | Para qué lo usamos |
|---|---|
| Email y nombre de usuario | Crear y administrar tu cuenta |
| Contraseña | Solo se guarda un hash criptográfico (bcrypt); nunca en texto plano |
| Foto de perfil (opcional) | Mostrarla en tu perfil y en los rankings |
| Datos de movimiento (pasos, acelerómetro, giroscopio) | Contar tu actividad durante una sesión de baile y calcular puntos. El procesamiento ocurre en tu dispositivo; al servidor solo se envían totales y métricas agregadas |
| Ubicación (solo mientras usás la app) | Verificar que estás dentro del área de un evento al que te unís (geofence). No guardamos historial de ubicaciones |
| Sesiones de baile (puntos, duración, fecha) | Rankings, estadísticas personales y feed de amigos |
| Token de notificaciones (FCM) | Enviarte avisos como solicitudes de amistad o el inicio de un evento |
| Cuenta de Google (si elegís ese login) | Autenticación; recibimos tu email, nombre y foto de Google |

**No** vendemos tus datos ni los compartimos con terceros con fines publicitarios.

## 2. Servicios de terceros

- **MongoDB Atlas** — base de datos.
- **[Railway/Render — completar]** — hosting del servidor.
- **Cloudinary** — almacenamiento de imágenes (avatares e imágenes de eventos).
- **Google Sign-In** — autenticación opcional.
- **Firebase Cloud Messaging** — notificaciones push.
- **Resend** — envío de emails transaccionales (recuperación de contraseña).

## 3. Contenido social y visibilidad

Tu nombre de usuario, avatar, nivel, rango y puntos son visibles para otros usuarios en rankings y eventos. Las sesiones que hacés en eventos aparecen en el feed de tus amigos. Podés **reportar** o **bloquear** usuarios desde la pestaña Community.

## 4. Retención y eliminación

Podés eliminar tu cuenta desde **Ajustes → Eliminar cuenta**. La eliminación es inmediata y en cascada: se borran tu perfil, sesiones, membresías de eventos, amistades y eventos que hayas creado. Las imágenes subidas a almacenamiento externo se eliminan en un plazo máximo de 30 días.

## 5. Menores

Looped no está dirigida a menores de **[13/16 — completar según jurisdicción]** años.

## 6. Seguridad

Usamos HTTPS en todas las comunicaciones, hashes bcrypt para contraseñas, tokens JWT con expiración y validación server-side de toda la actividad reportada.

## 7. Contacto

Consultas sobre privacidad: **[email de contacto — completar]**

## 8. Cambios

Publicaremos cualquier cambio en esta página y actualizaremos la fecha del encabezado.
