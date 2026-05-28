# 🎵 Looped MVP — Backlog

## 🔴 Alta Prioridad (Core features faltantes)

### DJ/Organizer Dashboard
**Agente:** `looped-frontend` + `looped-backend`
- [ ] **API:** Endpoint para que un organizador vea stats de su evento (asistentes, top dancers, duración)
- [ ] **API:** Endpoint para gestionar evento (editar, cancelar, promocionar)
- [ ] **Frontend:** Pantalla de dashboard con métricas del evento
- [ ] **Frontend:** Acceso desde la pantalla de evento (si sos organizador)

### Push Notifications (Server-side)
**Agente:** `looped-backend` + `looped-frontend`
- [ ] **Backend:** Integración con Firebase Cloud Messaging (FCM)
- [ ] **Backend:** Endpoint para guardar device tokens
- [ ] **Backend:** Lógica de notificaciones (evento empezando, amigo se unió, nuevo rank)
- [ ] **Frontend:** Registrar device token en login
- [ ] **Frontend:** Manejar notificaciones push entrantes (navegación)

### Friend Requests
**Agente:** `looped-backend` + `looped-frontend`
- [ ] **API:** Enviar/aceptar/rechazar solicitud de amistad
- [ ] **API:** Listar solicitudes pendientes
- [ ] **Frontend:** UI de solicitudes (enviar desde perfil, aceptar/rechazar)
- [ ] **Frontend:** Badge de notificación en tab de amigos

---

## 🟡 Media Prioridad (Mejoras)

### Anti-Cheat Refinamiento
**Agente:** `looped-backend`
- [ ] Mejorar detección de movimientos no-humanos
- [ ] Rate limiting en submission de scores
- [ ] Cooldown entre sesiones
- [ ] Flag system para sesiones sospechosas

### Tests
**Agente:** `looped-qa`
- [ ] Unit tests para rankUtils.js
- [ ] Integration tests para API endpoints
- [ ] Widget tests para pantallas principales
- [ ] Test de flujo completo (auth → evento → dance → stats)

### UX Polish
**Agente:** `looped-frontend`
- [ ] Empty states para listas vacías
- [ ] Loading skeletons
- [ ] Error handling mejorado (offline, timeout)
- [ ] Animaciones de transición entre pantallas

---

## 🟢 Baja Prioridad (Nice to have)

### Store Release Prep
**Agente:** `looped-architect`
- [ ] iOS provisioning profile y certificados
- [ ] Android app signing key
- [ ] App store screenshots y metadata
- [ ] Privacy policy

### Event Map View
**Agente:** `looped-frontend`
- [ ] Vista de mapa con eventos cercanos (flutter_map)
- [ ] Filtro por distancia/ubicación

### Performance
**Agente:** `looped-backend` + `looped-frontend`
- [ ] Paginación en leaderboards
- [ ] Caching de respuestas frecuentes
- [ ] Optimización de imágenes (thumbnails)

---

## 🟣 Deuda Técnica

- [ ] **Backend:** Validación de inputs con librería (Joi/Zod)
- [ ] **Backend:** Estructurar respuestas de error consistentes
- [ ] **Frontend:** Extraer strings a archivos de localización
- [ ] **Frontend:** Constants file para colores, tamaños, URLs
- [ ] **General:** Logger estructurado en backend
- [ ] **General:** Documentación de API (Swagger/OpenAPI)
