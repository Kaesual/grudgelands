#!/usr/bin/env python3
"""Round 28 Lane W1: every zone's spawn-recipe `from` / `to` by the border
rule (user, 2026-10-02), from the zone atlas.

Per zone kind (the atlas `role`), which borders are low (`from`, where
players come in), high (`to`, where they move on) or neutral:

  start      low: the start town (anchor start); high: the border to the
             race's own home zone 11-20; neutral: borders to heartlands.
  home       (11-20) low: the border to its race's start zone; high: the
             borders to its race's capital zone and to every adjacent
             heartland.
  capital    (20-30) low: the city (anchor capital) and the border to its
             race's home zone 11-20; high: the borders to contested zones;
             neutral: borders to heartlands.
  heartland  (21-30) low: every border to the faction's capital and home
             (11-20) zones, and to a start zone (the forced 10 -> 21 gap:
             neutral on the start side, low here so the heartland meets a
             player from the start zone with its lowest levels); high: the
             borders to contested zones and front zones; neutral: other
             heartlands.
  contested  (31-40) low: every border to the faction's 20-30 zones
             (capitals, heartlands); high: the borders to front zones;
             neutral: other contested zones.
  front      (the Battlegrounds, 41-60; the user, 2026-10-02) low: every
             border to a lower-band neighbour; high: the borders to
             higher-band neighbours, or the zone's core (`to: core`) where
             it has none; neutral: same-band fronts. The Broken Causeway and
             The Shattered Line (41-50) rise from their contested borders
             toward Gravesalt Escarpment and The Skyglass Canopy (51-60),
             which rise from their lower neighbours to their core.
  island     unchanged (one belt, no land border).

A contested zone's faction is its race's (`race_region`), as the start zones
give it. A neighbour the table does not cover (a kind or race the row does
not name) makes the zone NOT COVERED: it is reported and its recipe is left
as it is, never guessed. Deterministic: zone and border lists sorted.

Usage:
  border_rule.py [--atlas DIR] [--zones-dir DIR] [--report FILE]
                 [--out DIR | --apply] [--self-test]

  --atlas      the zone atlas (default docs/planning/round28/zones)
  --zones-dir  the recipes compared against and copied (default the shipped
               mods/ENTITIES/grug_mobs/data/zones)
  --report     write the markdown report there (default: stdout)
  --out        write every recipe zone's spawns file into DIR with `from` and
               `to` set by the rule (unchanged zones copied as they are)
  --apply      the same into the shipped data directory
Only the `from` and `to` lines of a file change; the rest of its text stays
byte for byte (checked by parsing the result).
"""
import argparse
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ATLAS = REPO / "docs" / "planning" / "round28" / "zones"
SHIPPED = REPO / "mods" / "ENTITIES" / "grug_mobs" / "data" / "zones"

ROLE_KIND = {
    "start zone": "start",
    "home zone 11-20": "home",
    "capital zone": "capital",
    "home zone 21-30": "heartland",
    "contested 31-40": "contested",
    "front zone": "front",
    "dragon island (60)": "island",
}
UNCHANGED = ("island",)


def load_atlas(atlas_dir):
    """{zone id: {kind, race, faction, neighbours, name, role}}."""
    zones = {}
    for path in sorted(Path(atlas_dir).glob("*.json")):
        rec = json.loads(path.read_text())
        if not isinstance(rec, dict) or "id" not in rec or "role" not in rec:
            continue
        zones[rec["id"]] = {"kind": ROLE_KIND.get(rec["role"]), "role": rec["role"],
                            "race": rec.get("race_region"), "faction": rec.get("faction"),
                            "name": rec.get("name", rec["id"]),
                            "band": (rec.get("level_min"), rec.get("level_max")),
                            "neighbours": sorted(rec.get("neighbors") or [])}
    # A race's faction, as its start zones give it; contested zones take it.
    race_faction = {}
    for z in zones.values():
        if z["kind"] == "start":
            race_faction[z["race"]] = z["faction"]
    for z in zones.values():
        if z["kind"] in ("contested", "front", "island") or z["faction"] not in ("accord", "throng"):
            z["faction"] = race_faction.get(z["race"]) if z["kind"] == "contested" else None
    return zones


