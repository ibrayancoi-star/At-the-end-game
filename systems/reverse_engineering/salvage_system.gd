class_name SalvageSystem
extends RefCounted
## SalvageSystem — DESMONTAJE (ingeniería inversa): objeto base → partes.
##
## Lógica pura y estática. Consume 1 unidad de un objeto base YA ANALIZADO y
## entrega las partes definidas en su SalvageData. Es ATÓMICO (todo o nada),
## reutilizando la transacción del inventario (anti-duping).
##
## NOTA DE ALCANCE: las partes son ítems fungibles sin calidad por instancia, así
## que la "calidad de parte = f(calidad base, habilidad)" queda DIFERIDA. En esta
## fase la habilidad influye sobre todo en el ENSAMBLAJE (ver EngineeringSystem).

## Desmonta 1 unidad de la chatarra del slot indicado.
## Requiere que esté ANALIZADA (is_identified). Devuelve true si tuvo éxito.
static func dismantle(inventory: Inventory, slot_index: int, _eng_level: int = 0) -> bool:
	if slot_index < 0 or slot_index >= inventory.slots.size():
		return false
	var slot: InventorySlot = inventory.slots[slot_index]
	if slot.is_empty():
		return false
	if not slot.is_identified:
		push_warning("SalvageSystem.dismantle: la chatarra debe analizarse antes de desmontarla.")
		return false
	if slot.hidden_metadata_array.is_empty():
		return false

	var salvage: SalvageData = Database.get_salvage(slot.item_id)
	if salvage == null:
		push_error("SalvageSystem.dismantle: no hay SalvageData para '%s'." % slot.item_id)
		return false

	inventory.begin_transaction()

	# Consumir 1 unidad (un metadato). Si la pila queda vacía, se libera el slot.
	var consumed: Dictionary = slot.pop_metadata()
	if consumed.is_empty():
		inventory.rollback_transaction()
		return false
	if slot.hidden_metadata_array.is_empty():
		slot.clear_slot()

	# Entregar las partes SOLO en slots principales (atómico).
	for part_id: String in salvage.yields:
		var qty: int = salvage.yields[part_id]
		var leftover: int = inventory.add_item(part_id, qty, false)
		if leftover > 0:
			inventory.rollback_transaction()  # no cabían las partes: se cancela todo
			return false

	inventory.commit_transaction()
	return true
