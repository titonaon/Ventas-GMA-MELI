"""Corre un bloque de sql/consultas.sql y muestra el resultado.

Uso:  python src/correr.py <bloque>      ej: python src/correr.py totales
Antes del bloque pedido se corren, en orden, los bloques anteriores que crean
tablas (los que tienen CREATE), así existen las tablas de las que depende.
"""
import re
import sys
from pathlib import Path

import duckdb


def leer_bloques(ruta="sql/consultas.sql"):
    """Devuelve {nombre: sql} separando el archivo en cada '-- name: xxx'."""
    texto = Path(ruta).read_text(encoding="utf-8")
    partes = re.split(r"^--\s*name:\s*(\w+)\s*$", texto, flags=re.MULTILINE)[1:]
    return dict(zip(partes[::2], partes[1::2]))


def main():
    sys.stdout.reconfigure(encoding="utf-8")  # las tablas de DuckDB usan caracteres de dibujo
    bloques = leer_bloques()
    pedido = sys.argv[1] if len(sys.argv) > 1 else "carga"
    if pedido not in bloques:
        sys.exit(f"No existe el bloque '{pedido}'. Disponibles: {', '.join(bloques)}")

    con = duckdb.connect()  # base en memoria: se arma de cero en cada corrida

    # Antes del pedido, corre en orden los bloques que crean tablas (carga,
    # productos_evento, ...) para que existan las tablas de las que depende.
    for nombre, sql in bloques.items():
        if nombre == pedido:
            break
        if crea_tablas(sql):
            con.execute(sql)
            print(f"[ok] {nombre}")

    resultado = con.sql(bloques[pedido])
    if resultado is not None:  # un bloque que termina en CREATE no devuelve filas
        resultado.show(max_rows=100, max_width=300)


def crea_tablas(sql):
    """True si el bloque tiene alguna línea que empiece con CREATE (ignora comentarios)."""
    return re.search(r"^\s*CREATE\b", sql, flags=re.MULTILINE | re.IGNORECASE) is not None


if __name__ == "__main__":
    main()
