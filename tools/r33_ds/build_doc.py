#!/usr/bin/env python3
"""Round 33 lane DS: refresh the generated tables of docs/design/item_tiers.md.

Each block between `<!-- generated: NAME -->` and `<!-- end generated -->`
is replaced by the matching script output; prose outside the markers is
left alone.

Usage: build_doc.py [--check]   (--check: exit 1 when the file is stale)
"""
import argparse
import re
import sys

import alchemy
import allocation
import common as C
import money
import stat_values

DOC = C.REPO / "docs" / "design" / "item_tiers.md"


def sections(lines):
    """Split Markdown lines at '### ' headings: {heading: lines}."""
    out, current = {}, None
    for line in lines:
        if line.startswith("### "):
            current = line[4:].strip()
            out[current] = []
        elif current is not None:
            out[current].append(line)
    return {k: _trim(v) for k, v in out.items()}


def _trim(lines):
    while lines and not lines[0].strip():
        lines = lines[1:]
    while lines and not lines[-1].strip():
        lines = lines[:-1]
    return lines


def blocks():
    alloc = sections(allocation.tables())
    check, _ = stat_values.class_check()
    income, bands, after = money.income_tables(money.REPAIR_PROPOSED)
    full = full_set_lines()
    return {
        "values": stat_values.value_tables() + [""] + full,
        "classcheck": _trim(check),
        "enchantloot": ["#### Enchant loot per channel (prefix / suffix)", ""] + alloc["Enchant loot per channel"],
        "signatures": alloc["Every signature and its uses"],
        "upgrades": ["#### Upgrade inputs (plus 2 × own material)", ""] + alloc[
            "Upgrade recipes (each also takes 2 × the own material of the tier)"] + [
            "", "#### Own material", ""] + alloc["Own material of the upgrade"],
        "crown": money.sinks(bands, after),
        "alchemy": alchemy.tables(),
        "sale": money.sale_table(),
        "upgradecost": money.upgrade_costs(bands),
        "income": income,
    }


def full_set_lines():
    """The +50-60 % ceiling check: a level-60 character's whole set."""
    import models as M
    rows = ["### A full set at level 60", "",
            "| Item level | Warrior, damage set | Scout, damage set | Mage, damage set "
            "(short fight / mana-bound) | Warrior, 5 × HP |", "|---:|---:|---:|---:|---:|"]
    for ilvl, tier in ((60, 6), (65, 7), (70, 7)):
        v = lambda s: stat_values.enchant_value(s, ilvl, tier)
        warrior = M.warrior_dps(60, ilvl, {"str": 8 * v("str"), "crit_percent": 2 * v("crit_percent"),
                                           "attack_speed_percent": v("attack_speed_percent")}) / M.warrior_dps(60, 60)
        scout = M.scout_dps(60, ilvl, {"dex": 8 * v("dex"), "crit_percent": v("crit_percent"),
                                       "attack_speed_percent": v("attack_speed_percent")}) / M.scout_dps(60, 60)
        short = M.mage_damage(60, ilvl, {"int": 8 * v("int"), "crit_percent": 2 * v("crit_percent")}) / M.mage_damage(60, 60)
        bound = M.mage_damage(60, ilvl, {"int": 8 * v("int"), "crit_percent": 2 * v("crit_percent"),
                                         "max_mana_percent": 6 * v("max_mana_percent")}) / M.mage_damage(60, 60)
        hp = M.ehp("warrior", 60, ilvl, {"max_hp_percent": 5 * v("max_hp_percent")}) / M.ehp("warrior", 60, 60)
        rows.append("| %d | %+.0f %% | %+.0f %% | %+.0f %% / %+.0f %% | %+.0f %% |" % (
            ilvl, 100 * (warrior - 1), 100 * (scout - 1), 100 * (short - 1), 100 * (bound - 1), 100 * (hp - 1)))
    rows += ["", "Damage sets: an attribute on every one of the eight items, Crit up to the "
             "cap (two for Warrior and Mage, one for the Scout), Attack speed on the weapon; "
             "the Mage's remaining six channels Mana. Against the same character in plain "
             "item-level-60 gear (Appendix A)."]
    return rows


def render(text):
    data = blocks()
    pattern = re.compile(r"(<!-- generated: (\w+) -->\n)(.*?)(<!-- end generated -->)", re.S)

    def fill(match):
        name = match.group(2)
        if name not in data:
            raise SystemExit("unknown generated block " + name)
        return match.group(1) + "\n".join(data[name]) + "\n" + match.group(4)

    return pattern.sub(fill, text)


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args(argv)
    text = DOC.read_text(encoding="utf-8")
    new = render(text)
    if args.check:
        stale = new != text
        print("R33 DS DOC %s" % ("STALE (run build_doc.py)" if stale else "CURRENT"))
        return 1 if stale else 0
    DOC.write_text(new, encoding="utf-8")
    print("wrote %s" % DOC.relative_to(C.REPO))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
