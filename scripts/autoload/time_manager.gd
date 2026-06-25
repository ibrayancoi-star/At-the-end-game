extends Node
## TimeManager (autoload / singleton) — el RELOJ CENTRAL del juego.
##
## El juego no piensa en "segundos", piensa en GAME TICKS:
##     1 Game Tick = 0.6 segundos  (igual que RuneScape).
##
## Toda la lógica de simulación (degradación de artefactos, recolección,
## movimiento por casillas...) debe "latir" al ritmo de este reloj, NO usar
## `delta` crudo por su cuenta. Así conseguimos:
##   - Determinismo: el mundo avanza en pasos fijos e idénticos.
##   - Preparación para servidor: el futuro servidor procesará los inputs de
##     todos los jugadores en "paquetes" cada 0.6 s. Este contador ES esa
##     línea temporal canónica.
##
## Se accede desde cualquier script: TimeManager.current_tick, o conectándose
## a la señal: TimeManager.tick_elapsed.connect(mi_funcion)
##
## Ver docs/SYSTEM_FOUNDATION.md (sección "El Tiempo del Mundo").

## Duración de un tick en segundos. Constante: es una regla del mundo.
const TICK_DURATION: float = 0.6

## Se emite UNA vez por cada tick transcurrido. El argumento es el número de
## tick (el mismo valor que `current_tick` en ese instante).
signal tick_elapsed(tick_count: int)

## Contador monótono de ticks desde el arranque. Es la "hora oficial" del
## mundo: serializable (va a la BD el día de mañana) y nunca retrocede.
var current_tick: int = 0

## Permite congelar el tiempo (menús, pausa, depuración) sin desconectar nada.
var paused: bool = false

# Acumulador interno de tiempo real. Privado (convención "_"): nadie de fuera
# debería tocarlo.
var _accumulator: float = 0.0


func _process(delta: float) -> void:
	if paused:
		return

	# Acumulamos el tiempo real transcurrido este frame.
	_accumulator += delta

	# Usamos `while` (no `if`) a propósito: si un frame tarda mucho (un parón,
	# carga de escena...) y han "cabido" varios ticks, los procesamos TODOS y
	# nos ponemos al día. Esto desacopla la simulación de los FPS: el mundo
	# avanza siempre a 0.6 s por tick, vaya el juego a 60 o a 20 FPS.
	while _accumulator >= TICK_DURATION:
		_accumulator -= TICK_DURATION
		current_tick += 1
		tick_elapsed.emit(current_tick)


## Pausa el reloj (deja de emitir ticks). El acumulador se conserva.
func pause() -> void:
	paused = true


## Reanuda el reloj.
func resume() -> void:
	paused = false


## Devuelve cuántos SEGUNDOS reales representa un número de ticks dado.
## Útil para mostrar tiempos en la UI o calcular duraciones de acciones.
func ticks_to_seconds(ticks: int) -> float:
	return ticks * TICK_DURATION
