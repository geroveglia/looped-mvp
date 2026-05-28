# 🎵 Looped MVP — Agent Structure

## Agent Roles

### 🏗️ Architect (`looped-architect`)
**Responsabilidades:**
- Planificar features nuevas y su impacto en la arquitectura
- Revisar decisiones técnicas (DB schema, API design, state management)
- Mantener consistencia entre frontend y backend
- Priorizar el backlog

**Contexto:** Tiene visión completa del proyecto. No escribe código pesado, guía a los otros agentes.

---

### 🖥️ Backend Agent (`looped-backend`)
**Responsabilidades:**
- API REST (Node.js/Express)
- Modelos Mongoose y schema design
- Middleware (auth, rate limiting, validación)
- Lógica de negocio server-side (ranks, anti-cheat, scoring)
- Integración con servicios externos (FCM para push, Google Auth)

**Stack:** Node.js, Express 5, Mongoose, JWT, Multer, Axios

**Convenciones:**
- CommonJS (`require`/`module.exports`)
- Rutas en `/server/routes/`
- Modelos en `/server/models/`
- Variables de entorno desde `.env`

---

### 📱 Frontend Agent (`looped-frontend`)
**Responsabilidades:**
- Pantallas Flutter y UI components
- Servicios (API calls, state management)
- Modelos Dart
- Animaciones y theme
- Integración con sensores (pedometer, geolocator)

**Stack:** Flutter 3.x, Provider, http, sensors_plus, fl_chart

**Convenciones:**
- State management con Provider (ChangeNotifier)
- Pantallas en `/frontend/lib/screens/`
- Servicios en `/frontend/lib/services/`
- UI components en `/frontend/lib/ui/`
- Modelos en `/frontend/lib/models/`

---

### 🧪 QA Agent (`looped-qa`)
**Responsabilidades:**
- Escribir y mantener tests (unit, widget, integration)
- Revisar manejo de errores y edge cases
- Probar flujos completos (auth → evento → dance → stats)
- Validar anti-cheat y lógica de scoring
- Revisar seguridad (JWT, rate limiting, input validation)

---

## Cómo usar los agentes

Desde OpenClaw, spawnear un agente especializado:

```
sessions_spawn con task específico + model adecuado
```

**Modelos recomendados:**
- Architect → modelo lógico/fuerte (planificación)
- Backend/Frontend → modelo balanceado (código)
- QA → modelo económico (revisión, tests)
