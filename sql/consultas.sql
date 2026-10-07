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
       
       SUM(t1.monto_usd) FILTER (WHERE t1.fecha <  '2026-07-14')                       AS antes,
       SUM(t1.monto_usd) FILTER (WHERE t1.fecha BETWEEN '2026-07-14' AND '2026-07-30') AS durante,
       SUM(t1.monto_usd) FILTER (WHERE t1.fecha >= '2026-07-31')                       AS despues
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
SELECT t0.clasificacion, COUNT(*) AS productos
FROM productos_evento t0
GROUP BY ALL
ORDER BY t0.clasificacion;

SELECT * FROM productos_evento t0 ORDER BY t0.clasificacion, t0.titulo;
