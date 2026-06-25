class_name InventoryManager
extends Node
## InventoryManager — Gestor AUTORITATIVO del inventario de un jugador.
##
## Instanciable: el servidor crea una instancia por jugador conectado.
## Todas las operaciones de mutación son servidor-autoritativas.
## Los clientes solo envían intenciones vía RPCs "any_peer".
##
## Sistemas implementados:
##   - 28 slots con InventorySlot (Resource)
##   - Contenedor de Desborde Temporal Virtual (overflow con expiración)
##   - Bloqueo atómico de slots (anti-duping)
##   - Reducción irreversible del 10% de durabilidad máxima por reparación
##   - Certificación y desguace de chatarra no identificada


# =============================================================================
# SEÑALES
# =============================================================================

## Emitida cuando el inventario cambia (para sincronización con clientes).
signal inventory_changed(player_id: int)

## Emitida cuando un ítem expira del overflow.
signal overflow_expired(player_id: int, overflow_key: String)

## Emitida cuando se completa una operación de certificación o desguace.
signal scrap_processed(player_id: int, slot_index: int, result_items: Array)


# =============================================================================
# ESTADO DEL INVENTARIO
# =============================================================================

## ID del jugador dueño de este inventario. Asignado al instanciar.
var owner_id: int = -1

## Los 28 slots del inventario.
var slots: Array[InventorySlot] = []

## Contenedor de Desborde Temporal Virtual.
## Clave: String generado único (ej. "overflow_<timestamp>_<index>")
## Valor: Dictionary { "item_id": String, "metadata": Dictionary, "expiry_tick": int,
##                     "is_identified": bool, "durability": float, "max_durability": float }
var _overflow_container: Dictionary = {}

## Contador interno para generar claves únicas de overflow.
var _overflow_counter: int = 0

## Registro de slots bloqueados durante una transacción activa.
## Almacena { slot_index: int → snapshot: Dictionary } para rollback.
var _locked_slots_snapshot: Dictionary = {}


# =============================================================================
# INICIALIZACIÓN
# =============================================================================

func _ready() -> void:
	_initialize_slots()
	# Conectar al reloj del servidor para purgar overflow expirado.
	# NOTA: Engine.has_singleton() es para singletons de MOTOR (módulos C++), NO
	# para autoloads GDScript. Los autoloads se comprueban por su nodo en /root.
	var time_mgr: Node = get_node_or_null("/root/CoreTimeManager")
	if time_mgr != null:
		time_mgr.tick_elapsed.connect(_on_tick_elapsed)
	else:
		push_error("InventoryManager: CoreTimeManager no encontrado en el árbol.")


## Inicializa exactamente 28 slots vacíos.
func _initialize_slots() -> void:
	slots.clear()
	for i: int in range(ConstantsCore.INVENTORY_SLOTS):
		var slot: InventorySlot = InventorySlot.new()
		slots.append(slot)


## Asigna el owner_id después de la creación. Debe llamarse antes de usar.
func setup(p_owner_id: int) -> void:
	owner_id = p_owner_id


# =============================================================================
# CONSULTAS BÁSICAS
# =============================================================================

## Cuenta las ranuras vacías disponibles.
func get_free_slot_count() -> int:
	var count: int = 0
	for slot: InventorySlot in slots:
		if slot.is_empty() and not slot.is_locked:
			count += 1
	return count


## Busca la primera ranura vacía y no bloqueada. Retorna -1 si no hay.
func find_free_slot() -> int:
	for i: int in range(slots.size()):
		if slots[i].is_empty() and not slots[i].is_locked:
			return i
	return -1


## Busca una pila de chatarra no identificada del mismo item_id que no esté
## llena ni bloqueada. Retorna el índice del slot, o -1 si no existe.
func find_stackable_scrap_slot(p_item_id: String) -> int:
	for i: int in range(slots.size()):
		var slot: InventorySlot = slots[i]
		if slot.is_locked:
			continue
		if slot.item_id == p_item_id and not slot.is_identified and not slot.is_stack_full():
			return i
	return -1


## Devuelve la cantidad total de un ítem en el inventario (sumando pilas).
func get_item_count(p_item_id: String) -> int:
	var total: int = 0
	for slot: InventorySlot in slots:
		if slot.item_id == p_item_id:
			total += slot.get_real_count()
	return total


# =============================================================================
# BLOQUEO ATÓMICO DE SLOTS (Anti-Duping)
# =============================================================================

