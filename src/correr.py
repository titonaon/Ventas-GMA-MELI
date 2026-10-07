# corre una consulta de sql/consultas.sql por nombre
# uso: python src/correr.py totales
import re
import sys
from pathlib import Path

import duckdb


def leer_bloques(ruta="sql/consultas.sql"):
    texto = Path(ruta).read_text(encoding="utf-8")
    partes = re.split(r"^--\s*name:\s*(\w+)\s*$", texto, flags=re.MULTILINE)[1:]
    return dict(zip(partes[::2], partes[1::2]))


def main():
    sys.stdout.reconfigure(encoding="utf-8")  # si no, windows no imprime las tablas
    bloques = leer_bloques()
    pedido = sys.argv[1] if len(sys.argv) > 1 else "carga"
    if pedido not in bloques:
        sys.exit(f"No existe el bloque '{pedido}'. Disponibles: {', '.join(bloques)}")

    con = duckdb.connect()  # en memoria

    # primero corro los bloques que crean tablas, si no la consulta no las encuentra
    for nombre, sql in bloques.items():
        if nombre == pedido:
            break
        if crea_tablas(sql):
            con.execute(sql)
            print(f"[ok] {nombre}")

    resultado = con.sql(bloques[pedido])
    if resultado is not None:
        resultado.show(max_rows=100, max_width=300)


def crea_tablas(sql):
    return re.search(r"^\s*CREATE\b", sql, flags=re.MULTILINE | re.IGNORECASE) is not None


if __name__ == "__main__":
    main()
