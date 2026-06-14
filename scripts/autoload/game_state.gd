extends Node
## GameState (autoload / singleton) — el ESTADO de la partida del jugador:
## su inventario y su oro.
##
## En esta fase de UN jugador, este estado vive aquí, en el cliente. Pero
## está deliberadamente aislado de cualquier nodo visual porque, cuando llegue
## el servidor, ESTE es exactamente el estado que pasará a ser propiedad del
## servidor (AUTORIDAD DE SERVIDOR). El objetivo es que ese día solo haya que
## cambiar "quién ejecuta esto", no "cómo está escrito".
##
## Se accede desde cualquier script con: GameState.inventory, GameState.gold...

## Se emite cuando cambia el oro, para que la UI lo refleje.
signal gold_changed(new_amount: int)

## El inventario del jugador (lógica pura, ver scripts/systems/inventory.gd).
var inventory: Inventory

## Oro: nuestra moneda interna. De momento es solo una estructura básica;
## TODAVÍA SIN mercado (eso es de fases futuras, ver docs/ROADMAP.md).
var gold: int = 0


func _ready() -> void:
	# Creamos el inventario al arrancar. 20 huecos para empezar.
	inventory = Inventory.new(20)


## Añade oro (un GRIFO de la economía: así entra valor al juego).
func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


## Gasta oro. Devuelve false si no hay suficiente (no se gasta nada).
func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true