def classify(zones, zid):
    """(low_anchor, low_borders, high_borders, neutral, uncovered) for one
    zone; low_anchor is a slot or None. high_borders empty: `to` core (a
    front zone with no higher neighbour). Kinds `island` / unknown return
    None (unchanged / not covered)."""
    z = zones[zid]
    kind = z["kind"]
    if kind is None or kind in UNCHANGED:
        return None
    anchor = {"start": "start", "capital": "capital"}.get(kind)
    low, high, neutral, uncovered = [], [], [], []
    for nid in z["neighbours"]:
        n = zones.get(nid)
        nk = n["kind"] if n else None
        same_race = n is not None and n["race"] == z["race"]
        same_faction = n is not None and n["faction"] is not None and n["faction"] == z["faction"]
        side = None
        if kind == "start":
            if nk == "home" and same_race:
                side = "high"
            elif nk == "heartland":
                side = "neutral"
        elif kind == "home":
            if nk == "start" and same_race:
                side = "low"
            elif (nk == "capital" and same_race) or nk == "heartland":
                side = "high"
        elif kind == "capital":
            if nk == "home" and same_race:
                side = "low"
            elif nk == "contested":
                side = "high"
            elif nk == "heartland":
                side = "neutral"
        elif kind == "heartland":
            if nk in ("capital", "home") and same_faction:
                side = "low"
            elif nk == "start":
                side = "low"
            elif nk in ("contested", "front"):
                side = "high"
            elif nk == "heartland":
                side = "neutral"
        elif kind == "contested":
            if nk in ("capital", "heartland") and same_faction:
                side = "low"
            elif nk == "front":
                side = "high"
            elif nk == "contested":
                side = "neutral"
        elif kind == "front" and n is not None and n["band"][0] and z["band"][0]:
            if n["band"][0] < z["band"][0]:
                side = "low"
            elif n["band"][0] > z["band"][0]:
                side = "high"
            elif nk == "front":
                side = "neutral"
        {"low": low, "high": high, "neutral": neutral, None: uncovered}[side].append(nid)
    if not high and kind != "front":
        uncovered.append("(no high border)")
    if not low and not anchor:
        uncovered.append("(no low border)")
    return anchor, low, high, neutral, uncovered


def rule_from_to(anchor, low, high):
    """The recipe's `from` and `to` objects (one id as a string, several as
    a sorted list; no high border: `to` core)."""
    def ids(v):
        v = sorted(v)
        return v[0] if len(v) == 1 else v
    frm = {}
    if anchor:
        frm["anchor"] = anchor
    if low:
        frm["border"] = ids(low)
    return frm, ({"border": ids(high)} if high else {"core": True})


def norm(obj):
    """A from/to object with string-or-list values as sorted lists."""
    if not isinstance(obj, dict):
        return obj
    return {k: sorted([v] if isinstance(v, str) else v) if isinstance(v, (str, list)) else v
            for k, v in obj.items()}


def rewrite(text, frm, to):
    """The spawns file text with the recipe's `from` / `to` objects replaced
    (or inserted at the top of the recipe when absent); the rest unchanged."""
    start = text.index('"recipe"')
    brace = text.index("{", start)
    for key, value in (("to", to), ("from", frm)):
        new = '"%s": %s' % (key, json.dumps(value, separators=(", ", ": ")))
        m = re.compile(r'"%s"\s*:\s*\{[^{}]*\}' % key).search(text, brace)
        if m:
            text = text[:m.start()] + new + text[m.end():]
        else:
            nl = text.index("\n", brace)
            indent = re.match(r"\s*", text[nl + 1:]).group(0)
            text = text[:nl + 1] + indent + new + ",\n" + text[nl + 1:]
    return text


def check_rewrite(old_text, new_text, frm, to):
    old, new = json.loads(old_text), json.loads(new_text)
    want = json.loads(old_text)
    want["recipe"]["from"], want["recipe"]["to"] = frm, to
    if new != want or set(old["recipe"]) - {"from", "to"} != set(new["recipe"]) - {"from", "to"}:
        raise SystemExit("rewrite changed more than from/to")


