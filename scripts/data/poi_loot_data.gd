class_name PoiLootData
extends Resource
## PoiLootData — tabla de LOOT de un POI / zona (Punto de Interés).
##
## Define qué objeto base se recolecta en una zona y en qué rango de CALIDAD
## (oculta hasta analizar). Es un DATO: añadir una zona = un .tres.
##
## La LÓGICA (generar la chatarra oculta en el inventario) vive en
## systems/reverse_engineering/loot_system.gd.

## Id del POI/zona. Es la CLAVE en Database (get_poi). Ej. "centro_comercial".
@export var id: String = ""

## Nombre legible de la zona.
@export var display_name: String = ""

## Objeto base que suelta esta zona (id de un ItemData base).
@export var base_item_id: String = ""

## Rango de CALIDAD oculta (porcentaje entero 0-100) de lo que se recolecta.
@export var quality_min: int = 10
@export var quality_max: int = 100
