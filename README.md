# At the end game

Juego 2D top-down (vista cenital) de **recolección y crafteo** con una economía
dirigida por los jugadores, inspirado en RuneScape. Hecho en Godot 4.6.

> Bucle central: **recolectar → craftear → mejorar herramientas → comerciar.**

📖 Lee primero [`docs/VISION.md`](docs/VISION.md) — incluye las **Reglas
Innegociables** del proyecto. Roadmap en [`docs/ROADMAP.md`](docs/ROADMAP.md) y
diseño de economía en [`docs/ECONOMIA.md`](docs/ECONOMIA.md).

## Stack
- **Motor:** Godot 4.6
- **Lenguaje:** GDScript
- **Control de versiones:** Git + GitHub
- **Coste:** 0 € (solo herramientas y assets gratuitos / open source)

## Cómo abrir el proyecto
1. Instala [Godot 4.6](https://godotengine.org/download) (versión **GDScript**,
   no la de .NET/C#).
2. Abre Godot → **Importar** → selecciona el archivo `project.godot` de esta
   carpeta → **Importar y editar**.
3. Godot generará la carpeta `.godot/` (caché) e importará el icono. Es normal.
4. Pulsa **Play** (F5). Se ejecuta `scenes/main.tscn`.

## Cómo se juega (de momento)
- **Mover:** WASD o flechas.
- **Interactuar / recolectar:** E o Espacio (acércate a un recuadro de color).
- **Inventario:** tecla I (acción ya mapeada; la interfaz aún no existe).

Por ahora el feedback de recolección sale por la **consola de Godot** (`print`).
Verás mensajes como `+1 madera` o `+3 madera (¡tu Hacha se ha roto!)`.

## Estructura de carpetas
```
At-the-end-game/
├── project.godot          # Configuración del proyecto (no editar a mano salvo necesidad)
├── icon.svg               # Icono provisional
├── scenes/                # Escenas .tscn (lo que se ensambla en el editor)
│   ├── main.tscn          #   Escena principal (mundo de prueba)
│   ├── player.tscn        #   Personaje
│   └── resource_node.tscn #   Recurso recolectable reutilizable
├── scripts/               # Código GDScript, organizado por responsabilidad
│   ├── autoload/          #   Singletons globales (Database, GameState)
│   ├── data/              #   Definiciones de datos (Resource): ItemData, ToolData, RecipeData
│   ├── systems/           #   Lógica PURA, sin visual (Inventory, CraftingSystem)
│   └── nodes/             #   Scripts pegados a nodos de escena (Player, ResourceNode)
├── resources/             # DATOS del juego en .tres (dirigido por datos)
│   ├── items/             #   madera, mineral, fibra, tabla, hacha
│   └── recipes/           #   receta_tabla, receta_hacha
├── assets/                # Arte, audio, fuentes (gratuitos / open source)
└── docs/                  # Visión, roadmap y economía
```

### ¿Por qué esta estructura?
- Separa **datos** (`resources/`, `scripts/data/`), **lógica** (`scripts/systems/`,
  `scripts/autoload/`) y **presentación** (`scenes/`, `scripts/nodes/`).
- Esa separación es deliberada: el día que haya servidor, la lógica de
  inventario/economía se podrá mover allí sin reescribir lo visual
  (principio de **autoridad de servidor**).

## Licencia / assets
Todo debe ser gratuito y open source. No añadir nada de pago (ver
`docs/VISION.md`).
