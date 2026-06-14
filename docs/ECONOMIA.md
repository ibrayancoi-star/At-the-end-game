# Diseño de la economía: grifos y sumideros

Una economía de juego sana se piensa como un sistema de **grifos** (cómo ENTRA
valor) y **sumideros** (cómo SALE valor). Si entra más de lo que sale, hay
inflación (todo pierde valor); si sale más de lo que entra, hay deflación
(escasez frustrante). El objetivo es un equilibrio dinámico.

## 🚰 Grifos (entrada de valor)
- **Recolección.** Talar, minar, recoger fibra. Es la fuente principal de
  materia prima. (Implementado en `ResourceNode.harvest()`.)
- **Recompensas** (futuro): misiones, logros, etc.

> Hoy, recolectar un recurso CREA valor nuevo en la economía.

## 🕳️ Sumideros (salida de valor) — ¡los más importantes!
- **Desgaste de herramientas (PRINCIPAL).** Cada uso gasta durabilidad; al
  llegar a 0 la herramienta se rompe y desaparece. Obliga a fabricar/comprar
  más, lo que mantiene la demanda de materiales. (Implementado en
  `Inventory.wear_tool()` y `ToolData`.)
- **Consumo al craftear.** Los ingredientes de una receta se destruyen al
  fabricar. (Implementado en `CraftingSystem.craft()`.)
- **Tasa de mercado (futuro).** Un pequeño % cobrado en cada venta del mercado
  retira oro de la economía.

## 💰 Moneda interna (oro)
- Estructura básica ya existe en `GameState` (`gold`, `add_gold`, `spend_gold`).
- TODAVÍA sin mercado: el oro aún no tiene en qué gastarse de forma
  significativa. Eso llega con las fases de comercio.

## Items intercambiables, no ligados a la cuenta
Los items valiosos deben poder pasar de un jugador a otro (es lo que permite
que emerja un mercado). NO se "vinculan a la cuenta". Esto es una decisión de
diseño deliberada, alineada con la visión a largo plazo (ver VISION.md).

## ⛔ Recordatorio de las Reglas Innegociables
Toda esta economía vive **dentro del juego**. El juego NUNCA coordina ni hace
referencia a pagos de dinero real, ni usa azar de pago. Ver VISION.md.
