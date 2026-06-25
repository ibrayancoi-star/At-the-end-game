# FUNDACIÓN DEL SISTEMA — REGLAS GLOBALES

## 1. El Tiempo del Mundo (El Reloj de Ticks)
- El juego no funciona por "segundos", funciona por **Game Ticks**.
- **1 Game Tick = 0.6 segundos** (Idéntico a RuneScape).
- Ninguna acción, movimiento, recolección o crafteo puede durar una fracción de tick. Todo debe ser un número entero de ticks (Ej: Talar = 3 ticks / 1.8s; Caminar 1 casilla = 1 tick / 0.6s).
- *Por qué:* Esto permite que el servidor procese todas las entradas de todos los jugadores en "paquetes" ordenados cada 0.6 segundos, eliminando ventajas por lag y facilitando el guardado de datos en la base de datos.

## 2. Restricciones Físicas del Inventario
- **Espacio Máximo Base:** 28 slots individuales (Independiente de si el ítem es apilable o no).
- **Límite de Pilas (Stack Limit):** Un slot que contenga un ítem apilable (como oro o flechas) tiene un valor máximo de `2,147,483,647` (Límite físico de un entero de 32 bits firmado).

## 3. La Curva de Progresión Maestra (Nivel 1 al 99)
- **Nivel Máximo de Habilidad:** 99.
- **Fórmula Global de Experiencia (XP):** La experiencia requerida para el nivel `N` se calcula mediante:
  `XP_Requerida(N) = truncar( base_xp * (N ^ 1.5) )`
- *Por qué:* Al definir la fórmula aquí, si en la Fase 4 descubrimos que los jugadores suben demasiado rápido, cambiamos el exponente `1.5` en este archivo central y todo el juego se rebalanceará automáticamente sin tocar las habilidades individualmente.

## 4. Protocolo Atómico de Transacción de Estado (Anti-Duplicación)
- Toda modificación del inventario o del banco debe ser **Atómica** (Principio ACID de bases de datos).
- Si una receta pide 2 maderas para dar 1 tabla:
  1. El servidor "congela" el inventario.
  2. Verifica la existencia de las 2 maderas.
  3. Resta las 2 maderas.
  4. Añade la tabla.
  5. Si cualquiera de los pasos falla (ej. pérdida de conexión en medio), la transacción completa se cancela (Rollback) y el inventario vuelve a su estado inicial exacto. Esto elimina al 100% los exploits clásicos de duplicación de ítems (*duping*).
