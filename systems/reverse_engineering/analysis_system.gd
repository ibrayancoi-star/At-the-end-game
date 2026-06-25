class_name AnalysisSystem
extends RefCounted
## AnalysisSystem — ANÁLISIS (escaneo) de chatarra: revela su calidad/contenido.
##
## Lógica pura y estática. El análisis está gobernado por la habilidad de
## Ingeniería del jugador (ver ADR-004 / petición del usuario):
##   Puede analizar SI  nivel >= ENGINEERING_ANALYSIS_MIN_LEVEL
##                  O    lleva un artefacto de análisis (tool_type "analisis")
##                  O    está en una máquina de escaneo (zona franca).
##
## DIFERIDO: la ceremonia temporizada real (bloquear N ticks) y las máquinas de
## escaneo como objetos del mundo. Aquí se devuelve el coste en ticks calculado,
## pero la ejecución temporizada es del paso de ticks/UI.

## ¿Puede el jugador analizar, dadas sus condiciones?
static func can_analyze(eng_level: int, has_tool: bool, at_machine: bool) -> bool:
	return eng_level >= ConstantsCore.ENGINEERING_ANALYSIS_MIN_LEVEL or has_tool or at_machine


## Analiza la chatarra de un slot: la marca como identificada (revela calidad).
## Si el habilitador fue el artefacto, lo desgasta. Devuelve
## {success: bool, message: String, ticks: int}.
static func analyze(inventory: Inventory, slot_index: int, eng_level: int, at_machine: bool = false) -> Dictionary:
	var result: Dictionary = {"success": false, "message": "", "ticks": 0}

	if slot_index < 0 or slot_index >= inventory.slots.size():
		result["message"] = "Slot inválido."
		return result
	var slot: InventorySlot = inventory.slots[slot_index]
	if slot.is_empty():
		result["message"] = "Slot vacío."
		return result
	if slot.hidden_metadata_array.is_empty():
		result["message"] = "Este objeto no es chatarra analizable."
		return result
	if slot.is_identified:
		result["message"] = "Ya está analizado."
		return result

	var has_tool: bool = inventory.find_tool_slot("analisis") != -1
	if not can_analyze(eng_level, has_tool, at_machine):
		result["message"] = "Ingeniería insuficiente: necesitas un analizador o una máquina de escaneo."
		return result

	# Revelar (no rompe la pila; el conteo sigue saliendo del array de metadatos).
	slot.is_identified = true

	# Si el ÚNICO habilitador fue el artefacto, se desgasta con el uso.
	var skill_ok: bool = eng_level >= ConstantsCore.ENGINEERING_ANALYSIS_MIN_LEVEL
	if has_tool and not skill_ok and not at_machine:
		var tool_slot: int = inventory.find_tool_slot("analisis")
		var tool_item: ToolData = Database.get_item(inventory.slots[tool_slot].item_id) as ToolData
		inventory.wear_tool(tool_slot, tool_item.wear_per_use)

	result["success"] = true
	result["ticks"] = ConstantsCore.ANALYSIS_BASE_TICKS
	result["message"] = "Analizado."
	inventory.changed.emit()
	return result
