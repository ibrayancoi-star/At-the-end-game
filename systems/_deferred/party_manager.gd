class_name PartyManager
extends Node
## PartyManager — Gestor AUTORITATIVO de parties/squads del servidor.
##
## Singleton del servidor. Gestiona todas las parties activas del juego.
## Implementa el "Invariante de Estado Global Proyectado" que determina
## dinámicamente el tamaño máximo de una party según la composición de
## facciones de sus miembros.
##
## Reglas inmutables:
##   - PACTO + RESISTENCIA = BLOQUEO ABSOLUTO (nunca pueden coexistir)
##   - Mixto (Facción + Mercenario) = Max 4 personas
##   - Puro Mercenarios = Max 5 personas
##   - Puro Facción (solo PACTO o solo RESISTENCIA) = Max 6 personas
##
## Toda mutación de party pasa por evaluate_projected_state() antes de
## ejecutarse. Si la proyección rompe el invariante, se deniega.


# =============================================================================
# FACCIONES
# =============================================================================
# Las 3 facciones y las REGLAS de composición de party viven en PartyRules
# (systems/party/party_rules.gd), fuente única compartida — ver ADR-004.
# Este gestor solo añade la capa de RED (RPC) por encima de esas reglas puras.


# =============================================================================
# SEÑALES
# =============================================================================

## Emitida cuando un jugador se une a una party.
signal member_joined(party_id: String, player_id: int)

## Emitida cuando un jugador abandona una party.
signal member_left(party_id: String, player_id: int)

## Emitida cuando una party se disuelve.
signal party_dissolved(party_id: String)

## Emitida cuando se transfiere el liderazgo.
signal leadership_transferred(party_id: String, old_leader: int, new_leader: int)


# =============================================================================
# ESTADO GLOBAL DE PARTIES
# =============================================================================

## Todas las parties activas.
## Clave: party_id (String) → Valor: Dictionary {
##   "leader_id": int,
##   "members": Array[Dictionary]  // Cada miembro: {"id": int, "faction": Faction}
## }
var _active_parties: Dictionary = {}

## Mapeo inverso: player_id → party_id para búsquedas rápidas.
var _player_to_party: Dictionary = {}

## Contador interno para generar IDs de party.
var _party_counter: int = 0


# =============================================================================
# INVARIANTE DE ESTADO GLOBAL PROYECTADO
# =============================================================================

## Simula el estado futuro de la party si ingresara el aspirante.
## NO muta estado: es una consulta pura (función sin efectos secundarios).
##
## current_members: Array de diccionarios {"id": int, "faction": Faction}
##                  representando a los miembros actuales de la party.
## applicant_faction: int (valor del enum Faction) de la facción del aspirante.
##
## Retorna: {"allowed": bool, "message": String}
##   - allowed = true: el aspirante puede ingresar.
##   - allowed = false: se violaría el invariante; message explica por qué.
func evaluate_projected_state(current_members: Array, applicant_faction: int) -> Dictionary:
	# Delega en la lógica pura compartida (DRY). Este gestor solo aporta la red.
	return PartyRules.evaluate_projected_state(current_members, applicant_faction)


# =============================================================================
# GESTIÓN DE PARTIES — RPCs AUTORITATIVAS
# =============================================================================

## Crea una nueva party con un jugador como líder y único miembro.
## Retorna el party_id generado, o "" si ya está en una party.
func create_party(leader_id: int, leader_faction: int) -> String:
	if _player_to_party.has(leader_id):
		push_error("PartyManager.create_party: jugador %d ya está en party '%s'." % [
			leader_id, _player_to_party[leader_id]
		])
		return ""

	_party_counter += 1
	var party_id: String = "party_%d" % _party_counter

	_active_parties[party_id] = {
		"leader_id": leader_id,
		"members": [{"id": leader_id, "faction": leader_faction}],
	}
	_player_to_party[leader_id] = party_id

	return party_id


## Solicitud de un jugador para unirse a una party existente.
## El servidor valida con evaluate_projected_state antes de permitirlo.
@rpc("authority", "reliable")
func server_request_join(party_id: String, applicant_id: int, applicant_faction: int) -> Dictionary:
	var result: Dictionary = {"success": false, "message": ""}

	# Validar que la party existe.
	if not _active_parties.has(party_id):
		result["message"] = "Party '%s' no existe." % party_id
		return result

	# Validar que el jugador no esté ya en una party.
	if _player_to_party.has(applicant_id):
		result["message"] = "Jugador %d ya está en party '%s'." % [
			applicant_id, _player_to_party[applicant_id]
		]
		return result

	var party_data: Dictionary = _active_parties[party_id]
	var current_members: Array = party_data.get("members", [])

	# Evaluar el invariante proyectado.
	var eval: Dictionary = evaluate_projected_state(current_members, applicant_faction)

	if not eval.get("allowed", false):
		result["message"] = eval.get("message", "Evaluación rechazada.")
		return result

	# Añadir miembro.
	current_members.append({"id": applicant_id, "faction": applicant_faction})
	_player_to_party[applicant_id] = party_id

	result["success"] = true
	result["message"] = "Jugador %d unido a party '%s'. %s" % [
		applicant_id, party_id, eval.get("message", "")
	]

	member_joined.emit(party_id, applicant_id)
	return result


