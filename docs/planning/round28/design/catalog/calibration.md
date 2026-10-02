# C1b quest reward calibration

Use real XP to balance a **selected route**, not the sum of every quest a
faction can find. The [frame](../../../round28-design-frame.md) owns the
curve, target shares, route rules and solo difficulty promise. This note
gives starting weights and reproducible arithmetic examples, not finished
zone content or measured completion times.

## Spend the band once

`M(L) = 25 + 5L`; a reward of `w` KE is `w * M(quest level)` XP,
rounded half up. Human quest rewards then receive their existing +10%.
Kill XP uses the actual mob level, the player+5 cap, gray rule and tier
multiplier. Never add KE at different levels as though they were XP.

| Entry → exit | Actual XP needed | Questing aim | Rewards aim | Required activity aim |
|---|---:|---:|---:|---:|
| 1 → 10 | 4,200 | 90% | 40% = 1,680 | 50% = 2,100 |
| 10 → 20 | 11,750 | 80% | 40% = 4,700 | 40% = 4,700 |
| 20 → 30 | 21,960 | 80% | 40% = 8,784 | 40% = 8,784 |
| 30 → 40 | 35,100 | 80% | 40% = 14,040 | 40% = 14,040 |
| 40 → 50 | 51,140 | 70% with stated repeats | 35% = 17,899 | 35% = 17,899 |
| 50 → 60 | 70,070 | 70% with stated repeats | 35% ≈ 24,525 | 35% ≈ 24,525 |

“Required activity” includes kills behind drop requests and XP-bearing
gathering as well as kill objectives. The remainder is free exploration,
crafting supply trips and combat. It is not a compulsory grind quest
hidden outside the ledger. Check **where** the simulation inserts free
play before a minimum level; a good aggregate can still hide a poor early
handoff. Reward level 10 belongs to the 10→20 ledger band: keep the final
start handoff at reward level 9 if its reward pays the start budget.

## Weight guide (KE at the quest's reward level)

| Quest type | 1–10 | 11–20 | 21–30 | 31–40 | 41–50 | 51–60 |
|---|---:|---:|---:|---:|---:|---:|
| Ordinary hunt, normally 8–10 targets | 2.5–3.5 | 4–5 | 4–6 | 4.5–6 | 5–7 | 6–8 |
| Gathering / bring request, one short task | 1–2.5 | 3–4 | 3–5 | 4–5 | 4–6 | 5–6 |
| Ordinary or quest-only drop request | 1.5–3 | 3–5 | 3–5 | 4–6 | 5–7 | 5–7 |
| Travel handoff, on the onward route | 0.5–1 | 1–1.5 | 1–2 | 1–2 | 1–2 | 1–2 |
| Line climax, including its approach work | 3.5–4.5 | 5–6 | 5–7 | 5–8 | 6–8 | 7–9 |
| Solo repeatable, comparable shorter task | 1–1.5 | 2–2.5 | 2–3 | 2–3 | 2.5–3 | 3–3.5 |

These are starting ranges, not minimum payments owed by the system.
Count travel **once** for a compatible bundle. A pantry request completed
with an earlier hunt's spare drops can use a lower weight; an isolated
eight-minute detour deserves more than a five-log pickup beside the giver.
Never pay extra XP merely because the spawn rate is poor. Fix the target
count or area instead. Use half-KE steps normally; quarter-KE adjustments
are available after the ledger exposes a small remaining imbalance.

Five start hunts at the low end of 8–10, with a five-crab exception,
leave little room for additional drop farming. Budget **incremental**
kills behind the pantry line, after loot from previous hunts. A request
for four tusks at 1-in-3 is twelve expected kills if starting empty;
eight preceding boars supply 8/3 tusks, leaving four expected extra kills.
That request and a hunt undertaken simultaneously are one outing.
Four tusks deliberately test pressure: it spends the whole expected pile
and leaves nothing for enchanting. The reconciled catalogue limits actual
T1/T2 compulsory requests to two of a stat ingredient across the band and
reserves two of the chosen first-enchant ingredient separately. The sample
below retains four as a stress fixture, not a recommended C2 quest.
Quest-only proof for a named normal leader should be guaranteed, not a
second roll that asks the player to wait five minutes and kill it again.

