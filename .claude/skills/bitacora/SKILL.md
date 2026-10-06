---
name: bitacora
description: Registra en docs/bitacora.md el avance del challenge - decisiones tomadas (con alternativas y porqué), preguntas que el usuario le hace a Claude y sus respuestas resumidas, contexto nuevo y pendientes. Usar proactivamente cada vez que se cierre una decisión, se responda una pregunta de enfoque, aparezca un hallazgo o criterio nuevo, o el usuario pida "anotá esto" / "/bitacora".
---

# Bitácora del challenge

Objetivo: que no se pierda contexto entre sesiones y tener material para la sección
"Uso de IA" y "criterios tomados" del entregable.

Archivo: `docs/bitacora.md`. Si no existe, crealo con la estructura de abajo.

## Estructura del archivo

```markdown
# Bitácora — Challenge Reporting & Automation

## Contexto vigente
<!-- Estado actual en bullets cortos: en qué paso del plan estamos, herramientas elegidas,
     números clave validados. Se REESCRIBE (no se acumula) para que siempre refleje el hoy. -->

## Decisiones
| # | Fecha | Decisión | Alternativas descartadas | Por qué |
|---|---|---|---|---|

## Pendientes / dudas abiertas
- [ ] ...

## Registro cronológico
### YYYY-MM-DD
- **[Pregunta]** resumen de lo que preguntó el usuario → resumen de la respuesta/recomendación.
- **[Decisión #N]** ...
- **[Hallazgo]** ...
- **[Hecho]** qué se implementó o completó (archivo/paso del plan).
```

## Reglas

1. **Agregá, no reescribas**: Decisiones y Registro cronológico son append-only. Solo
   "Contexto vigente" se reescribe, y los pendientes se tildan (`[x]`) al resolverse.
2. **Corto y concreto**: una o dos líneas por entrada. Incluí números y nombres de
   archivo cuando existan. Nada de transcribir la conversación.
3. **Distinguí quién decidió**: si la decisión la tomó el usuario sobre una sugerencia de
   Claude, decilo ("sugerido por Claude, aceptado"). Sirve para la sección de uso de IA.
4. **Una decisión = una fila** con su porqué. Si una decisión reemplaza a otra, nueva fila
   que referencie a la anterior (`reemplaza #3`).
5. **Fechas absolutas** (YYYY-MM-DD), nunca "hoy" o "ayer".
6. Después de escribir, avisá al usuario en una línea qué registraste.
