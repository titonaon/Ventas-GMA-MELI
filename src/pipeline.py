# genera el reporte de un evento a partir de su config
# uso: python src/pipeline.py --config config/olimpiadas_2026.yaml
import argparse
import base64
import json
import re
import sys
from datetime import date, timedelta
from pathlib import Path

import duckdb
import yaml
from jinja2 import Environment, FileSystemLoader

SQL = "sql/consultas.sql"
TEMPLATES = Path("templates")
NOMBRES = {"albumes": "Álbumes"}  # ids de categoria sin tilde


def cargar_config(ruta):
    with open(ruta, encoding="utf-8") as f:
        return yaml.safe_load(f)


def leer_bloques(ruta=SQL):
    texto = Path(ruta).read_text(encoding="utf-8")
    partes = re.split(r"^--\s*name:\s*(\w+)\s*$", texto, flags=re.MULTILINE)[1:]
    return dict(zip(partes[::2], partes[1::2]))


def preparar_variables(con, cfg):
    # cada valor de la config queda como variable de duckdb -> getvariable('nombre') en el sql
    for nombre, valor in cfg.items():
        if nombre == "reporte":  # los textos del reporte no van al sql
            continue
        con.execute(f"SET VARIABLE {nombre} = ?", [valor])


def correr(cfg):
    con = duckdb.connect()  # en memoria
    preparar_variables(con, cfg)
    resultados = {}
    for nombre, sql in leer_bloques().items():
        r = con.sql(sql)
        resultados[nombre] = r.df() if r is not None else None
    return resultados


# ---------- reporte html ----------

def usd_k(x):
    return f"USD {x / 1000:,.0f}K".replace(",", ".")


def usd(x):
    return f"USD {x:,.0f}".replace(",", ".")


def veces(x):
    return f"×{x:.1f}".replace(".", ",")


def datos_reporte(cfg, res):
    t = res["totales"].iloc[0]
    ovp = res["oficial_vs_particular"].set_index("clasificacion")
    libros = res["hallazgo_libros"].iloc[0]

    # solo semanas completas, las puntas cortadas distorsionan el promedio
    curva = res["curva_semanal"]
    curva = curva[curva.dias == 7].reset_index(drop=True)
    semanas = [s.date() for s in curva.semana]
    # posicion exacta de una fecha en el eje: cada punto es el lunes de su semana,
    # asi que un dia cae en indice_semana + dias_desde_el_lunes / 7
    def posicion(d):
        i = max(k for k, s in enumerate(semanas) if s <= d)
        return i + (d - semanas[i]).days / 7

    pais = res["por_pais"]
    cat = res["por_categoria"]

    numeros = {
        "incremental": usd_k(t.incremental),
        "total": usd_k(t.total_periodo),
        "durante": usd_k(t.durante),
        "pico": veces(curva.veces_base.max()),
        "pct_oficial": f"{ovp.loc['oficial', 'pct_total']:.0f}%",
        "pct_exclusivas": f"{ovp.loc['oficial', 'pct_cat_exclusivas']:.0f}%",
        "libros_total": usd_k(libros.total_periodo),
        "libros_veces": veces(libros.veces_base_durante),
        "pct_inc_fuera": f"{100 * (1 - t.incremental_durante / t.incremental):.0f}%",
    }

    def fecha(d):
        return d.strftime("%d/%m")

    periodos = [
        {"nombre": "Antes", "fechas": f"hasta {fecha(cfg['inicio_evento'] - timedelta(days=1))}",
         "total": usd_k(t.antes), "x_dia": usd(t.antes_x_dia)},
        {"nombre": "Durante", "fechas": f"{fecha(cfg['inicio_evento'])} al {fecha(cfg['fin_evento'])}",
         "total": usd_k(t.durante), "x_dia": usd(t.durante_x_dia)},
        {"nombre": "Después", "fechas": f"desde {fecha(cfg['fin_evento'] + timedelta(days=1))}",
         "total": usd_k(t.despues), "x_dia": usd(t.despues_x_dia)},
    ]

    graficos = {
        "curva": {
            "labels": [s.strftime("%d/%m") for s in semanas],
            "venta_x_dia": curva.venta_x_dia.round(0).tolist(),
            "base": round(float(t.base_diaria), 0),
            "evento_desde": posicion(cfg["inicio_evento"]),
            "evento_hasta": posicion(cfg["fin_evento"] + timedelta(days=1)),  # hasta el final del ultimo dia
        },
        "categoria": {
            "labels": [NOMBRES.get(c, c.capitalize()) for c in cat.categoria],
            "oficial": cat.oficial.round(0).tolist(),
            "particular": cat.particular.round(0).tolist(),
        },
        "pais": {
            "labels": pais.pais.str.replace("Mexico", "México").tolist(),
            "oficial": (pais.total_periodo * pais.pct_oficial / 100).round(0).tolist(),
            "particular": (pais.total_periodo * (100 - pais.pct_oficial) / 100).round(0).tolist(),
        },
    }

    tabla_paises = [
        {"pais": r.pais.replace("Mexico", "México"), "total": f"{r.total_periodo:,.0f}".replace(",", "."),
         "incremental": f"{r.incremental:,.0f}".replace(",", "."),
         "veces": veces(r.veces_base_durante),
         "oficial": f"{r.pct_oficial:.0f}%", "peso": f"{r.pct_total:.0f}%"}
        for r in pais.itertuples()
    ]
    return numeros, graficos, tabla_paises, periodos