def text_of(obj):
    if not obj:
        return "-"
    parts = []
    for k in ("anchor", "border", "core"):
        if k in obj:
            v = obj[k]
            parts.append("%s %s" % (k, ", ".join(sorted([v] if isinstance(v, str) else v))
                                    if not isinstance(v, bool) else k))
    return " + ".join(parts) if parts else json.dumps(obj)


def short(zid):
    return zid.split("_", 1)[1] if "_" in zid else zid


def rel(path):
    p = Path(path).resolve()
    return p.relative_to(REPO) if p.is_relative_to(REPO) else p


def run(atlas_dir, zones_dir, report, out_dir):
    zones = load_atlas(atlas_dir)
    lines = ["# Border rule: spawn recipes' from / to per zone\n",
             "Atlas `%s`, recipes `%s`. Low = `from` (entry), high = `to` (exit). Kinds by the "
             "atlas role; the rule table is in `tools/r28_world/border_rule.py`.\n"
             % (rel(atlas_dir), rel(zones_dir)),
             "| zone | kind | current from -> to | rule from -> to | neutral | status |",
             "|---|---|---|---|---|---|"]
    counts = {}
    written = 0
    for zid in sorted(zones):
        z = zones[zid]
        path = Path(zones_dir) / ("%s.spawns.json" % zid)
        text = path.read_text() if path.exists() else None
        data = json.loads(text) if text else None
        recipe = data.get("recipe") if isinstance(data, dict) else None
        cur = "%s -> %s" % (text_of(recipe.get("from")), text_of(recipe.get("to"))) if recipe else "no recipe"
        c = classify(zones, zid)
        new_text = text if recipe else None
        if c is None:
            status = "unchanged (%s)" % z["kind"] if z["kind"] else "NOT COVERED (role %r)" % z["role"]
            rule, neutral = "as today", ""
        else:
            anchor, low, high, neutral_ids, uncovered = c
            neutral = ", ".join(short(n) for n in neutral_ids)
            frm, to = rule_from_to(anchor, low, high)
            rule = "%s -> %s" % (text_of(frm), text_of(to))
            if uncovered:
                status = "NOT COVERED: " + ", ".join(uncovered)
                rule = "-"
            elif not recipe:
                status = "no recipe"
            elif norm(recipe.get("from")) == norm(frm) and norm(recipe.get("to")) == norm(to):
                status = "same"
            else:
                status = "changes"
                new_text = rewrite(text, frm, to)
                check_rewrite(text, new_text, frm, to)
        head = status.split(":")[0].split(" (")[0]
        counts[head] = counts.get(head, 0) + 1
        lines.append("| %s | %s | %s | %s | %s | %s |" % (z["name"], z["kind"] or z["role"],
                                                      cur, rule,
                                                      neutral, status))
        if out_dir and new_text is not None:
            Path(out_dir).mkdir(parents=True, exist_ok=True)
            target = Path(out_dir) / path.name
            if not (target.exists() and target.read_text() == new_text):
                target.write_text(new_text)
            written += 1
    lines.append("")
    lines.append("Zones: " + ", ".join("%s %d" % (k, v) for k, v in sorted(counts.items())) + ".")
    if out_dir:
        place = rel(out_dir)
        lines.append("Recipe files written: %d (%s)." % (
            written, "`%s`" % place if not place.is_absolute() else "a scratch directory"))
    text = "\n".join(lines) + "\n"
    if report:
        Path(report).write_text(text)
    else:
        sys.stdout.write(text)
    return counts


