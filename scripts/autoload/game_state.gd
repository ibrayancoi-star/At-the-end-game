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

## Se emite cuando el jugador elige/cambia de facción.
signal faction_changed(new_faction: int)

## El inventario del jugador (lógica pura, ver systems/inventory/inventory.gd).
var inventory: Inventory

## Oro: nuestra moneda interna. De momento es solo una estructura básica;
## TODAVÍA SIN mercado (eso es de fases futuras, ver docs/ROADMAP.md).
var gold: int = 0

## Facción del jugador (valor de PartyRules.Faction; -1 = sin elegir todavía).
## Solo IDENTIDAD por ahora: combate, habilidades y colonias son fases futuras.
## La selección real se hará en la UI; de momento se fija con set_player_faction.
var player_faction: int = -1


func _ready() -> void:
	# Creamos el inventario al arrancar (28 slots, ConstantsCore.INVENTORY_SLOTS).
	inventory = Inventory.new()
	# Cableamos el reloj global: GameState (Node) conecta la señal de ticks a la
	# purga de overflow del inventario (que es lógica pura y no toca el árbol).
	CoreTimeManager.tick_elapsed.connect(inventory.purge_expired_overflow)


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


## Fija la facción del jugador. Valida contra PartyRules.Faction.
## Devuelve false (sin cambiar nada) si el valor no es una facción válida.
func set_player_faction(faction: int) -> bool:
	if faction < 0 or faction > PartyRules.Faction.MERCENARY:
		push_error("GameState.set_player_faction: facción inválida %d." % faction)
		return false
	player_faction = faction
	faction_changed.emit(player_faction)
	return true


## Devuelve el perfil (FactionData) de la facción del jugador, o null si no eligió.
func get_player_faction_data() -> FactionData:
	for f: FactionData in Database.all_factions():
		if f.faction_type == player_faction:
			return f
	return null
