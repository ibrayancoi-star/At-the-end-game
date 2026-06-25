# Registro de Decisiones de Diseño (Architecture Decision Records - ADR)

Este archivo actúa como el repositorio central de decisiones técnicas y arquitectónicas tomadas para el proyecto del videojuego.

---

## ADR-001: Aceptación de Lore de Capa 1 y Degradación Tecnológica como Mecánica Central de Economía

### Estado
**Aceptado**

### Contexto
En los videojuegos tipo sandbox, el control del progreso y la inflación de recursos (acumular demasiado inventario sin utilidad) son problemas recurrentes que disminuyen la tensión y el factor de supervivencia a medio/largo plazo. Necesitamos un sistema de "sumideros de recursos" (resource sinks) que mantenga la economía del jugador en constante movimiento y encaje de manera orgánica con el lore del juego.

El lore establecido en [Capa 1: La Paradoja de la Empatía y el Gran Apagón](../narrative/CAP_1_EMPATIA.md) provee la base narrativa perfecta: la existencia de una atmósfera ionizada por el pulso EMP y la presencia de fragmentos inestables de la RNG (Red de Nutrición Global) dentro de cualquier hardware complejo.

### Decisión
Adoptar la degradación de maquinaria y la inestabilidad de los artefactos como la mecánica principal de balanceo económico y de progresión. Específicamente:
1. **Degradación Inevitable**: Toda tecnología compleja y circuitos lógicos sufrirán una penalización progresiva por ticks y uso continuo (detallado en [Inestabilidad del Artefacto](../systems/ARTEFACT_TRAUMA.md)).
2. **Sumidero de Recursos**: El mantenimiento y la reparación de estos equipos requerirá materiales consumibles raros, chatarra electrónica protegida de la radiación electromagnética (EMP shield containers) y componentes de calibración lógica.
3. **Restricción de Automatización**: No se permitirá la creación de bases o sistemas totalmente automatizados de manera indefinida. Cada estación automatizada requerirá mantenimiento activo de su firmware e infraestructura física contra las intrusiones de datos de la RNG residual.

### Consecuencias
* **Positivas**:
  * Mayor inmersión al conectar la jugabilidad directamente con la narrativa y la atmósfera post-apocalíptica.
  * Resolución natural de la acumulación ilimitada de recursos a través de un ciclo continuo de desgaste, reparación y búsqueda.
  * Promueve un estilo de juego adaptativo donde el jugador debe equilibrar el uso de tecnologías avanzadas e inestables con herramientas mecánicas simples y confiables.
* **Negativas**:
  * Puede generar frustración en jugadores orientados puramente a la automatización de fábricas a gran escala (estilo Factorio). El balance debe ser ajustado mediante pruebas de juego para no percibirse como excesivamente punitivo.
  * Incremento en la complejidad del bucle de simulación del motor de juego, requiriendo sistemas robustos de gestión de eventos por ticks.

---

## ADR-002: Adopción del Modelo Logístico de 3 Fases (Economía de Alto Riesgo)

### Estado
**Aceptado**

### Contexto
La economía de *The Ceiling* se define como de **alto riesgo**: el valor no se
genera ni se consume de forma segura, sino que debe **desplazarse** a través de
un mundo hostil (atmósfera ionizada, Espectros de Silicio y zonas PvP
*full-loot*). Necesitamos un marco que estructure el flujo de recursos desde su
origen hasta su consumo/venta y que coloque el riesgo de forma **deliberada**,
creando tensión, decisiones logísticas y oportunidades de mercado entre
jugadores.

