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

SELECT 'SUMA VENTAS' AS Tabla2, sum(t0.monto_usd) AS Total_Ventas FROM ventas t0; -- prueba suma montos

/*
-- prueba NULOS
SELECT COUNT(*) as Nulos FROM ventas t0
WHERE t0.monto_usd IS NULL 
OR t0.fecha IS NULL
OR t0.producto_id IS NULL
OR t0.venta_id IS NULL;
*/

-- VENTAS Con id repetidos
SELECT t0.venta_id, COUNT(*) AS Repetidos FROM ventas t0
GROUP BY t0.venta_id
HAVING COUNT(*) > 1;

-- filas identicas con distinto id
SELECT pais, fecha, producto_id, unidades, monto_usd,
       COUNT(*) AS veces,
       LIST(venta_id) AS ids
FROM ventas
GROUP BY ALL
HAVING COUNT(*) > 1;

-- rango de fechas - falta alguna fecha en el medio?
SELECT  MIN(fecha) AS fecha_min, 
       MAX(fecha) AS fecha_max, 
       COUNT(DISTINCT fecha) AS fechas_distintas,
       COUNT(*) AS filas
FROM ventas;


--MONTOS <0
SELECT COUNT(*) FROM ventas t0
WHERE t0.monto_usd < 0;


-- ventas cuyo producto no está en el catálogo
SELECT COUNT(t0.venta_id) FROM ventas t0
LEFT JOIN productos t1 on t0.producto_id = t1.producto_id
WHERE t1.producto_id IS NULL;

-- pais de la venta distinto al del producto
SELECT count(*) as ventas_pais_diferente FROM ventas t0
inner JOIN productos t1 ON t0.producto_id = t1.producto_id
WHERE t0.pais <> t1.pais;


-- Categorías sin nombre en el maestro
SELECT COUNT(DISTINCT T1.categoria) AS CAT_SIN_MAESTRO FROM categorias T0
RIGHT JOIN productos T1 ON T0.categoria = T1.categoria
WHERE T0.categoria_nombre IS NULL OR T0.categoria_nombre = '';


-- filas identicas con distinto id
SELECT pais, fecha, producto_id, unidades, monto_usd,
       COUNT(*) AS veces,
       LIST(venta_id) AS ids
FROM ventas
GROUP BY ALL
HAVING COUNT(*) > 1;