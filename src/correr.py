"""Corre un bloque de sql/consultas.sql y muestra el resultado.

Uso:  python src/correr.py <bloque>      ej: python src/correr.py calidad
El bloque "carga" se corre siempre primero para que existan las tablas.
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
    print(con.sql(bloques["carga"]))
    if pedido != "carga":
        print(con.sql(bloques[pedido]))


if __name__ == "__main__":
    main()
