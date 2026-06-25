class_name Inventory
extends RefCounted
## Inventory — LÓGICA PURA y AUTORITATIVA del inventario. Sin nada visual.
##
## Unifica dos modelos (ver ADR-003 "Híbrido Controlado"):
##   - FUNGIBLE + HERRAMIENTAS (del conjunto A): apilado por cantidad y desgaste
##     de herramientas. Es lo que el bucle de Fase 1 (recolección/crafteo) usa.
##   - SLOTS COMO RESOURCE + ATOMICIDAD (del conjunto B): 28 slots `InventorySlot`,
##     transacciones con snapshot/rollback (anti-duping) y contenedor de desborde
##     (overflow) con expiración por ticks.
##
## Es un RefCounted (objeto de datos), NO un Node: server-portable. La UI se
## engancha a la señal `changed`. La capa de red (@rpc) y la economía de chatarra
## (certificar/desguazar/reparar) viven DIFERIDAS en systems/_deferred/ hasta la
## fase MMO; aquí solo está lo que la Fase 1 necesita + el blindaje atómico.


## Se emite cada vez que cambia el contenido (para refrescar la UI).
signal changed

## Los slots del inventario (siempre INVENTORY_SLOTS elementos, nunca null).
var slots: Array[InventorySlot] = []

# --- Contenedor de Desborde (overflow) ---
# Clave única -> { "item_id": String, "quantity": int, "expiry_tick": int }
var _overflow: Dictionary = {}
var _overflow_counter: int = 0

# --- Estado de transacción atómica ---
var _tx_snapshot: Array = []
var _tx_active: bool = false


## Constructor. Por defecto usa ConstantsCore.INVENTORY_SLOTS (28).
func _init(p_size: int = -1) -> void:
	var n: int = p_size if p_size > 0 else ConstantsCore.INVENTORY_SLOTS
	slots.clear()
	for i: int in range(n):
		slots.append(InventorySlot.new())
	# NOTA: este objeto es lógica pura (RefCounted), no se conecta solo al reloj.
	# Quien lo posee (GameState, un Node) cablea CoreTimeManager.tick_elapsed a
	# purge_expired_overflow(). Así el inventario no depende del árbol de nodos.


# =============================================================================
# API FUNGIBLE / HERRAMIENTAS  (consumida por CraftingSystem, ResourceNode…)
# =============================================================================

## Añade `amount` unidades de un ítem.
## - Fungibles: apilan hasta ItemData.max_stack repartidos en slots.
## - Herramientas (ToolData): cada una ocupa su slot con su durabilidad.
## Lo que no quepa en los slots va al overflow si `allow_overflow` es true;
## si es false, NO se almacena y se devuelve como sobrante.
## Devuelve cuántas unidades quedaron SIN colocar en los slots principales
## (0 = todo cupo en slots; si allow_overflow, ese resto está en el overflow).
func add_item(item_id: String, amount: int = 1, allow_overflow: bool = true) -> int:
	var item: ItemData = Database.get_item(item_id)
	if item == null:
		push_error("Inventory.add_item: item desconocido '%s'." % item_id)
		return amount

	var remaining: int = amount
	var is_tool: bool = item is ToolData

	if is_tool:
		# Una herramienta por slot vacío, con su durabilidad inicial.
		var tool: ToolData = item as ToolData
		for i: int in range(slots.size()):
			if remaining <= 0:
				break
			if slots[i].is_empty():
				slots[i].set_identified_item(item_id, tool.max_durability, tool.max_durability)
				remaining -= 1
	else:
		var stack_limit: int = item.max_stack
		# Paso 1: rellenar pilas fungibles existentes del mismo item.
		for i: int in range(slots.size()):
			if remaining <= 0:
				break
			var slot: InventorySlot = slots[i]
			if slot.item_id == item_id and slot.is_identified and slot.quantity < stack_limit:
				var space: int = stack_limit - slot.quantity
				var moved: int = min(space, remaining)
				slot.quantity += moved
				remaining -= moved
		# Paso 2: usar slots vacíos.
		for i: int in range(slots.size()):
			if remaining <= 0:
				break
			if slots[i].is_empty():
				var qty: int = min(stack_limit, remaining)
				slots[i].set_fungible_item(item_id, qty)
				remaining -= qty

	if remaining < amount:
		changed.emit()

	# Lo que no cupo: al overflow o devuelto como sobrante.
	if remaining > 0 and allow_overflow:
		_add_to_overflow(item_id, remaining)
		return 0
	return remaining


