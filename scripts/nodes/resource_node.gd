## ResourceNode — un recurso recolectable del mundo (árbol, roca, planta...).
##
## Es la parte VISUAL / de escena de un recurso. La lógica de inventario NO
## está aquí: cuando el jugador recolecta, este nodo solo calcula "doy tanto
## de tal item" y DELEGA en el Inventory el guardarlo.
##
## Todo lo configurable está como @export: así el MISMO script y la MISMA
## escena sirven para un árbol, una roca o una planta, cambiando solo datos
## en el editor. Eso es diseño dirigido por datos otra vez.
class_name ResourceNode
extends Area2D

## Qué item entrega al recolectar (un id que debe existir en Database).
@export var yields_item_id: String = "madera"

## Cuánto da recolectando A MANO (sin la herramienta adecuada).
@export var base_yield: int = 1

## Tipo de herramienta que potencia esta recolección (ej. "axe" para árboles,
## "pickaxe" para rocas). Si el jugador lleva una herramienta de este tipo,
## recolecta más y la herramienta se desgasta.
@export var tool_type: String = "axe"

## Cuántas veces se puede recolectar antes de agotarse.
@export var max_harvests: int = 5

# Estado interno en partida: cuántas recolecciones quedan.
var _harvests_left: int = 0


func _ready() -> void:
	_harvests_left = max_harvests


## Lo llama el jugador al interactuar. Devuelve un texto de feedback.
func harvest() -> String:
	if _harvests_left <= 0:
		return "Este recurso está agotado."

	var inv: Inventory = GameState.inventory
	var amount := base_yield
	var extra_msg := ""

	# ¿Lleva el jugador una herramienta adecuada para este recurso?
	var tool_slot := inv.find_tool_slot(tool_type)
	if tool_slot != -1:
		var tool_item := Database.get_item(inv.slots[tool_slot].item_id) as ToolData
		amount += tool_item.gather_bonus
		# Usar la herramienta la desgasta (SUMIDERO económico principal).
		var broke := inv.wear_tool(tool_slot, tool_item.wear_per_use)
		if broke:
			extra_msg = " (¡tu %s se ha roto!)" % tool_item.display_name

	# GRIFO económico: aquí entra valor nuevo a la economía (recurso recolectado).
	inv.add_item(yields_item_id, amount)

	_harvests_left -= 1
	if _harvests_left <= 0:
		# De momento solo lo ocultamos y lo desactivamos. Más adelante:
		# un temporizador para que el recurso reaparezca (regeneración).
		hide()
		set_deferred("monitorable", false)

	return "+%d %s%s" % [amount, yields_item_id, extra_msg]
