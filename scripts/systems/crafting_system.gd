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


## Ejecuta el crafteo: consume los ingredientes y entrega el resultado.
## Es TODO O NADA: si falta algo, no toca el inventario y devuelve false.
static func craft(recipe: RecipeData, inventory: Inventory) -> bool:
	if not can_craft(recipe, inventory):
		return false

	# Consumir los ingredientes.
	# SUMIDERO económico: estos materiales SALEN de la economía para siempre.
	for item_id in recipe.ingredients:
		inventory.remove_item(item_id, recipe.ingredients[item_id])

	# Entregar el resultado.
	inventory.add_item(recipe.output_item_id, recipe.output_quantity)
	return true
