# Roadmap por fases

Regla de oro del roadmap: **una fase no empieza hasta que la anterior es
divertida y estable.** Todo lo que no esté en la fase actual va a "Más
adelante", aunque sea buena idea. Así matamos el *scope creep*.

## ✅ Fase 0 — Esqueleto del proyecto (HECHO)
- Estructura de carpetas limpia y escalable.
- `project.godot` con stretch `canvas_items`/`expand` e Input Map por acciones.
- `.gitignore`, `README.md` y documentación en `/docs`.
- Esqueletos de los sistemas de Fase 1 (ver abajo) y escenas mínimas.

## 🚧 Fase 1 — Núcleo de UN jugador (EN CURSO)
El único objetivo: que el bucle local enganche. Solo esto:
- [x] Movimiento de personaje 2D top-down.
- [x] 2–3 recursos recolectables (madera, mineral, fibra).
- [x] Sistema de inventario (lógica pura, separada de lo visual).
- [x] Crafteo con recetas definidas como datos.
- [x] Herramientas que mejoran la recolección y SE DESGASTAN.
- [x] Moneda interna (estructura básica, sin mercado).
- [ ] **Interfaz de inventario** (mostrar los huecos en pantalla).
- [ ] **Interfaz de crafteo** (lista de recetas + botón craftear).
- [ ] Feedback visual de recolección (texto flotante en vez de `print`).
- [ ] Sprites/arte placeholder decente (assets gratuitos).
- [ ] Guardado/carga local de la partida.

## 🔮 Fase 2 — Profundidad de un jugador
- Más recursos, materiales intermedios y árbol de crafteo más rico.
- Niveles de habilidad por actividad (talar, minar, etc.).
- Regeneración de recursos en el mundo.
- Audio y pulido.

## 🔮 Fase 3 — Persistencia y backend
- Backend open source / free tier (Nakama o Supabase).
- Autoridad de servidor real sobre inventario y oro.
- Cuentas de jugador.

## 🔮 Fase 4 — Multijugador y comercio
- Varios jugadores en el mismo mundo (API nativa de Godot + ENet).
- **Trade window** clásica de MMO (intercambio de items/oro DENTRO del juego).
- Mercado / casa de subastas (siempre dentro del juego, ver Reglas).

## ❌ Fuera de alcance (por ahora, no construir)
Multijugador, backend, mercado, combate, mundo grande, 3D, y CUALQUIER cosa
relacionada con pagos de dinero real o blockchain (ver VISION.md).
