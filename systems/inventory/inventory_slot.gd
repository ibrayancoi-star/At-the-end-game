class_name InventorySlot
extends Resource
## InventorySlot — Modelo de datos de una ranura individual del inventario.
##
## Cada slot puede contener chatarra no identificada (apilable hasta x5 con
## metadatos ocultos de calidad por unidad) o un ítem identificado singular.
##
## El campo `hidden_metadata_array` almacena un diccionario por cada unidad
## en la pila. El tamaño de este array ES el conteo real de la pila.
## Certificar o desguazar la chatarra rompe la pila y revela/consume
## los metadatos individuales.
##
## `is_locked` se activa durante transacciones atómicas del servidor
## (crafteo, trade, reparación) para prevenir duplicación (anti-duping).


# =============================================================================
# PROPIEDADES DEL SLOT
# =============================================================================

## Identificador del ítem en esta ranura. Vacío = slot libre.
@export var item_id: String = ""

## Si la chatarra ha sido certificada/identificada. Los ítems certificados
## revelan sus stats reales y ya no pueden apilarse como chatarra.
@export var is_identified: bool = false

## Bloqueo atómico para persistencia anti-duping. Mientras es true, ninguna
## operación puede leer ni modificar este slot. El servidor lo activa al
## inicio de una transacción y lo libera al commitear o hacer rollback.
@export var is_locked: bool = false

## Array de metadatos ocultos: un diccionario por cada unidad en la pila.
## Máximo estricto: SCRAP_STACK_MAX (5) elementos.
## Cada diccionario contiene la calidad oculta asignada por el POI de origen.
## Ejemplo: [{"quality": 0.73, "poi_id": "ruins_A3"}, {"quality": 0.41, ...}]
@export var hidden_metadata_array: Array[Dictionary] = []

## Durabilidad actual del ítem (solo relevante para ítems funcionales).
## -1.0 significa "no aplica" (no es un ítem con durabilidad).
@export var current_durability: float = -1.0

## Durabilidad máxima absoluta. Se reduce irreversiblemente con cada
## reparación exitosa (penalización del 10%). Empieza igual al máximo
## del ítem y solo puede decrecer.
@export var max_durability_absolute: float = -1.0


# =============================================================================
# MÉTODOS DE CONSULTA
# =============================================================================

## Devuelve true si el slot está vacío (no contiene ningún ítem).
func is_empty() -> bool:
	return item_id == ""


## Devuelve el conteo real de unidades en la pila.
## Para chatarra no identificada, el conteo es el tamaño del array de metadatos.
## Para ítems identificados o sin metadatos, es 1 si el slot tiene ítem, 0 si no.
func get_real_count() -> int:
	if item_id == "":
		return 0
	if not is_identified and hidden_metadata_array.size() > 0:
		return hidden_metadata_array.size()
	# Ítem identificado o sin metadatos: ocupa 1 slot, es 1 unidad.
	return 1


## Devuelve true si la pila de chatarra no identificada está llena (x5).
## Para ítems identificados, siempre retorna true (no apilan).
func is_stack_full() -> bool:
	if is_identified:
		return true
	return hidden_metadata_array.size() >= ConstantsCore.SCRAP_STACK_MAX


# =============================================================================
# MÉTODOS DE MUTACIÓN
# =============================================================================

## Añade un diccionario de metadatos ocultos a la pila.
## Retorna true si se añadió correctamente, false si la pila está llena
## o el slot está bloqueado.
## El diccionario debe contener al menos la clave "quality".
func add_metadata(metadata: Dictionary) -> bool:
	if is_locked:
		push_error("InventorySlot.add_metadata: slot bloqueado, no se puede modificar.")
		return false

	if is_identified:
		push_error("InventorySlot.add_metadata: ítem ya identificado, no acepta metadatos de pila.")
		return false

	if hidden_metadata_array.size() >= ConstantsCore.SCRAP_STACK_MAX:
		push_error("InventorySlot.add_metadata: pila llena (%d/%d)." % [
			hidden_metadata_array.size(), ConstantsCore.SCRAP_STACK_MAX
		])
		return false

	if not metadata.has("quality"):
		push_error("InventorySlot.add_metadata: el diccionario de metadatos debe contener 'quality'.")
		return false

	hidden_metadata_array.append(metadata.duplicate())
	return true


## Extrae y devuelve el último metadato de la pila (pop).
## Retorna un diccionario vacío si la pila está vacía o el slot está bloqueado.
func pop_metadata() -> Dictionary:
	if is_locked:
		push_error("InventorySlot.pop_metadata: slot bloqueado.")
		return {}

	if hidden_metadata_array.size() == 0:
		return {}

	return hidden_metadata_array.pop_back()


## Limpia completamente el slot, dejándolo vacío.
## Respeta el bloqueo: si is_locked, no hace nada y retorna false.
func clear_slot() -> bool:
	if is_locked:
		push_error("InventorySlot.clear_slot: slot bloqueado, no se puede limpiar.")
		return false

	item_id = ""
	is_identified = false
	is_locked = false
	hidden_metadata_array.clear()
	current_durability = -1.0
	max_durability_absolute = -1.0
	return true


## Inicializa el slot con un ítem identificado y durabilidad.
## Usado para ítems funcionales (herramientas, armas, equipamiento).
func set_identified_item(p_item_id: String, p_durability: float, p_max_durability: float) -> bool:
	if is_locked:
		push_error("InventorySlot.set_identified_item: slot bloqueado.")
		return false

	item_id = p_item_id
	is_identified = true
	hidden_metadata_array.clear()
	current_durability = p_durability
	max_durability_absolute = p_max_durability
	return true


## Inicializa el slot como chatarra no identificada con su primer metadato.
func set_unidentified_scrap(p_item_id: String, first_metadata: Dictionary) -> bool:
	if is_locked:
		push_error("InventorySlot.set_unidentified_scrap: slot bloqueado.")
		return false

	if not first_metadata.has("quality"):
		push_error("InventorySlot.set_unidentified_scrap: metadato sin 'quality'.")
		return false

	item_id = p_item_id
	is_identified = false
	hidden_metadata_array.clear()
	hidden_metadata_array.append(first_metadata.duplicate())
	current_durability = -1.0
	max_durability_absolute = -1.0
	return true
