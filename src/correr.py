# corre una consulta de sql/consultas.sql por nombre, para probar
# uso: python src/correr.py totales [config/otro_evento.yaml]
import re
import sys

import duckdb

from pipeline import cargar_config, leer_bloques, preparar_variables


def main():
    sys.stdout.reconfigure(encoding="utf-8")  # si no, windows no imprime las tablas
    bloques = leer_bloques()
    pedido = sys.argv[1] if len(sys.argv) > 1 else "carga"
    config = sys.argv[2] if len(sys.argv) > 2 else "config/olimpiadas_2026.yaml"
    if pedido not in bloques:
        sys.exit(f"No existe el bloque '{pedido}'. Disponibles: {', '.join(bloques)}")

    con = duckdb.connect()  # en memoria
    preparar_variables(con, cargar_config(config))

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