## ¿Cabe `amount` de este item en los slots principales (sin contar overflow)?
func can_add(item_id: String, amount: int = 1) -> bool:
	var item: ItemData = Database.get_item(item_id)
	if item == null:
		return false
	var capacity: int = 0
	var is_tool: bool = item is ToolData
	for slot: InventorySlot in slots:
		if slot.is_empty():
			capacity += 1 if is_tool else item.max_stack
		elif not is_tool and slot.item_id == item_id and slot.is_identified:
			capacity += item.max_stack - slot.quantity
		if capacity >= amount:
			return true
	return capacity >= amount


## Quita `amount` unidades del item. TODO O NADA: si no hay suficientes, no toca
## nada y devuelve false.
func remove_item(item_id: String, amount: int = 1) -> bool:
	if get_count(item_id) < amount:
		return false

	var remaining: int = amount
	for i: int in range(slots.size() - 1, -1, -1):
		if remaining <= 0:
			break
		var slot: InventorySlot = slots[i]
		if slot.item_id == item_id and slot.is_identified and slot.hidden_metadata_array.is_empty():
			var taken: int = min(slot.quantity, remaining)
			slot.quantity -= taken
			remaining -= taken
			if slot.quantity <= 0:
				slot.clear_slot()

	changed.emit()
	return true


## ¿Cuántas unidades de este item hay (sumando todos los slots)?
func get_count(item_id: String) -> int:
	var total: int = 0
	for slot: InventorySlot in slots:
		if slot.item_id == item_id:
			total += slot.get_real_count()
	return total


## ¿Hay al menos `amount` unidades de este item?
func has_item(item_id: String, amount: int = 1) -> bool:
	return get_count(item_id) >= amount


## Busca el primer slot con una herramienta del tipo pedido (ej. "axe").
## Devuelve el índice, o -1 si no hay ninguna.
func find_tool_slot(tool_type: String) -> int:
	for i: int in range(slots.size()):
		var slot: InventorySlot = slots[i]
		if slot.is_empty():
			continue
		var item: ItemData = Database.get_item(slot.item_id)
		if item is ToolData and (item as ToolData).tool_type == tool_type:
			return i
	return -1


## Aplica desgaste a la herramienta de un slot. Si su durabilidad llega a 0, la
## herramienta se rompe (el slot se vacía). Devuelve true si se rompió.
func wear_tool(slot_index: int, amount: int) -> bool:
	if slot_index < 0 or slot_index >= slots.size():
		return false
	var slot: InventorySlot = slots[slot_index]
	if slot.is_empty():
		return false

	slot.current_durability -= amount
	var broke: bool = false
	if slot.current_durability <= 0.0:
		slot.clear_slot()
		broke = true

	changed.emit()
	return broke


# =============================================================================
# TRANSACCIONES ATÓMICAS (anti-duping)
# =============================================================================
# Patrón: begin_transaction() -> operar -> commit_transaction() si todo fue bien,
# o rollback_transaction() para restaurar el estado exacto previo. Tomamos un
# snapshot completo de los 28 slots: simple y 100% correcto para single-player.

## Inicia una transacción: guarda un snapshot completo de los slots.
func begin_transaction() -> void:
	_tx_snapshot = _snapshot_all()
	_tx_active = true


## Confirma la transacción: descarta el snapshot (los cambios se quedan).
func commit_transaction() -> void:
	_tx_snapshot = []
	_tx_active = false


## Revierte la transacción: restaura los slots al estado del snapshot.
func rollback_transaction() -> void:
	if not _tx_active:
		return
	_restore_all(_tx_snapshot)
	_tx_snapshot = []
	_tx_active = false
	changed.emit()