Este modelo se apoya en dos piezas ya establecidas:
- El sumidero de mantenimiento tecnológico de [ADR-001](#adr-001-aceptación-de-lore-de-capa-1-y-degradación-tecnológica-como-mecánica-central-de-economía).
- El protocolo atómico de transacciones y el reloj de ticks definidos en
  [SYSTEM_FOUNDATION.md](../SYSTEM_FOUNDATION.md).

### Decisión
Adoptar un ciclo logístico de **3 fases** como columna vertebral del bucle
económico. Cada fase tiene un perfil de riesgo y un rol económico distintos:

1. **Fase 1 — Extracción.**
   Obtención de materia prima en las zonas exteriores degradadas. Es el
   principal **grifo** de valor. Exposición alta a glitches de artefacto y
   radiación, pero el valor extraído todavía es bajo y reemplazable.

2. **Fase 2 — Peregrinación.**
   El **transporte** del valor entre zonas. Es el punto de **máximo riesgo**:
   aquí viven las zonas PvP *full-loot*. El valor "en tránsito" es vulnerable a
   ser robado, lo que convierte a esta fase en el principal motor de tensión y
   en la justificación directa del *Protocolo Atómico de Transacción*
   (anti-duplicación) de SYSTEM_FOUNDATION.

3. **Fase 3 — Refinamiento / Servicios.**
   Zonas interiores más seguras donde el valor se **procesa, repara y comercia**:
   refinado de materiales, mantenimiento de artefactos (sumidero de ADR-001) y
   comercio jugador-a-jugador. Convierte el riesgo asumido en las fases previas
   en progreso y beneficio.

### Consecuencias
* **Positivas**:
  * Gradiente de riesgo explícito (bajo → máximo → bajo) que crea un bucle
    económico con tensión natural y favorece la emergencia de un mercado.
  * Encaja orgánicamente con ADR-001 (sumidero) y con el protocolo atómico
    (la Fase 2 es exactamente donde el *duping* sería más rentable).
* **Negativas / Pendiente (TBD)**:
  * Este ADR fija la **estructura** de las 3 fases, NO los números de balance
    (rendimientos, ratios de riesgo/recompensa, tamaños de zona). Eso queda
    sujeto a playtest.
  * Aumenta la complejidad del diseño de mundo y de la simulación por ticks.

---

## ADR-003: Estrategia "Híbrido Controlado" para los dos núcleos paralelos

### Estado
**Aceptado**

### Contexto
Un diagnóstico técnico del repo (HEAD posterior al commit `fc4f483`, "Add system
foundation and update scripts") detectó **dos implementaciones paralelas del
mismo subsistema** conviviendo en el árbol:

- **Conjunto A (vivo)** en `scripts/`: el juego single-player de recolección/
  crafteo de la Fase 1. Arranca y es jugable. `GameState`, `Database`,
  `Inventory` (RefCounted, 20 slots), `CraftingSystem`, `ResourceNode`, `Player`.
- **Conjunto B (huérfano / código muerto)** en `core/` y `systems/`: un MMO
  síncrono server-authoritative (`CoreTimeManager`, `ConstantsCore`,
  `InventoryManager`, `InventorySlot`, `PartyManager`) con `@rpc` y
  `multiplayer`. **No estaba registrado en `project.godot`** ni instanciado en
  ninguna escena: invisible en runtime.

Sobre ese diagnóstico se recibió un **prompt de refactor** ("Ingeniero Principal /
servidor autoritativo") que, en la práctica, ordenaba un **pivote total a B**:
borrar el inventario vivo de A del `project.godot` y registrar `PartyManager`
como autoload. Ese pivote (a) **rompería el juego** —`GameState`, `ResourceNode`,
`CraftingSystem` y `main.tscn` dependen del inventario de A— y (b) introduciría
multijugador/facciones, que están **fuera del alcance de la Fase 1**
(ver VISION.md y ROADMAP.md: "sin backend ni multijugador en esta fase").

### Decisión
Adoptar una estrategia **"Híbrido Controlado"**: incorporar **solo** el blindaje
de ingeniería que el conjunto A necesita de todas formas, sin arrastrar el MMO.

1. **Adoptar de B (Fase 1):** el modelo de slot como `Resource`
   (`InventorySlot`), el **bloqueo atómico con snapshots y rollback**, el
   **contenedor de desborde (overflow) con expiración por ticks**, las
   **constantes centralizadas** (`ConstantsCore`) y el **reloj de ticks por
   `Timer`** (`CoreTimeManager`) con su *tick slicing*.
2. **Diferir de B (Fase MMO):** registro de `PartyManager`, toda la capa
   `@rpc`/`multiplayer`, el disparador `peer_disconnected`, la persistencia de
   overflow por `player_session_id` y las constantes `STAMINA_*` / `MERCENARY_*`
   / `PVP_*` / `PARTY_*`. Se reubican a `systems/_deferred/` (no se cargan).
3. **Preservar de A:** el bucle jugable y, crucialmente, la **API de inventario**
   que consumen `CraftingSystem`, `ResourceNode` y `GameState`
   (`add_item/remove_item/has_item/get_count/find_tool_slot/wear_tool` +
   apilado de fungibles). El conjunto B **no** la implementaba; el trabajo
   central del híbrido es unificar ambos modelos sobre `InventorySlot`
   sin perder esa API.

### Desviaciones explícitas frente al prompt de refactor
Se documentan porque contradicen instrucciones literales del prompt, de forma
deliberada y justificada:

- **NO** se registra `PartyManager` como autoload (es MMO, fuera de alcance).
- **NO** se borra el inventario de A hasta migrar su API al núcleo unificado
  (borrarlo antes rompe el juego).
- **NO** se crean constantes duplicadas: el prompt pedía
  `OVERFLOW_EXPIRATION_TICKS`, `SCRAP_STACK_MAX`, `DURABILITY_REDUCTION_FACTOR`
  que ya existen como `OVERFLOW_EXPIRY_TICKS`, `SCRAP_STACK_MAX` y
  `REPAIR_MAX_DURABILITY_PENALTY` (= 1 − 0.90). Se conserva un nombre canónico
  por concepto y solo se añade lo nuevo (`REPAIR_COST_MODIFIER`).
- Canon del esquema de metadatos de chatarra: `quality: int` (0–100, %) +
  `poi_origin: String` (reconcilia el `quality: float` del código y el `poi_id`
  del DOCUMENTO MAESTRO).

### Consecuencias
* **Positivas**:
  * El juego sigue arrancando y siendo jugable en cada paso del refactor.
  * Se obtiene el blindaje anti-duping (transacciones atómicas) que la Fase 2
    (Peregrinación / PvP) exigirá, sin comprometerse aún con el MMO.
  * Se elimina la ambigüedad de "qué código es el real": A se unifica con lo
    valioso de B; el resto de B queda explícitamente diferido.
* **Negativas / Pendiente (TBD)**:
  * El conjunto diferido en `systems/_deferred/` queda como deuda técnica
    documentada hasta la Fase MMO.
  * La unificación de los modelos fungible (A) y chatarra/certificación (B)
    sobre un único `InventorySlot` añade complejidad al slot.
