# Round 15 local quests — independent review

Date: 2026-09-21. Implementer: native Sol. Reviewer: independent native Astra,
no quest-catalog or reward implementation authorship. Reviewed frozen commit
`c07c89846c178b1f252f5a3cb360a55b7b7734f7` against `5143d7c1` in
`/tmp/grug-r15-quests`.

**Verdict: PASS for the reviewed quest-content package.** No remaining
confirmed Critical, High or Medium finding. Actual POI socket integration,
the coordinator's final interpreter pair and GUI acceptance remain separate
required gates; this review does not certify an invented fixture socket as a
real placed NPC.

## Scope and design adherence

Read all 36 additions, their registration loop, the bounded catalog fixture
and final reward ledger against `docs/design/quests.md`, `story.md`,
`world_zones.md`, the approved Round 15 package and the mandatory review
checklist/Lua 5.1 rules. The 66 prior quests retain their objectives, stable IDs,
NPCs, requirements and rewards; their added target-level/effort fields are
static authoring metadata retained by the real registry's copy.

Each race gains six one-time optional tasks, split two per existing village,
outpost and camp. There are 12 new item objectives and 24 new kill objectives.
The six new givers use `r15_<race>_local` on `quest_local` with the existing
semantic village keys. Village/outpost/camp prerequisites point to completed
main steps 6/7/8 respectively; no new local quest gates another or the main
chain. Existing race/faction and level 10/11/12 gates are preserved. No new
objective engine, repeatable reward, mandatory profession, Nether requirement,
provenance predicate or migration path was introduced.

## Acquisition and spawn checks

Verified actual registration/drop/spawn code, not only the fixture's copied
allow-list. Named-zone palette rows in `spawn_policy.lua:30–98` and
`world_zones.md` section 8 admit the selected families. Actual registrations
provide matching biome surfaces, above-ground height ranges and clocks:

| Route | Local kill families outside the camp | Checked item source |
| --- | --- | --- |
| Copperfell | Fox/ibex by day; goblin raider/slinger/hound by night | Eight cobble: actual `default:stone` drops `default:cobble` (`mods/BASE/default/nodes.lua:259–263`) |
| Goldmead | Fox by day; poacher by night | Four raw meat: fox and local turkey each guarantee one |
| Starbough | Poacher by night; fox by day | Two leather: local fox has 1-in-2, one-item drop |
| Mournfen | Plague boar by day; crocodile/ooze any time | Three slime gel: ooze guarantees one or two |
| Redtusk | Hyena any time; scorpion by night | Two leather: local hyena has 1-in-2, one-item drop |
| Raincall | Jungle lynx by day; viper by night | Four raw meat: local lynx guarantees one, tapir is another local source |

Relevant definitions are `start_zone_families.lua:35–135,198–249`,
`night_families.lua:4–92`, `zero_asset_variants.lua:17–59`, `hyena.lua`,
`jungle_lynx.lua`, `boar_variants.lua`, `bog_ooze.lua` and `crocodile.lua`.
The hand-in items are registered ordinary items. Trading and already-owned
holdings count by the existing V1 contract; the texts correctly ask to bring
materials. Leather is explicitly probabilistic and only a small optional
branch, not an opening mandatory low-drop grind.

Every camp accepts either Bandit or Bandit Archer for its five kills and asks
for five ordinary linen cloth separately. Both variants use the same
`bandit_def` drop function (`bandit.lua:149–173`, `bandit_archer.lua:90–95`):
1–2 guaranteed linen at surface level at most 30. The six home camps are in
11–20 zones; the actual camp registry owns their 3–5 mixed-role population.
No ambient bandit spawn or archer-only probability is assumed. Five personally
looted qualifying bandits supply at least five linen, so the pair does not
require a second material-acquisition kill sequence. Shared kill eligibility
is not mistaken for duplicate personal loot.

Night-only task descriptions now explicitly tell players to return after
nightfall/sunset. Scene descriptions follow the approved workshop, granary,
sapling, wax store, freight and stilt-house compositions. Ordinary blight and
undead residents are not reframed as Nether corruption. The six final camp
hand-ins remain culturally narrated versions of a shared linen mechanic;
this is bounded variation within the approved objective families.

## Reward and simultaneous-credit review

Verified the actual quadratic XP curve, Human quest-source multiplier,
`grug_mobs.kill_xp` player-level-plus-five cap, gray suppression and shared
participant division. Fixed local rewards total 4,700 XP per race, 5,170 for a
Human after per-award rounding. No reward reads the turn-in player's level.
The existing main route remains at 14,800 quest XP; its later awards already
match or exceed the nearby level spans, supporting the documented decision
not to apply an extra blanket 15–20% increase.

`state.lua:236–252` advances every matching active objective on one eligible
kill. The final ledger correctly distinguishes 19 summed local kill counters
from incremental combat after overlapping main quests. The theoretical
additional-kill minima of 6/6/5/11/5/5 for Dwarf/Human/Elf/Undead/Orc/Troll
respect prerequisite timing and permitted deferred turn-ins. Main camp four,
local camp five and the five-cloth hand-in are not counted as nine or more
separate required kills. Human XP bonus applies to quest rewards, not kill XP.
The ledger labels its 100–170 solo kill-XP range as an assumed local-level
planning range; party splits, gray kills, existing items and different quest
acceptance order remain explicit qualifications.

## Evidence and remaining gates

Inspected the author's bounded LuaJIT output and static logs in `/tmp/`;
no Lua, native or seed suite was rerun by this reviewer. Canonical output:

```
quests=102;r14=66;r15=36;npcs=30;routes=6;local_per_route=6;local_per_poi=2;items=12;kills=24
```

`content.lua` has no SETGLOBAL; the tool has only its four declared engine
stub globals. Explicit tool sweeps are empty. Repository sweep matches are
existing comments or literal string delimiters, not newly introduced syntax.
Inspected `/tmp/r15-quests-parser.log`: both changed Lua files parse; root
final gates remain required.
The fixture validates the real registry against bounded authored stubs and
source-derived target/clock tables; it does not execute live spawning or prove
actual blueprint sockets. Source review supplies the availability check above.

Immutable reviewed SHA-256:

- `content.lua`: `82ba15ec5bca87ddbcb937611f4b935c90158bd0d633c973a7c408e0286f66d6`.
- `check_catalog.lua`: `e64caba7a3d578e9a3adfa1ebd7f7d4e2d9d4a65d17ec638de8165565e542412`.
- `/tmp/r15-quests-registry.log`: `0cd386c8e79d512d90fc032c755d0e127aa60be003c4ccd947c273347cbbbbf1`.

Root must verify all six real `quest_local` role/position bindings through the
actual integrated roster and native consumers, include the final content in
its single final PUC/LuaJIT pair, and retain GUI acceptance. User checks: visit
one new village giver, accept the optional branches alongside the main chain,
verify a shared bandit kill advances both accepted counters, bring ordinary
linen for the paired hand-in, and check an explicit night-only target and the
Human reward bonus.

Calibration: native Sol implementation / native Astra independent review;
0 Critical, 0 High, 0 Medium after freeze; no post-freeze correction round;
pre-freeze discussion clarified night text and ledger accounting; elapsed
wall time unknown.