Every selected solo route has reachable normal-tier named climaxes through
L59, including intermediate lines at 21–30. Optional group elites from L31
are excluded from the solo baseline; their kill XP is already ×4, so do
not also multiply the reward weight by four. Reward skill and the trip,
not the size of the health bar. No rare is a required target.

## Route assembly and alternatives

The start and home zone each carry their race's whole band budget.
At 20–30, the faction offers seven zones, each with about 35–50% of the
band in its full quest offering. Budget a chosen two- or three-zone
journey around 80%; do not require all seven. Include at least one other
race's capital outskirts or 21–30 heartland, with travel prerequisites
reachable from the player's own route. Never use another race's 11–20
zone. A two-zone 40%+40% selection is the simplest ledger; a three-zone
route selects shorter portions rather than completing three 40% catalogues.

At 31–40 each of the faction's three contested zones and the shared
Broken Causeway offers about 30–40%. About three zones are visited, but
the selected quests need not exhaust all three. Three full 35% offers
would total 105%, contradicting the route's 80% aim. For example, select
30% + 30% + 20%; the remaining quests are alternatives. Publish which
lines/quests are selected and prove their prerequisites, rather than
marking an arbitrary overfull ledger acceptable. The samples below are
selected slices, not a claim to specify each zone's complete offering.

At the front budget one-time work plus a bounded number of repeat
completions. Three completions means **three total turn-ins**, not the
initial turn-in plus three. Use two appropriately placed contracts and
compatible one-time work; the route must not require a carousel of all
seven faction dispatchers. Count round trips from the actual host NPCs,
not just time inside the target zone. Islands at 60 pay coin/materials
and have weight 0; they cannot close a 50→60 deficit.

## Copper rule

For an ordinary quest use `round_half_up(0.08 * P(T) * w)` copper,
minimum 1c when `w > 0`, with `T = ceil(reward_level / 10)` and the
authored reward weight `w`. Repeatables use their already reduced weight;
do not halve it again. Human +10% affects XP only. This puts a 5-KE
one-time quest at about 40% of one Common weapon and a 2.5-KE bounty at
20%; slot items awarded by a quest are separate, explicitly budgeted perks.

| Price state | P(T1) | P(T2) | P(T3) | P(T4) | P(T5) | P(T6) |
|---|---:|---:|---:|---:|---:|---:|
| Current shipped vendors: use for Round 28 until WP44 | 50 | 70 | 98 | 137 | 192 | 269 |
| Approved WP44 cutover, not activated by C1b | 25 | 65 | 160 | 400 | 1,000 | 2,500 |

The current price state is documented in
[economy.md](../../../../design/economy.md) §1–3. A T1 3-KE hunt pays 12c
now; a T3 5-KE task 39c; a T5 3-KE repeatable 46c. On the coordinated
WP44 cutover those become 6c, 64c and 240c. Store the selected integer
in `rewards.copper`, not a runtime dual-price rule. Recompute quest copper
with the price catalog when WP44 lands; do not adopt its target prices
for quests alone during Round 28.

A cap-level island salvage bounty pays `round_half_up(0.24 * P(6))`
copper (65c now, 600c at the cutover), **weight 0**. Optional elite island
work may pay `round_half_up(0.32 * P(6))` (86c now, 800c at cutover) with
its longer cooldown. Useful existing material rewards may supplement
coin, after checking their supply and sale value; no new island currency.
There is no claim here that these sums fund a mount at a measured speed.

Audit any bring-quest input purchasable from a vendor against the cheapest
applicable discounted price, and include the vendor value of reward
items. A repeat must not be a profitable buy-and-turn-in loop or a
substitute for its intended outing. No repeatable travel-only reward.
The present 25% vendor buy-back and WP44's future 5% ceiling are different
states; test the actual state, not a mixture.

## Reproduce the worked examples

