## CraftingSystem — LÓGICA de crafteo. Separada de los datos y de lo visual.
##
## No guarda estado propio: son funciones ESTÁTICAS que reciben una receta y
## un inventario y operan sobre ellos. Se llaman así:
##     CraftingSystem.craft(receta, GameState.inventory)
##
## Igual que el inventario, está pensada para poder ejecutarse en el servidor
## el día de mañana. El cliente NUNCA debería decidir por su cuenta que ha
## fabricado algo: solo lo pide, y la autoridad (hoy local, mañana servidor)
## lo valida y lo ejecuta.
class_name CraftingSystem
extends RefCounted


## ¿Hay ingredientes suficientes en el inventario para esta receta?
static func can_craft(recipe: RecipeData, inventory: Inventory) -> bool:
	for item_id in recipe.ingredients:
		var needed: int = recipe.ingredients[item_id]
		if not inventory.has_item(item_id, needed):
			return false
	return true


## Ejecuta el crafteo de forma ATÓMICA (anti-duping): o se completa entero o el
## inventario queda EXACTAMENTE como estaba. Devuelve true si se craftéo.
##
## Usa una transacción del inventario: si algo falla a mitad (falta un
## ingrediente, o no cabe el resultado), se hace rollback al snapshot inicial.
## Esto cierra el exploit clásico de duplicación al interrumpir la operación.
static func craft(recipe: RecipeData, inventory: Inventory) -> bool:
	if not can_craft(recipe, inventory):
		return false

	inventory.begin_transaction()

	# Consumir ingredientes (SUMIDERO: salen de la economía para siempre).
	for item_id in recipe.ingredients:
		if not inventory.remove_item(item_id, recipe.ingredients[item_id]):
			inventory.rollback_transaction()
			return false

	# Entregar el resultado SOLO en slots principales (sin overflow): si no cabe,
	# se revierte todo y el crafteo no ocurre (el jugador debe hacer hueco).
	var leftover: int = inventory.add_item(recipe.output_item_id, recipe.output_quantity, false)
	if leftover > 0:
		inventory.rollback_transaction()
		return false

	inventory.commit_transaction()
	return true
