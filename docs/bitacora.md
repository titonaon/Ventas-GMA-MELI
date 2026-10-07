# Bitácora — Challenge Reporting & Automation

## Contexto vigente
- Paso actual: **Etapa 3 — Cálculos**. Etapas 1 y 2 cerradas. `productos_evento` validada: oficial 70 productos / USD 113.237,37; particular 97 / USD 161.416,94; **total evento USD 274.654,31**.
- Para correr bloques: `python src/correr.py <bloque>` (siempre corre `carga` primero).
- Trabajo en conjunto (decisión #6): Claude puede escribir código, de a partes chicas y explicando; el usuario valida cada paso.
- Motor SQL: **DuckDB** (decisión #5).
- Entregable: HTML generado con Python, parametrizable por evento/área (config-driven).
- Números exploratorios (a revalidar con el SQL propio): oficial USD 113,2K + particulares
  2026 en camisetas/álbumes/cartas USD 161,4K = **USD 274,7K**; incremental ~USD 211K.

## Decisiones
| # | Fecha | Decisión | Alternativas descartadas | Por qué |
|---|---|---|---|---|
| 1 | 2026-10-05 | El usuario resuelve el challenge; Claude asiste con preguntas | Que Claude lo implemente | Decisión del usuario |
| 2 | 2026-10-05 | Seguir el plan de 7 pasos (entender → clasificar → calcular → conclusiones → entregable → anexos → revisión) | — | Sugerido por Claude, aceptado |
| 3 | 2026-10-05 | Entregable HTML generado por Python, con inputs parametrizables (config por evento) | Presentación estática, dashboard BI | Responde también al punto 3 (escala) y evita ETL manual |
| 4 | 2026-10-05 | Llevar bitácora en `docs/bitacora.md` vía skill `bitacora` | — | No perder contexto; insumo para "uso de IA" |
| 5 | 2026-10-05 | Motor SQL: DuckDB | SQLite | Lee CSV directo con autodetección de separador, fechas reales, ILIKE/regex, integra con pandas. Sugerido por Claude, aceptado |
| 6 | 2026-10-05 | Trabajo en conjunto: Claude escribe código por partes, explicando; el usuario acompaña y valida (reemplaza #1) | Usuario solo | Se permite IA; prioridad es entender todo |
| 7 | 2026-10-06 | Las 10 ventas repetidas se mantienen en los números y se mencionan en la nota de criterios (con el patrón de posible duplicado técnico, para avisar al equipo de datos) | Excluirlas con `ventas_raw` + `QUALIFY ROW_NUMBER()` (recomendación de Claude) | Decisión del usuario: impacto ~USD 180 (0,008%), no cambia conclusiones |
| 8 | 2026-10-06 | Libros/pósters 2026 quedan FUERA del número principal y se muestran como hallazgo aparte (~USD 88K, lift ~7) | Incluirlos en el número | Respeta las categorías que pidió el comercial y aporta un insight para el próximo evento. Sugerido por Claude, aceptado |

## Pendientes / dudas abiertas
- [x] Elegir motor SQL → DuckDB (#5).
- [x] Libros/pósters 2026 → fuera del número, hallazgo aparte (#8).
- [ ] ¿"Venta de Olimpiadas" = todo el período, solo 14–30/07, o incremental? (propuesta: mostrar las tres).
- [ ] Instalar duckdb dentro del `.venv` (activar venv + `pip install -r requirements.txt`).
- [x] 10 pares de filas idénticas → se mantienen y se mencionan (#7).
- [ ] Restaurar `data/ventas.csv` original (`,` y fechas ISO) y volver la carga a `delim=','`.
- [ ] Separar los chequeos de calidad en bloques `-- name: calidad_*` y completar nulos (`pais`, `unidades`), montos/unidades `<= 0`.

## Registro cronológico
### 2026-10-05
- **[Pregunta]** Analizar el challenge → Claude perfiló los datos y detectó trampas de clasificación.
- **[Hallazgo]** Datos limpios: sin nulos, sin huérfanos, país venta = país producto. Separadores distintos (`,` vs `;`).
- **[Hallazgo]** Falsos positivos por título: Álbum Barcelona 1992, Camiseta Comité Olímpico 2016 Vintage (ediciones viejas, ventas planas); "Mochila Escolar Modelo Olimpico", libro de juegos antiguos, DVD Berlín 1936 (solo comparten la palabra).
- **[Hallazgo]** La licenciataria vende también mochilas y botellas (fuera de las 3 categorías) → cuentan igual.
- **[Hallazgo]** Efecto: arranca ~28/06, pico ~13× la base durante los Juegos, vuelve a la base ~20/08. Oficial = 41% sin sobreprecio (camiseta USD 36,1 vs 36,7). México 33% oficial, Chile 53%.
- **[Pregunta]** Tiempo estimado sin IA → 6-10 h (1 a 1,5 días).
- **[Pregunta]** Plan general del proyecto → plan de 7 pasos (decisión #2).
- **[Pregunta]** ¿SQLite para las consultas? → Claude recomienda DuckDB (lee CSV directo con autodetección de separador, ILIKE, funciones de fecha, integra con pandas); SQLite válido pero requiere cargar CSV vía pandas y tiene fechas más pobres.
- **[Pregunta]** Diseño para escala → pipeline config-driven: YAML por evento + SQL parametrizado + template HTML; un comando genera el reporte y un CSV de títulos para revisión de falsos positivos.
- **[Hecho]** Creado skill `.claude/skills/bitacora/SKILL.md`, `CLAUDE.md` y esta bitácora.
- **[Decisión #5]** Motor SQL: DuckDB (sugerido por Claude, aceptado).
- **[Pregunta]** Arquitectura del proyecto → 4 partes: `config/` (YAML por evento), `sql/` (consultas con parámetros), `src/` (pipeline.py: lee config → carga CSV en DuckDB → corre SQL → arma HTML), `templates/` (HTML Jinja2); salida en `output/`.
- **[Pregunta]** ¿Un solo archivo SQL o varios? → Claude recomienda uno solo (`sql/consultas.sql`) con bloques nombrados (`-- name: xxx`) que el .py separa; cumple directo con "consultas en un archivo aparte".
- **[Pregunta]** ¿Cómo llega el HTML al comercial? → El .py corre solo en la PC del analista; el resultado es un HTML autocontenido (datos, CSS y JS embebidos) que se abre con doble clic en cualquier navegador, sin Python ni internet. Se envía por mail/Drive o link (GitHub Pages); PDF como respaldo.
- **[Hecho]** Creada estructura vacía: `config/olimpiadas_2026.yaml`, `sql/consultas.sql`, `src/pipeline.py`, `templates/reporte.html.j2`, `output/`, `README.md`, `requirements.txt`.
- **[Decisión #6]** Pasamos a trabajo en conjunto (reemplaza #1).
- **[Pregunta]** Plan actualizado con las decisiones → 8 etapas: setup, carga+calidad, clasificación, cálculos, conclusiones, pipeline+config, HTML, README+entrega.
- **[Hecho]** Etapa 0 completa: duckdb instalado, lectura de CSV probada. Ojo: `.venv` existe pero duckdb quedó instalado en el Python global (falta instalar dentro del venv).
- **[Hallazgo]** PowerShell 5.1 rompe comillas dobles anidadas en `python -c` → se usa un script en vez de one-liners (detectado por el usuario).
- **[Hecho]** Etapa 1 iniciada: bloque `carga` en `sql/consultas.sql` (separadores explícitos) y `src/correr.py <bloque>` para correr bloques (germen de pipeline.py). Carga OK: 30.871 ventas, 700 productos, 8 categorías.
- **[Pregunta]** Próximo paso → bloque `calidad` con 8 chequeos (nulos, venta_id repetido, filas idénticas, rango de fechas, montos/unidades <= 0, ventas sin producto, país venta ≠ país producto, categorías sin maestro). El usuario escribe los dos primeros.
- **[Cierre de sesión]** Estado al cortar: el usuario empezó a escribir pruebas (suma de montos y conteo de nulos en `ventas`) **dentro del bloque `carga`**, sin `;` final en la de nulos. Al retomar: moverlas a un bloque nuevo `-- name: calidad` (`correr.py` solo muestra el resultado del último SELECT de cada bloque), completar el chequeo de nulos (faltan `pais`, `unidades`) y seguir con los demás chequeos.

### 2026-10-06
- **[Hecho]** El usuario escribió y probó los chequeos de calidad de la etapa 1 en `consultas.sql` (todavía dentro del bloque `carga`).
- **[Hallazgo]** `data/ventas.csv` fue modificado el 2026-10-06 12:21 (pasó a `;` y fechas `dd/mm/aaaa`, probablemente guardado desde Excel). Validado contra el original: mismas 30.871 filas, suma USD 2.214.869,37, fechas 2026-05-01 a 2026-08-31 (123 días) → datos intactos, pero el formato ya no coincide con el que tienen los evaluadores. Recomendación: restaurar el original y no editar `data/`.
- **[Hallazgo]** Calidad OK: sin nulos, sin `venta_id` repetidos, 10 pares de filas idénticas (~USD 180), fechas completas (123 días), sin montos negativos, sin ventas huérfanas, país venta = país producto, sin categorías sin maestro.
- **[Hallazgo]** Los 10 pares repetidos tienen patrón de duplicado técnico: IDs consecutivos (diferencia 1-3), todos de 1 unidad, los 10 son productos con título olímpico y 9 de 10 caen entre el 12/07 y el 01/08 (pico del evento). Impacto ~USD 180 total, ~USD 134 en el número del evento (8 de los 10 son oficiales o particulares 2026). Claude cambia su recomendación: excluirlos (antes: mantenerlos). Pendiente que el usuario decida.
- **[Decisión #7]** Repetidas: se mantienen y se mencionan.
- **[Hecho]** Etapa 1 cerrada. Inicio etapa 2: primero exploración de títulos que matchean keywords (con `strip_accents` + `ILIKE`) y su venta por período, para definir exclusiones.
- **[Hallazgo]** `explorar_titulos` normalizado por día (antes 74 d, durante 17 d, después 32 d): separación limpia. Falsos positivos con lift ~1,0 (Álbum 1992, Camiseta Comité 2016, DVD Berlín 1936, Libro Historia antiguos, Mochila Escolar Modelo); productos del evento con lift 6,3-8,0 (incluye Libro Guía 2026 y Póster 2026). La regla de `productos_evento` (oficial por vendedor; particular = keyword + 3 categorías + sin año distinto de 2026) separa exactamente esos grupos.
- **[Decisión #8]** Libros/pósters 2026 fuera del número principal, como hallazgo aparte.
- **[Hecho]** Etapa 2 cerrada: `productos_evento` validada (coincide con la exploración inicial). Nota: el último SELECT del bloque es un `SELECT *` de 700 filas y tapa el control por clase.
- **[Pregunta]** Inicio etapa 3 → primero tabla auxiliar `ventas_evento` (ventas + clasificación + período, solo oficial/particular); definir 3 números: total período, durante 14-30/07 e incremental vs base (promedio diario 01/05-15/06).
