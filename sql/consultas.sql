-- =====================================================================
-- Challenge Reporting & Automation — Venta Olimpiadas 2026
-- Motor: DuckDB. Cada bloque empieza con "-- name: <nombre>".
-- =====================================================================


-- name: carga
-- Crea las tablas a partir de los CSV. El separador se indica explícito
-- (los tres CSV usan ';') para no depender de la autodetección.
CREATE OR REPLACE TABLE ventas AS
SELECT * FROM read_csv('data/ventas.csv', delim = ';', header = true);

CREATE OR REPLACE TABLE productos AS
SELECT * FROM read_csv('data/productos.csv', delim = ';', header = true);

CREATE OR REPLACE TABLE categorias AS
SELECT * FROM read_csv('data/categorias.csv', delim = ';', header = true);

SELECT 'ventas' AS tabla, COUNT(*) AS filas FROM ventas
UNION ALL SELECT 'productos', COUNT(*) FROM productos
UNION ALL SELECT 'categorias', COUNT(*) FROM categorias;

-- name: calidad_suma
SELECT 'SUMA VENTAS' AS Tabla2, sum(t0.monto_usd) AS Total_Ventas FROM ventas t0; -- prueba suma montos

-- name: calidad_nulos
-- prueba NULOS
SELECT COUNT(*) as Nulos FROM ventas t0
WHERE t0.monto_usd IS NULL 
OR t0.fecha IS NULL
OR t0.producto_id IS NULL
OR t0.venta_id IS NULL;

-- name: calidad_id_repetidos
-- VENTAS Con id repetidos
SELECT t0.venta_id, COUNT(*) AS Repetidos FROM ventas t0
GROUP BY t0.venta_id
HAVING COUNT(*) > 1;

-- name: calidad_identicas
-- filas identicas con distinto id
SELECT pais, fecha, producto_id, unidades, monto_usd,
       COUNT(*) AS veces,
       LIST(venta_id) AS ids
FROM ventas
GROUP BY ALL
HAVING COUNT(*) > 1;

-- name: calidad_fechas
-- rango de fechas - falta alguna fecha en el medio?
SELECT  MIN(fecha) AS fecha_min, 
       MAX(fecha) AS fecha_max, 
       COUNT(DISTINCT fecha) AS fechas_distintas,
       COUNT(*) AS filas
FROM ventas;


-- name: calidad_montos
--MONTOS <0
SELECT COUNT(*) FROM ventas t0
WHERE t0.monto_usd < 0;


-- name: calidad_sin_producto
-- ventas cuyo producto no está en el catálogo
SELECT COUNT(t0.venta_id) FROM ventas t0
LEFT JOIN productos t1 on t0.producto_id = t1.producto_id
WHERE t1.producto_id IS NULL;

-- name: calidad_pais
-- pais de la venta distinto al del producto
SELECT count(*) as ventas_pais_diferente FROM ventas t0
inner JOIN productos t1 ON t0.producto_id = t1.producto_id
WHERE t0.pais <> t1.pais;


-- name: calidad_categorias
-- Categorías sin nombre en el maestro
SELECT COUNT(DISTINCT T1.categoria) AS CAT_SIN_MAESTRO FROM categorias T0
RIGHT JOIN productos T1 ON T0.categoria = T1.categoria
WHERE T0.categoria_nombre IS NULL OR T0.categoria_nombre = '';



--Etapa 2 Clasificar qué productos son del evento
-- name: explorar_titulos
-- Títulos que mencionan el evento, con ventas antes / durante / después. Incluyo aca falsos positivos
SELECT t0.titulo,
       t0.categoria,
       t0.vendedor_id IN (700100, 700200, 700300, 700400, 700500) AS es_oficial,
       COUNT(DISTINCT t0.producto_id) AS productos,
       
       SUM(t1.monto_usd) FILTER (WHERE t1.fecha <  '2026-07-14') AS antes,
       SUM(t1.monto_usd) FILTER (WHERE t1.fecha BETWEEN '2026-07-14' AND '2026-07-30') AS durante,
       SUM(t1.monto_usd) FILTER (WHERE t1.fecha >= '2026-07-31') AS despues
FROM productos t0
LEFT JOIN ventas t1 ON t1.producto_id = t0.producto_id
WHERE strip_accents(lower(t0.titulo)) LIKE '%olimp%'
GROUP BY ALL
ORDER BY t0.categoria, t0.titulo;




