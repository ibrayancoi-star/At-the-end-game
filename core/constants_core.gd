extends Node
## ConstantsCore (autoload / singleton) — CONSTANTES CENTRALES DE SIMULACIÓN.
##
## Fuente única de verdad para todos los valores numéricos que rigen la
## simulación del servidor. Ningún sistema debe hardcodear estos valores:
## siempre referir a ConstantsCore.NOMBRE_CONSTANTE.
##
## Registrado como autoload en project.godot.
## Acceso global: ConstantsCore.STAMINA_MAX, etc.


# =============================================================================
# TICK ENGINE
# =============================================================================

## Duración de un Game Tick en segundos. Regla del mundo: inmutable en runtime.
const TICK_DURATION: float = 0.6


# =============================================================================
# STAMINA
# =============================================================================

## Estamina máxima base de cualquier jugador.
const STAMINA_MAX: float = 100.0

## Regeneración de estamina en reposo (aplicada cada 2 ticks = 1.2s).
const STAMINA_REGEN_REPOSO: float = 5.0

## Regeneración de estamina en movimiento (aplicada cada 2 ticks = 1.2s).
const STAMINA_REGEN_MOVIMIENTO: float = 1.0


# =============================================================================
# COSTOS BASE DE ACCIONES (en estamina)
# =============================================================================

## Costo base de estamina por acción de crafteo.
const COST_BASE_CRAFTEO: float = 10.0

## Costo base de estamina por acción de desguace.
const COST_BASE_DESGUACE: float = 8.0

## Costo base de estamina por escaneo de campo.
const COST_BASE_ESCANEO_CAMPO: float = 5.0


# =============================================================================
# MERCENARY — PENALIZACIONES EN SOLITARIO
# =============================================================================

## Multiplicador de costo de estamina para Mercenarios jugando solos (+25%).
const MERCENARY_SOLO_STAMINA_PENALTY: float = 1.25

## Multiplicador de velocidad de tick para Mercenarios jugando solos (+25%).
## Las acciones del Mercenario solitario tardan un 25% más en ticks.
const MERCENARY_SOLO_TICK_SPEED_MODIFIER: float = 1.25


# =============================================================================
# PVP
# =============================================================================

## Duración del Combat Tag en ticks (20 ticks = 12 segundos reales).
## Mientras el tag está activo, el jugador no puede desconectarse de forma
## segura ni usar ciertas interacciones protegidas.
const PVP_COMBAT_TAG_DURATION_TICKS: int = 20


# =============================================================================
# INVENTARIO
# =============================================================================

## Número fijo de slots del inventario de cada jugador.
const INVENTORY_SLOTS: int = 28

## Tamaño máximo de pila para chatarra no identificada.
const SCRAP_STACK_MAX: int = 5

## Ticks que dura el contenedor de desborde temporal antes de expirar.
## 500 ticks × 0.6s = 300 segundos = 5 minutos.
const OVERFLOW_EXPIRY_TICKS: int = 500


# =============================================================================
# REPARACIÓN
# =============================================================================

## Fracción de durabilidad máxima absoluta que se pierde permanentemente
## por cada reparación exitosa. Irreversible.
const REPAIR_MAX_DURABILITY_PENALTY: float = 0.10


# =============================================================================
# PARTY — INVARIANTE DE ESTADO GLOBAL PROYECTADO
# =============================================================================

## Máximo de miembros en una party mixta (Facción + Mercenarios).
const PARTY_MAX_MIXED: int = 4

## Máximo de miembros en una party de puros Mercenarios.
const PARTY_MAX_PURE_MERCENARY: int = 5

## Máximo de miembros en una party de pura Facción (solo PACTO o solo RESISTENCIA).
const PARTY_MAX_PURE_FACTION: int = 6
