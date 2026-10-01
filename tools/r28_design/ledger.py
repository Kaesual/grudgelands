#!/usr/bin/env python3
"""Round 28 leveling ledger: how much of each level band a route's quests cover.

Reads the zone quest and spawn files of a design (frame section 4.6/4.7) and
the catalogues, walks a stated route (a list of zones) quest by quest with a
simulated player, and reports real XP (never summed KE) per band and per zone:

  * quest rewards      weight x M(quest level), rounded; --human adds 10 %
  * quest kills        kill objectives, count x M(min(mob level, player + 5))
                       at the simulated player level (gray rule, tier mult.)
  * drop kills         kills behind item objectives for mob drops: quest-only
                       drops (catalog quest_drops) and family drops
                       (catalog/drops.json bands, else today's entity drops);
                       drops from earlier quest kills are used first
  * gathering          ore/gem/fish units behind item objectives (bars and
                       alloys resolve to their ores)

against the XP needed to cross the band (XP(L->L+1) = round(M(L) k(L), tens)),
for a solo player and a two-player party (kill XP is split, quest credit is
not), and flags shares outside the frame's targets (questing ~90 % / rewards
~40 % in 1->10; ~80 % / ~40 % in 10->40; ~70 % / ~35 % in 40->60).

Usage:
  ledger.py --route zone_a,zone_b[:lo-hi],... [--design DIR] [--existing FILE]
            [--start-level N] [--human] [--party solo|duo|both]
            [--repeat N] [--skip-optional] [--solo-group] [--tolerance PCT]
            [--out FILE] [--strict] [--atlas DIR]
  Exit code 0 (flags are rough guides, Ruling 33); --strict exits 1 when a
  band is flagged; 2 when design files cannot be read.
  ledger.py --self-test
"""
import argparse
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import r28common as C  # noqa: E402


class Route:
    def __init__(self, spec, atlas=None):
        self.atlas = atlas
        self.zones = []
        self.bands = {}
        for part in [p.strip() for p in spec.split(",") if p.strip()]:
            if ":" in part:
                zone, band = part.split(":", 1)
                lo, hi = band.split("-", 1)
                self.bands[zone] = (int(lo), int(hi))
            else:
                zone = part
            self.zones.append(zone)


