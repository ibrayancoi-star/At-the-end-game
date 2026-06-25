class_name EngineeringSystem
extends RefCounted
## EngineeringSystem — ENSAMBLAJE escalado por la habilidad de Ingeniería.
##
## Lógica pura y estática. Sobre la base del crafteo atómico, el resultado depende
## del nivel de Ingeniería del jugador (petición del usuario):
##   - A MENOR nivel → objeto de MENOR durabilidad (se desgasta antes), aunque las
##     partes sean buenas.
##   - A MENOR nivel → MÁS tiempo de ensamblaje (más ticks).
## Otorga XP de Ingeniería al ensamblar.
##
## DIFERIDO: la ejecución temporizada real (bloquear los ticks). Aquí se calcula y
## se devuelve el coste en ticks, pero no se bloquea al jugador (eso es de la fase
## de ticks/UI).

## XP de Ingeniería otorgada por un ensamblaje exitoso.
const XP_PER_ASSEMBLY: int = 25


## Ensambla la receta aplicando el escalado por habilidad. `skills` es opcional;
## si se pasa, se le otorga XP de Ingeniería. Devuelve
## {success: bool, message: String, ticks: int, durability_factor: float}.
static func assemble(recipe: RecipeData, inventory: Inventory, eng_level: int, skills: SkillSet = null) -> Dictionary:
	var result: Dictionary = {"success": false, "message": "", "ticks": 0, "durability_factor": 0.0}
	if recipe == null:
		result["message"] = "Receta nula."
		return result

	# Validar ingredientes.
	for ingredient_id: String in recipe.ingredients:
		if not inventory.has_item(ingredient_id, recipe.ingredients[ingredient_id]):
			result["message"] = "Faltan ingredientes."
			return result

	inventory.begin_transaction()

	# Consumir ingredientes.
	for ingredient_id: String in recipe.ingredients:
		if not inventory.remove_item(ingredient_id, recipe.ingredients[ingredient_id]):
			inventory.rollback_transaction()
			result["message"] = "Error al consumir ingredientes."
			return result

	var factor: float = _durability_factor(eng_level)
	var out_item: ItemData = Database.get_item(recipe.output_item_id)
	var placed_ok: bool = false

	if out_item is ToolData:
		# La durabilidad del objeto resultante se escala por la habilidad.
		var max_dur: float = maxf(1.0, float((out_item as ToolData).max_durability) * factor)
		placed_ok = _place_tool(inventory, recipe.output_item_id, max_dur)
	else:
		# Objetos no-herramienta: sin durabilidad que escalar; se entregan normal.
		placed_ok = inventory.add_item(recipe.output_item_id, recipe.output_quantity, false) == 0

	if not placed_ok:
		inventory.rollback_transaction()
		result["message"] = "No hay espacio para el resultado."
		return result

	inventory.commit_transaction()

	if skills != null:
		skills.add_xp("ingenieria", XP_PER_ASSEMBLY)

	result["success"] = true
	result["durability_factor"] = factor
	result["ticks"] = _assembly_ticks(eng_level)
	result["message"] = "Ensamblado."
	return result


## Factor de durabilidad [MIN..1.0] interpolado por el nivel de ingeniería.
static func _durability_factor(eng_level: int) -> float:
	var t: float = clampf(float(eng_level) / float(ConstantsCore.SKILL_MAX_LEVEL), 0.0, 1.0)
	return lerpf(ConstantsCore.ASSEMBLY_DURABILITY_MIN_FACTOR, 1.0, t)


## Coste en ticks: base + penalización que decrece con el nivel.
static func _assembly_ticks(eng_level: int) -> int:
	var t: float = clampf(float(eng_level) / float(ConstantsCore.SKILL_MAX_LEVEL), 0.0, 1.0)
	return ConstantsCore.ASSEMBLY_BASE_TICKS + int(round(ConstantsCore.ASSEMBLY_TICKS_PENALTY_MAX * (1.0 - t)))


## Coloca una herramienta con durabilidad explícita en el primer slot vacío.
static func _place_tool(inventory: Inventory, item_id: String, max_dur: float) -> bool:
	for slot: InventorySlot in inventory.slots:
		if slot.is_empty():
			slot.set_identified_item(item_id, max_dur, max_dur)
			inventory.changed.emit()
			return true
	return false