def armar_html(cfg, res):
    numeros, graficos, tabla_paises, periodos = datos_reporte(cfg, res)
    rep = cfg["reporte"]
    env = Environment(loader=FileSystemLoader(TEMPLATES), autoescape=True)

    # los textos de la config pueden tener {{ numero }}
    def texto(s):
        return env.from_string(s).render(**numeros)

    mensajes = {k: {campo: texto(v) for campo, v in m.items()} for k, m in rep["mensajes"].items()}

    # todo embebido (logo, librerias) para que sea un solo archivo que anda sin internet
    assets = TEMPLATES / "assets"
    logo = base64.b64encode((assets / "logo_mercadolibre.png").read_bytes()).decode()
    js = "\n".join((assets / f).read_text(encoding="utf-8")
                   for f in ["chart.umd.min.js", "chartjs-plugin-annotation.min.js"])

    return env.get_template("reporte.html.j2").render(
        cfg=cfg, rep=rep, resumen=texto(rep["resumen"]), mensajes=mensajes,
        numeros=numeros, tabla_paises=tabla_paises, periodos=periodos,
        graficos_json=json.dumps(graficos), logo_b64=logo, librerias_js=js,
        generado=date.today().strftime("%d/%m/%Y"),
    )


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", default="config/olimpiadas_2026.yaml")
    args = parser.parse_args()

    cfg = cargar_config(args.config)
    res = correr(cfg)

    salida = Path(cfg["salida"])
    salida.mkdir(parents=True, exist_ok=True)
    # titulos que matchean el patron, para revisar falsos positivos a mano
    res["explorar_titulos"].to_csv(salida / "revision_titulos.csv", index=False, encoding="utf-8-sig")
    (salida / "reporte.html").write_text(armar_html(cfg, res), encoding="utf-8")

    t = res["totales"].iloc[0]
    print(f"{cfg['evento']}")
    print(f"  total periodo: USD {t.total_periodo:,.2f}")
    print(f"  durante:       USD {t.durante:,.2f}")
    print(f"  incremental:   USD {t.incremental:,.2f}")
    print(f"  reporte     -> {salida / 'reporte.html'}")
    print(f"  revision    -> {salida / 'revision_titulos.csv'}")


if __name__ == "__main__":
    main()