-- name: productos_evento
-- Clasifica cada producto del catálogo como oficial / particular / fuera.
-- 1) oficial = vendedores 700100-700500, sin importar título ni categoría.
-- 2) particular = título menciona el evento + categoría camisetas/albumes/cartas
-- + no es falso positivo (título con un año distinto de 2026).
-- 3) fuera = todo lo demás (incluye libros del evento: decisión opción a).
CREATE OR REPLACE TABLE productos_evento AS
SELECT t0.*,
       regexp_extract(t0.titulo, '(19|20)\d{2}') AS anio_titulo,
       CASE
         WHEN t0.vendedor_id IN (700100, 700200, 700300, 700400, 700500)
           THEN 'oficial'
         WHEN strip_accents(lower(t0.titulo)) LIKE '%olimp%'
              AND t0.categoria IN ('camisetas', 'albumes', 'cartas')
              AND regexp_extract(t0.titulo, '(19|20)\d{2}') IN ('', '2026')
           THEN 'particular'
         ELSE 'fuera'
       END AS clasificacion
FROM productos t0;

-- Control: cuántos productos quedaron en cada clase
-- name: resumen_clasificacion
SELECT t0.clasificacion, COUNT(*) AS productos
FROM productos_evento t0
GROUP BY ALL
ORDER BY t0.clasificacion;

-- name: revisar_clasificacion
SELECT * FROM productos_evento t0 ORDER BY t0.clasificacion, t0.titulo;




-- ETAPA 3 - CALCULOS DE VENTA 

-- name: ventas_evento
-- Ventas de productos del evento (oficial + particular), con su período.
CREATE OR REPLACE TABLE ventas_evento AS
SELECT t0.*,
       t1.titulo,
       t1.categoria,
       t1.vendedor_id,
       t1.clasificacion,
       CASE
         WHEN t0.fecha <= '2026-07-13' THEN 'antes'
         WHEN t0.fecha <= '2026-07-30' THEN 'durante'
         ELSE 'despues'
       END AS periodo
FROM ventas t0
JOIN productos_evento t1 ON t1.producto_id = t0.producto_id
WHERE t1.clasificacion IN ('oficial', 'particular');

-- suma de las ventas del evento 
SELECT ROUND(SUM(t0.monto_usd), 2) AS total_evento,
       COUNT(*) AS ventas
FROM ventas_evento t0;

-- name: totales
-- Los tres números de "venta de Olimpiadas":
--   total_periodo: todo lo vendido de productos del evento (01/05 al 31/08).
--   durante:  solo 14/07 al 30/07.
--   incremental: lo vendido por encima de la base diaria (promedio 01/05 al 15/06),
--   sumado día por día; un día por debajo de la base cuenta 0.
WITH venta_dia AS (
    SELECT t0.fecha, SUM(t0.monto_usd) AS venta
    FROM ventas_evento t0
    GROUP BY ALL
),
base AS (
    SELECT SUM(t0.venta) / 46 AS base_diaria
    FROM venta_dia t0
    WHERE t0.fecha BETWEEN '2026-05-01' AND '2026-06-15'
)
SELECT ROUND(SUM(t0.venta), 2) AS total_periodo,
       ROUND(SUM(t0.venta) FILTER (WHERE t0.fecha BETWEEN '2026-07-14' AND '2026-07-30'), 2) AS durante,
       ROUND(SUM(GREATEST(t0.venta - t1.base_diaria, 0)), 2) AS incremental,
       ROUND(ANY_VALUE(t1.base_diaria), 2) AS base_diaria
FROM venta_dia t0
CROSS JOIN base t1;


-- name: por_pais
-- Venta del evento por país. Cada país se compara contra SU propia base diaria
-- (promedio 01/05 al 15/06), porque los mercados tienen tamaños muy distintos.
-- pct_oficial: qué parte de la venta del país fue merchandising oficial.
WITH venta_dia AS (
    SELECT t0.pais, t0.fecha,
           SUM(t0.monto_usd) AS venta,
           COALESCE(SUM(t0.monto_usd) FILTER (WHERE t0.clasificacion = 'oficial'), 0) AS venta_oficial
    FROM ventas_evento t0
    GROUP BY ALL
),
base AS (
    SELECT t0.pais, SUM(t0.venta) / 46 AS base_diaria
    FROM venta_dia t0
    WHERE t0.fecha BETWEEN '2026-05-01' AND '2026-06-15'
    GROUP BY ALL
)
SELECT t0.pais,
       ROUND(SUM(t0.venta), 2) AS total_periodo,
       ROUND(SUM(t0.venta) FILTER (WHERE t0.fecha BETWEEN '2026-07-14' AND '2026-07-30'), 2) AS durante,
       ROUND(SUM(GREATEST(t0.venta - t1.base_diaria, 0)), 2) AS incremental,
       ROUND(ANY_VALUE(t1.base_diaria), 2) AS base_diaria,
       ROUND(SUM(t0.venta) FILTER (WHERE t0.fecha BETWEEN '2026-07-14' AND '2026-07-30')
             / COUNT(*) FILTER (WHERE t0.fecha BETWEEN '2026-07-14' AND '2026-07-30')
             / ANY_VALUE(t1.base_diaria), 1) AS veces_base_durante,
       ROUND(100 * SUM(t0.venta) / SUM(SUM(t0.venta)) OVER (), 1) AS pct_total,
       ROUND(100 * SUM(t0.venta_oficial) / SUM(t0.venta), 1) AS pct_oficial
