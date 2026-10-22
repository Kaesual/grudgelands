#!/usr/bin/env python3
"""Write the probe's raw dump as tools/building_templates/nodes.json.

Sorted keys, one node and one alias per line, so a refresh with unchanged node
definitions is byte-identical and a changed node shows as a one-line diff.

    python3 tools/building_templates/node_dump/normalize.py RAW.json [OUT.json]
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_OUT = os.path.join(os.path.dirname(HERE), "nodes.json")


def dumps(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"),
                      ensure_ascii=False)


def normalize(raw):
    nodes = raw.get("nodes") or {}
    aliases = raw.get("aliases") or {}
    if not isinstance(nodes, dict) or not nodes:
        raise SystemExit("the dump has no nodes")
    if not isinstance(aliases, dict):
        aliases = {}  # an empty Lua table comes out as []
    out = ["{"]
    out.append('"aliases":{')
    keys = sorted(aliases)
    for i, key in enumerate(keys):
        out.append("%s:%s%s" % (dumps(key), dumps(aliases[key]),
                                "," if i + 1 < len(keys) else ""))
    out.append("},")
    out.append('"nodes":{')
    keys = sorted(nodes)
    for i, key in enumerate(keys):
        out.append("%s:%s%s" % (dumps(key), dumps(nodes[key]),
                                "," if i + 1 < len(keys) else ""))
    out.append("}")
    out.append("}")
    return "\n".join(out) + "\n"


def main(argv):
    if len(argv) not in (2, 3):
        raise SystemExit(__doc__)
    with open(argv[1], encoding="utf-8") as fh:
        raw = json.load(fh)
    text = normalize(raw)
    out = argv[2] if len(argv) == 3 else DEFAULT_OUT
    with open(out, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)
    print("wrote %s: %d nodes, %d aliases" % (
        out, len(raw["nodes"]), len(raw.get("aliases") or {})))


if __name__ == "__main__":
    main(sys.argv)
