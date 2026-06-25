class_name SkillSet
extends RefCounted
## SkillSet — ESTADO de habilidades de un jugador (nivel/XP por habilidad).
##
## Lógica pura (RefCounted), server-portable. Sirve para CUALQUIER habilidad
## (Combate, Ingeniería, ...): la lista de habilidades existentes son datos
## (SkillData en Database); aquí solo guardamos el progreso del jugador.
##
## Curva de progresión (docs/SYSTEM_FOUNDATION.md):
##   XP_requerida(N) = trunc(base_xp · N^1.5)   — umbral acumulado para el nivel N.
## Un jugador SIN XP es nivel 0 (sin entrenar); el máximo es SKILL_MAX_LEVEL (99).

## Se emite cuando una habilidad sube (o baja) de nivel.
signal skill_changed(skill_id: String, new_level: int)

# XP acumulada por habilidad. id -> int. Lo que no está aquí cuenta como 0 XP.
var _xp: Dictionary = {}


## XP acumulada total de una habilidad.
func get_xp(skill_id: String) -> int:
	return _xp.get(skill_id, 0)


## Nivel actual de una habilidad (derivado de su XP).
func get_level(skill_id: String) -> int:
	return _level_from_xp(get_xp(skill_id))


## Añade XP a una habilidad. Si cambia de nivel, emite skill_changed.
func add_xp(skill_id: String, amount: int) -> void:
	if amount <= 0:
		return
	var before: int = get_level(skill_id)
	_xp[skill_id] = get_xp(skill_id) + amount
	var after: int = get_level(skill_id)
	if after != before:
		skill_changed.emit(skill_id, after)


## XP acumulada necesaria para ALCANZAR el nivel `n` (umbral). n<=0 -> 0.
static func xp_for_level(n: int) -> int:
	if n <= 0:
		return 0
	return int(floor(ConstantsCore.SKILL_XP_BASE * pow(float(n), 1.5)))


## Calcula el nivel correspondiente a una XP acumulada.
func _level_from_xp(xp: int) -> int:
	var level: int = 0
	while level < ConstantsCore.SKILL_MAX_LEVEL and xp >= xp_for_level(level + 1):
		level += 1
	return level
