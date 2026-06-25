extends Node
## faction_rules.gd — Test de humo de las reglas de facción/party + datos.
##
## Arnés de verificación (no es parte del juego). Ejecutar:
##   Godot_..._console.exe --headless --path . res://tests/faction_rules.tscn
## Sale con código = nº de fallos (0 = todo OK).

const PACTO := PartyRules.Faction.PACTO
const RESIS := PartyRules.Faction.RESISTENCIA
const MERC := PartyRules.Faction.MERCENARY

var _failures: int = 0


func _ready() -> void:
	print("===== SMOKE TEST: facciones y reglas de party =====")
	_test_pure_factions()
	_test_pure_mercenary()
	_test_mixed()
	_test_pacto_resistencia_blocked()
	_test_faction_data()
	_test_player_identity()
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


## Crea `count` miembros de una facción.
func _members(faction: int, count: int) -> Array:
	var arr: Array = []
	for i: int in range(count):
		arr.append({"id": i + 1, "faction": faction})
	return arr


## ¿Se permite que entre `applicant` con esos miembros actuales?
func _allowed(current: Array, applicant: int) -> bool:
	return PartyRules.evaluate_projected_state(current, applicant).get("allowed", false)


# --- Pura facción (Pacto / Resistencia): máx 6 ---
func _test_pure_factions() -> void:
	print("- Party pura de facción (máx 6):")
	_check("5 Pacto + 1 Pacto = 6 OK", _allowed(_members(PACTO, 5), PACTO))
	_check("6 Pacto + 1 Pacto = 7 BLOQUEADO", not _allowed(_members(PACTO, 6), PACTO))
	_check("5 Resistencia + 1 = 6 OK", _allowed(_members(RESIS, 5), RESIS))
	_check("6 Resistencia + 1 = 7 BLOQUEADO", not _allowed(_members(RESIS, 6), RESIS))


# --- Pura mercenarios: máx 5 ---
func _test_pure_mercenary() -> void:
	print("- Party pura de mercenarios (máx 5):")
	_check("4 Merc + 1 = 5 OK", _allowed(_members(MERC, 4), MERC))
	_check("5 Merc + 1 = 6 BLOQUEADO", not _allowed(_members(MERC, 5), MERC))


# --- Mixtas (facción + mercenarios): máx 4 ---
func _test_mixed() -> void:
	print("- Party mixta facción+mercenarios (máx 4):")
	_check("3 Pacto + 1 Merc = 4 OK", _allowed(_members(PACTO, 3), MERC))
	_check("(3 Pacto,1 Merc) + 1 Merc = 5 BLOQUEADO",
		not _allowed(_members(PACTO, 3) + _members(MERC, 1), MERC))
	_check("3 Resistencia + 1 Merc = 4 OK", _allowed(_members(RESIS, 3), MERC))
	_check("(3 Resistencia,1 Merc) + 1 Merc = 5 BLOQUEADO",
		not _allowed(_members(RESIS, 3) + _members(MERC, 1), MERC))


# --- Pacto + Resistencia: SIEMPRE bloqueado ---
func _test_pacto_resistencia_blocked() -> void:
	print("- Pacto + Resistencia (bloqueo absoluto):")
	_check("1 Pacto + 1 Resistencia BLOQUEADO", not _allowed(_members(PACTO, 1), RESIS))
	_check("1 Resistencia + 1 Pacto BLOQUEADO", not _allowed(_members(RESIS, 1), PACTO))
	_check("(2 Merc, 1 Pacto) + 1 Resistencia BLOQUEADO",
		not _allowed(_members(MERC, 2) + _members(PACTO, 1), RESIS))


# --- Datos de perfil de facción ---
func _test_faction_data() -> void:
	print("- FactionData (perfiles):")
	_check("Database carga 3 facciones", Database.all_factions().size() == 3)
	var pacto: FactionData = Database.get_faction("pacto")
	var resis: FactionData = Database.get_faction("resistencia")
	var merc: FactionData = Database.get_faction("mercenario")
	_check("existen las 3 por id", pacto != null and resis != null and merc != null)
	_check("Pacto: principal, +1 habilidad", pacto.is_main_faction and pacto.extra_skill_slots == 1)
	_check("Resistencia: principal, +1 habilidad", resis.is_main_faction and resis.extra_skill_slots == 1)
	_check("Mercenarios: neutral, +2 habilidades", (not merc.is_main_faction) and merc.extra_skill_slots == 2)
	_check("campamento principal > mercenario", pacto.camp_capacity > merc.camp_capacity)
	_check("faction_type mapea al enum", merc.faction_type == MERC and pacto.faction_type == PACTO)


# --- Identidad del jugador en GameState ---
func _test_player_identity() -> void:
	print("- Identidad de facción del jugador:")
	_check("set_player_faction válido -> true", GameState.set_player_faction(RESIS))
	_check("player_faction quedó fijada", GameState.player_faction == RESIS)
	_check("get_player_faction_data devuelve La Resistencia",
		GameState.get_player_faction_data() != null and GameState.get_player_faction_data().id == "resistencia")
	_check("set_player_faction inválido -> false", GameState.set_player_faction(99) == false)
	_check("facción no cambió tras valor inválido", GameState.player_faction == RESIS)
