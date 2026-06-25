## ItemData — definición INMUTABLE de un objeto del juego.
##
## Esto es un Resource (un DATO), no un nodo visual. Aquí vive solo la
## "ficha" del item: su id, nombre, icono, cuánto apila, etc. El estado que
## cambia durante la partida (cuántos tienes, la durabilidad de una
## herramienta concreta) NO va aquí: eso lo guarda el inventario.
##
## ¿Por qué? Porque una misma definición "madera" se comparte para TODOS los
## montones de madera del juego. Si guardáramos aquí la cantidad, todos los
## montones compartirían el mismo número. La definición es la receta; el
## inventario es lo que tienes en la mano.
##
## Usar Resource cumple el principio de DISEÑO DIRIGIDO POR DATOS del proyecto:
## añadir un item nuevo = crear un archivo .tres, sin tocar el motor.
class_name ItemData
extends Resource

## Identificador único y estable (ej. "madera"). Es la CLAVE con la que el
## resto del juego se refiere a este item. El inventario guarda estos ids de
## texto, NO referencias directas al objeto.
##
## ¿Por qué texto y no la referencia? Pensando en el futuro servidor: el
## servidor mandará "tienes madera x5" y el cliente buscará la ficha por id.
## Además, guardar la partida en disco es trivial si todo son ids + números.
@export var id: String = ""

## Nombre legible que se mostrará al jugador.
@export var display_name: String = ""

## Descripción larga (el editor muestra una caja de texto multilínea).
@export_multiline var description: String = ""

## Icono para la futura interfaz de inventario. Puede quedar vacío de momento.
@export var icon: Texture2D

## Cuántas unidades caben en un mismo hueco del inventario.
## Las herramientas valen 1 (cada una lleva su propia durabilidad).
@export var max_stack: int = 99

## Categoría libre para organizar/filtrar (ej. "recurso", "material",
## "herramienta"). No afecta a la lógica; es para tu comodidad.
@export var category: String = "recurso"


# ─────────────────────────────────────────────────────────────────────────
# ESTADO DE INESTABILIDAD Y FLUIDOS (Lore Capa 1 — RNG)
# ─────────────────────────────────────────────────────────────────────────
# Estas tres propiedades alimentan las mecánicas descritas en
# docs/systems/ARTEFACT_TRAUMA.md. Son valores POR DEFECTO de la definición
# del item; el estado que varía por instancia durante la partida (p. ej. la
# integridad concreta de un artefacto) seguirá viviendo en el inventario.
#
# NOTA DE COMPATIBILIDAD GODOT 4: la sintaxis del brief
#   export(float, 0.0, 1.0) var x
# es de Godot 3 y NO compila en Godot 4.6. El equivalente correcto es
#   @export_range(min, max) var x: float
# que es lo que usamos aquí (mismo rango 0.0–1.0, deslizador en el Inspector).

## Trauma residual de datos de la RNG retenido por el item (0.0 = limpio,
## 1.0 = profundamente traumatizado). A mayor valor, más probabilidad de
## glitches e inestabilidad al operarlo.
@export_range(0.0, 1.0) var emotional_instability: float = 0.0

## Grado de purificación del item, usado en procesos de destilación/refinado
## (0.0 = impuro, 1.0 = puro). Refinar sube este valor; degradarse lo baja.
@export_range(0.0, 1.0) var purity_percentage: float = 1.0

## Si es verdadero, el item es un fluido inestable: su peso/volumen interactúa
## de forma diferente al transportarlo (relevante en la Fase de Peregrinación).
@export var is_unstable_fluid: bool = false
