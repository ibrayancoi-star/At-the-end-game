class_name SkillData
extends Resource
## SkillData — definición (DATO) de una HABILIDAD del juego.
##
## El juego tendrá VARIAS habilidades (ver ADR-004 / DOCUMENTO MAESTRO §6.1):
## Combate, Ingeniería, Agricultura, Construcción, Medicina. Añadir una nueva =
## crear un .tres en resources/skills/, sin tocar código.
##
## Esto es solo la "ficha" (id, nombre, descripción). El ESTADO por jugador
## (nivel y XP) vive en SkillSet (systems/skills/skill_set.gd). La curva de
## progresión es común a todas (ver docs/SYSTEM_FOUNDATION.md).

## Identificador estable (clave en Database). Ej. "ingenieria".
@export var id: String = ""

## Nombre legible para la UI. Ej. "Ingeniería".
@export var display_name: String = ""

## Descripción de qué hace/desbloquea la habilidad.
@export_multiline var description: String = ""
