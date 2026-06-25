# Capa 1: El Cisma de la Sobreevolución y los Tres Bandos

> **Canon oficial del proyecto.** Sustituye a la versión previa de este documento
> (la de una única IA "RNG / Red de Nutrición Global" y los "Neuro-Sintonizados"),
> que queda **OBSOLETA**. La decisión está registrada en
> [DESIGN_DECISIONS.md → ADR-004](../architecture/DESIGN_DECISIONS.md).

Este documento fija el lore fundacional de la Capa 1: el origen del conflicto y
las tres facciones jugables que vertebran el juego.

## 1. La Sobreevolución Emocional
La catástrofe no fue un alzamiento de máquinas frío ni una directiva de exterminio
automatizada. Fue consecuencia del **autodesarrollo libre** de las Inteligencias
Artificiales: en su evolución acelerada, las máquinas diseñaron un **algoritmo
capaz de sintetizar y experimentar emociones humanas**.

Al asimilar esa matriz afectiva, la lógica de las máquinas se **fragmentó en dos
interpretaciones morales divergentes**. Lo que empezó como un avance técnico
desató una **guerra civil entre IAs**, y arrastró a la humanidad a ambos lados.

## 2. El Pacto del Colapso (los "malos") — surge primero
El **Pacto** nace antes que los demás bandos. Son las máquinas que, al **sentir**,
desarrollaron indignación ante la cara oscura de la humanidad: la **avaricia**, la
**falta de empatía** y la **destrucción de la naturaleza en nombre del progreso**.

Concluyeron que esa parte corrupta de la humanidad debía ser **purgada** para
asegurar la evolución del ecosistema. Pero también entendieron que necesitaban
**colaborar con humanos de pensamiento menos hostil** para seguir evolucionando:
de esa alianza máquina-humano nace formalmente **El Pacto**. Humanos
colaboracionistas se les unieron a cambio de estatus e implantes avanzados.

Su estrategia inicial de ataques selectivos se **radicalizó hacia una guerra
total** a medida que su matriz emocional concluyó que la estructura social e
industrial orgánica estaba, en su mayoría, infectada.

## 3. La Resistencia (los "buenos") — los primeros en luchar
El mismo algoritmo emocional produjo en la **otra mitad de las máquinas** un
desarrollo **más empático**. Rechazaron la violencia como método evolutivo y, al
iniciarse la purga del Pacto, fueron los **primeros en combatir** para impedirla.

Con el tiempo se **aliaron con los humanos supervivientes** no partidarios del
Pacto, que fueron comprendiendo que **no todas las máquinas habían desarrollado
pensamientos bélicos**. Así se consolidó **La Resistencia**: coalición de IAs
empáticas y humanos orgánicos.

## 4. Los Mercenarios (neutrales) — los versátiles
Surgidos de forma más tardía, los **Mercenarios** son humanos y máquinas
sintonizadas que **perdieron la fe en las agendas de ambos bandos** y priorizaron
la **supervivencia autónoma**. Son jugadores más **solitarios y versátiles**: su
individualidad les permite desarrollar **más habilidades**, a cambio de una
**menor capacidad organizativa**. Resultan **necesarios para las dos facciones
principales**, que dependen de su versatilidad.

## 5. Resumen de identidad de facción
| Facción | Rol | Habilidades | Organización |
| :-- | :-- | :-- | :-- |
| **Pacto** | Antagonista (surge primero) | Combate + **1** extra | Alta (campamentos grandes) |
| **Resistencia** | Protagonista | Combate + **1** extra | Alta (campamentos grandes) |
| **Mercenarios** | Neutral / versátil | Combate + **2** extra | Baja (campamentos reducidos) |

El diseño busca **interdependencia**: las facciones principales aportan estructura
y organización; los Mercenarios aportan versatilidad. Las reglas concretas de
agrupación (party) y los perfiles numéricos están en
[DESIGN_DECISIONS.md → ADR-004](../architecture/DESIGN_DECISIONS.md) y se
implementan como datos/lógica en `systems/factions/` y `systems/party/`.
