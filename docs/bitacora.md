# Bitácora: Challenge Reporting & Automation

## Contexto vigente
- Paso actual: **Etapa 7, README y entrega** (etapas 1 a 6 cerradas). Total evento USD 274.654,31; incremental USD 205.948,33 (#9).
- Para correr bloques: `python src/correr.py <bloque>` (siempre corre `carga` primero).
- Trabajo en conjunto (decisión #6): el código se arma por partes, explicando y validando cada paso.
- Motor SQL: **DuckDB** (decisión #5).
- Entregable: HTML generado con Python, parametrizable por evento/área (config-driven).
- Números validados: oficial USD 113,2K + particulares 2026 en camisetas/álbumes/cartas
  USD 161,4K = **USD 274,7K**; durante USD 128,1K; incremental **USD 205,9K**; pico ×13,5.

## Decisiones
| # | Fecha | Decisión | Alternativas descartadas | Por qué |
|---|---|---|---|---|
| 1 | 2026-10-05 | Resolver el challenge usando IA solo para consultas puntuales | Usar IA en todo el proceso | Prioridad: entender cada paso |
| 2 | 2026-10-05 | Seguir un plan de 7 pasos (entender → clasificar → calcular → conclusiones → entregable → anexos → revisión) | - | Ordena el trabajo desde los datos hasta el entregable |
| 3 | 2026-10-05 | Entregable HTML generado por Python, con inputs parametrizables (config por evento) | Presentación estática, dashboard BI | Responde también al punto 3 (escala) y evita ETL manual |
| 4 | 2026-10-05 | Llevar bitácora en `docs/bitacora.md` vía skill `bitacora` | - | No perder contexto; insumo para "uso de IA" |
| 5 | 2026-10-05 | Motor SQL: DuckDB | SQLite | Lee CSV directo con autodetección de separador, fechas reales, ILIKE/regex, integra con pandas |
| 6 | 2026-10-05 | Trabajo en conjunto con IA: el código se escribe por partes, explicando y validando cada paso (reemplaza #1) | Hacerlo todo sin IA | Se permite IA; prioridad es entender todo |
| 7 | 2026-10-06 | Las 10 ventas repetidas se mantienen en los números y se mencionan en la nota de criterios (con el patrón de posible duplicado técnico, para avisar al equipo de datos) | Excluirlas con `ventas_raw` + `QUALIFY ROW_NUMBER()` | Impacto ~USD 180 (0,008%), no cambia conclusiones |
| 8 | 2026-10-06 | Libros/pósters 2026 quedan FUERA del número principal y se muestran como hallazgo aparte (~USD 88K, ×13,2 la base durante los Juegos) | Incluirlos en el número | Respeta las categorías que pidió el comercial y aporta un insight para el próximo evento |
| 9 | 2026-10-06 | Incremental = venta del período − base diaria × 123 días (sin recorte por día). Total USD 205,9K | Suma diaria con `GREATEST(venta − base, 0)` (210,8K) | El recorte suma ruido como si fuera evento y no es aditivo (países sumaban 215,3K) |

## Pendientes / dudas abiertas
- [x] Elegir motor SQL → DuckDB (#5).
- [x] Libros/pósters 2026 → fuera del número, hallazgo aparte (#8).
- [x] ¿"Venta de Olimpiadas" = todo el período, solo 14–30/07, o incremental? → el reporte muestra las tres; el número principal es el incremental.
- [ ] Instalar duckdb dentro del `.venv` (activar venv + `pip install -r requirements.txt`).
- [x] 10 pares de filas idénticas → se mantienen y se mencionan (#7).
- [x] `data/ventas.csv` restaurado al formato original y config con `,`.
- [x] Separar los chequeos de calidad en bloques `-- name: calidad_*` y completar nulos (`pais`, `unidades`), montos/unidades `<= 0`.

## Registro cronológico
### 2026-10-05
- **[Hecho]** Análisis inicial del challenge: perfilado de los datos; aparecen trampas de clasificación.
- **[Hallazgo]** Datos limpios: sin nulos, sin huérfanos, país venta = país producto. Separadores distintos (`,` vs `;`).
- **[Hallazgo]** Falsos positivos por título: Álbum Barcelona 1992, Camiseta Comité Olímpico 2016 Vintage (ediciones viejas, ventas planas); "Mochila Escolar Modelo Olimpico", libro de juegos antiguos, DVD Berlín 1936 (solo comparten la palabra).
- **[Hallazgo]** La licenciataria vende también mochilas y botellas (fuera de las 3 categorías) → cuentan igual.
- **[Hallazgo]** Efecto: arranca ~28/06, pico ~13× la base durante los Juegos, vuelve a la base ~20/08. Oficial = 41% sin sobreprecio (camiseta USD 36,1 vs 36,7). México 33% oficial, Chile 53%.
- **[Pregunta]** Estimación de tiempo → 6-10 h (1 a 1,5 días).
- **[Pregunta]** Plan general del proyecto → plan de 7 pasos (decisión #2).
- **[Pregunta]** ¿SQLite o DuckDB? → DuckDB (lee CSV directo con autodetección de separador, ILIKE, funciones de fecha, integra con pandas); SQLite es válido pero requiere cargar los CSV vía pandas y tiene fechas más pobres.
- **[Pregunta]** Diseño para escala → pipeline config-driven: YAML por evento + SQL parametrizado + template HTML; un comando genera el reporte y un CSV de títulos para revisión de falsos positivos.
- **[Hecho]** Creado skill `.claude/skills/bitacora/SKILL.md`, `CLAUDE.md` y esta bitácora.
- **[Decisión #5]** Motor SQL: DuckDB.
- **[Pregunta]** Arquitectura del proyecto → 4 partes: `config/` (YAML por evento), `sql/` (consultas con parámetros), `src/` (pipeline.py: lee config → carga CSV en DuckDB → corre SQL → arma HTML), `templates/` (HTML Jinja2); salida en `output/`.
- **[Pregunta]** ¿Un solo archivo SQL o varios? → uno solo (`sql/consultas.sql`) con bloques nombrados (`-- name: xxx`) que el .py separa; cumple directo con "consultas en un archivo aparte".
- **[Pregunta]** ¿Cómo llega el HTML al comercial? → El .py corre solo en la PC del analista; el resultado es un HTML autocontenido (datos, CSS y JS embebidos) que se abre con doble clic en cualquier navegador, sin Python ni internet. Se envía por mail/Drive o link (GitHub Pages); PDF como respaldo.
- **[Hecho]** Creada estructura vacía: `config/olimpiadas_2026.yaml`, `sql/consultas.sql`, `src/pipeline.py`, `templates/reporte.html.j2`, `output/`, `README.md`, `requirements.txt`.
- **[Decisión #6]** Pasamos a trabajo en conjunto (reemplaza #1).
- **[Pregunta]** Plan actualizado con las decisiones → 8 etapas: setup, carga+calidad, clasificación, cálculos, conclusiones, pipeline+config, HTML, README+entrega.
- **[Hecho]** Etapa 0 completa: duckdb instalado, lectura de CSV probada. Ojo: `.venv` existe pero duckdb quedó instalado en el Python global (falta instalar dentro del venv).
- **[Hallazgo]** PowerShell 5.1 rompe comillas dobles anidadas en `python -c` → se usa un script en vez de one-liners.
- **[Hecho]** Etapa 1 iniciada: bloque `carga` en `sql/consultas.sql` (separadores explícitos) y `src/correr.py <bloque>` para correr bloques (germen de pipeline.py). Carga OK: 30.871 ventas, 700 productos, 8 categorías.
- **[Pregunta]** Próximo paso → bloque `calidad` con 8 chequeos (nulos, venta_id repetido, filas idénticas, rango de fechas, montos/unidades <= 0, ventas sin producto, país venta ≠ país producto, categorías sin maestro). Arranco escribiendo los dos primeros.
- **[Cierre de sesión]** Estado al cortar: empecé a escribir pruebas (suma de montos y conteo de nulos en `ventas`) **dentro del bloque `carga`**, sin `;` final en la de nulos. Al retomar: moverlas a un bloque nuevo `-- name: calidad` (`correr.py` solo muestra el resultado del último SELECT de cada bloque), completar el chequeo de nulos (faltan `pais`, `unidades`) y seguir con los demás chequeos.

### 2026-10-06
- **[Hecho]** Escribí y probé los chequeos de calidad de la etapa 1 en `consultas.sql` (todavía dentro del bloque `carga`).
- **[Hallazgo]** `data/ventas.csv` fue modificado el 2026-10-06 12:21 (pasó a `;` y fechas `dd/mm/aaaa`, probablemente guardado desde Excel). Validado contra el original: mismas 30.871 filas, suma USD 2.214.869,37, fechas 2026-05-01 a 2026-08-31 (123 días) → datos intactos, pero el formato ya no coincide con el que tienen los evaluadores. Recomendación: restaurar el original y no editar `data/`.
- **[Hallazgo]** Calidad OK: sin nulos, sin `venta_id` repetidos, 10 pares de filas idénticas (~USD 180), fechas completas (123 días), sin montos negativos, sin ventas huérfanas, país venta = país producto, sin categorías sin maestro.
- **[Hallazgo]** Los 10 pares repetidos tienen patrón de duplicado técnico: IDs consecutivos (diferencia 1-3), todos de 1 unidad, los 10 son productos con título olímpico y 9 de 10 caen entre el 12/07 y el 01/08 (pico del evento). Impacto ~USD 180 total, ~USD 134 en el número del evento (8 de los 10 son oficiales o particulares 2026). Se evalúa excluirlos; queda a definir.
- **[Decisión #7]** Repetidas: se mantienen y se mencionan.
- **[Hecho]** Etapa 1 cerrada. Inicio etapa 2: primero exploración de títulos que matchean keywords (con `strip_accents` + `ILIKE`) y su venta por período, para definir exclusiones.
- **[Hallazgo]** `explorar_titulos` normalizado por día (antes 74 d, durante 17 d, después 32 d): separación limpia. Falsos positivos con lift ~1,0 (Álbum 1992, Camiseta Comité 2016, DVD Berlín 1936, Libro Historia antiguos, Mochila Escolar Modelo); productos del evento con lift 6,3-8,0 (incluye Libro Guía 2026 y Póster 2026). La regla de `productos_evento` (oficial por vendedor; particular = keyword + 3 categorías + sin año distinto de 2026) separa exactamente esos grupos.
- **[Decisión #8]** Libros/pósters 2026 fuera del número principal, como hallazgo aparte.
- **[Hecho]** Etapa 2 cerrada: `productos_evento` validada (coincide con la exploración inicial). Nota: el último SELECT del bloque es un `SELECT *` de 700 filas y tapa el control por clase.
- **[Pregunta]** Inicio etapa 3 → primero tabla auxiliar `ventas_evento` (ventas + clasificación + período, solo oficial/particular); definir 3 números: total período, durante 14-30/07 e incremental vs base (promedio diario 01/05-15/06).
- **[Hecho]** Etapa 3 escrita por mí (bloques `ventas_evento`, `totales`, `por_pais`, `oficial_vs_particular`, `curva_semanal`, `hallazgo_libros`); usé IA para completar algunas queries y revisarlas (insumo para "uso de IA"). `correr.py` ahora corre antes todos los bloques con CREATE.
- **[Hallazgo]** Resultados: total USD 274.654 / durante 128.107 / base diaria 558,59. Curva: x3,4 semana del 29/06, pico x13,5 (semana 20/07), x1,4 semana del 17/08, x0,8 la última semana. Oficial: sin sobreprecio (camiseta 36,1 vs 36,7; álbum 8,5 vs 8,4), 62K de sus 113K vienen de botellas y mochilas (categorías sin particulares). Colombia x16,2 pero 8,4% del volumen; México 33% oficial.
- **[Hallazgo]** El incremental con recorte (`GREATEST(...,0)`) suma desvíos positivos de ruido y no es aditivo: total 210,8K vs suma países 215,3K vs suma clases 211,7K. Sin recorte (venta − base × 123 días) = USD 205,9K y suma exacto por país. Se cambia a sin recorte (#9).
- **[Decisión #9]** Incremental sin recorte: USD 205,9K.
- **[Decisión]** Para responder "¿valió la pena el oficial?" se agrega una columna `venta_cat_exclusivas` a `oficial_vs_particular` en vez de un bloque nuevo; el dato de sobreprecio queda fuera del reporte. Criterio: solo lo necesario para lo que pide el mail.
- **[Hecho]** Etapa 4 cerrada (conclusiones abajo). Inicio etapa 5: parametrizar con variables de DuckDB (`SET VARIABLE` + `getvariable()`), probado en DuckDB 1.5.6 con rutas, fechas y listas.

- **[Hecho]** Etapa 5 (automatización, armada en conjunto con IA): `config/olimpiadas_2026.yaml` con 13 valores + `evento`/`salida`; SQL sin valores fijos (`getvariable()`; días de base/evento/período calculados en `carga`); `src/pipeline.py` corre todo y genera `output/olimpiadas_2026/revision_titulos.csv`; `correr.py` reutiliza las funciones del pipeline. Test: los 20 bloques dan idéntico a antes (`calidad_identicas` solo cambia el orden de filas, no tiene ORDER BY).
- **[Hallazgo]** Prueba con libros en `categorias_evento`: entra "Libro Historia de los Juegos Olímpicos Antiguos" porque no tiene año en el título. La regla del año no cubre falsos positivos sin año → para otros eventos, el resguardo es revisar `revision_titulos.csv` (o sumar un `excluir_titulos` en la config).

- **[Hecho]** Agregado `excluir_titulos` a la config (regex, "" = no excluir) y a `productos_evento`. Olimpiadas: `antiguos|modelo`. Tests: números sin cambios (274.654,31 / 205.948,33); con libros en categorías ahora da 363.058,40 (antes 386.066 por el libro de historia).
- **[Pregunta]** Inicio etapa 6 → propuesta de diseño del HTML de una pantalla.

- **[Hecho]** Etapa 6 (armada en conjunto con IA): reporte HTML con formato Mercado Libre (logo oficial descargado de mlstatic.com, amarillo #FFE600, azul #3483FA). Paleta de gráficos validada (oficial #3F48A8 = azul marino de marca un paso más claro para pasar el chequeo de luminosidad; particular #3483FA). Todo embebido (logo en base64, Chart.js + plugin annotation) → un solo archivo de ~250KB que anda sin internet. Textos del reporte en `config` (sección `reporte`, con `{{ numeros }}` que completa el pipeline). Nuevo bloque SQL `por_categoria` para el gráfico del oficial. Probado en escritorio y celular.
- **[Decisión]** Pico del reporte = ×13,5 (máximo semanal de `curva_semanal`, con un decimal) para no redondear a ×14 y que coincida con las conclusiones.

- **[Hallazgo]** Validación independiente desde cero (pandas): todos los números del reporte coinciden. Incremental robusto a la base (203,6K-207,8K con otras ventanas). Detectado: la frase "la mitad de esa venta" era imprecisa (42% del incremental cae fuera de los Juegos; 53% de la venta total).
- **[Hecho]** Franja de los Juegos en la curva ajustada a las fechas exactas (14/07 al 30/07).
- **[Hecho]** `data/ventas.csv` reconstruido al formato original (`,`, fechas ISO, LF) a partir del archivo modificado por Excel, sin cambiar valores (misma suma y fechas); copia del modificado guardada fuera del proyecto. Config: `separador_ventas: ","`. Los montos pueden diferir del original solo en ceros finales (ej: 48.5 vs 48.50).
- **[Hecho]** `totales` suma antes/durante/después (USD 81K / 128K / 65K; 1.099 / 7.536 / 2.039 por día) e `incremental_durante`; el reporte los muestra debajo de la curva. Resumen corregido: "el 42% de esa venta se dio antes o después de los Juegos".
- **[Hecho]** README completo: entregables, cómo correrlo, criterios, escala y uso de IA. Etapa 7 en curso.

- **[Decisión]** En el reporte, "venta incremental" pasa a "Venta extra por las Olimpiadas" (con "incremental: por encima del nivel normal" de apoyo) para que el director lo lea sin esfuerzo; en criterios y README queda el término técnico. Las etiquetas propias del evento ("Juegos", "Durante los Juegos") pasan a `reporte.etiquetas` en la config, así la plantilla no tiene textos de las Olimpiadas.

## Conclusiones (etapa 4)
**Resumen:** Las Olimpiadas generaron USD 206K de venta incremental. El efecto duró unas 7 semanas y el 42% de esa venta se dio antes o después de los Juegos.
1. **El efecto empieza antes del evento.** Las ventas suben desde 2 semanas antes, durante los Juegos llegan a 13,5 veces el nivel normal y se normalizan 2-3 semanas después. Recomendación: tener stock y campañas listos 3 semanas antes del próximo evento.
2. **El merchandising oficial suma por las categorías que incorpora.** Representa el 41% de la venta y cada producto vende en línea con los particulares. El 55% de su venta viene de botellas y mochilas, categorías sin oferta de particulares. Recomendación: mantenerlo y enfocarlo en productos que no ofrecen otros vendedores.
3. **Brasil y México concentran la venta.** Entre ambos suman el 62% del total. En México el oficial tiene la menor participación (33%), lo que muestra margen de crecimiento. Colombia tuvo el mayor crecimiento, aunque representa solo el 8% de la venta.
4. **Libros y pósters también respondieron al evento.** Sumaron USD 88K con la misma curva que el resto (×13,2 el nivel normal durante los Juegos), aunque no estaban dentro de las categorías analizadas. Recomendación: incluirlos en el seguimiento del próximo evento.
**Limitación:** El análisis se basa solo en ventas. Para evaluar la rentabilidad del oficial se necesitan el margen y el costo de la licencia.