The six JSON files in [samples/](samples/) are compact **arithmetic
fixtures**, not zone quest files. Their ordered rows use the named
`columns`; `zone` indexes the `zones` list. A `climax` source is an actual
catalogue leader role and always counts one kill at its fixed level. The
optional `approaches` entry adds separately counted ordinary helpers to that
quest. Other sources are existing base labels, catalogue/registered items,
groups or NPCs. These rows do not propose subtype
registrations, terrain or giver allocations. Front zone names label destinations;
production front quests still belong in the reserved host files.

Measured with this adapter, the reconciled C1 drops and `existing.json`
on 2026-10-02:

| Fixture | Templates / counted turn-ins | Solo questing | Solo rewards | Duo questing | Solo flags |
|---|---:|---:|---:|---:|---|
| [start.json](samples/start.json), Human | 14 / 14 | 91.57% | 40.02% | 72.74% | None |
| [home.json](samples/home.json), Human | 10 / 10 | 83.82% | 41.19% | 70.52% | None |
| [heartland.json](samples/heartland.json), Human, two zones | 14 / 14 | 80.65% | 42.46% | 67.44% | None |
| [contested.json](samples/contested.json), Human, three zones | 15 / 15 | 80.93% | 41.59% | 63.11% | None |
| [front_40.json](samples/front_40.json), no race bonus | 11 / 15 | 70.94% | 34.29% | 53.93% | None |
| [front_50.json](samples/front_50.json), no race bonus | 11 / 15 | 71.66% | 34.71% | 54.62% | None |

The named fixtures use Chief Crumb (L10), Requisitioner Hobb (L20),
Basket-Poacher Thorn (L24), Pearl-Counter Iss (L30), Quartermaster Scrip
(L33), Bolt-Chewer (L36), Basket-Biter (L39), Standard-Bearer Ninepins
(L48) and Watch-Captain Huskell (L58). All nine are authored **normal**
leaders. Reward levels remain in their intended bands; source levels
come from the actual leader, not the quest reward. The late examples keep
their previous arithmetic because these new normal leaders have the same
levels as the former stand-ins. Elites contribute nothing to these totals.

The start sample demands 37 normal kills through five kill quests
(the last counts seven L9 Confused Bandits plus L10 Chief Crumb), four
additional expected boars for tusks, and 195 gathering XP. Its 1,681 reward XP plus 1,830 kill XP,
140 incremental drop-kill XP and 195 gathering XP total **3,846 / 4,200**.
The remaining 354 XP is free play. With the same weights and no Human
bonus it gives 87.88% questing / 36.33% rewards: within the rough targets,
without removing the Human advantage. Other race designs are still
calibrated against their own quests and sources.

The heartland sample selects Whitebridge and Lorindor, fulfilling the
other-race visit; their contributions are 36.94% and 43.72% of the band.
Its six-target cleanup uses 2.5 KE because it is part of the climax
approach, below the full independent-hunt range. The contested example
selects 25.02%, 26.99% and 28.92% slices from three zones; each complete
zone must still offer its frame-mandated 30–40%. These fixtures prove
the budget arithmetic, not completion of the surrounding zone catalogue.

Each front fixture has nine one-time templates plus two bounty templates,
each counted three times. Removing repeats gives only 43.75% questing /
25.22% rewards at 40→50 and 44.01% / 25.49% at 50→60. Those deficits are
intentional: repeat work supplies about 27 percentage points of questing,
including its kills, but only about nine points of turn-in rewards.
For that sensitivity check set `repeat` to 0 in memory before running
the adapter; do not add unbounded repeats to make a ledger pass.

Five duo runs report `UNDERSHOOT questing`; these are explained
informational flags from split combat XP. Home is within tolerance:
the integrated one-meat-per-kill table makes its twenty-meat stress order
cost ten additional solo kills (800 XP), or fifteen additional kills'
worth of XP per duo member (1,200 XP), after the first ten boars. The old
registry-based fixture understated that demand. Solo minimum-level top-ups are
0 XP (start/home), 436 (heartland), 1,045 (contested), 8,674 (front 40)
and 11,820 (front 50). They fit within the respective free-play budgets;
the two front values also reflect the tool's repeat-at-the-end ordering.
They must be placed sensibly in a real itinerary. Exit levels shown by
the tool exclude the remaining free play after the last quest; an exit
below the next band is not itself an additional XP shortfall.

