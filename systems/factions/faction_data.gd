class_name FactionData
extends Resource
## FactionData — definición (DATO) del PERFIL de una facción.
##
## Diseño dirigido por datos: añadir/ajustar una facción = editar un .tres, sin
## tocar código. El lore está en docs/narrative/CAP_1_EMPATIA.md y las reglas de
## party en systems/party/party_rules.gd (ver ADR-004).
##
## OJO: esto es el PERFIL (sabor + números), no la identidad enum. El valor enum
## canónico vive en PartyRules.Faction; aquí se referencia por `faction_type`.

## Identificador estable (clave en Database). Ej. "pacto".
@export var id: String = ""

## Nombre legible para la UI. Ej. "El Pacto".
@export var display_name: String = ""

## Índice que mapea a PartyRules.Faction: 0=PACTO, 1=RESISTENCIA, 2=MERCENARY.
@export var faction_type: int = 0

## ¿Es una de las dos facciones principales (Pacto/Resistencia)?
## Los Mercenarios son neutrales (false).
@export var is_main_faction: bool = true

## Habilidad base que todos los miembros de la facción comparten.
@export var base_skill: String = "combate"

## Cuántas habilidades EXTRA (además de la base) puede desarrollar la facción.
## Pacto/Resistencia = 1; Mercenarios = 2 (más versátiles).
@export var extra_skill_slots: int = 1

## Capacidad de jugadores de los campamentos de la facción.
## Principales = mayor; Mercenarios = menor. NÚMEROS PLACEHOLDER (balance TBD).
@export var camp_capacity: int = 24
