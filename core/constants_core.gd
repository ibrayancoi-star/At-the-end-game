extends Node
## ConstantsCore (autoload / singleton) — CONSTANTES CENTRALES DE SIMULACIÓN.
##
## Fuente única de verdad para los valores numéricos que rigen la simulación.
## Ningún sistema debe hardcodear estos valores: siempre referir a
## ConstantsCore.NOMBRE_CONSTANTE.
##
## Registrado como autoload en project.godot (el PRIMERO: el resto depende de él).
## Acceso global: ConstantsCore.TICK_DURATION, etc.
##
## ORGANIZACIÓN (ver ADR-003 "Híbrido Controlado" en docs/architecture):
##   - "FASE 1 ACTIVA": constantes en uso por el juego single-player actual.
##   - "DIFERIDO (MMO)": constantes que solo usa el código de systems/_deferred/
##     (party, RPC, estamina...). Se conservan para que ese código compile, pero
##     NO forman parte del alcance de la Fase 1.


# =============================================================================
# FASE 1 ACTIVA
# =============================================================================

# --- Motor de ticks ---

## Duración de un Game Tick en segundos. Regla del mundo: inmutable en runtime.
const TICK_DURATION: float = 0.6

## Número de "cubos" para el Tick Slicing (reparto de carga entre ticks).
## Una entidad procesa su lógica pesada 1 de cada TICK_SLICE_BUCKETS ticks.
const TICK_SLICE_BUCKETS: int = 10

# --- Inventario ---

## Número fijo de slots del inventario de cada jugador.
const INVENTORY_SLOTS: int = 28

## Tamaño máximo de pila para chatarra no identificada.
const SCRAP_STACK_MAX: int = 5

## Ticks que dura el contenedor de desborde temporal antes de expirar.
## 500 ticks × 0.6s = 300 segundos = 5 minutos.
const OVERFLOW_EXPIRY_TICKS: int = 500

# --- Reparación (sumidero económico) ---

## Fracción de durabilidad máxima absoluta que se pierde permanentemente por
## cada reparación exitosa. Irreversible. (0.10 = pierde el 10%; equivale a
## conservar el 90% — descartamos el nombre alternativo DURABILITY_REDUCTION_FACTOR
## para no duplicar el concepto, ver ADR-003.)
const REPAIR_MAX_DURABILITY_PENALTY: float = 0.10

## Multiplicador base del coste de reparación. 1.0 = sin modificación.
## Punto de ajuste para futuros eventos económicos o dificultad.
const REPAIR_COST_MODIFIER: float = 1.0

# --- Habilidades (multi-skill, ver ADR-004 y docs/SYSTEM_FOUNDATION.md) ---

## Nivel máximo de cualquier habilidad.
const SKILL_MAX_LEVEL: int = 99

## base_xp de la curva XP(N) = trunc(base_xp · N^1.5). Un jugador sin XP es nivel 0.
const SKILL_XP_BASE: float = 100.0

# --- Ingeniería inversa (escalado por habilidad; placeholders, balance TBD) ---

## Nivel de Ingeniería que permite ANALIZAR (escanear) sin herramienta ni máquina.
const ENGINEERING_ANALYSIS_MIN_LEVEL: int = 10

## Ticks base de un análisis/escaneo (la ejecución temporizada está diferida).
const ANALYSIS_BASE_TICKS: int = 3

## Factor de durabilidad del objeto ensamblado a nivel 0 de ingeniería.
## A nivel máximo el factor es 1.0 (se interpola linealmente por nivel).
const ASSEMBLY_DURABILITY_MIN_FACTOR: float = 0.4

## Ticks base de ensamblaje (a habilidad alta).
const ASSEMBLY_BASE_TICKS: int = 5

## Ticks EXTRA de ensamblaje a nivel 0 de ingeniería (decrecen con el nivel).
const ASSEMBLY_TICKS_PENALTY_MAX: int = 10


# =============================================================================
# DIFERIDO (MMO) — usado solo por systems/_deferred/ (no Fase 1, ver ADR-003)
# =============================================================================

# --- Estamina ---
const STAMINA_MAX: float = 100.0
const STAMINA_REGEN_REPOSO: float = 5.0           ## cada 2 ticks (1.2s)
const STAMINA_REGEN_MOVIMIENTO: float = 1.0       ## cada 2 ticks (1.2s)
const COST_BASE_CRAFTEO: float = 10.0
const COST_BASE_DESGUACE: float = 8.0
const COST_BASE_ESCANEO_CAMPO: float = 5.0

# --- Mercenario en solitario ---
const MERCENARY_SOLO_STAMINA_PENALTY: float = 1.25
const MERCENARY_SOLO_TICK_SPEED_MODIFIER: float = 1.25

# --- PvP ---
const PVP_COMBAT_TAG_DURATION_TICKS: int = 20     ## 12 segundos reales

# --- Party (límites por composición de facciones) ---
const PARTY_MAX_MIXED: int = 4
const PARTY_MAX_PURE_MERCENARY: int = 5
const PARTY_MAX_PURE_FACTION: int = 6
