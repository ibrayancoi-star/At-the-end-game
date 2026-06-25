extends Node
## smoke_loop.gd — Test de humo del bucle de Fase 1 + blindaje atómico.
##
## NO es parte del juego: es un arnés de verificación. Se ejecuta como escena
## (tests/smoke_loop.tscn) en modo headless para validar end-to-end que el
## refactor "Híbrido Controlado" funciona. Sale con código = nº de fallos.
##
## Ejecutar:
##   Godot_..._console.exe --headless --path . res://tests/smoke_loop.tscn

var _failures: int = 0


func _ready() -> void:
	print("===== SMOKE TEST: bucle Fase 1 (hibrido) =====")
	_test_slots()
	_test_harvest_loop()
	_test_craft_atomic()
	_test_overflow_purge()
	_test_transaction_rollback()
	_test_schema_validation()
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


# --- 1. Inventario de 28 slots ---
func _test_slots() -> void:
	print("- Slots:")
	var inv := Inventory.new()
	_check("inventario tiene 28 slots", inv.slots.size() == ConstantsCore.INVENTORY_SLOTS)
	_check("constante INVENTORY_SLOTS == 28", ConstantsCore.INVENTORY_SLOTS == 28)


# --- 2. Bucle de recolección con herramienta (integración ResourceNode) ---
func _test_harvest_loop() -> void:
	print("- Recoleccion + desgaste de herramienta:")
	var inv: Inventory = GameState.inventory

	# Sin herramienta: recolecta solo el base.
	var rn: ResourceNode = load("res://scenes/resource_node.tscn").instantiate()
	add_child(rn)  # tool_type por defecto "axe", yields "madera", base_yield 1
	var before_hand: int = inv.get_count("madera")
	rn.harvest()
	_check("recolectar a mano da base_yield", inv.get_count("madera") - before_hand == rn.base_yield)

	# Con hacha: recolecta base + gather_bonus(2) y la herramienta se desgasta.
	inv.add_item("hacha")
	var axe_slot: int = inv.find_tool_slot("axe")
	_check("el hacha entra al inventario (find_tool_slot)", axe_slot != -1)
	var before_tool: int = inv.get_count("madera")
	rn.harvest()
	var bonus: int = (Database.get_item("hacha") as ToolData).gather_bonus
	_check("recolectar con hacha da base+bonus", inv.get_count("madera") - before_tool == rn.base_yield + bonus)

	# Desgaste total: el hacha se rompe al llegar a 0 de durabilidad.
	axe_slot = inv.find_tool_slot("axe")
	var broke: bool = inv.wear_tool(axe_slot, 999)
	_check("el hacha se rompe al agotar durabilidad", broke)
	_check("tras romperse, no hay hacha en el inventario", inv.find_tool_slot("axe") == -1)

	rn.queue_free()


# --- 3. Crafteo atómico ---
func _test_craft_atomic() -> void:
	print("- Crafteo atomico:")
	var inv := Inventory.new()
	var recipe: RecipeData = Database.get_recipe("receta_tabla")  # 2 madera -> 1 tabla
	_check("receta_tabla existe", recipe != null)

	# Sin ingredientes: no craftea y no muta nada.
	_check("craft sin ingredientes -> false", CraftingSystem.craft(recipe, inv) == false)
	_check("no se creo tabla al fallar", inv.get_count("tabla") == 0)

	# Con ingredientes justos: craftea (consume 2 madera, da 1 tabla).
	inv.add_item("madera", 2)
	_check("craft con 2 madera -> true", CraftingSystem.craft(recipe, inv) == true)
	_check("consumio las 2 maderas", inv.get_count("madera") == 0)
	_check("entrego 1 tabla", inv.get_count("tabla") == 1)


# --- 4. Overflow con purga por ticks ---
func _test_overflow_purge() -> void:
	print("- Overflow + purga por ticks:")
	var inv := Inventory.new()
	var capacity: int = ConstantsCore.INVENTORY_SLOTS * Database.get_item("madera").max_stack
	inv.add_item("madera", capacity)  # llena todos los slots
	_check("inventario lleno sin overflow", inv.get_overflow_count() == 0)

	inv.add_item("madera", 5)  # no cabe -> overflow
	_check("excedente va al overflow", inv.get_overflow_count() == 1)

	# Avanzar el reloj más allá de la expiración purga el overflow.
	var future: int = CoreTimeManager.current_tick + ConstantsCore.OVERFLOW_EXPIRY_TICKS
	inv.purge_expired_overflow(future)
	_check("el overflow expira tras 500 ticks", inv.get_overflow_count() == 0)


# --- 5. Rollback transaccional (anti-duping) ---
func _test_transaction_rollback() -> void:
	print("- Rollback transaccional:")
	var inv := Inventory.new()
	inv.add_item("madera", 5)

	inv.begin_transaction()
	inv.remove_item("madera", 5)
	inv.add_item("mineral", 3)
	# Simulamos un fallo a mitad de la transacción -> revertir.
	inv.rollback_transaction()

	_check("rollback restaura la madera", inv.get_count("madera") == 5)
	_check("rollback descarta el mineral añadido", inv.get_count("mineral") == 0)


# --- 6. Validación de esquema de metadatos ---
func _test_schema_validation() -> void:
	print("- Validacion de esquema (se esperan ERROR de rechazo):")
	_check("metadato válido (quality:int, poi_origin:String)",
		InventorySlot.validate_metadata_schema({"quality": 50, "poi_origin": "ruins_A3"}))
	_check("rechaza si falta poi_origin",
		InventorySlot.validate_metadata_schema({"quality": 50}) == false)
	_check("rechaza si quality no es int",
		InventorySlot.validate_metadata_schema({"quality": 1.0, "poi_origin": "x"}) == false)

	var inv := Inventory.new()
	_check("add_scrap con metadato válido -> true",
		inv.add_scrap("monitor", {"quality": 73, "poi_origin": "ruins_A3"}))
	_check("add_scrap cuenta la chatarra", inv.get_count("monitor") == 1)
	_check("add_scrap con metadato inválido -> false",
		inv.add_scrap("monitor", {"basura": 1}) == false)
