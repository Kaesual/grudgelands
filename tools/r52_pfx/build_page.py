#!/usr/bin/env python3
"""Round 52 PFX: build the preview page from data.json and template.html.

    python3 -I tools/r52_pfx/effects.py        # the cards and their costs -> data.json
    python3 -I tools/r52_pfx/build_page.py     # -> page/index.html (+ page/local.html)
    python3 -I tools/r52_pfx/build_page.py --check
        reruns effects.py (data.json) and rebuilds the page in memory; fails
        unless page/index.html is byte for byte the same (with `git diff
        --exit-code tools/r52_pfx` the regenerated data.json is checked too).

page/index.html is page content only (title, style, markup, data, script;
the publisher wraps it); page/local.html is the same wrapped in a document
skeleton for opening from file:// (gitignored). Standard library only; the
page needs no file beside it.

Ratings follow the Round 52 storage contract: collection `notes`, document id
= the card's key (pfx.<skill>.<moment>; only [a-z_.] occur, characters
outside [A-Za-z0-9_.:@+-] would be written as ~XX hex), fields {key, verdict,
text, updatedAt}, verdict "pick" | "rework" | "drop" | "".
"""
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PAGE = HERE / "page"
# The fields of a card the page reads.
CARD_FIELDS = ("n", "key", "skill", "name", "class", "tree", "unlock", "family", "family_name", "family_de",
               "moment", "status", "id", "look", "hook", "today", "note", "sprite", "dynamic", "target",
               "lua_text", "sim", "cost", "today_cost", "rate", "t0", "context", "flight", "marker", "group")
COST_FIELDS = ("particles", "spawners", "singles", "wire", "dg", "spawner_wire", "spawner_dg", "marginal",
               "single_events", "lua_us", "rx_us", "check_us", "i1", "i2", "peak")
SIM_FIELDS = ("kind", "n", "time", "shape", "engine", "vel", "acc", "exp", "size", "glow", "color", "tex",
              "fade", "pull", "radial", "reach")


def rounded(v):
    if isinstance(v, float):
        return round(v, 4)
    if isinstance(v, list):
        return [rounded(x) for x in v]
    if isinstance(v, dict):
        return {k: rounded(x) for k, x in v.items()}
    return v


def slim(doc):
    cards = []
    for c in doc["cards"]:
        d = {k: c[k] for k in CARD_FIELDS}
        d["sim"] = [{k: e[k] for k in SIM_FIELDS} for e in c["sim"]]
        d["cost"] = c["cost"] and {k: c["cost"][k] for k in COST_FIELDS}
        d["today_cost"] = c["today_cost"] and {k: c["today_cost"][k] for k in ("particles", "wire")}
        d["context"] = [{"key": x["key"], "t0": x["t0"], "flight": x["flight"],
                         "emitters": [{k: e[k] for k in SIM_FIELDS} for e in x["emitters"]]}
                        for x in c["context"]]
        cards.append(rounded(d))
    return {"cards": cards, "families": doc["families"], "classes": doc["classes"],
            "scenarios": doc["scenarios"], "constants": doc["constants"]}


def build(data_text):
    page = (HERE / "template.html").read_text()
    data = json.dumps(slim(json.loads(data_text)), ensure_ascii=False, separators=(",", ":"), sort_keys=True)
    page = page.replace("/*DATA*/", data.replace("</", "<\\/"))
    local = ('<!doctype html>\n<html lang="de">\n<head>\n<meta charset="utf-8">\n'
             '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
             "</head>\n<body>\n" + page + "</body>\n</html>\n")
    return page, local


def main():
    if "--check" in sys.argv:
        out = subprocess.run([sys.executable, "-I", str(HERE / "effects.py")], capture_output=True, text=True)
        if out.returncode:
            print(out.stdout, out.stderr)
            raise SystemExit("effects.py failed")
        page, _ = build((HERE / "data.json").read_text())
        same = (PAGE / "index.html").read_text() == page
        print("page/index.html " + ("reproduces byte for byte" if same else "DIFFERS from a rebuild"))
        raise SystemExit(0 if same else 1)
    page, local = build((HERE / "data.json").read_text())
    PAGE.mkdir(exist_ok=True)
    (PAGE / "index.html").write_text(page)
    (PAGE / "local.html").write_text(local)
    print("page/index.html %.0f KB" % (len(page.encode()) / 1024))


if __name__ == "__main__":
    main()