FROM venta_dia t0
JOIN base t1 ON t1.pais = t0.pais
GROUP BY t0.pais
ORDER BY total_periodo DESC;


-- name: oficial_vs_particular
-- ¿Valió la pena el merchandising oficial? Misma lógica que por_pais, por clasificación,
-- más cuántos productos vendieron y cuánto vendió cada uno en promedio.
WITH venta_dia AS (
    SELECT t0.clasificacion, t0.fecha, SUM(t0.monto_usd) AS venta
    FROM ventas_evento t0
    GROUP BY ALL
),
base AS (
    SELECT t0.clasificacion, SUM(t0.venta) / 46 AS base_diaria
    FROM venta_dia t0
    WHERE t0.fecha BETWEEN '2026-05-01' AND '2026-06-15'
    GROUP BY ALL
),
prods AS (
    SELECT t0.clasificacion, COUNT(DISTINCT t0.producto_id) AS productos
    FROM ventas_evento t0
    GROUP BY ALL
)
SELECT t0.clasificacion,
       ANY_VALUE(t2.productos) AS productos,
       ROUND(SUM(t0.venta), 2) AS total_periodo,
       ROUND(SUM(t0.venta) / ANY_VALUE(t2.productos), 2) AS venta_x_producto,
       ROUND(SUM(t0.venta) FILTER (WHERE t0.fecha BETWEEN '2026-07-14' AND '2026-07-30'), 2) AS durante,
       ROUND(SUM(GREATEST(t0.venta - t1.base_diaria, 0)), 2) AS incremental,
       ROUND(SUM(t0.venta) FILTER (WHERE t0.fecha BETWEEN '2026-07-14' AND '2026-07-30')
             / COUNT(*) FILTER (WHERE t0.fecha BETWEEN '2026-07-14' AND '2026-07-30')
             / ANY_VALUE(t1.base_diaria), 1) AS veces_base_durante,
       ROUND(100 * SUM(t0.venta) / SUM(SUM(t0.venta)) OVER (), 1) AS pct_total
FROM venta_dia t0
JOIN base t1 ON t1.clasificacion = t0.clasificacion
JOIN prods t2 ON t2.clasificacion = t0.clasificacion
GROUP BY t0.clasificacion
ORDER BY total_periodo DESC;


-- name: curva_semanal
-- Cuánto duró el efecto: venta por día de cada semana (lunes a domingo) vs la base.
-- Ojo: la primera semana (desde 27/04) y la última (31/08) están incompletas.
WITH base AS (
    SELECT SUM(t0.monto_usd) / 46 AS base_diaria
    FROM ventas_evento t0
    WHERE t0.fecha BETWEEN '2026-05-01' AND '2026-06-15'
)
SELECT date_trunc('week', t0.fecha) AS semana,
       COUNT(DISTINCT t0.fecha) AS dias,
       ROUND(SUM(t0.monto_usd), 2) AS venta,
       ROUND(SUM(t0.monto_usd) / COUNT(DISTINCT t0.fecha), 2) AS venta_x_dia,
       ROUND(SUM(t0.monto_usd) / COUNT(DISTINCT t0.fecha)
             / ANY_VALUE(t1.base_diaria), 1) AS veces_base
FROM ventas_evento t0
CROSS JOIN base t1
GROUP BY ALL
ORDER BY semana;


-- name: hallazgo_libros
-- Productos de particulares que SON del evento (título con 'olimp' y año 2026)
-- pero quedaron fuera por categoría (decisión #8). Se muestran aparte.
SELECT t1.categoria,
       COUNT(DISTINCT t1.producto_id) AS productos,
       ROUND(SUM(t0.monto_usd), 2) AS total_periodo,
       ROUND(SUM(t0.monto_usd) FILTER (WHERE t0.fecha BETWEEN '2026-07-14' AND '2026-07-30'), 2) AS durante,
       ROUND((SUM(t0.monto_usd) FILTER (WHERE t0.fecha BETWEEN '2026-07-14' AND '2026-07-30') / 17)
           / (SUM(t0.monto_usd) FILTER (WHERE t0.fecha BETWEEN '2026-05-01' AND '2026-06-15') / 46), 1) AS veces_base_durante
FROM ventas t0
JOIN productos_evento t1 ON t1.producto_id = t0.producto_id
WHERE t1.clasificacion = 'fuera'
  AND strip_accents(lower(t1.titulo)) LIKE '%olimp%'
  AND t1.anio_titulo = '2026'
GROUP BY ALL;
