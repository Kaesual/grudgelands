#!/usr/bin/env python3
"""Round 28 leveling ledger: how much of each level band a route's quests cover.

Reads the zone quest and spawn files of a design (frame section 4.6/4.7) and
the catalogues, walks a stated route (a list of zones) quest by quest with a
simulated player, and reports real XP (never summed KE) per band and per zone:

  * quest rewards      weight x M(quest level), rounded; --human adds 10 %
  * quest kills        kill objectives, count x M(min(mob level, player + 5))
                       at the simulated player level (gray rule, tier mult.);
                       a kill area is a kind or camp of the zone's spawn
                       recipe, where a role is met at its own levels (the
                       belt's levels within the role's catalogue levels)
  * drop kills         kills behind item objectives for mob drops: quest-only
                       drops (catalog quest_drops) and family drops
                       (catalog/drops.json bands of the drop family: a sub-type's
                       `drops`, else an existing mob's role; else today's entity drops);
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
            [--repeat N] [--skip-optional] [--solo-group] [--tolerance PCT] [--lines a,b]
            [--out FILE] [--strict] [--atlas DIR]
  Exit code 0 (flags are rough guides, Ruling 33); --strict exits 1 when a
  band is flagged; 2 when design files cannot be read.
  ledger.py --self-test
"""
import argparse
import json
import shutil
import sys
import tempfile
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import r28common as C  # noqa: E402


class Route:
    """The zones in play order: a --route spec ("zone_a,zone_b:lo-hi"), or
    `entries` [(zone, lines, levels, label)] of r28common.track_route (lines
    None = every line but `front`; levels = a host's front quests of one
    band only)."""

    def __init__(self, spec="", atlas=None, entries=None):
        self.atlas = atlas
        self.zones = []
        self.bands = {}
        self.entries = list(entries or [])
        for part in [p.strip() for p in spec.split(",") if p.strip()]:
            if ":" in part:
                zone, band = part.split(":", 1)
                lo, hi = band.split("-", 1)
                self.bands[zone] = (int(lo), int(hi))
            else:
                zone = part
            self.entries.append((zone, None, None, None))
        self.zones = [entry[0] for entry in self.entries]


