## RecipeData — una receta de crafteo, definida como DATO.
##
## Una receta solo DESCRIBE: "con estos ingredientes obtienes este resultado".
## La LÓGICA de craftear (comprobar, consumir, entregar) NO está aquí: vive en
## scripts/systems/crafting_system.gd.
##
## Separar el dato (la receta) de la lógica (cómo se ejecuta) es lo que nos
## permitirá mover el crafteo al servidor más adelante sin reescribir ni una
## sola receta.
class_name RecipeData
extends Resource

## Identificador único de la receta (ej. "receta_tabla").
@export var id: String = ""

## Nombre legible para mostrar en el futuro menú de crafteo.
@export var display_name: String = ""

## Ingredientes: diccionario { id_item: cantidad }.
## Ejemplo: {"madera": 2} = consume 2 de madera.
## Usamos un diccionario porque se lee y se edita muy fácil en el .tres.
@export var ingredients: Dictionary = {}

## Qué item produce la receta (su id).
@export var output_item_id: String = ""

## Cuántas unidades produce.
@export var output_quantity: int = 1