func _snapshot_all() -> Array:
	var snap: Array = []
	for slot: InventorySlot in slots:
		var meta_copy: Array = []
		for m: Dictionary in slot.hidden_metadata_array:
			meta_copy.append(m.duplicate())
		snap.append({
			"item_id": slot.item_id,
			"quantity": slot.quantity,
			"is_identified": slot.is_identified,
			"is_locked": slot.is_locked,
			"current_durability": slot.current_durability,
			"max_durability_absolute": slot.max_durability_absolute,
			"hidden_metadata_array": meta_copy,
		})
	return snap


func _restore_all(snap: Array) -> void:
	for i: int in range(slots.size()):
		var s: Dictionary = snap[i]
		var slot: InventorySlot = slots[i]
		slot.item_id = s["item_id"]
		slot.quantity = s["quantity"]
		slot.is_identified = s["is_identified"]
		slot.is_locked = s["is_locked"]
		slot.current_durability = s["current_durability"]
		slot.max_durability_absolute = s["max_durability_absolute"]
		slot.hidden_metadata_array.clear()
		for m: Dictionary in s["hidden_metadata_array"]:
			slot.hidden_metadata_array.append(m.duplicate())


# =============================================================================
# CHATARRA NO IDENTIFICADA (cimiento para loot de POIs; valida esquema)
# =============================================================================

## Añade una unidad de chatarra no identificada con sus metadatos ocultos.
## Apila en una pila existente (<5) o usa un slot vacío; si no hay sitio, va al
## overflow. Valida el esquema del metadato (quality:int, poi_origin:String).
## Devuelve true si se almacenó (en slot u overflow).
func add_scrap(item_id: String, metadata: Dictionary) -> bool:
	if not InventorySlot.validate_metadata_schema(metadata):
		return false

	# 1) Apilar en chatarra existente del mismo tipo no llena.
	for slot: InventorySlot in slots:
		if slot.item_id == item_id and not slot.is_identified and not slot.is_stack_full():
			if slot.add_metadata(metadata):
				changed.emit()
				return true

	# 2) Slot vacío.
	for slot: InventorySlot in slots:
		if slot.is_empty():
			if slot.set_unidentified_scrap(item_id, metadata):
				changed.emit()
				return true

	# 3) Overflow.
	_add_to_overflow(item_id, 1)
	changed.emit()
	return true


# =============================================================================
# CONTENEDOR DE DESBORDE (overflow) — purga por ticks
# =============================================================================

## Inyecta `amount` unidades de un item al overflow con expiración por ticks.
## Devuelve la clave generada.
func _add_to_overflow(item_id: String, amount: int) -> String:
	_overflow_counter += 1
	var key: String = "overflow_%d" % _overflow_counter
	_overflow[key] = {
		"item_id": item_id,
		"quantity": amount,
		"expiry_tick": CoreTimeManager.current_tick + ConstantsCore.OVERFLOW_EXPIRY_TICKS,
	}
	return key


## Intenta devolver un item del overflow a los slots principales.
func recover_from_overflow(key: String) -> bool:
	if not _overflow.has(key):
		return false
	var data: Dictionary = _overflow[key]
	if not can_add(data["item_id"], data["quantity"]):
		return false
	add_item(data["item_id"], data["quantity"], false)
	_overflow.erase(key)
	changed.emit()
	return true


## Número de entradas actualmente en overflow.
func get_overflow_count() -> int:
	return _overflow.size()


## Purga las entradas del overflow cuyo tiempo ha expirado.
## La cablea GameState a la señal CoreTimeManager.tick_elapsed.
func purge_expired_overflow(tick_count: int) -> void:
	if _overflow.is_empty():
		return
	var expired: Array = []
	for key: String in _overflow.keys():
		if tick_count >= _overflow[key]["expiry_tick"]:
			expired.append(key)
	for key: String in expired:
		_overflow.erase(key)
	if not expired.is_empty():
		changed.emit()