class Ledger:
    def __init__(self, design, existing, human=False, participants=1, repeat=0,
                 skip_optional=False, include_group=False, start_level=1, lines=None):
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
        self.inventory = defaultdict(float)
        self.warnings = []
        self.kill_rows = []
        self.zone_rows = []
        self.done = set()
        self.lines = set(lines) if lines else None
        self.per_band = defaultdict(lambda: defaultdict(float))
        # (route entry label, band) -> acc: the 20-30 split own zones/sister.
        self.zone_band_acc = defaultdict(lambda: defaultdict(float))

    # -- helpers --------------------------------------------------------
    @property
    def level(self):
        return C.level_of(int(self.xp))

    def warn(self, text):
        if text not in self.warnings:
            self.warnings.append(text)

    def role_tier(self, role, area=None):
        # A PvP garrison's tiers are its own (Round 31, read from G.slot).
        if area and role in (area.get("tiers_by_role") or {}):
            return area["tiers_by_role"][role]
        sub = self.subtypes.get(role)
        return (sub or {}).get("tier", "normal")

    def quest_area(self, area_ref, zone):
        """The kind, camp or PvP garrison an objective names, or None."""
        if not area_ref:
            return None
        azone, aid = C.split_area_ref(area_ref, zone)
        return self.design.quest_areas(azone).get(aid)

    def role_levels(self, role, zone, area_ref=None, own_zone=None):
        # A named leader (this zone first, else any zone: leader roles are
        # unique fixed spots) is met at its fixed level.
        target_zone = C.split_area_ref(area_ref, own_zone or zone)[0] if area_ref else zone
        found = self.design.find_leader(role, target_zone)
        if found and isinstance(found[1].get("level"), int):
            return (found[1]["level"], found[1]["level"])
        # Areas are the recipe's kinds and camps; a role is met there at its
        # own levels (the belt's levels within the role's).
        if area_ref:
            area = self.quest_area(area_ref, own_zone or zone)
            if area and area["levels_by_role"].get(role):
                return tuple(area["levels_by_role"][role])
            if area and area.get("levels"):
                return tuple(area["levels"])
            self.warn("area %s not found; using role levels" % area_ref)
        # Kinds and camps of the zone that host the role.
        ranges = [tuple(a["levels_by_role"][role]) for a in self.design.areas(zone).values()
                  if role in a["levels_by_role"]]
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
        # The game's rule (grug_mobs/subtypes.lua band_drop_rows): a sub-type's
        # drop family, else the existing mob's own role; rows of the band replace
        # the static drops, a family or band without rows keeps them.
        family = (sub or {}).get("drops") or role
        table = self.drop_tables.get(family) if family else None
        mid = (level_range[0] + level_range[1]) // 2
        band = str(min(6, (max(1, mid) - 1) // 10 + 1))
        rows = (table.get("bands") or {}).get(band) if table else None
        if rows:
            for row in rows:
                lo, hi = row.get("min", 1), row.get("max", 1)
                out[row["item"]] = out.get(row["item"], 0) + (lo + hi) / 2 / max(1, row.get("chance", 1))
            return out
        # Static fallback: an existing mob's own drops; a sub-type's are its
        # base entity's (the game copies the base definition).
        base = (sub or {}).get("base") or ("grug_mobs:" + role)
        entity = (self.existing.get("entities") or {}).get(base)
        if entity:
            for row in entity.get("drops") or []:
                lo, hi = row.get("min", 1), row.get("max", 1)
                out[row["item"]] = out.get(row["item"], 0) + (lo + hi) / 2 / max(1, row.get("chance", 1))
        return out

    def add_kills(self, count, role, level_range, acc, key, area=None):
        """`count` kills by this player's party; returns XP for this player.
        Expected drops go into this player's inventory (split in a party)."""
        tier = self.role_tier(role, area)
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
        if entry.get("alloy_inputs"):
            inputs = entry["alloy_inputs"]
        elif entry.get("furnace_inputs"):
            inputs = entry["furnace_inputs"][0]
        out = []
        for source in inputs or []:
            for kind, tier, qty in self.gather_units(source, depth + 1):
                out.append((kind, tier, qty))
        return out

    def drop_source(self, item, zone):
        """Best (role, level range, yield per kill) in the zone's kinds and
        camps."""
        best = None
        for area in self.design.areas(zone).values():
            for role, levels in sorted(area["levels_by_role"].items()):
                yield_ = self.family_rows(role, tuple(levels)).get(item, 0)
                if yield_ > 0 and (best is None or yield_ > best[2]):
                    best = (role, tuple(levels), yield_)
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

    def quest_band(self, zone, q):
        """A quest counts in the band of its reward level (front quests in
        contested or capital files count in the front bands). A pinned
        `zone:lo-hi` only labels the zone row."""
        band = C.band_of_level(q.get("level", 1) if isinstance(q.get("level"), int) else 1)
        return (band[0], band[1])

    def run_zone(self, zone, band, lines=None, levels=None, label=None):
        """One route entry: the zone's quests (`lines` overrides --lines;
        `levels` keeps only quests whose reward level lies in that band)."""
        acc = defaultdict(float)
        row = {"zone": zone + (" (%s)" % label if label else ""), "band": band, "entry": self.level,
               "quests": 0, "label": label}
        if zone not in self.design.quests and zone not in self.design.front:
            self.warn("%s: no quests file in the design" % zone)
            row.update(exit=self.level, acc=acc)
            self.zone_rows.append(row)
            return acc
        lines = set(lines) if lines else self.lines
        quests = self.design.zone_quests(zone, lines)
        if not lines or "front" not in lines:
            # Front quests (front files, line `front`) belong to the front
            # ledger; a race or contested route counts them only when
            # --lines names `front`.
            quests = [q for q in quests if q.get("line") != "front"]
        if levels:
            quests = [q for q in quests if levels[0] <= (q.get("level") or 1) <= levels[1]]
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
            qacc = defaultdict(float)
            self.run_quest(zone, q, qacc)
            for key, value in qacc.items():
                acc[key] += value
                self.per_band[self.quest_band(zone, q)][key] += value
                self.zone_band_acc[(label, self.quest_band(zone, q))][key] += value
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
                roles = obj.get("roles") or []
                role = roles[0] if roles else None
                levels = self.role_levels(role, zone, obj.get("area"), zone) if role else None
                if not levels:
                    self.warn("%s: no level range for kill target %s; using quest level" % (qid, role))
                    levels = (q.get("level", 1), q.get("level", 1))
                start = self.level
                gained = self.add_kills(count, role, levels, acc, "kills", self.quest_area(obj.get("area"), zone))
                self.kill_rows.append({
                    "quest": qid, "zone": zone, "area": obj.get("area") or "(anywhere)",
                    "count": count, "roles": roles, "levels": levels, "player": start,
                    "xp": gained, "species": self.species_mix(zone, obj.get("area"))})
            elif kind == "item":
                self.item_objective(zone, q, obj, count, quest_drops, acc)
        rewards = q.get("rewards") or {}
        xp = C.quest_xp(rewards.get("weight") or 0, q.get("level", 1), self.human)
        self.xp += xp
        acc["rewards"] += xp

    def species_mix(self, zone, area_ref):
        if not area_ref:
            return ""
        return C.species_text(self.quest_area(area_ref, zone) or {})

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
        # The objective's source area names the zone it drops in (a front
        # file's quests hunt in another zone than their host's).
        source_zone = C.split_area_ref(obj["area"], zone)[0] if obj.get("area") else zone
        source = self.drop_source(item, source_zone)
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


ZONE_RECORDS = None


def gameplay_band(zone):
    """The zone's level band (r28common.zone_records: the mapgen's zone
    rows), or None."""
    global ZONE_RECORDS
    if ZONE_RECORDS is None:
        ZONE_RECORDS = C.zone_records()
    info = ZONE_RECORDS.get(zone)
    return info["levels"] if info else None


def zone_band(route, design, zone):
    if zone in route.bands:
        return route.bands[zone]
    levels = gameplay_band(zone)
    if levels:
        band = C.band_of_level(levels[0])
        return (band[0], band[1])
    info = route.atlas.zones.get(zone) if route.atlas else None
    if info and info.get("levels"):
        band = C.band_of_level(info["levels"][0])
        return (band[0], band[1])
    levels = sorted(q.get("level", 1) for q in design.zone_quests(zone) if not q.get("repeatable"))
    if not levels:
        return None
    band = C.band_of_level(levels[len(levels) // 2])
    return (band[0], band[1])


def run(design, existing, route, participants, args):
    ledger = Ledger(design, existing, human=args.human, participants=participants,
                    repeat=args.repeat, skip_optional=args.skip_optional,
                    include_group=args.solo_group, start_level=args.start_level,
                    lines=getattr(args, "lines_set", None))
    if any(entry[3] for entry in route.entries):
        # A track route reports every band, also one without quests yet.
        for band in C.BANDS:
            ledger.per_band[(band[0], band[1])]
    for zone, lines, levels, label in route.entries:
        band = tuple(C.band_of_level(levels[0])[:2]) if levels else zone_band(route, design, zone)
        ledger.run_zone(zone, band, lines, levels, label)
    return ledger, ledger.per_band


def pct(x):
    return "%d %%" % round(100 * x)


def target_for(band):
    for row in C.BANDS:
        if (row[0], row[1]) == tuple(band):
            return row[2], row[3]
    return C.band_of_level(band[0])[2:4]


def sister_split(ledger):
    """20 -> 30 on a track route: the share of the band's questing XP from
    the own capital and heartland (target about 60-70 %, the rest from one
    sister zone; round29-quests-plan section 3.1). None off a track."""
    labels = {label for label, _ in ledger.zone_band_acc}
    if "capital" not in labels:
        return None

    def questing(label):
        acc = ledger.zone_band_acc.get((label, (20, 30))) or {}
        return sum(acc.get(k, 0) for k in ("rewards", "kills", "drop_kills", "gathering"))
    own = questing("capital") + questing("heartland")
    sister = questing("sister")
    if own + sister <= 0:
        return None
    return ("20 → 30 questing XP: own capital and heartland %s, sister zone %s (target about 60–70 %% own)."
            % (pct(own / (own + sister)), pct(sister / (own + sister)) if "sister" in labels else "none on this run"))


def report(design, existing, route, args):
    out = []
    flags_total = 0
    parties = {"solo": [1], "duo": [2], "both": [1, 2]}[args.party]
    track = getattr(args, "track", None)
    out.append("# Leveling ledger: %s" % ("%s track (frame section 2.1)" % track if track
                                          else " → ".join(route.zones)))
    out.append("")
    out.append("Generated by `tools/r28_design/ledger.py` (design `%s`). Real XP, not KE. "
               "Start level %d%s; repeatables counted %d×; tolerance ±%d points%s. Quests count in the band "
               "of their reward level." % (args.design, args.start_level,
                                            ", human +10 % quest XP" if args.human else "", args.repeat,
                                            args.tolerance, "; lines: " + ", ".join(args.lines_set)
                                            if getattr(args, "lines_set", None) else ""))
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
            start = max(band[0], min(args.start_level, band[1] - 1))
            need = C.xp_between(start, band[1])
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
                start, band[1], need, C.ke_between(start, band[1]), acc["rewards"], acc["kills"],
                acc["drop_kills"], acc["gathering"], questing, pct(share), pct(target), pct(rshare),
                pct(rtarget), max(0, need - questing), ", ".join(flags) or "ok"))
        out.append("")
        split = sister_split(ledger)
        if split:
            out.append(split)
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
    ap.add_argument("--track", help="a race's whole route 1-60 (start, home, capital and heartland, "
                    "the faction's three contested zones, the 41-50 and 51-60 zones with the faction's "
                    "front quests); human implies --human")
    ap.add_argument("--sister", help="with --track: the sister zone of the faction's 20-30 zones")
    ap.add_argument("--game", action="store_true",
                    help="read the zone files from the game (grug_mobs and grug_quests data/zones)")
    ap.add_argument("--design", default=str(C.DEFAULT_DESIGN))
    ap.add_argument("--existing", default=str(C.DEFAULT_EXISTING))
    ap.add_argument("--atlas", help="zone atlas directory: zone bands from the atlas level ranges")
    ap.add_argument("--start-level", type=int, default=1)
    ap.add_argument("--human", action="store_true", help="+10 %% quest XP (Human race perk)")
    ap.add_argument("--party", choices=("solo", "duo", "both"), default="both")
    ap.add_argument("--repeat", type=int, default=0, help="count each repeatable quest N times")
    ap.add_argument("--skip-optional", action="store_true")
    ap.add_argument("--lines", help="comma-separated quest lines to count (e.g. front); default all")
    ap.add_argument("--solo-group", action="store_true", help="solo player also does group quests")
    ap.add_argument("--tolerance", type=int, default=10, help="flag shares more than PCT points off target")
    ap.add_argument("--out", help="also write the report to this file")
    ap.add_argument("--strict", action="store_true", help="exit 1 when a band is flagged")
    ap.add_argument("--self-test", action="store_true")
    return ap.parse_args(argv)


def main(argv):
    args = parse(argv)
    args.lines_set = [x.strip() for x in args.lines.split(",") if x.strip()] if args.lines else None
    if args.self_test:
        return self_test()
    if bool(args.route) == bool(args.track):
        print("ledger.py: give --route or --track (see --help)", file=sys.stderr)
        return 2
    entries = None
    if args.track:
        try:
            entries = C.track_route(args.track, args.sister)
        except ValueError as err:
            print("ledger.py: %s" % err, file=sys.stderr)
            return 2
        args.human = args.human or args.track == "human"
    design = C.Design(args.design, C.GAME_ZONE_DIRS if args.game else None)
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
    route = Route(args.route or "", atlas, entries)
    if atlas:
        for zone in route.zones:
            if zone not in atlas.zones:
                print("warning: %s is not an atlas zone" % zone, file=sys.stderr)
    text, flags = report(design, existing, route, args)
    print(text)
    if args.out:
        Path(args.out).write_text(text + "\n", encoding="utf-8")
    return 1 if flags and args.strict else 0


# --- self-test ----------------------------------------------------------------

def self_test():
    here = Path(__file__).resolve().parent
    sample = here / "samples" / "valid"
    failures = []
    checks = [0]

    def check(cond, msg):
        checks[0] += 1
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
    args.lines_set = None
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
    # Leaders count at their fixed level; quests in the band of their level.
    check(solo.role_levels("confused_bandit_chief", "elandor_dawnmere_fields") == (10, 10), "leader level")
    check(solo.role_levels("small_boar", "elandor_dawnmere_fields", "elandor_dawnmere_fields/meadows")
          == (3, 3), "a role in a kind is met at the belt's levels within its own (3-5 x 1-3)")
    check(solo.role_levels("small_boar", "elandor_dawnmere_fields") == (1, 3),
          "without an area: the union over the kinds hosting the role")
    check(solo.species_mix("elandor_dawnmere_fields", "elandor_dawnmere_fields/meadows")
          == "day: small_boar 4, boar 1; night: braindead_zombie 1", "species mix per clock")
    check(solo.species_mix("elandor_dawnmere_fields", "elandor_dawnmere_fields/border_bandits")
          == "confused_bandit 1", "a camp's species mix")
    check("confused_bandit_chief" in solo.subtypes and "grug_mobs:crop_ledger" in solo.catalog_items,
          "zone catalogue roles and items merge into the catalogue")
    check(solo.role_levels("confused_bandit_chief", "elandor_goldmead_vale") == (10, 10),
          "a leader of another zone keeps its fixed level")
    # An item objective's source area in another zone than the quest's host
    # (a front file): its drop kills are found there (Highcourt has no recipe).
    fresh, _ = run(design, existing, Route("elandor_dawnmere_fields:1-10"), 1, args)
    drop_acc = defaultdict(float)
    fresh.item_objective("elandor_highcourt", {"id": "sample_front_tails", "level": 2},
                         {"type": "item", "item": "grug_mobs:rat_tail", "count": 40, "roles": ["large_rat"],
                          "area": "elandor_dawnmere_fields/home_fields"}, 40, {}, drop_acc)
    check(drop_acc["drop_kills"] > 0, "drop kills in the source area's zone, not the host's (%.0f XP)"
          % drop_acc["drop_kills"])
    check(set(solo.per_band) == {(1, 10), (10, 20)}, "the level-10 quests count in 10 -> 20 (%s)"
          % sorted(solo.per_band))
    lined = A()
    lined.__dict__.update(args.__dict__)
    lined.lines_set = ["hunt"]
    hunt, _ = run(design, existing, Route("elandor_dawnmere_fields"), 1, lined)
    check(hunt.zone_rows[0]["quests"] == 4, "--lines hunt keeps the four hunt quests")
    # Front quests count only when --lines names `front`.
    tmp = Path(tempfile.mkdtemp(prefix="r28_ledger_"))
    try:
        shutil.copytree(sample, tmp / "design")
        front_quest = {"id": "sample_front_01", "line": "front", "giver": "r20_human_start_cook",
                       "turnin": "r20_human_start_cook", "min_level": 1, "level": 1, "requires": [],
                       "title": "Front", "text": "Front. Quest.", "objectives": [],
                       "rewards": {"weight": 1}}
        (tmp / "design" / "zones" / "elandor_dawnmere_fields.front.quests.json").write_text(
            json.dumps({"zone": "elandor_dawnmere_fields", "quests": [front_quest]}))
        fdesign = C.Design(tmp / "design")
        plain, _ = run(fdesign, existing, Route("elandor_dawnmere_fields"), 1, args)
        fronted = A()
        fronted.__dict__.update(args.__dict__)
        fronted.lines_set = ["front"]
        front, _ = run(fdesign, existing, Route("elandor_dawnmere_fields"), 1, fronted)
        check(plain.zone_rows[0]["quests"] == 11 and front.zone_rows[0]["quests"] == 1,
              "front quests count only with --lines front (%d, %d)"
              % (plain.zone_rows[0]["quests"], front.zone_rows[0]["quests"]))
    finally:
        shutil.rmtree(tmp)
    started = A()
    started.__dict__.update(args.__dict__)
    started.start_level = 5
    text5, _ = report(design, existing, Route("elandor_dawnmere_fields"), started)
    check("| 5 → 10 | %d " % C.xp_between(5, 10) in text5, "--start-level 5 starts the band need at 5")
    human = A()
    human.__dict__.update(args.__dict__)
    human.human = True
    hsolo, _ = run(design, existing, Route("elandor_dawnmere_fields:1-10"), 1, human)
    check(hsolo.zone_rows[0]["acc"]["rewards"] > sacc["rewards"], "human option raises rewards")
    # Track routes (round29-quests-plan section 3.1) on the gameplay bands.
    check(gameplay_band("front_broken_causeway") == (41, 50) and gameplay_band("front_skyglass_canopy") == (51, 60),
          "bands: the Causeway 41-50, Skyglass 51-60 (the mapgen rows)")
    entries = C.track_route("human", "elandor_lorindor")
    own = [(zone, label) for zone, lines, _, label in entries if lines is None]
    check(own == [("elandor_dawnmere_fields", "start"), ("elandor_goldmead_vale", "home"),
                  ("elandor_highcourt", "capital"), ("elandor_whitebridge_shire", "heartland"),
                  ("elandor_lorindor", "sister"), ("elandor_ashenward_march", "contested"),
                  ("elandor_stormvault_heights", "contested"), ("elandor_glassroot_wilds", "contested"),
                  ("front_broken_causeway", "front"), ("front_shattered_line", "front"),
                  ("front_gravesalt_escarpment", "front"), ("front_skyglass_canopy", "front")],
          "human track: own zones, sister, the three contested zones, 41-50 and 51-60 (%s)" % own)
    hosts = sorted({zone for zone, lines, levels, _ in entries if lines == ("front",) and levels == (41, 50)})
    check(hosts == ["elandor_ashenward_march", "elandor_dur_brannoc", "elandor_glassroot_wilds",
                    "elandor_highcourt", "elandor_lethariel", "elandor_stormvault_heights"],
          "front quests from the faction's contested zones and capitals (%s)" % hosts)
    elf = [zone for zone, lines, _, label in C.track_route("troll") if label == "heartland"]
    check(elf == ["kragmar_whispering_reedlands", "kragmar_totemwater_reach"], "both troll heartland zones")
    for bad in ("kragmar_ossuary_reach", "elandor_whitebridge_shire", "elandor_goldmead_vale"):
        try:
            C.track_route("human", bad)
            check(False, "sister %s refused" % bad)
        except ValueError:
            check(True, "sister refused")
    tracked, _ = run(design, existing, Route(entries=entries), 1, args)
    check(set(tracked.per_band) == {(b[0], b[1]) for b in C.BANDS}, "a track reports every band")
    check(tracked.zone_rows[0]["quests"] == 11 and tracked.zone_rows[0]["zone"] == "elandor_dawnmere_fields (start)",
          "the track runs the design's start zone")
    if failures:
        for f in failures:
            print("FAIL " + f)
        print("ledger self-test: FAIL (%d)" % len(failures))
        return 1
    print("ledger self-test: PASS (%d checks)" % checks[0])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