The adapter below feeds these rows into **the actual `ledger.py` engine**
in memory. No zone file, tool change or new item is written. Ordinary combat
rows get synthetic exact-level sources with explicit `drops`, selected
from catalogue subtypes using the fixture's base-mob label. Climax rows
use the real normal leader subtype and fixed level, with no area; the
start approach uses a separate real Confused Bandit source at L9.
This is an adapter for arithmetic, **not** B2 inheritance: an existing
`wolf` does not receive `canid` merely because its subtypes use that table.
Production zones use actual catalogue roles; see the
[B2 dispatch rule](README.md#b2-loot-dispatch-and-band-coverage).
This exercises the final tier tables and item carry-over;
it checks climax role/level/zone binding but does not certify terrain
placement or a finished route. Item gathering uses the existing registry. The T3 recovery
example requests Serrated Fang, not the earlier T2 Fang. Rerun real route
ledgers with actual subtype ids and areas before accepting C2/C3 content.

Run from the repository root. Output goes to stdout; keep any redirected
full reports in the coordinator's output path, not in the repository.

```python
import json
import sys
from pathlib import Path
from types import SimpleNamespace

sys.dont_write_bytecode = True
sys.path.insert(0, "tools/r28_design")
import ledger as L
import r28common as C

root = Path("docs/planning/round28/design/catalog/samples")
existing = C.load_existing(C.DEFAULT_EXISTING)
catalog = C.Design(root.parent.parent)
normal_families = {}
for subtype in catalog.subtypes:
    if subtype["tier"] == "normal" and not subtype.get("leader"):
        normal_families.setdefault(subtype["base"], set()).add(subtype["drops"])
assert all(len(families) == 1 for families in normal_families.values())
roles = {r["role"]: r for r in catalog.subtypes}
for path in sorted(root.glob("*.json")):
    sample = json.loads(path.read_text())
    design = C.Design(root)  # Empty catalog/zones; populated only in memory.
    design.items = catalog.items
    design.drops = catalog.drops
    design.reagents = catalog.reagents
    design.subtypes = []
    previous = {}
    for zone in sample["zones"]:
        design.spawns[zone] = {"areas": [], "leaders": []}
        design.quests[zone] = {"quests": []}
    for i, values in enumerate(sample["rows"]):
        row = dict(zip(sample["columns"], values))
        zone = sample["zones"][row["zone"]]
        kind, source = row["kind"], row["source"]
        qid = "sample_%02d" % i
        quest = {
            "id": qid, "level": row["level"], "min_level": row["min_level"],
            "line": "sample", "rewards": {"weight": row["weight"]},
            "requires": [previous[zone]] if zone in previous else [],
        }
        if kind == "climax":
            leader = roles[source]
            assert leader.get("leader") and leader["tier"] == "normal"
            assert leader["levels"][0] == leader["levels"][1]
            assert zone in leader["notes"] and row["count"] == 1
            level = leader["levels"][0]
            assert abs(level - row["level"]) <= 3
            design.subtypes.append(leader)
            design.spawns[zone]["leaders"].append({
                "role": source, "level": level, "respawn": 300})
            quest["climax"] = True
            quest["objectives"] = []
            approach = sample.get("approaches", {}).get(source)
            if approach:
                helper = roles[approach["role"]]
                assert not helper.get("leader") and helper["tier"] == "normal"
                assert helper["levels"][0] <= approach["level"] <= helper["levels"][1]
                assert abs(approach["level"] - row["level"]) <= 3
                design.subtypes.append(helper)
                design.spawns[zone]["areas"].append({
                    "id": qid, "levels": [approach["level"], approach["level"]],
                    "species": [{"role": helper["role"], "weight": 1}]})
                quest["objectives"].append({"type": "kill", "roles": [helper["role"]],
                    "count": approach["count"], "area": zone + "/" + qid})
            quest["objectives"].append({"type": "kill", "roles": [source], "count": 1})
        elif kind in ("kill", "repeat"):
            assert "grug_mobs:" + source in existing["entities"]
            family = next(iter(normal_families["grug_mobs:" + source]))
            role = "fixture_source_%02d" % i
            design.subtypes.append({"role": role, "drops": family,
                "tier": "normal", "levels": [row["level"], row["level"]]})
            design.spawns[zone]["areas"].append({
                "id": qid, "levels": [row["level"], row["level"]],
                "species": [{"role": role, "weight": 1}],
            })
            quest["objectives"] = [{"type": "kill", "roles": [role],
                "count": row["count"], "area": zone + "/" + qid}]
        elif kind == "item":
            is_group = source.startswith("group:")
            key, value = ("group", source[6:]) if is_group else ("item", source)
            assert (value in existing["groups"] if is_group else
                    value in existing["items"] or value in catalog.item_map())
            quest["objectives"] = [{"type": "item", key: value,
                                    "count": row["count"]}]
        else:
            assert kind == "talk" and source in existing["quest_npcs"]
            quest["objectives"] = [{"type": "talk", "npc": source}]
        if kind == "repeat":
            quest["repeatable"] = {"cooldown": 1200}
            quest["requires"] = []  # Capacity/unlock structure is not simulated.
        else:
            previous[zone] = qid
        design.quests[zone]["quests"].append(quest)
    args = SimpleNamespace(
        design=str(path), human=sample["human"], repeat=sample["repeat"],
        skip_optional=False, solo_group=False, start_level=sample["start_level"],
        lines_set=None, party="both", tolerance=10,
    )
    report, flags = L.report(design, existing, L.Route(
        ",".join(sample["zones"])), args)
    print(report)
    print("Reported flags, including informational duo flags:", flags)
```

## Measurement limits and acceptance

The ledger splits kill XP in a duo and does not split quest rewards.
Ordinary drops are shared inventory loot, so each partner needs their own
requested items; quest-only drops roll separately. A duo's lower questing
share is informational, not a reason to inflate solo rewards. Check both
with the real route. Check Human routes with `--human`; use the other
race's real weights without that flag. Do not remove the Human bonus by
silently rescaling a universal quest at runtime.

The ledger reuses ordinary drops from **previous** kill rows, but it does
not schedule concurrently active quests. It can count a kill again for
an overlapping kill objective or quest-only request. Prefer kill +
ordinary recovery bundles for the calibration; for overlapping proofs,
record the overlap and an adjusted unique-kill total beside the raw
ledger. It uses expected drop yield, not the long tail of unlucky rolls.

The tool also groups all completions of each repeatable after the
one-time quests, without cooldowns or travel, and reports the sum of
`duration_min`, not separate time categories. The arithmetic fixtures
therefore leave duration unset. Content lanes must record **travel,
combat, collection, respawn and clock wait** separately in their route
narrative, plus actual repeat order and overlap. Front free-play notes
from this artificial order do not prove that the player must grind those
gaps before using an already available bounty.

Before a zone is accepted, replace expected encounter counts with Lane
E's area reachability measurements and make a time estimate from the
actual host trips. No quest weight compensates for an unreachable spawn,
an unplayable solo leader, a missed giver slot or a mandatory long wait.

## Blockers / questions

- **Copper deployment condition:** I checked the existing economy spec;
  its ×2.5 axis explicitly waits for WP44's coordinated price cutover.
  Recommend the current-price column for Round 28. If the coordinator
  intends to ship WP44 in this round too, it must select the target
  column with that cutover; C1b does not authorize one.
- Stat-loot bindings and rates are reconciled in [README.md](README.md).
  The adapter exercises those drop tables; sample math still cannot
  certify zone placement, throughput or reserved enchant stock.
- No frame change is needed for three-zone budgets or multiple front
  tiers: select route portions and distribute permanent bounty tails
  across the existing reserved hosts, as described above and in
  [bounties.md](bounties.md).