## Bloquea un slot para una transacción atómica.
## Guarda un snapshot del estado actual para posible rollback.
## Retorna true si se bloqueó correctamente.
func lock_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= slots.size():
		push_error("InventoryManager.lock_slot: índice fuera de rango (%d)." % slot_index)
		return false

	var slot: InventorySlot = slots[slot_index]
	if slot.is_locked:
		push_error("InventoryManager.lock_slot: slot %d ya está bloqueado." % slot_index)
		return false

	# Guardar snapshot antes de bloquear.
	_locked_slots_snapshot[slot_index] = _snapshot_slot(slot)
	slot.is_locked = true
	return true


## Desbloquea un slot tras completar exitosamente una transacción.
## Elimina el snapshot (ya no se necesita rollback).
func unlock_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= slots.size():
		push_error("InventoryManager.unlock_slot: índice fuera de rango (%d)." % slot_index)
		return

	slots[slot_index].is_locked = false
	_locked_slots_snapshot.erase(slot_index)


## Hace rollback de TODOS los slots bloqueados a su estado pre-transacción.
## Usado cuando una transacción falla o el jugador se desconecta.
func rollback_locked_slots() -> void:
	for slot_index: int in _locked_slots_snapshot.keys():
		if slot_index >= 0 and slot_index < slots.size():
			_restore_slot_from_snapshot(slot_index, _locked_slots_snapshot[slot_index])
			slots[slot_index].is_locked = false

	_locked_slots_snapshot.clear()
	inventory_changed.emit(owner_id)


## Genera un snapshot serializable del estado de un slot.
func _snapshot_slot(slot: InventorySlot) -> Dictionary:
	var snapshot: Dictionary = {
		"item_id": slot.item_id,
		"is_identified": slot.is_identified,
		"is_locked": slot.is_locked,
		"current_durability": slot.current_durability,
		"max_durability_absolute": slot.max_durability_absolute,
		"hidden_metadata_array": [],
	}
	# Copia profunda del array de metadatos.
	for meta: Dictionary in slot.hidden_metadata_array:
		snapshot["hidden_metadata_array"].append(meta.duplicate())
	return snapshot


## Restaura un slot desde un snapshot.
func _restore_slot_from_snapshot(slot_index: int, snapshot: Dictionary) -> void:
	var slot: InventorySlot = slots[slot_index]
	slot.item_id = snapshot.get("item_id", "")
	slot.is_identified = snapshot.get("is_identified", false)
	slot.current_durability = snapshot.get("current_durability", -1.0)
	slot.max_durability_absolute = snapshot.get("max_durability_absolute", -1.0)
	slot.hidden_metadata_array.clear()
	var meta_array: Array = snapshot.get("hidden_metadata_array", [])
	for meta: Dictionary in meta_array:
		slot.hidden_metadata_array.append(meta.duplicate())


# =============================================================================
# CONTENEDOR DE DESBORDE TEMPORAL VIRTUAL
# =============================================================================

## Inyecta un ítem en el overflow con expiración de 500 ticks (5 minutos).
## Retorna la clave generada del ítem en overflow.
func _add_to_overflow(p_item_id: String, metadata: Dictionary,
		p_is_identified: bool, p_durability: float,
		p_max_durability: float) -> String:

	var time_mgr: Node = get_node_or_null("/root/CoreTimeManager")
	var current_tick: int = 0
	if time_mgr != null:
		current_tick = time_mgr.current_tick

	_overflow_counter += 1
	var key: String = "overflow_%d_%d" % [owner_id, _overflow_counter]

	_overflow_container[key] = {
		"item_id": p_item_id,
		"metadata": metadata.duplicate(),
		"is_identified": p_is_identified,
		"durability": p_durability,
		"max_durability": p_max_durability,
		"expiry_tick": current_tick + ConstantsCore.OVERFLOW_EXPIRY_TICKS,
	}
	return key


