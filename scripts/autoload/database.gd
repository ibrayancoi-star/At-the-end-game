extends Node
## Database (autoload / singleton) — REGISTRO de todas las definiciones de
## datos del juego: items y recetas. Se carga una sola vez al arrancar.
##
## Gracias a esto, el resto del código pide "dame el item 'madera'" sin tener
## que saber en qué archivo está. Y como ESCANEA carpetas enteras, añadir
## contenido nuevo = soltar un archivo .tres en la carpeta correcta. Eso es
## el DISEÑO DIRIGIDO POR DATOS en acción: sin tocar código.
##
## Se accede desde cualquier script simplemente escribiendo: Database.get_item(...)

const ITEMS_PATH := "res://resources/items/"
const RECIPES_PATH := "res://resources/recipes/"
const FACTIONS_PATH := "res://resources/factions/"

# Diccionarios internos: id -> definición. El "_" inicial es una convención
# para indicar "privado, no lo toques desde fuera; usa las funciones get_*".
var _items: Dictionary = {}
var _recipes: Dictionary = {}
var _factions: Dictionary = {}


func _ready() -> void:
	_load_folder(ITEMS_PATH, _items)
	_load_folder(RECIPES_PATH, _recipes)
	_load_folder(FACTIONS_PATH, _factions)
	print("Database lista: %d items, %d recetas, %d facciones." % [
		_items.size(), _recipes.size(), _factions.size()
	])


## Carga todos los .tres de una carpeta y los registra por su campo "id".
func _load_folder(path: String, target: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("Database: no se pudo abrir la carpeta %s" % path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res = load(path + file_name)
			# Solo registramos recursos que tengan un campo "id" no vacío.
			if res != null and "id" in res and res.id != "":
				target[res.id] = res
			else:
				push_warning("Database: %s no tiene un 'id' válido, se ignora." % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


## Devuelve la definición de un item por su id, o null si no existe.
func get_item(id: String) -> ItemData:
	return _items.get(id)


## Devuelve la definición de una receta por su id, o null si no existe.
func get_recipe(id: String) -> RecipeData:
	return _recipes.get(id)


## Devuelve todas las recetas (útil para construir el menú de crafteo).
func all_recipes() -> Array:
	return _recipes.values()


## Devuelve la definición de una facción por su id, o null si no existe.
func get_faction(id: String) -> FactionData:
	return _factions.get(id)


## Devuelve todas las facciones (útil para la futura pantalla de selección).
func all_factions() -> Array:
	return _factions.values()