## Invitación inversa: un miembro de la party invita a un jugador externo.
## Valida igualmente con evaluate_projected_state.
@rpc("authority", "reliable")
func server_invite_player(party_id: String, inviter_id: int,
		invitee_id: int, invitee_faction: int) -> Dictionary:

	var result: Dictionary = {"success": false, "message": ""}

	if not _active_parties.has(party_id):
		result["message"] = "Party '%s' no existe." % party_id
		return result

	# Verificar que quien invita pertenece a la party.
	var inviter_party: String = _player_to_party.get(inviter_id, "")
	if inviter_party != party_id:
		result["message"] = "Jugador %d no pertenece a party '%s'." % [inviter_id, party_id]
		return result

	if _player_to_party.has(invitee_id):
		result["message"] = "Jugador %d ya está en party '%s'." % [
			invitee_id, _player_to_party[invitee_id]
		]
		return result

	var party_data: Dictionary = _active_parties[party_id]
	var current_members: Array = party_data.get("members", [])

	var eval: Dictionary = evaluate_projected_state(current_members, invitee_faction)

	if not eval.get("allowed", false):
		result["message"] = eval.get("message", "Evaluación rechazada.")
		return result

	current_members.append({"id": invitee_id, "faction": invitee_faction})
	_player_to_party[invitee_id] = party_id

	result["success"] = true
	result["message"] = "Jugador %d invitado a party '%s' por %d. %s" % [
		invitee_id, party_id, inviter_id, eval.get("message", "")
	]

	member_joined.emit(party_id, invitee_id)
	return result


## Transferencia de liderazgo. Si el nuevo líder cambiaría la composición
## de la party (no, el líder ya es miembro), solo se actualiza leader_id.
## Pero se valida igualmente para asegurar la integridad.
@rpc("authority", "reliable")
func server_transfer_leadership(party_id: String, current_leader_id: int,
		new_leader_id: int) -> Dictionary:

	var result: Dictionary = {"success": false, "message": ""}

	if not _active_parties.has(party_id):
		result["message"] = "Party '%s' no existe." % party_id
		return result

	var party_data: Dictionary = _active_parties[party_id]

	if party_data.get("leader_id", -1) != current_leader_id:
		result["message"] = "Jugador %d no es el líder de party '%s'." % [
			current_leader_id, party_id
		]
		return result

	# Verificar que el nuevo líder es miembro de la party.
	var new_leader_found: bool = false
	var members: Array = party_data.get("members", [])
	for member: Dictionary in members:
		if member.get("id", -1) == new_leader_id:
			new_leader_found = true
			break

	if not new_leader_found:
		result["message"] = "Jugador %d no es miembro de party '%s'." % [
			new_leader_id, party_id
		]
		return result

	# Transferir liderazgo (no cambia composición, no necesita re-evaluar invariante).
	party_data["leader_id"] = new_leader_id

	result["success"] = true
	result["message"] = "Liderazgo de party '%s' transferido de %d a %d." % [
		party_id, current_leader_id, new_leader_id
	]

	leadership_transferred.emit(party_id, current_leader_id, new_leader_id)
	return result


## Reconexión de emergencia: un jugador que se desconectó intentando
## reincorporarse a su party. Se re-evalúa el invariante porque la party
## pudo haber cambiado durante su ausencia.
@rpc("authority", "reliable")
func server_handle_reconnection(party_id: String, player_id: int,
		player_faction: int) -> Dictionary:

	var result: Dictionary = {"success": false, "message": ""}

	if not _active_parties.has(party_id):
		result["message"] = "Party '%s' ya no existe. No se puede reconectar." % party_id
		return result

	var party_data: Dictionary = _active_parties[party_id]
	var current_members: Array = party_data.get("members", [])

	# Verificar si el jugador ya está en la lista (reconexión sin haberse limpiado).
	for member: Dictionary in current_members:
		if member.get("id", -1) == player_id:
			result["success"] = true
			result["message"] = "Jugador %d ya está en party '%s'. Reconexión exitosa." % [
				player_id, party_id
			]
			return result

	# El jugador fue removido durante la desconexión. Re-evaluar si puede volver.
	var eval: Dictionary = evaluate_projected_state(current_members, player_faction)

	if not eval.get("allowed", false):
		result["message"] = "Reconexión denegada para jugador %d. %s" % [
			player_id, eval.get("message", "")
		]
		# Limpiar el mapeo inverso si quedó stale.
		if _player_to_party.get(player_id, "") == party_id:
			_player_to_party.erase(player_id)
		return result

	# Re-incorporar al jugador.
	current_members.append({"id": player_id, "faction": player_faction})
	_player_to_party[player_id] = party_id

	result["success"] = true
	result["message"] = "Reconexión exitosa. Jugador %d reincorporado a party '%s'. %s" % [
		player_id, party_id, eval.get("message", "")
	]

	member_joined.emit(party_id, player_id)
	return result


