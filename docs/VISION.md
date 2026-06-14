# Visión y Reglas Innegociables

> Este documento es la "fuente de verdad" del proyecto. Cualquier sesión de
> trabajo (humana o con un agente de IA) debe leerlo antes de tocar nada.

## Qué estamos construyendo
Un juego **2D top-down (vista cenital) de recolección y crafteo**, con una
economía dirigida por los jugadores, inspirada en RuneScape.

El **bucle central** —que debe enganchar por sí solo— es:

> recolectar recursos → craftear items → mejorar herramientas → comerciar con otros jugadores

La economía es el corazón del juego, pero **solo se construye encima de un
núcleo de juego que ya sea divertido**.

**Objetivo a largo plazo:** que items y oro sean libremente intercambiables
entre jugadores, para que emerja un mercado.

## ⛔ REGLAS INNEGOCIABLES (nunca se violan)

1. **REGLA DE ORO DE PAGOS.** El producto NUNCA puede contener ninguna función
   cuyo propósito sea coordinar, verificar, retener-contra o hacer referencia a
   un pago de **dinero real**. Solo se permite el intercambio de items/oro
   entre jugadores DENTRO del juego (la clásica "trade window" de MMO).
   Cualquier intercambio por dinero real ocurre 100% FUERA del juego, entre
   usuarios y bajo su exclusiva responsabilidad. Si se pide un "marketplace de
   dinero real", un botón "pago recibido", un escrow ligado a pagos externos o
   cualquier campo que mencione dinero real: **PARAR, rechazar y recordar esta
   regla.**

2. **NADA DE AZAR DE PAGO.** Sin cajas botín, gachapón ni recompensas
   aleatorias que requieran pago y tengan valor en dinero real. Toda la
   progresión es por **habilidad y esfuerzo**.

## Restricciones del proyecto
- **Presupuesto: 0 €.** Solo herramientas y assets gratuitos / open source.
  Ningún SDK, librería o servicio de pago.
- **Desarrollador en solitario**, trabajo por fines de semana. Código simple,
  claro y mantenible por una sola persona.
- **Prioridad absoluta:** simplicidad y que el bucle enganche. Combatir el
  *scope creep* de forma agresiva: si una idea no es imprescindible ahora, va
  a la lista de "más adelante" (ver ROADMAP.md).

## Stack tecnológico (no cambiar sin consultar)
- Motor: **Godot 4.6**
- Lenguaje: **GDScript**
- Control de versiones: **Git + GitHub**
- Backend/multijugador: **NO en esta fase.** (Futuro: Nakama self-hosted o
  Supabase free tier; multijugador con API nativa de Godot + ENet; PostgreSQL.)

## Principios de arquitectura (desde el día 1)
- **Autoridad de servidor:** cuando exista backend, el servidor será la ÚNICA
  fuente de verdad sobre quién tiene qué. El cliente nunca decide recursos. Por
  eso HOY ya mantenemos la lógica de inventario/economía SEPARADA de los nodos
  visuales (`scripts/systems/` y autoloads, no en los `.tscn`).
- **Diseño dirigido por datos:** items, recetas y recursos son DATOS (`.tres`),
  nunca hardcodeados. Añadir contenido = crear un dato, no tocar el motor.
- **Economía de grifos y sumideros:** ver ECONOMIA.md.