## Intenta recuperar un ítem del overflow al inventario principal.
## Retorna true si se movió exitosamente.
func recover_from_overflow(overflow_key: String) -> bool:
	if not _overflow_container.has(overflow_key):
		push_error("InventoryManager.recover_from_overflow: clave '%s' no existe." % overflow_key)
		return false

	var data: Dictionary = _overflow_container[overflow_key]
	var free_index: int = find_free_slot()

	if free_index == -1:
		push_error("InventoryManager.recover_from_overflow: no hay slots libres.")
		return false

	var slot: InventorySlot = slots[free_index]

	if data.get("is_identified", false):
		slot.set_identified_item(
			data.get("item_id", ""),
			data.get("durability", -1.0),
			data.get("max_durability", -1.0)
		)
	else:
		var meta: Dictionary = data.get("metadata", {})
		if meta.has("quality"):
			slot.set_unidentified_scrap(data.get("item_id", ""), meta)
		else:
			# Ítem sin calidad: tratarlo como identificado.
			slot.set_identified_item(
				data.get("item_id", ""),
				data.get("durability", -1.0),
				data.get("max_durability", -1.0)
			)

	_overflow_container.erase(overflow_key)
	inventory_changed.emit(owner_id)
	return true


## Devuelve cuántos ítems hay actualmente en overflow.
func get_overflow_count() -> int:
	return _overflow_container.size()


## Devuelve las claves de los ítems en overflow (para UI o debug).
func get_overflow_keys() -> Array[String]:
	var keys: Array[String] = []
	for key: String in _overflow_container.keys():
		keys.append(key)
	return keys


## Purga ítems expirados del overflow. Llamada cada tick del servidor.
func _purge_expired_overflow(current_tick: int) -> void:
	var expired_keys: Array[String] = []
	for key: String in _overflow_container.keys():
		var data: Dictionary = _overflow_container[key]
		var expiry: int = data.get("expiry_tick", 0)
		if current_tick >= expiry:
			expired_keys.append(key)

	for key: String in expired_keys:
		_overflow_container.erase(key)
		overflow_expired.emit(owner_id, key)


## Callback del tick del servidor.
func _on_tick_elapsed(tick_count: int) -> void:
	_purge_expired_overflow(tick_count)


# =============================================================================
# CERTIFICACIÓN Y DESGUACE DE CHATARRA
# =============================================================================

## Certifica (identifica) una pila de chatarra no identificada.
## Rompe la pila: cada unidad se convierte en un ítem individual con sus
## stats revelados. Si no caben en los 28 slots, van al overflow.
## Retorna un diccionario con el resultado de la operación.
@rpc("authority", "reliable")
func server_certify_scrap(slot_index: int) -> Dictionary:
	var result: Dictionary = {"success": false, "message": "", "items_created": 0, "items_overflowed": 0}

	# Validaciones.
	if slot_index < 0 or slot_index >= slots.size():
		result["message"] = "Índice de slot inválido."
		push_error("InventoryManager.certify: %s" % result["message"])
		return result

	var slot: InventorySlot = slots[slot_index]

	if slot.is_locked:
		result["message"] = "Slot bloqueado por otra transacción."
		return result

	if slot.is_empty():
		result["message"] = "Slot vacío."
		return result

	if slot.is_identified:
		result["message"] = "Ítem ya identificado."
		return result

	if slot.hidden_metadata_array.size() == 0:
		result["message"] = "Sin metadatos de chatarra para certificar."
		return result

	# Bloquear el slot durante la operación.
	if not lock_slot(slot_index):
		result["message"] = "No se pudo bloquear el slot."
		return result

	# Extraer todos los metadatos de la pila.
	var source_item_id: String = slot.item_id
	var metadata_list: Array[Dictionary] = []
	for meta: Dictionary in slot.hidden_metadata_array:
		metadata_list.append(meta.duplicate())

	# Limpiar el slot original (la pila se rompe).
	slots[slot_index].is_locked = false  # Desbloquear temporalmente para clear.
	slot.clear_slot()

	var items_created: int = 0
	var items_overflowed: int = 0

	# Crear un ítem individual por cada metadato.
	for meta: Dictionary in metadata_list:
		var free_index: int = find_free_slot()
		if free_index != -1:
			var target_slot: InventorySlot = slots[free_index]
			target_slot.item_id = source_item_id
			target_slot.is_identified = true
			target_slot.hidden_metadata_array.clear()
			# La calidad del metadato se podría usar para calcular durabilidad.
			target_slot.current_durability = meta.get("quality", 1.0) * 100.0
			target_slot.max_durability_absolute = 100.0
			items_created += 1
		else:
			# No hay espacio: va al overflow.
			_add_to_overflow(source_item_id, meta, true,
				meta.get("quality", 1.0) * 100.0, 100.0)
			items_overflowed += 1

	# Limpiar snapshot del lock ya que la transacción fue exitosa.
	_locked_slots_snapshot.erase(slot_index)

	result["success"] = true
	result["items_created"] = items_created
	result["items_overflowed"] = items_overflowed
	result["message"] = "Certificación completada: %d ítems creados, %d en overflow." % [
		items_created, items_overflowed
	]

	scrap_processed.emit(owner_id, slot_index, metadata_list)
	inventory_changed.emit(owner_id)
	return result