## Elimina a un jugador de su party.
@rpc("authority", "reliable")
func server_remove_member(party_id: String, player_id: int) -> Dictionary:
	var result: Dictionary = {"success": false, "message": ""}

	if not _active_parties.has(party_id):
		result["message"] = "Party '%s' no existe." % party_id
		return result

	var party_data: Dictionary = _active_parties[party_id]
	var members: Array = party_data.get("members", [])

	var found_index: int = -1
	for i: int in range(members.size()):
		if members[i].get("id", -1) == player_id:
			found_index = i
			break

	if found_index == -1:
		result["message"] = "Jugador %d no es miembro de party '%s'." % [player_id, party_id]
		return result

	members.remove_at(found_index)
	_player_to_party.erase(player_id)

	# Si la party queda vacía, disolverla.
	if members.size() == 0:
		_active_parties.erase(party_id)
		result["success"] = true
		result["message"] = "Jugador %d removido. Party '%s' disuelta (vacía)." % [
			player_id, party_id
		]
		party_dissolved.emit(party_id)
		return result

	# Si el líder se fue, transferir al primer miembro restante.
	if party_data.get("leader_id", -1) == player_id:
		var new_leader_id: int = members[0].get("id", -1)
		party_data["leader_id"] = new_leader_id
		leadership_transferred.emit(party_id, player_id, new_leader_id)

	result["success"] = true
	result["message"] = "Jugador %d removido de party '%s'. Quedan %d miembros." % [
		player_id, party_id, members.size()
	]

	member_left.emit(party_id, player_id)
	return result


# =============================================================================
# RPCs DE INTENCIÓN DEL CLIENTE
# =============================================================================

## El cliente solicita unirse a una party.
@rpc("any_peer", "call_local", "reliable")
func request_join(party_id: String, applicant_faction: int) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	server_request_join(party_id, sender_id, applicant_faction)


## El cliente solicita invitar a un jugador a su party.
@rpc("any_peer", "call_local", "reliable")
func request_invite(invitee_id: int, invitee_faction: int) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	var party_id: String = _player_to_party.get(sender_id, "")
	if party_id == "":
		push_error("PartyManager.request_invite: jugador %d no está en ninguna party." % sender_id)
		return
	server_invite_player(party_id, sender_id, invitee_id, invitee_faction)


## El cliente solicita transferir liderazgo.
@rpc("any_peer", "call_local", "reliable")
func request_transfer_leadership(new_leader_id: int) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	var party_id: String = _player_to_party.get(sender_id, "")
	if party_id == "":
		push_error("PartyManager.request_transfer: jugador %d no está en ninguna party." % sender_id)
		return
	server_transfer_leadership(party_id, sender_id, new_leader_id)


## El cliente solicita abandonar su party.
@rpc("any_peer", "call_local", "reliable")
func request_leave() -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	var party_id: String = _player_to_party.get(sender_id, "")
	if party_id == "":
		push_error("PartyManager.request_leave: jugador %d no está en ninguna party." % sender_id)
		return
	server_remove_member(party_id, sender_id)


# =============================================================================
# CONSULTAS PÚBLICAS
# =============================================================================

## Devuelve la party de un jugador, o "" si no está en ninguna.
func get_player_party(player_id: int) -> String:
	return _player_to_party.get(player_id, "")


## Devuelve los miembros de una party, o un array vacío.
func get_party_members(party_id: String) -> Array:
	if not _active_parties.has(party_id):
		return []
	return _active_parties[party_id].get("members", [])


## Devuelve el líder de una party, o -1 si no existe.
func get_party_leader(party_id: String) -> int:
	if not _active_parties.has(party_id):
		return -1
	return _active_parties[party_id].get("leader_id", -1)


## Devuelve si un jugador está solo (no en party o party de 1).
## Útil para aplicar penalizaciones de Mercenario solitario.
func is_player_solo(player_id: int) -> bool:
	var party_id: String = _player_to_party.get(player_id, "")
	if party_id == "":
		return true
	var members: Array = get_party_members(party_id)
	return members.size() <= 1
