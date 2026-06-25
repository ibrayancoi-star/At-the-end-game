class_name InventorySlot
extends Resource
## InventorySlot — Modelo de datos de una ranura individual del inventario.
##
## Un slot puede estar en UNO de estos modos (ver ADR-003 "Híbrido Controlado"):
##   1. VACÍO            → item_id == ""
##   2. FUNGIBLE         → item_id != "", apila por `quantity` (madera, mineral…)
##   3. IDENTIFICADO ÚNICO → herramienta/equipo con durabilidad, quantity == 1
##   4. CHATARRA NO IDENTIFICADA → apila hasta x5 en `hidden_metadata_array`,
##      preservando la calidad oculta por unidad (metadatos por POI de origen)
##
## El modo FUNGIBLE es lo que el conjunto B original NO tenía y el bucle de
## Fase 1 (recolección/crafteo) necesita. Los modos 3 y 4 vienen del diseño MMO
## y se mantienen para la progresión futura.
##
## `is_locked` se activa durante transacciones atómicas para prevenir
## duplicación (anti-duping): mientras es true, nadie debe leer ni mutar el slot.


# =============================================================================
# PROPIEDADES DEL SLOT
# =============================================================================

## Identificador del ítem en esta ranura. Vacío = slot libre.
@export var item_id: String = ""

## Unidades en el slot para ítems FUNGIBLES (o 1 para identificado único).
## Para chatarra no identificada el conteo lo da `hidden_metadata_array`.
@export var quantity: int = 0

## Si la chatarra ha sido certificada/identificada. Los ítems certificados
## revelan sus stats reales y ya no apilan como chatarra.
@export var is_identified: bool = false

## Bloqueo atómico anti-duping. Mientras es true, ninguna operación puede leer
## ni modificar este slot. El servidor lo activa al iniciar una transacción y lo
## libera al commitear o hacer rollback.
@export var is_locked: bool = false

## Array de metadatos ocultos: un diccionario por cada unidad de chatarra.
## Máximo estricto: SCRAP_STACK_MAX (5). Cada dict debe pasar el esquema
## (ver validate_metadata_schema): { "quality": int 0-100, "poi_origin": String }.
@export var hidden_metadata_array: Array[Dictionary] = []

## Durabilidad actual (solo ítems funcionales). -1.0 = no aplica.
@export var current_durability: float = -1.0

## Durabilidad máxima absoluta. Decrece irreversiblemente con cada reparación
## (penalización fija). Empieza igual al máximo del ítem y solo puede bajar.
@export var max_durability_absolute: float = -1.0


# =============================================================================
# VALIDACIÓN DE ESQUEMA (reutilizable por el inventario)
# =============================================================================

## Verifica que un diccionario de metadatos de chatarra tenga las claves y tipos
## requeridos antes de inyectarlo. Rechaza paquetes malformados con push_error.
## Canon (ADR-003): "quality" (int 0-100) y "poi_origin" (String).
static func validate_metadata_schema(metadata: Dictionary) -> bool:
	if not metadata.has("quality") or typeof(metadata["quality"]) != TYPE_INT:
		push_error("InventorySlot: metadato inválido, falta 'quality' (int 0-100).")
		return false
	if not metadata.has("poi_origin") or typeof(metadata["poi_origin"]) != TYPE_STRING:
		push_error("InventorySlot: metadato inválido, falta 'poi_origin' (String).")
		return false
	return true


# =============================================================================
# MÉTODOS DE CONSULTA
# =============================================================================

## Devuelve true si el slot está vacío (no contiene ningún ítem).
func is_empty() -> bool:
	return item_id == ""


## Devuelve el conteo real de unidades del slot, sea cual sea su modo.
func get_real_count() -> int:
	if item_id == "":
		return 0
	# Chatarra no identificada: el conteo es el tamaño del array de metadatos.
	if not is_identified and hidden_metadata_array.size() > 0:
		return hidden_metadata_array.size()
	# Fungible o identificado único: el conteo es `quantity`.
	return quantity