## Desguaza una pila de chatarra no identificada para componentes.
## Consume la chatarra y genera materiales de desguace basados en los metadatos.
## Los sobrantes van al overflow.
@rpc("authority", "reliable")
func server_dismantle_scrap(slot_index: int) -> Dictionary:
	var result: Dictionary = {"success": false, "message": "", "items_created": 0, "items_overflowed": 0}

	# Validaciones.
	if slot_index < 0 or slot_index >= slots.size():
		result["message"] = "Índice de slot inválido."
		push_error("InventoryManager.dismantle: %s" % result["message"])
		return result

	var slot: InventorySlot = slots[slot_index]

	if slot.is_locked:
		result["message"] = "Slot bloqueado por otra transacción."
		return result

	if slot.is_empty():
		result["message"] = "Slot vacío."
		return result

	if slot.is_identified:
		result["message"] = "Solo se puede desguazar chatarra no identificada."
		return result

	if slot.hidden_metadata_array.size() == 0:
		result["message"] = "Sin metadatos de chatarra para desguazar."
		return result

	# Bloquear el slot.
	if not lock_slot(slot_index):
		result["message"] = "No se pudo bloquear el slot."
		return result

	# Extraer metadatos y limpiar el slot fuente.
	var source_item_id: String = slot.item_id
	var metadata_list: Array[Dictionary] = []
	for meta: Dictionary in slot.hidden_metadata_array:
		metadata_list.append(meta.duplicate())

	slots[slot_index].is_locked = false
	slot.clear_slot()

	var items_created: int = 0
	var items_overflowed: int = 0

	# Generar un componente de desguace por cada unidad de la pila.
	# El ID del componente resultante sería "{item_id}_salvage" (convención).
	var salvage_id: String = source_item_id + "_salvage"

	for meta: Dictionary in metadata_list:
		var free_index: int = find_free_slot()
		if free_index != -1:
			var target_slot: InventorySlot = slots[free_index]
			target_slot.item_id = salvage_id
			target_slot.is_identified = true
			target_slot.hidden_metadata_array.clear()
			target_slot.current_durability = -1.0
			target_slot.max_durability_absolute = -1.0
			items_created += 1
		else:
			_add_to_overflow(salvage_id, meta, true, -1.0, -1.0)
			items_overflowed += 1

	_locked_slots_snapshot.erase(slot_index)

	result["success"] = true
	result["items_created"] = items_created
	result["items_overflowed"] = items_overflowed
	result["message"] = "Desguace completado: %d componentes, %d en overflow." % [
		items_created, items_overflowed
	]

	scrap_processed.emit(owner_id, slot_index, metadata_list)
	inventory_changed.emit(owner_id)
	return result


# =============================================================================
# REPARACIÓN — Reducción irreversible de durabilidad máxima
# =============================================================================

## Aplica una reparación exitosa a un ítem funcional.
## Restaura durabilidad actual al máximo absoluto ACTUAL, pero reduce
## permanentemente el máximo absoluto en un 10%.
## Retorna un diccionario con el resultado.
@rpc("authority", "reliable")
func server_repair_item(slot_index: int) -> Dictionary:
	var result: Dictionary = {"success": false, "message": "", "new_max": 0.0, "new_current": 0.0}

	if slot_index < 0 or slot_index >= slots.size():
		result["message"] = "Índice de slot inválido."
		push_error("InventoryManager.repair: %s" % result["message"])
		return result

	var slot: InventorySlot = slots[slot_index]

	if slot.is_locked:
		result["message"] = "Slot bloqueado por otra transacción."
		return result

	if slot.is_empty():
		result["message"] = "Slot vacío."
		return result

	if slot.max_durability_absolute <= 0.0:
		result["message"] = "Este ítem no tiene durabilidad reparable."
		return result

	# Bloquear durante la reparación.
	if not lock_slot(slot_index):
		result["message"] = "No se pudo bloquear el slot."
		return result

	# Aplicar penalización irreversible del 10% al máximo absoluto.
	var old_max: float = slot.max_durability_absolute
	var new_max: float = old_max * (1.0 - ConstantsCore.REPAIR_MAX_DURABILITY_PENALTY)

	# El máximo no puede bajar de 1.0 (mínimo funcional).
	if new_max < 1.0:
		new_max = 1.0

	slot.max_durability_absolute = new_max

	# Restaurar durabilidad actual al nuevo máximo.
	slot.current_durability = new_max

	# Desbloquear: la reparación fue exitosa.
	unlock_slot(slot_index)

	result["success"] = true
	result["new_max"] = new_max
	result["new_current"] = new_max
	result["message"] = "Reparación exitosa. Durabilidad máxima: %.1f → %.1f (penalización permanente del %d%%)." % [
		old_max, new_max, int(ConstantsCore.REPAIR_MAX_DURABILITY_PENALTY * 100)
	]

	inventory_changed.emit(owner_id)
	return result