def self_test():
    """The table on a small synthetic atlas (two races of one faction, one of
    the other side's contested zone as a stranger)."""
    def zone(kind, race, faction, nb, band=(None, None)):
        return {"kind": kind, "role": kind, "race": race, "faction": faction, "name": kind,
                "band": band, "neighbours": sorted(nb)}
    zones = {
        "s_h": zone("start", "human", "accord", ["h_h", "hl_e"]),
        "h_h": zone("home", "human", "accord", ["s_h", "c_h", "hl_e", "hl_h"]),
        "c_h": zone("capital", "human", "accord", ["h_h", "hl_h", "x_h"]),
        "hl_h": zone("heartland", "human", "accord", ["h_h", "c_h", "hl_e", "x_h", "c_e"]),
        "hl_e": zone("heartland", "elf", "accord", ["hl_h", "h_h", "s_h", "x_h"]),
        "c_e": zone("capital", "elf", "accord", ["hl_h"]),
        "x_h": zone("contested", "human", "accord", ["c_h", "hl_h", "hl_e", "x_o", "f", "f2"], (31, 40)),
        "x_o": zone("contested", "orc", "throng", ["x_h", "f", "g", "h_h"], (31, 40)),
        "f": zone("front", None, None, ["x_h", "x_o", "f2", "g"], (41, 50)),
        "f2": zone("front", None, None, ["x_h", "f", "g2"], (41, 50)),
        "g": zone("front", None, None, ["f", "x_o"], (51, 60)),
        "g2": zone("front", None, None, ["f2"], (51, 60)),
        "i": zone("island", None, None, [], (60, 60)),
    }
    fails = []

    def expect(zid, want):
        got = classify(zones, zid)
        if got != want:
            fails.append("%s: got %r, want %r" % (zid, got, want))
    expect("s_h", ("start", [], ["h_h"], ["hl_e"], []))
    expect("h_h", (None, ["s_h"], ["c_h", "hl_e", "hl_h"], [], []))
    expect("c_h", ("capital", ["h_h"], ["x_h"], ["hl_h"], []))
    expect("hl_h", (None, ["c_e", "c_h", "h_h"], ["x_h"], ["hl_e"], []))
    expect("hl_e", (None, ["h_h", "s_h"], ["x_h"], ["hl_h"], []))
    expect("x_h", (None, ["c_h", "hl_e", "hl_h"], ["f", "f2"], ["x_o"], []))
    # The orc contested zone beside an accord home zone: not covered.
    expect("x_o", (None, [], ["f", "g"], ["x_h"], ["h_h", "(no low border)"]))
    # Fronts: lower bands low, higher bands high, same band neutral; no
    # higher neighbour: the core. Islands stay as they are.
    expect("f", (None, ["x_h", "x_o"], ["g"], ["f2"], []))
    expect("f2", (None, ["x_h"], ["g2"], ["f"], []))
    expect("g", (None, ["f", "x_o"], [], [], []))
    expect("g2", (None, ["f2"], [], [], []))
    expect("i", None)
    frm, to = rule_from_to(None, ["f", "x_o"], [])
    if frm != {"border": ["f", "x_o"]} or to != {"core": True}:
        fails.append("rule_from_to without a high border: %r %r" % (frm, to))
    # The capital's elf neighbour (another race's capital) is no low border;
    # c_e has no contested neighbour: not covered (no exit).
    expect("c_e", ("capital", [], [], ["hl_h"], ["(no high border)"]))
    frm, to = rule_from_to("capital", ["h_h"], ["x_h", "f"])
    if frm != {"anchor": "capital", "border": "h_h"} or to != {"border": ["f", "x_h"]}:
        fails.append("rule_from_to: %r %r" % (frm, to))
    text = ('{\n  "zone": "z",\n  "recipe": {\n    "from": {"anchor": "start"},\n'
            '    "to": {"border": "a"},\n    "belts": [{"id": "b", "kinds": {"open": {"to": 1}}}]\n  }\n}\n')
    new = rewrite(text, {"anchor": "capital", "border": "h"}, {"border": ["a", "b"]})
    check_rewrite(text, new, {"anchor": "capital", "border": "h"}, {"border": ["a", "b"]})
    if '"belts": [{"id": "b", "kinds": {"open": {"to": 1}}}]' not in new:
        fails.append("rewrite touched the belts")
    bare = '{\n  "zone": "z",\n  "recipe": {\n    "belts": []\n  }\n}\n'
    new = rewrite(bare, {"border": "a"}, {"border": "b"})
    check_rewrite(bare, new, {"border": "a"}, {"border": "b"})
    if fails:
        print("border_rule self-test: FAIL\n  " + "\n  ".join(fails))
        return 1
    print("border_rule self-test: PASS")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--atlas", default=str(ATLAS))
    ap.add_argument("--zones-dir", default=str(SHIPPED))
    ap.add_argument("--report")
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--out")
    g.add_argument("--apply", action="store_true")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        return self_test()
    out = str(SHIPPED) if args.apply else args.out
    run(args.atlas, args.zones_dir, args.report, out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
