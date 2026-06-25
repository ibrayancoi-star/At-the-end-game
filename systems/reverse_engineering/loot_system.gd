class_name LootSystem
extends RefCounted
## LootSystem — genera el LOOT de un POI como chatarra OCULTA (ingeniería inversa).
##
## Lógica pura y estática. Al recolectar en una zona, se crea una unidad de
## chatarra base NO identificada con su calidad oculta (dentro del rango del POI)
## y su origen. El contenido real (partes) NO se guarda por unidad: se deriva del
## SalvageData del item base al desmontar (ver SalvageSystem).
##
## Reutiliza el modelo de chatarra del inventario (apila hasta 5, valida esquema).

## Recolecta una unidad de chatarra del POI hacia el inventario.
## Devuelve true si se almacenó (en slot u overflow).
static func roll_into_inventory(poi: PoiLootData, inventory: Inventory) -> bool:
	if poi == null:
		push_error("LootSystem.roll_into_inventory: POI nulo.")
		return false
	# Calidad oculta dentro del rango de la zona (porcentaje entero).
	var quality: int = randi_range(poi.quality_min, poi.quality_max)
	var metadata: Dictionary = {"quality": quality, "poi_origin": poi.id}
	return inventory.add_scrap(poi.base_item_id, metadata)
