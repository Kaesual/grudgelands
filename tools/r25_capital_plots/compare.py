#!/usr/bin/env python3
"""Round 25 Lane H: summarise harness TSVs and compare main with the branch.

  compare.py branch.tsv [main.tsv or -] [baseline.tsv]

results/: failing.txt (the five seeds that failed the load on main), sample200.txt
(the first 200 seeds of baseline-main-300.tsv, the investigation's main
sample), sample120.txt (its first 120, also run on main for digests); *-main.tsv
from main c79827e4, *-branch.tsv from Round 25 Lane H; summary-*.txt are this
script's output.

branch.tsv / main.tsv: harness.lua output (per capital: miss, leftbld,
leftfill, ovf, nb, digest). baseline.tsv: the investigation's 300-seed
main sample (older harness: anchor ids, miss, leftbld, no fill or digest).
"""
import re
import sys
from collections import Counter

ANCHOR = {"anchor_007": "dur_brannoc", "anchor_008": "highcourt",
          "anchor_009": "lethariel", "anchor_010": "nhal_veyr",
          "anchor_011": "gor_drazhak", "anchor_012": "kezamba"}
ORDER = ["highcourt", "dur_brannoc", "gor_drazhak", "lethariel", "kezamba", "nhal_veyr"]
FIELD = re.compile(r"(\S+?)\[([^\]]*)\]")


def load(path):
    rows = {}
    for line in open(path, encoding="utf-8", errors="replace"):
        parts = line.rstrip("\n").split("\t")
        if len(parts) < 5:
            continue
        caps = {}
        for name, body in FIELD.findall(parts[4]):
            kv = dict(item.split("=", 1) for item in body.split(";") if "=" in item)
            caps[ANCHOR.get(name, name)] = kv
        rows[parts[0]] = {"status": parts[1], "secs": float(parts[2]), "fails": parts[3], "caps": caps}
    return rows


def ids(value):
    return [x for x in (value or "").split("+") if x]


def summary(label, rows, seeds):
    fails = [s for s in seeds if rows[s]["status"] != "OK"]
    print(f"== {label}: {len(seeds)} seeds, load failures {len(fails)}"
          + (": " + ", ".join(f"{s} ({rows[s]['fails']})" for s in fails) if fails else ""))
    secs = [rows[s]["secs"] for s in seeds]
    print(f"   CPU s/seed mean {sum(secs) / len(secs):.1f}")
    has_fill = any("leftfill" in rows[s]["caps"].get("kezamba", {}) for s in seeds)
    print("   capital      seeds_w_named_drop  named_drops  top_dropped" +
          ("                       fill_drops(mean/max)" if has_fill else ""))
    for cap in ORDER:
        dropped = Counter()
        seeds_w = 0
        fill = []
        for s in seeds:
            kv = rows[s]["caps"].get(cap, {})
            d = ids(kv.get("leftbld"))
            if d:
                seeds_w += 1
            dropped.update(d)
            if "leftfill" in kv:
                fill.append(int(kv["leftfill"]))
        top = ", ".join(f"{k} {v}" for k, v in dropped.most_common(3))
        line = f"   {cap:12s} {seeds_w:18d}  {sum(dropped.values()):11d}  {top:32s}"
        if fill:
            line += f"  {sum(fill) / len(fill):.2f}/{max(fill)}"
        print(line)


def main():
    branch = load(sys.argv[1])
    main_rows = load(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2] not in ("", "-") else {}
    base = load(sys.argv[3]) if len(sys.argv) > 3 else {}
    bseeds = list(branch)
    summary("branch", branch, bseeds)
    if base:
        common = [s for s in bseeds if s in base]
        summary("baseline (investigation, main)", base, common)
        summary("branch, same seeds", branch, common)
    if main_rows:
        common = [s for s in bseeds if s in main_rows]
        summary("main (this harness)", main_rows, common)
        summary("branch, same seeds", branch, common)
        print(f"== layout identity, {len(common)} seeds (digest of planner.serialize)")
        print("   capital      clean_on_main  identical/clean  changed_total  "
              "overflow_named_on_main  identical_among_those")
        for cap in ORDER:
            clean = ident_clean = changed = nb_pos = ident_nb = 0
            for s in common:
                m = main_rows[s]["caps"].get(cap, {})
                b = branch[s]["caps"].get(cap, {})
                same = m.get("digest") == b.get("digest")
                if not same:
                    changed += 1
                # clean: every required and named plot stood in its own
                # quarter in pass 1 (relaxed ones may sit in their own
                # quarter too, so they count as missed)
                if m.get("nb") == "0" and not ids(m.get("relaxed")):
                    clean += 1
                    ident_clean += same
                else:
                    nb_pos += 1
                    ident_nb += same
            print(f"   {cap:12s} {clean:13d}  {ident_clean:15d}  {changed:5d} ({100 * changed / len(common):3.0f} %)"
                  f"  {nb_pos:22d}  {ident_nb:21d}")


main()
