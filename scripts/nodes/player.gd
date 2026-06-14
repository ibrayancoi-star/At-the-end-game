## Player — el personaje controlable. Parte VISUAL / de escena.
##
## Sus responsabilidades son DOS y solo dos:
##   1) Moverse (top-down, en 4 direcciones libres).
##   2) Disparar la interacción de "recolectar".
##
## Fíjate en lo que NO hace: no decide qué item se obtiene, ni cuánto, ni
## toca el inventario directamente con reglas. Eso vive en ResourceNode y en
## Inventory. El jugador solo "pide interactuar". Mantener esta frontera clara
## es lo que hará fácil mover la lógica al servidor más adelante.
class_name Player
extends CharacterBody2D

## Velocidad en píxeles por segundo. Es @export para poder ajustarla desde el
## editor (Inspector) sin tocar el código.
@export var speed: float = 150.0

## Área hija que detecta qué hay cerca para poder interactuar.
## @onready = se asigna justo cuando el nodo entra en la escena.
## El "$" busca un nodo hijo por su nombre (aquí "InteractionArea").
@onready var interaction_area: Area2D = $InteractionArea


func _physics_process(_delta: float) -> void:
	# Leemos ACCIONES del Input Map, NUNCA teclas sueltas. Así se pueden
	# remapear y queda preparado para mando o controles táctiles.
	#
	# Input.get_vector(izq, der, arriba, abajo) devuelve un vector ya
	# normalizado: moverse en diagonal no es más rápido. Muy cómodo.
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	move_and_slide()  # mueve el cuerpo respetando colisiones


func _unhandled_input(event: InputEvent) -> void:
	# _unhandled_input solo recibe input que la UI no haya "consumido" antes.
	# Es el sitio correcto para acciones del mundo como interactuar.
	if event.is_action_pressed("interact"):
		_try_interact()


## Busca un recurso recolectable que solape el área de interacción y lo recolecta.
func _try_interact() -> void:
	for area in interaction_area.get_overlapping_areas():
		if area is ResourceNode:
			var result: String = (area as ResourceNode).harvest()
			# Feedback provisional por consola. Más adelante: texto flotante / UI.
			print(result)
			return  # solo recolectamos un recurso por pulsación