# =============================================================================
# AÑADIR CHATARRA NO IDENTIFICADA
# =============================================================================

## Añade una unidad de chatarra no identificada al inventario.
## Primero intenta apilar en un slot existente del mismo item_id.
## Si no hay pila disponible, usa un slot vacío.
## Si no hay espacio, va al overflow.
## Retorna un diccionario con el resultado.
@rpc("authority", "reliable")
func server_add_scrap(p_item_id: String, metadata: Dictionary) -> Dictionary:
	var result: Dictionary = {"success": false, "message": "", "slot_index": -1, "overflowed": false}

	if not metadata.has("quality"):
		result["message"] = "Metadato sin campo 'quality'."
		push_error("InventoryManager.add_scrap: %s" % result["message"])
		return result

	# Intentar apilar en pila existente.
	var stack_index: int = find_stackable_scrap_slot(p_item_id)
	if stack_index != -1:
		if slots[stack_index].add_metadata(metadata):
			result["success"] = true
			result["slot_index"] = stack_index
			result["message"] = "Chatarra apilada en slot %d (%d/%d)." % [
				stack_index,
				slots[stack_index].hidden_metadata_array.size(),
				ConstantsCore.SCRAP_STACK_MAX
			]
			inventory_changed.emit(owner_id)
			return result

	# Intentar usar slot vacío.
	var free_index: int = find_free_slot()
	if free_index != -1:
		if slots[free_index].set_unidentified_scrap(p_item_id, metadata):
			result["success"] = true
			result["slot_index"] = free_index
			result["message"] = "Chatarra colocada en slot vacío %d." % free_index
			inventory_changed.emit(owner_id)
			return result

	# Overflow.
	var overflow_key: String = _add_to_overflow(p_item_id, metadata, false, -1.0, -1.0)
	result["success"] = true
	result["overflowed"] = true
	result["message"] = "Inventario lleno. Chatarra enviada a overflow (clave: %s). Expira en %d ticks." % [
		overflow_key, ConstantsCore.OVERFLOW_EXPIRY_TICKS
	]
	inventory_changed.emit(owner_id)
	return result


# =============================================================================
# RPCs DE INTENCIÓN DEL CLIENTE
# =============================================================================

## El cliente solicita certificar chatarra. El servidor valida y ejecuta.
@rpc("any_peer", "call_local", "reliable")
func request_certify_scrap(slot_index: int) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != owner_id and sender_id != 1:  # 1 = servidor
		push_error("InventoryManager.request_certify: jugador %d intentó operar inventario de %d." % [
			sender_id, owner_id
		])
		return
	server_certify_scrap(slot_index)


## El cliente solicita desguazar chatarra.
@rpc("any_peer", "call_local", "reliable")
func request_dismantle_scrap(slot_index: int) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != owner_id and sender_id != 1:
		push_error("InventoryManager.request_dismantle: jugador %d intentó operar inventario de %d." % [
			sender_id, owner_id
		])
		return
	server_dismantle_scrap(slot_index)


## El cliente solicita reparar un ítem.
@rpc("any_peer", "call_local", "reliable")
func request_repair_item(slot_index: int) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != owner_id and sender_id != 1:
		push_error("InventoryManager.request_repair: jugador %d intentó operar inventario de %d." % [
			sender_id, owner_id
		])
		return
	server_repair_item(slot_index)


## El cliente solicita recuperar un ítem del overflow.
@rpc("any_peer", "call_local", "reliable")
func request_recover_overflow(overflow_key: String) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != owner_id and sender_id != 1:
		push_error("InventoryManager.request_recover: jugador %d intentó operar inventario de %d." % [
			sender_id, owner_id
		])
		return
	recover_from_overflow(overflow_key)
