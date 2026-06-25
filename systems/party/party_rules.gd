class_name PartyRules
extends RefCounted
## PartyRules — REGLAS PURAS de composición de party (sin red, sin estado).
##
## Fuente única de verdad de:
##   - Las 3 facciones del juego (enum Faction).
##   - El "Invariante de Estado Global Proyectado": dada la composición actual de
##     una party y un aspirante, decide si puede entrar SIN romper las reglas.
##
## Es lógica pura y estática: la usa tanto el single-player (validación local) como
## el PartyManager EN RED (systems/_deferred/), que solo añade la capa RPC encima.
## Así las reglas viven en un único sitio (DRY). Ver ADR-003 y ADR-004.
##
## Reglas (ver ADR-004):
##   - Solo Pacto o solo Resistencia .... máx PARTY_MAX_PURE_FACTION (6)
##   - Solo Mercenarios ................. máx PARTY_MAX_PURE_MERCENARY (5)
##   - Facción + Mercenarios (mixta) .... máx PARTY_MAX_MIXED (4)
##   - Pacto + Resistencia juntos ....... PROHIBIDO (bloqueo absoluto)

## Las tres facciones. El orden/índice es el canon compartido por todo el juego.
enum Faction { PACTO, RESISTENCIA, MERCENARY }


## Simula el estado futuro de la party SI entrara el aspirante y dice si se
## permite. NO muta nada (consulta pura).
##
## current_members: Array de diccionarios {"id": int, "faction": int (Faction)}.
## applicant_faction: int (valor del enum Faction) del aspirante.
## Devuelve: {"allowed": bool, "message": String}.
static func evaluate_projected_state(current_members: Array, applicant_faction: int) -> Dictionary:
	var result: Dictionary = {"allowed": false, "message": ""}

	# Validar facción del aspirante.
	if applicant_faction < 0 or applicant_faction > Faction.MERCENARY:
		result["message"] = "Facción del aspirante inválida: %d." % applicant_faction
		push_error("PartyRules.evaluate_projected_state: %s" % result["message"])
		return result

	# Proyectar: miembros actuales + aspirante (id -1 = proyección).
	var projected: Array = current_members.duplicate()
	projected.append({"id": -1, "faction": applicant_faction})
	var projected_size: int = projected.size()

	# Contar facciones en el estado proyectado.
	var count_pacto: int = 0
	var count_resistencia: int = 0
	var count_mercenary: int = 0
	for member: Dictionary in projected:
		match int(member.get("faction", -1)):
			Faction.PACTO:
				count_pacto += 1
			Faction.RESISTENCIA:
				count_resistencia += 1
			Faction.MERCENARY:
				count_mercenary += 1
			_:
				result["message"] = "Miembro con facción desconocida."
				push_error("PartyRules.evaluate_projected_state: %s" % result["message"])
				return result

	# REGLA 1: bloqueo absoluto de coexistencia Pacto + Resistencia.
	if count_pacto > 0 and count_resistencia > 0:
		result["message"] = "BLOQUEO: Pacto y Resistencia no pueden coexistir en la misma party."
		return result

	# Determinar tipo de party y su límite.
	var has_faction: bool = (count_pacto > 0) or (count_resistencia > 0)
	var has_mercenary: bool = count_mercenary > 0
	var party_type: String = ""
	var max_size: int = 0

	if has_faction and has_mercenary:
		party_type = "MIXTA"
		max_size = ConstantsCore.PARTY_MAX_MIXED
	elif has_mercenary:
		party_type = "PURO_MERCENARIO"
		max_size = ConstantsCore.PARTY_MAX_PURE_MERCENARY
	elif has_faction:
		party_type = "PURO_FACCION"
		max_size = ConstantsCore.PARTY_MAX_PURE_FACTION
	else:
		result["message"] = "Error interno: no se pudo determinar el tipo de party."
		push_error("PartyRules.evaluate_projected_state: %s" % result["message"])
		return result

	# REGLA 2: límite de tamaño.
	if projected_size > max_size:
		result["message"] = "Party %s excedería el límite: %d/%d." % [party_type, projected_size, max_size]
		return result

	# Aprobado.
	result["allowed"] = true
	result["message"] = "Aprobado. Party %s: %d/%d." % [party_type, projected_size, max_size]
	return result
