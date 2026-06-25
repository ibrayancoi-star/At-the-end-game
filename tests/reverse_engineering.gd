extends Node
## reverse_engineering.gd — Test de humo de la ingeniería inversa + habilidades.
##
## Arnés de verificación (no es parte del juego). Ejecutar:
##   Godot_..._console.exe --headless --path . res://tests/reverse_engineering.tscn
## Sale con código = nº de fallos (0 = todo OK).

var _failures: int = 0


func _ready() -> void:
	print("===== SMOKE TEST: ingeniería inversa + habilidades =====")
	_test_skills()
	_test_loot()
	_test_analysis_gating()
	_test_dismantle()
	_test_assembly_by_skill()
	print("===== RESULTADO: %s (%d fallos) =====" % [
		("OK" if _failures == 0 else "HAY FALLOS"), _failures
	])
	get_tree().quit(_failures)


func _check(label: String, cond: bool) -> void:
	if cond:
		print("  [PASS] %s" % label)
	else:
		_failures += 1
		print("  [FAIL] %s" % label)


## Índice del primer slot con el item dado (o -1).
func _slot_of(inv: Inventory, item_id: String) -> int:
	for i: int in range(inv.slots.size()):
		if inv.slots[i].item_id == item_id:
			return i
	return -1


# --- 1. Habilidades (XP / nivel) ---
func _test_skills() -> void:
	print("- Habilidades (XP/nivel):")
	var skills := SkillSet.new()
	_check("habilidad sin XP es nivel 0", skills.get_level("ingenieria") == 0)
	skills.add_xp("ingenieria", 100)  # xp_for_level(1) = 100
	_check("100 XP -> nivel 1", skills.get_level("ingenieria") == 1)
	skills.add_xp("ingenieria", 200)  # total 300 >= xp_for_level(2)=282
	_check("300 XP -> nivel 2", skills.get_level("ingenieria") == 2)
	_check("Database tiene 5 habilidades", Database.all_skills().size() == 5)


# --- 2. Loot oculto por POI ---
func _test_loot() -> void:
	print("- Loot oculto por POI:")
	var inv := Inventory.new()
	var poi: PoiLootData = Database.get_poi("centro_comercial")  # monitor, calidad 10-35
	_check("POI centro_comercial existe", poi != null)
	_check("recolectar mete chatarra", LootSystem.roll_into_inventory(poi, inv))
	var idx := _slot_of(inv, "monitor")
	_check("hay un monitor en el inventario", idx != -1)
	_check("la chatarra NO está identificada (oculta)", not inv.slots[idx].is_identified)
	var q: int = inv.slots[idx].hidden_metadata_array[0]["quality"]
	_check("calidad dentro del rango del POI", q >= 10 and q <= 35)
	# Apila hasta 5 en un solo slot.
	for i in range(4):
		LootSystem.roll_into_inventory(poi, inv)
	_check("apila 5 unidades", inv.get_count("monitor") == 5)


# --- 3. Análisis con gating por habilidad/herramienta/máquina ---
func _test_analysis_gating() -> void:
	print("- Análisis (gating):")
	_check("can_analyze: nivel 0 sin ayudas -> NO", not AnalysisSystem.can_analyze(0, false, false))
	_check("can_analyze: nivel >= umbral -> SÍ", AnalysisSystem.can_analyze(ConstantsCore.ENGINEERING_ANALYSIS_MIN_LEVEL, false, false))
	_check("can_analyze: con máquina -> SÍ", AnalysisSystem.can_analyze(0, false, true))
	_check("can_analyze: con herramienta -> SÍ", AnalysisSystem.can_analyze(0, true, false))

	# Nivel 0, sin herramienta, sin máquina: NO se puede analizar.
	var inv := Inventory.new()
	LootSystem.roll_into_inventory(Database.get_poi("centro_comercial"), inv)
	var idx := _slot_of(inv, "monitor")
	var r1: Dictionary = AnalysisSystem.analyze(inv, idx, 0, false)
	_check("analizar sin ayudas falla", not r1["success"] and not inv.slots[idx].is_identified)

	# En máquina: sí.
	var r2: Dictionary = AnalysisSystem.analyze(inv, idx, 0, true)
	_check("analizar en máquina revela", r2["success"] and inv.slots[idx].is_identified)
	_check("el análisis reporta coste en ticks", r2["ticks"] == ConstantsCore.ANALYSIS_BASE_TICKS)

	# Con artefacto analizador: se puede y el artefacto se desgasta.
	var inv2 := Inventory.new()
	inv2.add_item("analizador")
	LootSystem.roll_into_inventory(Database.get_poi("centro_comercial"), inv2)
	var midx := _slot_of(inv2, "monitor")
	var r3: Dictionary = AnalysisSystem.analyze(inv2, midx, 0, false)
	_check("analizar con artefacto revela", r3["success"])
	var tslot := inv2.find_tool_slot("analisis")
	_check("el analizador se desgastó (40 -> 39)", tslot != -1 and inv2.slots[tslot].current_durability == 39.0)