class Ledger:
    def __init__(self, design, existing, human=False, participants=1, repeat=0,
                 skip_optional=False, include_group=False, start_level=1):
        self.design = design
        self.existing = existing or {}
        self.human = human
        self.participants = participants
        self.repeat = repeat
        self.skip_optional = skip_optional
        self.include_group = include_group
        self.xp = float(C.CUMULATIVE[start_level])
        self.subtypes = design.subtype_map()
        self.catalog_items = design.item_map()
        self.drop_tables = design.drop_map()
        self.reagents = {row.get("id"): row for row in design.reagents or [] if isinstance(row, dict)}
        self.inventory = defaultdict(float)
        self.warnings = []
        self.kill_rows = []
        self.zone_rows = []
        self.done = set()

    # -- helpers --------------------------------------------------------
    @property
    def level(self):
        return C.level_of(int(self.xp))

    def warn(self, text):
        if text not in self.warnings:
            self.warnings.append(text)

    def role_tier(self, role):
        sub = self.subtypes.get(role)
        return (sub or {}).get("tier", "normal")

    def role_levels(self, role, zone, area_ref=None, own_zone=None):
        if area_ref:
            azone, aid = C.split_area_ref(area_ref, own_zone or zone)
            area = self.design.areas(azone).get(aid)
            if area and area.get("levels"):
                return tuple(area["levels"])
            self.warn("area %s not found; using role levels" % area_ref)
        # Areas of the zone that host the role.
        ranges = [tuple(a["levels"]) for a in self.design.areas(zone).values()
                  if a.get("levels") and any(s.get("role") == role for s in a.get("species") or [])]
        if ranges:
            return (min(r[0] for r in ranges), max(r[1] for r in ranges))
        sub = self.subtypes.get(role)
        if sub and sub.get("levels"):
            return tuple(sub["levels"])
        return None

    def family_rows(self, role, level_range):
        """Expected drops per kill of a role: {item: expected count}."""
        sub = self.subtypes.get(role)
        out = {}
        family = (sub or {}).get("drops")
        table = self.drop_tables.get(family) if family else None
        if table:
            mid = (level_range[0] + level_range[1]) // 2
            band = str(min(6, (max(1, mid) - 1) // 10 + 1))
            for row in (table.get("bands") or {}).get(band) or []:
                lo, hi = row.get("min", 1), row.get("max", 1)
                out[row["item"]] = out.get(row["item"], 0) + (lo + hi) / 2 / max(1, row.get("chance", 1))
            return out
        entity = (self.existing.get("entities") or {}).get("grug_mobs:" + role)
        if entity:
            for row in entity.get("drops") or []:
                lo, hi = row.get("min", 1), row.get("max", 1)
                out[row["item"]] = out.get(row["item"], 0) + (lo + hi) / 2 / max(1, row.get("chance", 1))
        return out

    def add_kills(self, count, role, level_range, acc, key):
        """`count` kills by this player's party; returns XP for this player.
        Expected drops go into this player's inventory (split in a party)."""
        tier = self.role_tier(role)
        drops = self.family_rows(role, level_range)
        total = 0.0
        whole = int(count)
        for i in range(whole + (1 if count > whole else 0)):
            share = 1.0 if i < whole else count - whole
            gained = C.expected_kill_xp(level_range, self.level, tier, self.participants) * share
            self.xp += gained
            total += gained
            for item, amount in drops.items():
                self.inventory[item] += amount * share / self.participants
        acc[key] += total
        return total

    def gather_units(self, item, depth=0):
        """[(kind, tier, quantity)] of gathering behind one unit of item."""
        if depth > 6:
            return []
        entry = (self.existing.get("items") or {}).get(item) or {}
        gathering = entry.get("gathering")
        if gathering and gathering.get("kind") in C.GATHER_RATIO:
            return [(gathering["kind"], gathering.get("tier") or 1, 1.0)]
        inputs = None
        per = 1.0
        if entry.get("alloy_inputs"):
            inputs = entry["alloy_inputs"]
        elif entry.get("furnace_inputs"):
            inputs = entry["furnace_inputs"][0]
        elif item in self.reagents:
            inputs = self.reagents[item].get("inputs") or []
            per = 1.0 / max(1, self.reagents[item].get("output_count", 1))
        out = []
        for source in inputs or []:
            for kind, tier, qty in self.gather_units(source, depth + 1):
                out.append((kind, tier, qty * per))
        return out

    def drop_source(self, item, zone):
        """Best (role, level range, yield per kill) in the zone's areas."""
        best = None
        for area in self.design.areas(zone).values():
            if not area.get("levels"):
                continue
            for species in area.get("species") or []:
                role = species.get("role")
                yield_ = self.family_rows(role, tuple(area["levels"])).get(item, 0)
                if yield_ > 0 and (best is None or yield_ > best[2]):
                    best = (role, tuple(area["levels"]), yield_)
        return best

    # -- quests ---------------------------------------------------------
    def ordered(self, zone, quests):
        by_id = {q.get("id"): q for q in quests}
        index = {q.get("id"): i for i, q in enumerate(quests)}
        pending = dict(by_id)
        out = []
        while pending:
            ready = [q for qid, q in pending.items()
                     if all(r in self.done or r not in by_id or r in [o.get("id") for o in out]
                            for r in q.get("requires") or [])]
            if not ready:
                self.warn("%s: prerequisite cycle or unreachable quests: %s" % (zone, ", ".join(sorted(pending))))
                ready = list(pending.values())
            ready.sort(key=lambda q: (q.get("min_level", 1), q.get("level", 1), index[q.get("id")]))
            pick = ready[0]
            out.append(pick)
            del pending[pick.get("id")]
        return out

    def run_zone(self, zone, band):
        data = self.design.quests.get(zone)
        acc = defaultdict(float)
        row = {"zone": zone, "band": band, "entry": self.level, "quests": 0}
        if data is None:
            self.warn("%s: no quests file in the design" % zone)
            row.update(exit=self.level, acc=acc)
            self.zone_rows.append(row)
            return acc
        quests = [q for q in data.get("quests") or [] if isinstance(q, dict)]
        one_time = [q for q in quests if not q.get("repeatable")]
        repeatables = [q for q in quests if q.get("repeatable")]
        plan = self.ordered(zone, one_time)
        for q in repeatables:
            plan.extend([q] * self.repeat)
        for q in plan:
            if self.skip_optional and q.get("optional"):
                continue
            if q.get("group") and self.participants == 1 and not self.include_group:
                continue
            for req in q.get("requires") or []:
                if req not in self.done and req not in {o.get("id") for o in quests}:
                    self.warn("%s requires %s, which is not on the route (assumed done)" % (q.get("id"), req))
            self.run_quest(zone, q, acc)
            self.done.add(q.get("id"))
            row["quests"] += 1
        row.update(exit=self.level, acc=acc)
        self.zone_rows.append(row)
        return acc

    def run_quest(self, zone, q, acc):
        qid = q.get("id")
        min_level = q.get("min_level", 1)
        if self.level < min_level:
            need = C.CUMULATIVE[min_level] - self.xp
            self.xp += need
            acc["grind"] += need
            self.warn("%s: player is level %d at min_level %d; %.0f XP of free play first"
                      % (qid, C.level_of(int(self.xp - need)), min_level, need))
        acc["minutes"] += q.get("duration_min") or 0
        quest_drops = {d.get("item"): d for d in q.get("quest_drops") or [] if isinstance(d, dict)}
        for obj in q.get("objectives") or []:
            kind = obj.get("type")
            count = obj.get("count", 1)
            if kind == "kill":
                roles = obj.get("roles") or ([obj["role"]] if obj.get("role") else [])
                role = roles[0] if roles else None
                levels = self.role_levels(role, zone, obj.get("area"), zone) if role else None
                if not levels:
                    self.warn("%s: no level range for kill target %s; using quest level" % (qid, role))
                    levels = (q.get("level", 1), q.get("level", 1))
                start = self.level
                gained = self.add_kills(count, role, levels, acc, "kills")
                self.kill_rows.append({
                    "quest": qid, "zone": zone, "area": obj.get("area") or "(anywhere)",
                    "count": count, "roles": roles, "levels": levels, "player": start,
                    "xp": gained, "species": self.species_mix(zone, obj.get("area"))})
            elif kind == "item":
                self.item_objective(zone, q, obj, count, quest_drops, acc)
        rewards = q.get("rewards") or {}
        if rewards.get("weight") is None and ("xp" in rewards or "xp" in q):
            # Legacy quest from B4's mechanical split: a fixed XP number.
            xp = rewards.get("xp", q.get("xp")) or 0
            if self.human:
                xp = C.round_half_up(xp * C.HUMAN_QUEST_BONUS)
        else:
            xp = C.quest_xp(rewards.get("weight") or 0, q.get("level", 1), self.human)
        self.xp += xp
        acc["rewards"] += xp

    def species_mix(self, zone, area_ref):
        if not area_ref:
            return ""
        azone, aid = C.split_area_ref(area_ref, zone)
        area = self.design.areas(azone).get(aid) or {}
        return ", ".join("%s %s" % (s.get("role"), s.get("weight")) for s in area.get("species") or [])

    def item_objective(self, zone, q, obj, count, quest_drops, acc):
        qid = q.get("id")
        item = obj.get("item")
        if item and item in quest_drops:
            drop = quest_drops[item]
            roles = drop.get("roles") or []
            role = roles[0] if roles else None
            levels = self.role_levels(role, zone, drop.get("area"), zone) if role else None
            if not levels:
                self.warn("%s: quest drop %s has no level range" % (qid, item))
                return
            # Rolled per eligible participant: a party shares the kills.
            kills = count * max(1, drop.get("chance", 1))
            self.add_kills(kills, role, levels, acc, "drop_kills")
            return
        if obj.get("group"):
            members = ((self.existing.get("groups") or {}).get(obj["group"]) or {}).get("members") or []
            options = [m for m in members if self.gather_units(m)]
            if options:
                item = min(options, key=lambda m: min(t for _, t, _ in self.gather_units(m)))
            else:
                return
        units = self.gather_units(item)
        if units:
            gained = 0
            for kind, tier, qty in units:
                for _ in range(int(round(qty * count))):
                    xp = C.gathering_xp(kind, tier, self.level)
                    self.xp += xp
                    gained += xp
            acc["gathering"] += gained
            return
        have = min(self.inventory.get(item, 0.0), count)
        self.inventory[item] -= have
        missing = count - have
        if missing <= 0:
            return
        source = self.drop_source(item, zone)
        if source is None:
            entry = (self.existing.get("items") or {}).get(item) or self.catalog_items.get(item)
            if entry is None:
                self.warn("%s: item %s is unknown" % (qid, item))
            return  # crafted, bought or gathered without XP
        role, levels, per_kill = source
        # Ordinary drops go to one player: each party member needs their own,
        # so per player the XP equals a solo player's.
        kills = missing / per_kill
        gained = 0.0
        tier = self.role_tier(role)
        drops = self.family_rows(role, levels)
        whole = int(kills)
        for i in range(whole + (1 if kills > whole else 0)):
            share = 1.0 if i < whole else kills - whole
            xp = C.expected_kill_xp(levels, self.level, tier, 1) * share
            self.xp += xp
            gained += xp
            for other, amount in drops.items():
                if other != item:
                    self.inventory[other] += amount * share
        acc["drop_kills"] += gained


def zone_band(route, design, zone):
    if zone in route.bands:
        return route.bands[zone]
    info = route.atlas.zones.get(zone) if route.atlas else None
    if info and info.get("levels"):
        band = C.band_of_level(info["levels"][0])
        return (band[0], band[1])
    data = design.quests.get(zone) or {}
    levels = sorted(q.get("level", 1) for q in data.get("quests") or [] if isinstance(q, dict)
                    and not q.get("repeatable"))
    if not levels:
        return None
    band = C.band_of_level(levels[len(levels) // 2])
    return (band[0], band[1])


def run(design, existing, route, participants, args):
    ledger = Ledger(design, existing, human=args.human, participants=participants,
                    repeat=args.repeat, skip_optional=args.skip_optional,
                    include_group=args.solo_group, start_level=args.start_level)
    per_band = defaultdict(lambda: defaultdict(float))
    for zone in route.zones:
        band = zone_band(route, design, zone)
        acc = ledger.run_zone(zone, band)
        if band:
            for key, value in acc.items():
                per_band[band][key] += value
    return ledger, per_band


def pct(x):
    return "%d %%" % round(100 * x)


def target_for(band):
    for row in C.BANDS:
        if (row[0], row[1]) == tuple(band):
            return row[2], row[3]
    return C.band_of_level(band[0])[2:4]


def report(design, existing, route, args):
    out = []
    flags_total = 0
    parties = {"solo": [1], "duo": [2], "both": [1, 2]}[args.party]
    out.append("# Leveling ledger: %s" % " → ".join(route.zones))
    out.append("")
    out.append("Generated by `tools/r28_design/ledger.py` (design `%s`). Real XP, not KE. "
               "Start level %d%s; repeatables counted %d×; tolerance ±%d points."
               % (args.design, args.start_level, ", human +10 % quest XP" if args.human else "",
                  args.repeat, args.tolerance))
    out.append("")
    for participants in parties:
        ledger, per_band = run(design, existing, route, participants, args)
        label = "Solo" if participants == 1 else "Two-player party"
        out.append("## %s" % label)
        out.append("")
        out.append("| Band | XP needed (KE) | Rewards | Quest kills | Drop kills | Gathering | Questing | "
                   "Questing share (target) | Reward share (target) | Free play | Flags |")
        out.append("|---|---|---|---|---|---|---|---|---|---|---|")
        for band in sorted(per_band):
            acc = per_band[band]
            need = C.xp_between(band[0], band[1])
            questing = acc["rewards"] + acc["kills"] + acc["drop_kills"] + acc["gathering"]
            share, rshare = questing / need, acc["rewards"] / need
            target, rtarget = target_for(band)
            tol = args.tolerance / 100.0
            flags = []
            if share > target + tol:
                flags.append("OVERSHOOT questing")
            elif share < target - tol:
                flags.append("UNDERSHOOT questing")
            if rshare > rtarget + tol:
                flags.append("OVERSHOOT rewards")
            elif rshare < rtarget - tol:
                flags.append("UNDERSHOOT rewards")
            flags_total += len(flags)
            out.append("| %d → %d | %d (%.0f) | %d | %d | %d | %d | %d | %s (%s) | %s (%s) | %d | %s |" % (
                band[0], band[1], need, C.ke_between(band[0], band[1]), acc["rewards"], acc["kills"],
                acc["drop_kills"], acc["gathering"], questing, pct(share), pct(target), pct(rshare),
                pct(rtarget), max(0, need - questing), ", ".join(flags) or "ok"))
        out.append("")
        out.append("| Zone | Band | Quests | Level in | Level out | Rewards | Quest kills | Drop kills | "
                   "Gathering | Free play before quests | Minutes (duration_min) |")
        out.append("|---|---|---|---|---|---|---|---|---|---|---|")
        for row in ledger.zone_rows:
            acc = row["acc"]
            band = "%d → %d" % row["band"] if row["band"] else "?"
            out.append("| %s | %s | %d | %d | %d | %d | %d | %d | %d | %d | %d |" % (
                row["zone"], band, row["quests"], row["entry"], row["exit"], acc["rewards"],
                acc["kills"], acc["drop_kills"], acc["gathering"], acc["grind"], acc["minutes"]))
        out.append("")
        if participants == parties[0]:
            out.append("### Kill quests")
            out.append("")
            out.append("| Quest | Area | Count | Targets | Area species (weight) | Mob levels | Player level | XP per player |")
            out.append("|---|---|---|---|---|---|---|---|")
            for k in ledger.kill_rows:
                out.append("| %s | %s | %s | %s | %s | %d–%d | %d | %d |" % (
                    k["quest"], k["area"], k["count"], ", ".join(k["roles"]), k["species"],
                    k["levels"][0], k["levels"][1], k["player"], k["xp"]))
            out.append("")
        if ledger.warnings:
            out.append("### Notes (%s)" % label.lower())
            out.append("")
            for w in ledger.warnings:
                out.append("- " + w)
            out.append("")
    return "\n".join(out), flags_total


def parse(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--route", help="comma-separated zone ids in play order; zone:lo-hi pins its band")
    ap.add_argument("--design", default=str(C.DEFAULT_DESIGN))
    ap.add_argument("--existing", default=str(C.DEFAULT_EXISTING))
    ap.add_argument("--atlas", help="zone atlas directory: zone bands from the atlas level ranges")
    ap.add_argument("--start-level", type=int, default=1)
    ap.add_argument("--human", action="store_true", help="+10 %% quest XP (Human race perk)")
    ap.add_argument("--party", choices=("solo", "duo", "both"), default="both")
    ap.add_argument("--repeat", type=int, default=0, help="count each repeatable quest N times")
    ap.add_argument("--skip-optional", action="store_true")
    ap.add_argument("--solo-group", action="store_true", help="solo player also does group quests")
    ap.add_argument("--tolerance", type=int, default=10, help="flag shares more than PCT points off target")
    ap.add_argument("--out", help="also write the report to this file")
    ap.add_argument("--strict", action="store_true", help="exit 1 when a band is flagged")
    ap.add_argument("--self-test", action="store_true")
    return ap.parse_args(argv)


def main(argv):
    args = parse(argv)
    if args.self_test:
        return self_test()
    if not args.route:
        print("ledger.py: --route is required (see --help)", file=sys.stderr)
        return 2
    design = C.Design(args.design)
    for err in design.errors:
        print("error: " + err, file=sys.stderr)
    if design.errors:
        return 2
    try:
        existing = C.load_existing(args.existing)
    except C.LoadError as err:
        print("warning: %s; gathering and existing drops are unknown" % err, file=sys.stderr)
        existing = {}
    atlas = None
    if args.atlas:
        try:
            atlas = C.Atlas(args.atlas)
        except C.LoadError as err:
            print("error: %s" % err, file=sys.stderr)
            return 2
        for zone in Route(args.route).zones:
            if zone not in atlas.zones:
                print("warning: %s is not an atlas zone" % zone, file=sys.stderr)
    text, flags = report(design, existing, Route(args.route, atlas), args)
    print(text)
    if args.out:
        Path(args.out).write_text(text + "\n", encoding="utf-8")
    return 1 if flags and args.strict else 0


# --- self-test ----------------------------------------------------------------

def self_test():
    here = Path(__file__).resolve().parent
    sample = here / "samples" / "valid"
    failures = []

    def check(cond, msg):
        if not cond:
            failures.append(msg)

    # Formulas against the plan's published numbers.
    check(C.level_xp(1) == 240, "XP(1->2) = 240")
    check(C.CUMULATIVE[10] == 4200, "XP to level 10 = 4200 (plan: 4.2k)")
    check(abs(C.CUMULATIVE[60] - 194000) < 1000, "XP to level 60 about 194k")
    check(round(C.ke_between(1, 10)) == 82, "82 KE to level 10")
    check(round(C.ke_between(1, 60)) == 968, "968 KE to level 60")
    check(C.quest_xp(4, 6) == 220, "weight 4 at level 6 = 220 XP (frame example)")
    check(C.quest_xp(4, 6, human=True) == 242, "human +10 %")
    check(C.kill_xp(3, 1) == 40 and C.kill_xp(9, 1) == 55, "kill XP caps at player + 5")
    check(C.kill_xp(1, 11) == 0, "gray rule: 10 below gives 0")
    check(C.kill_xp(5, 5, participants=2) == 25, "party split floors")
    check(C.kill_xp(5, 5, tier="elite") == 200, "elite x4")
    check(C.gathering_xp("ore", 1, 1) == 6, "T1 ore at level 1: 0.1 x M(6) = 6")

    design = C.Design(sample)
    check(not design.errors, "sample loads: %s" % design.errors)
    existing = C.load_existing(here / "samples" / "existing_min.json")

    class A:  # argparse stand-in
        pass
    args = A()
    args.design, args.start_level, args.human, args.repeat = str(sample), 1, False, 0
    args.skip_optional, args.solo_group, args.tolerance, args.party = False, False, 10, "both"
    solo, _ = run(design, existing, Route("elandor_dawnmere_fields:1-10"), 1, args)
    duo, _ = run(design, existing, Route("elandor_dawnmere_fields:1-10"), 2, args)
    sacc, dacc = solo.zone_rows[0]["acc"], duo.zone_rows[0]["acc"]
    check(sacc["rewards"] == dacc["rewards"] and sacc["rewards"] > 0, "quest credit is not split")
    check(abs(dacc["kills"] - sacc["kills"] / 2) < sacc["kills"] * 0.15,
          "duo kill-quest XP about half of solo (%.0f vs %.0f)" % (dacc["kills"], sacc["kills"]))
    check(sacc["gathering"] > 0 and sacc["gathering"] == dacc["gathering"], "gathering is per player")
    check(sacc["drop_kills"] > 0, "drop requests cost kills")
    # Expected meat from the boar quest covers part of the meat request: the
    # request alone at 1 meat per kill would be 5 kills.
    check(any(k["quest"] == "sample_hunt_01" and k["count"] == 8 for k in solo.kill_rows),
          "kill rows list the hunt quest")
    text, flags = report(design, existing, Route("elandor_dawnmere_fields:1-10"), args)
    check("Solo" in text and "Two-player party" in text and "1 → 10" in text, "report renders")
    atlas = C.Atlas(here / "samples" / "atlas")
    routed = Route("elandor_dawnmere_fields,elandor_goldmead_vale,elandor_highcourt,front_shattered_line", atlas)
    check([zone_band(routed, design, z) for z in routed.zones] == [(1, 10), (10, 20), (20, 30), (40, 50)],
          "atlas level ranges give the bands")
    human = A()
    human.__dict__.update(args.__dict__)
    human.human = True
    hsolo, _ = run(design, existing, Route("elandor_dawnmere_fields:1-10"), 1, human)
    check(hsolo.zone_rows[0]["acc"]["rewards"] > sacc["rewards"], "human option raises rewards")
    if failures:
        for f in failures:
            print("FAIL " + f)
        print("ledger self-test: FAIL (%d)" % len(failures))
        return 1
    print(text)
    print("ledger self-test: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
