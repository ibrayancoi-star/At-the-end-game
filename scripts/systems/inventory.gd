## Inventory — LÓGICA PURA del inventario. Sin NADA visual.
##
## Esto es un RefCounted (un objeto de datos en memoria), NO un Node. No sabe
## dibujar nada: solo guarda qué tienes y ofrece una API para
## añadir / quitar / consultar. La interfaz gráfica (más adelante) se
## "enganchará" a la señal `changed` y se limitará a MOSTRAR este estado.
##
## ¿Por qué tanto cuidado en separarlo de lo visual? Por el principio de
## AUTORIDAD DE SERVIDOR. El día de mañana esta misma clase puede vivir en el
## servidor, que será quien decida de verdad qué tiene cada jugador.
## Mantenerla libre de nodos hace ese traslado casi indoloro.
class_name Inventory
extends RefCounted

## Se emite cada vez que cambia el contenido. La UI escuchará esto para
## refrescarse sola, en lugar de preguntar constantemente.
signal changed

## Número de huecos del inventario.
var size: int = 20

## Los huecos. Cada hueco es `null` (vacío) o un diccionario:
##   { "item_id": String, "quantity": int, "durability": int }
## - durability = -1 significa "no aplica" (no es una herramienta).
##
## Guardamos diccionarios simples (no objetos complejos) pensando en el futuro:
## son triviales de enviar por red al servidor y de guardar en disco.
var slots: Array = []


## El constructor. Se llama con Inventory.new(20).
func _init(inventory_size: int = 20) -> void:
	size = inventory_size
	slots.resize(size)  # crea `size` huecos rellenos de null


## Añade `amount` unidades del item indicado.
## Devuelve cuántas NO cupieron (0 = cupo todo).
func add_item(item_id: String, amount: int = 1) -> int:
	var item = Database.get_item(item_id)
	if item == null:
		push_error("Inventory.add_item: item desconocido '%s'" % item_id)
		return amount

	var remaining := amount
	var is_tool := item is ToolData
	# Las herramientas no apilan: cada una ocupa su hueco con su durabilidad.
	var stack_limit: int = 1 if is_tool else item.max_stack

	# Paso 1: si el item apila, intenta rellenar montones ya existentes.
	if not is_tool:
		for i in slots.size():
			if remaining <= 0:
				break
			var slot = slots[i]
			if slot != null and slot.item_id == item_id and slot.quantity < stack_limit:
				var space: int = stack_limit - slot.quantity
				var moved: int = min(space, remaining)
				slot.quantity += moved
				remaining -= moved

	# Paso 2: coloca el resto en huecos vacíos.
	for i in slots.size():
		if remaining <= 0:
			break
		if slots[i] == null:
			var qty: int = min(stack_limit, remaining)
			slots[i] = {
				"item_id": item_id,
				"quantity": qty,
				# Si es herramienta, nace con la durabilidad máxima.
				"durability": item.max_durability if is_tool else -1,
			}
			remaining -= qty

	# Solo avisamos a la UI si de verdad entró algo.
	if remaining < amount:
		changed.emit()
	return remaining


## Quita `amount` unidades del item. Es TODO O NADA: si no hay suficientes,
## no toca el inventario y devuelve false.
func remove_item(item_id: String, amount: int = 1) -> bool:
	if get_count(item_id) < amount:
		return false

	var remaining := amount
	# Recorremos de atrás hacia delante para vaciar huecos de forma limpia.
	for i in range(slots.size() - 1, -1, -1):
		if remaining <= 0:
			break
		var slot = slots[i]
		if slot != null and slot.item_id == item_id:
			var taken: int = min(slot.quantity, remaining)
			slot.quantity -= taken
			remaining -= taken
			if slot.quantity <= 0:
				slots[i] = null  # hueco vacío otra vez

	changed.emit()
	return true


## ¿Cuántas unidades de este item hay en total (sumando todos los huecos)?
func get_count(item_id: String) -> int:
	var total := 0
	for slot in slots:
		if slot != null and slot.item_id == item_id:
			total += slot.quantity
	return total


## ¿Hay al menos `amount` unidades de este item?
func has_item(item_id: String, amount: int = 1) -> bool:
	return get_count(item_id) >= amount


## Busca el primer hueco que contenga una herramienta del tipo pedido
## (ej. "axe"). Devuelve el índice del hueco, o -1 si no hay ninguna.
func find_tool_slot(tool_type: String) -> int:
	for i in slots.size():
		var slot = slots[i]
		if slot == null:
			continue
		var item = Database.get_item(slot.item_id)
		if item is ToolData and item.tool_type == tool_type:
			return i
	return -1


## Aplica desgaste a la herramienta de un hueco. Si su durabilidad llega a 0,
## la herramienta se ROMPE (desaparece del inventario).
## Devuelve true si se rompió en esta llamada.
func wear_tool(slot_index: int, amount: int) -> bool:
	var slot = slots[slot_index]
	if slot == null:
		return false

	slot.durability -= amount
	var broke := false
	if slot.durability <= 0:
		slots[slot_index] = null  # la herramienta se ha roto
		broke = true

	changed.emit()
	return broke