# --- 4. Desmontaje (atómico) ---
func _test_dismantle() -> void:
	print("- Desmontaje:")
	# No analizado -> rechazado.
	var inv0 := Inventory.new()
	LootSystem.roll_into_inventory(Database.get_poi("centro_comercial"), inv0)
	_check("desmontar sin analizar falla", not SalvageSystem.dismantle(inv0, _slot_of(inv0, "monitor")))

	# Analizado -> produce las partes y consume el base.
	var inv := Inventory.new()
	LootSystem.roll_into_inventory(Database.get_poi("centro_comercial"), inv)
	var idx := _slot_of(inv, "monitor")
	AnalysisSystem.analyze(inv, idx, 0, true)
	_check("desmontar analizado funciona", SalvageSystem.dismantle(inv, idx))
	_check("se consumió el monitor", inv.get_count("monitor") == 0)
	_check("se obtuvo placa_circuito", inv.get_count("placa_circuito") == 1)
	_check("se obtuvo bateria", inv.get_count("bateria") == 1)

	# Atómico: si no caben las partes, se revierte (el base sigue ahí).
	var inv2 := Inventory.new()
	LootSystem.roll_into_inventory(Database.get_poi("centro_comercial"), inv2)
	var midx := _slot_of(inv2, "monitor")
	AnalysisSystem.analyze(inv2, midx, 0, true)
	# Llenar TODOS los demás slots con madera para que solo quede 1 hueco al consumir.
	inv2.add_item("madera", (ConstantsCore.INVENTORY_SLOTS - 1) * Database.get_item("madera").max_stack)
	_check("inventario sin huecos libres salvo el del base", inv2.add_item("fibra", 1, false) == 1)
	var ok := SalvageSystem.dismantle(inv2, midx)
	_check("desmontaje sin espacio -> rollback (false)", not ok)
	_check("el monitor sigue tras el rollback", inv2.get_count("monitor") == 1)
	_check("no se crearon partes en el rollback", inv2.get_count("placa_circuito") == 0)


# --- 5. Ensamblaje escalado por habilidad ---
func _test_assembly_by_skill() -> void:
	print("- Ensamblaje por habilidad:")
	var recipe: RecipeData = Database.get_recipe("receta_analizador")  # placa+bateria -> analizador
	_check("receta_analizador existe", recipe != null)

	# Baja ingeniería (nivel 0): durabilidad mermada, más ticks.
	var inv_low := Inventory.new()
	inv_low.add_item("placa_circuito", 1)
	inv_low.add_item("bateria", 1)
	var skills := SkillSet.new()
	var low: Dictionary = EngineeringSystem.assemble(recipe, inv_low, 0, skills)
	_check("ensamblar a nivel 0 funciona", low["success"])
	var low_slot := inv_low.find_tool_slot("analisis")
	var base_dur: float = float((Database.get_item("analizador") as ToolData).max_durability)
	_check("durabilidad mermada a nivel 0", inv_low.slots[low_slot].max_durability_absolute < base_dur)
	_check("otorgó XP de ingeniería", skills.get_xp("ingenieria") == EngineeringSystem.XP_PER_ASSEMBLY)

	# Alta ingeniería (nivel máximo): durabilidad completa, menos ticks.
	var inv_hi := Inventory.new()
	inv_hi.add_item("placa_circuito", 1)
	inv_hi.add_item("bateria", 1)
	var hi: Dictionary = EngineeringSystem.assemble(recipe, inv_hi, ConstantsCore.SKILL_MAX_LEVEL)
	var hi_slot := inv_hi.find_tool_slot("analisis")
	_check("durabilidad completa a nivel máximo", inv_hi.slots[hi_slot].max_durability_absolute == base_dur)
	_check("mejor habilidad = objeto más duradero",
		inv_hi.slots[hi_slot].max_durability_absolute > inv_low.slots[low_slot].max_durability_absolute)
	_check("mejor habilidad = menos ticks de ensamblaje", hi["ticks"] < low["ticks"])
