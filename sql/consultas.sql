-- Venta Olimpiadas 2026 - consultas (DuckDB)
-- cada consulta tiene un "-- name:" para poder correrla sola con src/correr.py


-- name: carga
-- carga de los csv. rutas, separadores y fechas salen de la config (getvariable)
CREATE OR REPLACE TABLE ventas AS
SELECT * FROM read_csv(getvariable('ruta_ventas'), delim = getvariable('separador_ventas'), header = true);

CREATE OR REPLACE TABLE productos AS
SELECT * FROM read_csv(getvariable('ruta_productos'), delim = getvariable('separador_maestros'), header = true);

CREATE OR REPLACE TABLE categorias AS
SELECT * FROM read_csv(getvariable('ruta_categorias'), delim = getvariable('separador_maestros'), header = true);

-- dias que se usan para promedios (asi no quedan numeros fijos en las consultas)
SET VARIABLE dias_base    = getvariable('fin_base') - getvariable('inicio_base') + 1;
SET VARIABLE dias_evento  = getvariable('fin_evento') - getvariable('inicio_evento') + 1;
SET VARIABLE dias_periodo = (SELECT COUNT(DISTINCT fecha) FROM ventas);

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
       list_contains(getvariable('vendedores_oficiales'), t0.vendedor_id) AS es_oficial,
       COUNT(DISTINCT t0.producto_id) AS productos,
       
       SUM(t1.monto_usd) FILTER (WHERE t1.fecha < getvariable('inicio_evento')) AS antes,
       SUM(t1.monto_usd) FILTER (WHERE t1.fecha BETWEEN getvariable('inicio_evento') AND getvariable('fin_evento')) AS durante,
       SUM(t1.monto_usd) FILTER (WHERE t1.fecha > getvariable('fin_evento')) AS despues
FROM productos t0
LEFT JOIN ventas t1 ON t1.producto_id = t0.producto_id
WHERE regexp_matches(strip_accents(lower(t0.titulo)), getvariable('patron_titulo'))
GROUP BY ALL
ORDER BY t0.categoria, t0.titulo;




-- name: productos_evento
-- clasificacion de productos:
-- oficial: las cuentas de la licenciataria (todo lo que publican es del evento)
-- particular: titulo con "olimp" en camisetas/albumes/cartas, sacando los que
-- tienen otro año (album 1992, camiseta 2016)
-- o alguna palabra de excluir_titulos (ej: "modelo olimpico")
-- fuera: el resto. los libros/posters 2026 quedan aca, se muestran aparte
CREATE OR REPLACE TABLE productos_evento AS
SELECT t0.*,
       regexp_extract(t0.titulo, '(19|20)\d{2}') AS anio_titulo,
       CASE
         WHEN list_contains(getvariable('vendedores_oficiales'), t0.vendedor_id)
           THEN 'oficial'
         WHEN regexp_matches(strip_accents(lower(t0.titulo)), getvariable('patron_titulo'))
              AND list_contains(getvariable('categorias_evento'), t0.categoria)
              AND regexp_extract(t0.titulo, '(19|20)\d{2}') IN ('', getvariable('anio_evento'))
              AND (getvariable('excluir_titulos') = ''
                   OR NOT regexp_matches(strip_accents(lower(t0.titulo)), getvariable('excluir_titulos')))
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
-- solo ventas del evento, con el periodo (antes / durante / despues)
CREATE OR REPLACE TABLE ventas_evento AS
SELECT t0.*,
       t1.titulo,
       t1.categoria,
       t1.vendedor_id,
       t1.clasificacion,
       CASE
         WHEN t0.fecha < getvariable('inicio_evento') THEN 'antes'
         WHEN t0.fecha <= getvariable('fin_evento') THEN 'durante'
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
-- total del periodo, durante el evento e incremental
-- base = promedio diario entre inicio_base y fin_base (antes de que empiece a subir)
-- incremental = total - base * dias del periodo
WITH venta_dia AS (
    SELECT t0.fecha, SUM(t0.monto_usd) AS venta
    FROM ventas_evento t0
    GROUP BY ALL
),
base AS (
    SELECT SUM(t0.venta) / getvariable('dias_base') AS base_diaria
    FROM venta_dia t0
    WHERE t0.fecha BETWEEN getvariable('inicio_base') AND getvariable('fin_base')
)
SELECT ROUND(SUM(t0.venta), 2) AS total_periodo,
       ROUND(SUM(t0.venta) FILTER (WHERE t0.fecha BETWEEN getvariable('inicio_evento') AND getvariable('fin_evento')), 2) AS durante,
       ROUND(SUM(t0.venta) - ANY_VALUE(t1.base_diaria) * getvariable('dias_periodo'), 2) AS incremental,
       ROUND(ANY_VALUE(t1.base_diaria), 2) AS base_diaria
FROM venta_dia t0
CROSS JOIN base t1;


