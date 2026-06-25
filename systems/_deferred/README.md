# systems/_deferred — Código DIFERIDO (no cargar en Fase 1)

Este directorio contiene código de la fase **MMO** que **NO** forma parte del
alcance actual (Fase 1, single-player). Está aquí para no perderlo, pero:

- **NO** está registrado como autoload en `project.godot`.
- **NO** se instancia en ninguna escena.
- Depende de `multiplayer` / `@rpc` y de constantes agrupadas como "Diferido (MMO)"
  en `core/constants_core.gd`.

Se reactivará cuando llegue la fase de multijugador. Ver la decisión en
`docs/architecture/DESIGN_DECISIONS.md` → **ADR-003 (Híbrido Controlado)**.

Contenido:
- `party_manager.gd` — gestor autoritativo de parties/squads (facciones, RPCs).
