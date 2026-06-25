extends Node
## CoreTimeManager (autoload / singleton) — RELOJ CENTRAL DEL SERVIDOR.
##
## Implementación autoritativa del reloj de ticks para el MMO síncrono.
## Usa un Timer node de 0.6 segundos (no delta acumulado) para garantizar
## intervalos fijos independientes de los FPS del proceso.
##
## Incluye Tick Slicing para segmentar cargas secundarias de entidades
## en sub-grupos de 10, distribuyendo el procesamiento pesado entre ticks.
##
## Registrado como autoload en project.godot.
## Acceso global: CoreTimeManager.current_tick, CoreTimeManager.tick_elapsed


## Se emite UNA vez por cada tick transcurrido. El argumento es el número
## de tick (el mismo valor que `current_tick` en ese instante).
signal tick_elapsed(tick_count: int)

## Contador monótono de ticks desde el arranque del servidor.
## Es la "hora oficial" del mundo: serializable, nunca retrocede.
var current_tick: int = 0

## Referencia interna al Timer node. Privado.
var _tick_timer: Timer = null

## Permite congelar el reloj (depuración del servidor) sin destruir el Timer.
var _paused: bool = false


func _ready() -> void:
	_tick_timer = Timer.new()
	_tick_timer.wait_time = ConstantsCore.TICK_DURATION
	_tick_timer.one_shot = false
	_tick_timer.autostart = true
	_tick_timer.timeout.connect(_on_tick_timeout)
	add_child(_tick_timer)


## Callback del Timer. Incrementa el tick y emite la señal global.
func _on_tick_timeout() -> void:
	if _paused:
		return

	current_tick += 1
	tick_elapsed.emit(current_tick)


# =============================================================================
# TICK SLICING — Distribución de carga entre entidades
# =============================================================================

## Determina si una entidad debe procesarse en este tick específico.
## Divide las entidades en 10 sub-grupos basándose en su ID.
## Útil para distribuir operaciones costosas (regeneración de estamina,
## degradación de artefactos, expiración de overflow) entre ticks.
##
## Ejemplo: si entity_id=23 y tick_index=3 → (23 % 10) == (3 % 10) → true.
## Esa entidad solo se procesa en ticks cuyo índice termine en 3.
static func is_entity_tick(entity_id: int, tick_index: int) -> bool:
	return (entity_id % 10) == (tick_index % 10)


# =============================================================================
# CONTROL DEL RELOJ
# =============================================================================

## Pausa el reloj. El Timer sigue corriendo pero los ticks no se emiten.
## Útil para depuración del servidor o eventos globales de pausa.
func pause() -> void:
	_paused = true


## Reanuda el reloj.
func resume() -> void:
	_paused = false


## Devuelve si el reloj está pausado.
func is_paused() -> bool:
	return _paused


## Convierte un número de ticks a segundos reales.
## Útil para cálculos de duración y logs del servidor.
static func ticks_to_seconds(ticks: int) -> float:
	return ticks * ConstantsCore.TICK_DURATION


## Convierte segundos reales a ticks (redondeando hacia abajo).
## Útil para convertir duraciones de diseño a unidades de simulación.
static func seconds_to_ticks(seconds: float) -> int:
	if ConstantsCore.TICK_DURATION <= 0.0:
		push_error("CoreTimeManager: TICK_DURATION es <= 0, imposible convertir.")
		return 0
	return int(seconds / ConstantsCore.TICK_DURATION)