-- name: por_pais
-- por pais, cada uno contra su propia base (los paises son de tamaños muy distintos)
WITH venta_dia AS (
    SELECT t0.pais, t0.fecha,
           SUM(t0.monto_usd) AS venta,
           COALESCE(SUM(t0.monto_usd) FILTER (WHERE t0.clasificacion = 'oficial'), 0) AS venta_oficial
    FROM ventas_evento t0
    GROUP BY ALL
),
base AS (
    SELECT t0.pais, SUM(t0.venta) / getvariable('dias_base') AS base_diaria
    FROM venta_dia t0
    WHERE t0.fecha BETWEEN getvariable('inicio_base') AND getvariable('fin_base')
    GROUP BY ALL
)
SELECT t0.pais,
       ROUND(SUM(t0.venta), 2) AS total_periodo,
       ROUND(SUM(t0.venta) FILTER (WHERE t0.fecha BETWEEN getvariable('inicio_evento') AND getvariable('fin_evento')), 2) AS durante,
       ROUND(SUM(t0.venta) - ANY_VALUE(t1.base_diaria) * getvariable('dias_periodo'), 2) AS incremental,
       ROUND(ANY_VALUE(t1.base_diaria), 2) AS base_diaria,
       ROUND(SUM(t0.venta) FILTER (WHERE t0.fecha BETWEEN getvariable('inicio_evento') AND getvariable('fin_evento'))
             / COUNT(*) FILTER (WHERE t0.fecha BETWEEN getvariable('inicio_evento') AND getvariable('fin_evento'))
             / ANY_VALUE(t1.base_diaria), 1) AS veces_base_durante,
       ROUND(100 * SUM(t0.venta) / SUM(SUM(t0.venta)) OVER (), 1) AS pct_total,
       ROUND(100 * SUM(t0.venta_oficial) / SUM(t0.venta), 1) AS pct_oficial
FROM venta_dia t0
JOIN base t1 ON t1.pais = t0.pais
GROUP BY t0.pais
ORDER BY total_periodo DESC;


-- name: oficial_vs_particular
-- oficial vs particular, igual que por_pais
-- venta_cat_exclusivas = lo que vende el oficial en categorias donde no hay
-- particulares (botellas y mochilas)
WITH venta_dia AS (
    SELECT t0.clasificacion, t0.fecha,
           SUM(t0.monto_usd) AS venta,
           COALESCE(SUM(t0.monto_usd) FILTER (WHERE t0.categoria NOT IN (
               SELECT t9.categoria FROM ventas_evento t9 WHERE t9.clasificacion = 'particular')), 0)
               AS venta_cat_exclusivas
    FROM ventas_evento t0
    GROUP BY ALL
),
base AS (
    SELECT t0.clasificacion, SUM(t0.venta) / getvariable('dias_base') AS base_diaria
    FROM venta_dia t0
    WHERE t0.fecha BETWEEN getvariable('inicio_base') AND getvariable('fin_base')
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
       ROUND(SUM(t0.venta) FILTER (WHERE t0.fecha BETWEEN getvariable('inicio_evento') AND getvariable('fin_evento')), 2) AS durante,
       ROUND(SUM(t0.venta) - ANY_VALUE(t1.base_diaria) * getvariable('dias_periodo'), 2) AS incremental,
       ROUND(SUM(t0.venta) FILTER (WHERE t0.fecha BETWEEN getvariable('inicio_evento') AND getvariable('fin_evento'))
             / COUNT(*) FILTER (WHERE t0.fecha BETWEEN getvariable('inicio_evento') AND getvariable('fin_evento'))
             / ANY_VALUE(t1.base_diaria), 1) AS veces_base_durante,
       ROUND(100 * SUM(t0.venta) / SUM(SUM(t0.venta)) OVER (), 1) AS pct_total,
       ROUND(SUM(t0.venta_cat_exclusivas), 2) AS venta_cat_exclusivas,
       ROUND(100 * SUM(t0.venta_cat_exclusivas) / SUM(t0.venta), 1) AS pct_cat_exclusivas
FROM venta_dia t0
JOIN base t1 ON t1.clasificacion = t0.clasificacion
JOIN prods t2 ON t2.clasificacion = t0.clasificacion
GROUP BY t0.clasificacion
ORDER BY total_periodo DESC;


-- name: curva_semanal
-- venta por semana vs la base, para ver cuanto duro el efecto
-- la primera y la ultima semana estan incompletas, por eso uso venta por dia
WITH base AS (
    SELECT SUM(t0.monto_usd) / getvariable('dias_base') AS base_diaria
    FROM ventas_evento t0
    WHERE t0.fecha BETWEEN getvariable('inicio_base') AND getvariable('fin_base')
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
-- libros y posters 2026: son del evento pero no estan en las categorias del mail
SELECT t1.categoria,
       COUNT(DISTINCT t1.producto_id) AS productos,
       ROUND(SUM(t0.monto_usd), 2) AS total_periodo,
       ROUND(SUM(t0.monto_usd) FILTER (WHERE t0.fecha BETWEEN getvariable('inicio_evento') AND getvariable('fin_evento')), 2) AS durante,
       ROUND((SUM(t0.monto_usd) FILTER (WHERE t0.fecha BETWEEN getvariable('inicio_evento') AND getvariable('fin_evento')) / getvariable('dias_evento'))
           / (SUM(t0.monto_usd) FILTER (WHERE t0.fecha BETWEEN getvariable('inicio_base') AND getvariable('fin_base')) / getvariable('dias_base')), 1) AS veces_base_durante
FROM ventas t0
JOIN productos_evento t1 ON t1.producto_id = t0.producto_id
WHERE t1.clasificacion = 'fuera'
  AND regexp_matches(strip_accents(lower(t1.titulo)), getvariable('patron_titulo'))
  AND t1.anio_titulo = getvariable('anio_evento')
GROUP BY ALL;


-- name: por_categoria
-- venta del evento por categoria, oficial vs particular (para el grafico del reporte)
SELECT t0.categoria,
       ROUND(COALESCE(SUM(t0.monto_usd) FILTER (WHERE t0.clasificacion = 'oficial'), 0), 2)    AS oficial,
       ROUND(COALESCE(SUM(t0.monto_usd) FILTER (WHERE t0.clasificacion = 'particular'), 0), 2) AS particular
FROM ventas_evento t0
GROUP BY ALL
ORDER BY oficial + particular DESC;
