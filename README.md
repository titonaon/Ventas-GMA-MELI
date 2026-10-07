# Venta Olimpiadas 2026 — Reporting & Automation

Reporte para el equipo comercial de artículos deportivos sobre la venta de productos de los
Juegos Olímpicos 2026 (14/07 al 30/07), con datos de mayo a agosto en cinco países.

## Entregables

| Pedido | Dónde está |
|---|---|
| 1. Entregable para el equipo comercial | [`output/olimpiadas_2026/reporte.html`](output/olimpiadas_2026/reporte.html): un solo archivo, se abre con doble clic y funciona sin internet |
| 2. Consultas SQL | [`sql/consultas.sql`](sql/consultas.sql) |
| 3. Escala | [sección Escala](#escala) de este README |
| Criterios y uso de IA | secciones [Criterios](#criterios) y [Uso de IA](#uso-de-ia) |

## Resultado principal

Las Olimpiadas generaron **USD 206K de venta incremental** (USD 275K en total, USD 128K
durante los Juegos). El efecto duró unas 7 semanas: empezó 2 semanas antes, durante los
Juegos se vendió 13,5 veces el nivel normal y se normalizó 2-3 semanas después.

1. **El efecto empieza antes del evento** → tener stock y campañas listos 3 semanas antes.
2. **El oficial suma por las categorías que incorpora**: 41% de la venta, sin vender más por
   producto que los particulares, pero el 55% de su venta viene de botellas y mochilas, donde
   no hay particulares.
3. **Brasil y México concentran la venta** (62%). En México el oficial tiene la menor
   participación (33%).
4. **Libros y pósters del evento vendieron USD 88K** fuera de las categorías analizadas.

Limitación: solo hay datos de ventas. Para saber si el oficial fue rentable hacen falta el
margen y el costo de la licencia.

## Cómo correrlo

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt

python src/pipeline.py --config config/olimpiadas_2026.yaml
```

Genera en `output/olimpiadas_2026/`:
- `reporte.html`: el reporte.
- `revision_titulos.csv`: los títulos que matchean el patrón del evento, con su venta antes,
  durante y después, para revisar falsos positivos.

Para probar una consulta suelta: `python src/correr.py totales`.

## Estructura

```
config/olimpiadas_2026.yaml   lo que cambia por evento: fechas, vendedores, patrón, categorías, textos
sql/consultas.sql             todas las consultas (DuckDB), cada una con un "-- name:"
src/pipeline.py               lee la config, corre el sql y arma el html
src/correr.py                 corre una consulta por nombre, para probar
templates/reporte.html.j2     diseño del reporte
templates/assets/             logo y librería de gráficos (se embeben en el html)
data/                         csv originales
docs/bitacora.md              registro de decisiones del proyecto
```

## Criterios

- **Productos del evento.** Oficial: todo lo que publica la licenciataria (cuentas 700100 a
  700500), en cualquier categoría (también vende botellas y mochilas). Particular: títulos que
  mencionan el evento (`olimp`, sin importar tildes ni mayúsculas) en camisetas, álbumes y
  cartas.
- **Falsos positivos.** Se excluyeron títulos con un año distinto de 2026 (álbum Barcelona 1992,
  camiseta 2016) y menciones que no son del evento ("mochila modelo olímpico", "juegos
  antiguos"). Lo validé comparando la venta diaria antes y durante: los productos del evento
  vendieron entre 6 y 8 veces más durante los Juegos; los excluidos vendieron igual (≈1 vez).
- **Base (nivel normal).** Promedio diario del 01/05 al 15/06, antes de que empiece la suba.
  Solo hay datos de 2026, así que no hay comparación contra el año anterior. Con otras
  ventanas de base el incremental da entre USD 204K y 208K, el número se sostiene.
- **Incremental.** Venta del período menos la base por los 123 días. Sin recortar días por
  debajo de la base, para no sumar ruido y que el total coincida con la suma por país.
- **Libros y pósters 2026.** Son del evento (misma curva), pero quedaron fuera del número
  principal porque el pedido hablaba de camisetas, álbumes y cartas. Se muestran aparte.
- **Calidad de datos.** Sin nulos, sin ventas huérfanas, fechas completas y país de la venta
  igual al del producto. Hay 10 pares de ventas idénticas con distinto ID (USD ~180, 0,008%):
  se mantuvieron porque no se puede confirmar que sean duplicados. Como tienen IDs casi
  consecutivos y caen en el pico del evento, convendría revisarlo con el equipo de datos.

## Escala

Si otra área pide lo mismo para otro evento, no hay que reescribir nada: se copia la config,
se cambian los valores y se corre el mismo comando.

```yaml
evento: Mundial 2026
inicio_evento: 2026-06-11
fin_evento: 2026-07-19
vendedores_oficiales: [800100, 800200]
patron_titulo: "mundial|copa del mundo"
categorias_evento: [camisetas, televisores]
excluir_titulos: "..."
```

- **Todo lo que cambia por evento está en la config**: fechas del evento y de la base, rutas de
  los datos, vendedores oficiales, patrón del título, categorías, exclusiones y los textos del
  reporte. El SQL no tiene valores fijos (lee la config con `getvariable()`), y los días de la
  base y del período se calculan solos.
- **La clasificación por título es lo que más se rompe** de un evento a otro, por eso el
  pipeline deja `revision_titulos.csv` para revisar los títulos detectados antes de dar el
  número. Un título sin año que no es del evento (ej: un libro de historia) solo se detecta
  ahí, y se agrega a `excluir_titulos`.
- **Lo que haría con más tiempo:**
  - Pasar las reglas de clasificación a una tabla compartida, para no depender de que cada
    analista escriba el regex.
  - Clasificar los títulos dudosos con IA (es justo el tipo de texto libre donde un modelo
    rinde bien) y dejar la revisión humana solo para esos casos.
  - Comparar contra el mismo período del año anterior para tener una base más sólida.
  - Correrlo programado o desde un tablero si los pedidos se vuelven frecuentes.

## Uso de IA

Usé Claude Code (Claude) como asistente durante todo el trabajo. Las decisiones de criterio y
las conclusiones las tomé yo; la IA propuso, revisó y en algunas partes escribió código.

- **Exploración inicial:** perfilar los datos y detectar los falsos positivos en los títulos.
- **Plan y enfoque:** ordenar el trabajo en etapas y elegir herramientas (DuckDB).
- **SQL:** las consultas de calidad y clasificación las escribí yo; usé IA para completar
  consultas que no sabía resolver y para revisarlas. En la revisión detectó que el incremental
  con recorte por día no cerraba con la suma por país, y lo cambiamos.
- **Automatización:** la parametrización con la config, `pipeline.py` y el reporte HTML los
  armé con ayuda de IA, revisando cada paso y validando que los resultados no cambiaran.
- **Validación:** un análisis independiente desde cero (con pandas) para confirmar todos los
  números del reporte.
- **Bitácora:** fui registrando decisiones y preguntas en `docs/bitacora.md`.