## Devuelve true si la pila de chatarra no identificada está llena (x5).
## Para ítems identificados, siempre true (no apilan como chatarra).
func is_stack_full() -> bool:
	if is_identified:
		return true
	return hidden_metadata_array.size() >= ConstantsCore.SCRAP_STACK_MAX


# =============================================================================
# MÉTODOS DE MUTACIÓN — MODO FUNGIBLE
# =============================================================================

## Inicializa el slot como ítem FUNGIBLE con una cantidad dada.
## No comprueba el tope de pila (max_stack vive en ItemData): de eso se encarga
## el inventario, que sí tiene acceso a Database.
func set_fungible_item(p_item_id: String, p_quantity: int) -> bool:
	if is_locked:
		push_error("InventorySlot.set_fungible_item: slot bloqueado.")
		return false
	item_id = p_item_id
	quantity = p_quantity
	is_identified = true  # un fungible "se conoce"; no es chatarra por revelar
	hidden_metadata_array.clear()
	current_durability = -1.0
	max_durability_absolute = -1.0
	return true


# =============================================================================
# MÉTODOS DE MUTACIÓN — MODO CHATARRA / IDENTIFICADO
# =============================================================================

## Añade un diccionario de metadatos ocultos a la pila de chatarra.
## Devuelve true si se añadió; false si bloqueado, identificado, pila llena o
## el metadato no cumple el esquema.
func add_metadata(metadata: Dictionary) -> bool:
	if is_locked:
		push_error("InventorySlot.add_metadata: slot bloqueado, no se puede modificar.")
		return false
	if is_identified:
		push_error("InventorySlot.add_metadata: ítem identificado, no acepta metadatos de pila.")
		return false
	if hidden_metadata_array.size() >= ConstantsCore.SCRAP_STACK_MAX:
		push_error("InventorySlot.add_metadata: pila llena (%d/%d)." % [
			hidden_metadata_array.size(), ConstantsCore.SCRAP_STACK_MAX
		])
		return false
	if not validate_metadata_schema(metadata):
		return false

	hidden_metadata_array.append(metadata.duplicate())
	return true


## Extrae y devuelve el último metadato de la pila (pop).
## Devuelve {} si la pila está vacía o el slot está bloqueado.
func pop_metadata() -> Dictionary:
	if is_locked:
		push_error("InventorySlot.pop_metadata: slot bloqueado.")
		return {}
	if hidden_metadata_array.size() == 0:
		return {}
	return hidden_metadata_array.pop_back()


## Inicializa el slot con un ítem identificado y durabilidad (herramientas/equipo).
func set_identified_item(p_item_id: String, p_durability: float, p_max_durability: float) -> bool:
	if is_locked:
		push_error("InventorySlot.set_identified_item: slot bloqueado.")
		return false
	item_id = p_item_id
	is_identified = true
	quantity = 1
	hidden_metadata_array.clear()
	current_durability = p_durability
	max_durability_absolute = p_max_durability
	return true


## Inicializa el slot como chatarra no identificada con su primer metadato.
func set_unidentified_scrap(p_item_id: String, first_metadata: Dictionary) -> bool:
	if is_locked:
		push_error("InventorySlot.set_unidentified_scrap: slot bloqueado.")
		return false
	if not validate_metadata_schema(first_metadata):
		return false

	item_id = p_item_id
	is_identified = false
	quantity = 0
	hidden_metadata_array.clear()
	hidden_metadata_array.append(first_metadata.duplicate())
	current_durability = -1.0
	max_durability_absolute = -1.0
	return true


# =============================================================================
# LIMPIEZA
# =============================================================================

## Limpia completamente el slot, dejándolo vacío.
## Respeta el bloqueo: si is_locked, no hace nada y devuelve false.
func clear_slot() -> bool:
	if is_locked:
		push_error("InventorySlot.clear_slot: slot bloqueado, no se puede limpiar.")
		return false
	item_id = ""
	quantity = 0
	is_identified = false
	hidden_metadata_array.clear()
	current_durability = -1.0
	max_durability_absolute = -1.0
	return true
