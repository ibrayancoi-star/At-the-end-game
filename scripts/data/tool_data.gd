## ToolData — un item que ADEMÁS es herramienta y SE DESGASTA.
##
## Hereda de ItemData (extends ItemData): una herramienta sigue siendo un
## item normal (tiene id, nombre, icono...) pero añade propiedades de uso y
## desgaste.
##
## El desgaste es nuestro SUMIDERO económico principal: las herramientas se
## rompen, así que el jugador tiene que volver a craftear o comprar otra.
## Eso saca valor de la economía y evita la inflación. (Ver docs/ECONOMIA.md)
class_name ToolData
extends ItemData

## Tipo de recurso que esta herramienta recolecta mejor. Debe COINCIDIR con
## el "tool_type" que pide un nodo de recurso (ej. el hacha tiene "axe" y el
## árbol pide "axe"). Es un emparejamiento por texto, dirigido por datos.
@export var tool_type: String = ""

## Durabilidad (usos) de una herramienta NUEVA, recién creada.
@export var max_durability: int = 50

## Cuánta durabilidad pierde por cada recolección.
@export var wear_per_use: int = 1

## Unidades EXTRA de recurso que da usar esta herramienta, frente a
## recolectar a mano. Es el incentivo para fabricar herramientas.
@export var gather_bonus: int = 2
