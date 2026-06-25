class_name SalvageData
extends Resource
## SalvageData — tabla de DESMONTAJE de un objeto base (ingeniería inversa).
##
## Define qué PARTES funcionales se obtienen al desmontar un objeto base
## (monitor, electrodoméstico, arma...). Es un DATO: añadir/ajustar un desmontaje
## = editar un .tres, sin tocar código.
##
## La LÓGICA (consumir base, validar, entregar partes de forma atómica) vive en
## systems/reverse_engineering/salvage_system.gd.

## Id del objeto base que se desmonta. Es la CLAVE en Database (get_salvage).
## Debe coincidir con el id de un ItemData base (ej. "monitor").
@export var id: String = ""

## Partes que produce el desmontaje: diccionario { id_parte: cantidad }.
## Ej. {"placa_circuito": 1, "bateria": 1}.
@export var yields: Dictionary = {}
