# Venta Olimpiadas 2026

Reporte sobre la venta de productos de los Juegos Olímpicos 2026 (14/07 al 30/07) en cinco
países, con datos de mayo a agosto.

## Entregables

1. **Reporte:** [`output/olimpiadas_2026/reporte.html`](output/olimpiadas_2026/reporte.html).
   Se abre con doble clic y funciona sin internet.
2. **Consultas SQL:** [`sql/consultas.sql`](sql/consultas.sql).
3. **Escala, criterios y uso de IA:** en este README.

Para regenerar el reporte:

```powershell
pip install -r requirements.txt
python src/pipeline.py --config config/olimpiadas_2026.yaml
```

## Criterios

- **Productos del evento.** Oficial: todo lo que publica la licenciataria (cuentas 700100 a
  700500), en cualquier categoría. Particular: títulos que mencionan el evento (`olimp`) en
  camisetas, álbumes y cartas.
- **Falsos positivos.** Excluí títulos con un año distinto de 2026 (álbum 1992, camiseta 2016)
  y menciones que no son del evento ("mochila modelo olímpico", "juegos antiguos"). Lo validé
  con la venta diaria: los excluidos vendieron igual durante los Juegos que antes, mientras que
  los productos del evento vendieron varias veces más.
- **Base (nivel normal).** Promedio diario del 01/05 al 15/06, antes de que empiece la suba.
  No hay datos de años anteriores para comparar.
- **Incremental.** Venta del período menos la base por los 123 días.
- **Libros y pósters 2026.** Responden al evento, pero no están en las categorías del pedido:
  se muestran aparte y no suman al número principal.
- **Calidad de datos.** Sin nulos ni ventas huérfanas. Hay 10 pares de ventas idénticas con
  distinto ID (USD ~180, 0,008%): se mantuvieron y conviene revisarlos con el equipo de datos.

## Escala

Todo lo que cambia por evento está en un archivo de config (fechas, vendedores oficiales,
patrón del título, categorías, exclusiones y textos del reporte). Para otro evento se copia
la config, se cambian los valores y se corre el mismo comando; el SQL no tiene valores fijos.

Lo que más se rompe de un evento a otro es la clasificación por título, por eso el pipeline
genera `revision_titulos.csv` para revisar los títulos detectados antes de dar el número.

Con más tiempo: pasar las reglas de clasificación a una tabla compartida y comparar contra el
año anterior.

## Uso de IA

Usé Claude Code como apoyo para explorar los datos, revisar consultas y armar la
automatización. Los criterios y las conclusiones los definí yo.

- **SQL:** las consultas de calidad y clasificación las escribí yo; usé IA para completar
  algunas y revisarlas. En esa revisión vimos que el incremental con recorte por día no cerraba
  con la suma por país, y lo cambiamos.
- **Automatización y reporte:** la config, `pipeline.py` y el HTML los armé con ayuda de IA,
  validando en cada paso que los resultados no cambiaran.
- **Validación:** un análisis independiente desde cero para confirmar los números del reporte.
