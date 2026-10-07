# Plan de trabajo
El trabajo lo dividí en etapas, desde entender los datos hasta armar el entregable. Antes de
pasar a la siguiente etapa revisaba que lo anterior estuviera bien.


## Etapa 0: Setup
Armé la estructura de carpetas, el entorno de Python y probé la lectura de los CSV.
Elegí DuckDB como motor porque lee los CSV directo y maneja bien fechas y búsquedas por texto.
Dejé todas las consultas en un solo archivo, separadas por nombre, para poder correrlas sueltas
o todas juntas.


## Etapa 1: Carga y calidad de datos
Cargué las tres tablas e hice los chequeos básicos: nulos, IDs repetidos, filas idénticas,
rango de fechas, montos, ventas sin producto y que el país de la venta coincida con el del
producto.
Los datos estaban limpios salvo 10 pares de ventas idénticas con distinto ID. Decidí
mantenerlas y mencionarlas, porque el impacto es mínimo y no se puede confirmar que sean
duplicados.


## Etapa 2: Clasificación de productos
Revisé los títulos que mencionan el evento para entender qué entraba y qué no.
Definí oficial como todo lo que vende la licenciataria, en cualquier categoría, y particular
como los títulos que mencionan las olimpiadas en camisetas, álbumes y cartas.
Saqué los falsos positivos: productos de ediciones anteriores y títulos que usan la palabra
pero no son del evento. Lo validé viendo que su venta no cambiaba durante los Juegos.


## Etapa 3: Cálculos
Armé las consultas de totales, curva semanal, venta por país y oficial contra particular.
Tomé como nivel normal el promedio diario de mayo y la primera mitad de junio, antes de que
empiece la suba.
Para el incremental resté ese nivel normal a la venta de todo el período. Probé también
recortando por día, pero sumaba ruido y no cerraba con la suma por país, así que lo descarté.


## Etapa 4: Conclusiones
Escribí cuatro mensajes con su recomendación: cuánto dura el efecto, el oficial, los países y
libros.
Libros y pósters del evento los dejé fuera del número principal porque no estaban en las
categorías del pedido, pero los muestro aparte porque se comportaron igual.
Traté de quedarme solo con lo necesario para responder lo que se pidió.


## Etapa 5: Automatización
Pasé todo lo que cambia por evento a un archivo de configuración: fechas, vendedores,
palabras del título, categorías, exclusiones y textos.
El SQL quedó sin valores fijos y un script corre todo con un solo comando.
El script además genera un listado de títulos para revisar a mano, porque la clasificación es
lo que más puede fallar al cambiar de evento.


## Etapa 6: Reporte
Armé el reporte en HTML con el formato de Mercado Libre.
Es un solo archivo que funciona sin internet.


## Etapa 7: Revisión y entrega
Rehice los cálculos por separado para confirmar los números y revisé que el reporte, el README
y la configuración.
Dejé el README con lo que pide el challenge: criterios, escala y uso de IA.
