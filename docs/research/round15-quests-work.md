# Round 15 local quests — implementation record

Date: 2026-09-21. Scope: the quest-content lane of Round 15.

## Result

The catalog now contains 102 one-time quests and 30 quest-giver identities.
Each race receives two independent optional quests at its village, outpost and
bandit camp. The new village identity uses that village's semantic settlement
key and the `quest_local` socket; all 24 existing giver IDs remain unchanged.
Village branches unlock after main step 6, outpost branches after step 7 and
camp branches after step 8. Local quests do not gate one another or the main
chain.

The authored scenes follow the approved POI compositions: workshops and loose
stone at Copperfell, granary/orchard work at Goldmead, saplings and cut timber
at Starbough, wax stores and drainage at Mournfen, cooking/freight at Redtusk,
and stilt-house preparation and wet stores at Raincall. Each village pair mixes
one ordinary item hand-in with one local kill task; outposts use two distinct
local kills, while camps pair one bandit task with one ordinary bandit-cloth
hand-in. Item readiness uses the existing inventory authority and does
not claim provenance. This adds no quest-drop, escort, visit, repeatable or
profession rule.

Every new task records a fixed `target_level` and `effort` alongside its normal
`min_level`. Rewards never read the player's turn-in level. Existing Round 14
records also carry this authoring metadata without changing registry or state
mechanics.

## Availability evidence

The target check is the intersection of the closed zone palettes in
`mods/ENTITIES/grug_mobs/spawn_policy.lua`, each mob's registered spawn rows,
and the authored camp spawner in `mods/ENTITIES/grug_mobs/camps.lua`.

| Route | Ambient targets | Spawn clock | Camp target |
| --- | --- | --- | --- |
| Dwarf / Copperfell | Ibex, Fox, Goblin raid | day, day, night | Bandit/Archer, any |
| Human / Goldmead | Wild Turkey, Fox, Poacher | day, day, night | Bandit/Archer, any |
| Elf / Starbough | Fox, Poacher | day, night | Bandit/Archer, any |
| Undead / Mournfen | Bog Ooze, Plague Boar, Crocodile | any, day, any | Bandit/Archer, any |
| Orc / Redtusk | Scorpion, Hyena | night, any | Bandit/Archer, any |
| Troll / Raincall | Viper, Jungle Lynx | night, day | Bandit/Archer, any |

The twelve hand-ins are ordinary registered items with a checked local source.
Copperfell asks for `default:cobble`, the direct drop from mineable stone; Goldmead and
Raincall ask for `mobs:meat_raw`, guaranteed by their local Turkey/Fox and
Jungle Lynx/Tapir families; Starbough and Redtusk ask for `mobs:leather`,
dropped locally by Fox and Hyena; Mournfen asks for `grug_mobs:slime_gel`,
guaranteed in 1–2 units by its any-time Bog Ooze. Every camp asks for five
`grug_mobs:linen_cloth`; inner-band Bandits and Bandit Archers each drop 1–2
with certainty. Trading or prior ownership also remains valid by design.

Camp tasks accept either bandit role because each authored bandit camp has a
stable population of 3–5 with the archer only a one-in-three variant. Requiring
archers alone would turn normal respawn variance into an unnecessary wait.
The local objective keeps the named-zone predicate, while camp population
comes from the settlement's camp spawner rather than the ambient palette.

## Reward and progression ledger

The level spans from `xp_for_level(L) = 100 * (L - 1)^2` are 1,900 XP at
level 10, 2,100 at level 11 and 2,300 at level 12. Each race has the same fixed
local-quest schedule:

| POI | Target level / effort | Counts | Quest XP | Share of target span |
| --- | --- | --- | --- | --- |
| Village | L10 light, L10 standard | local item, 5 kills | 550, 700 | 29%, 37% |
| Outpost | L11 light, L11 standard | 4, 5 | 650, 800 | 31%, 38% |
| Camp | L12 standard, L12 hard | 5 kills, 5 linen | 900, 1,100 | 39%, 48% |

That is 4,700 authored quest XP per route. A Human receives 5,170 because the
existing quest passive rounds each award after multiplying by 1.10: 605, 770,
715, 880, 990 and 1,210. The passive therefore adds 470 XP across all six.

Required-combat XP is bounded rather than simulated. The item tasks have no
required combat because the engine accepts prior-owned or traded items. For a
solo non-gray kill, the engine pays `10 * min(mob level, player level + 5)`.
Assuming the local field is roughly L10–L17 across these L10–L12 tasks, that is
about 100–170 XP before party splitting. The four local kill counters sum to
19 targets, so completing them separately represents roughly 1,900–3,230 kill
XP. Five camp bandits also guarantee at
least the five linen needed by the paired hand-in when sourced there, so
concurrent acceptance does not require another kill beyond the camp counter.
Already-owned or traded items can reduce acquisition combat further. Shared
participation divides kill XP; the player-level-plus-five cap bounds high mobs,
and a target ten levels below the player awards zero while quest credit still
advances.

Parallel main objectives can reduce new combat further because one eligible kill
advances every matching active quest without paying kill XP twice. With the
main steps and local tasks accepted or deliberately deferred for maximum
overlap, the theoretical minimum additional local kills beyond steps 7–9 are
Dwarf 6, Human 6, Elf 5, Undead 11, Orc 5 and Troll 5. The difference comes from whether each
village/outpost target matches main steps 7/8; every camp bandit task overlaps
step 9 except for one extra kill (5 versus 4). At the assumption above this is
roughly 500–1,870 incremental kill XP, before party splitting or gray
suppression. This is a lower-bound scheduling observation, not a promised or
required play order; accepting or completing branches at other times spends
more kills up to the 19-counter separate-task bound.

The existing nine-step main route already awards 14,800 quest XP before kills;
the cumulative level-12 threshold is 12,100 and level 13 is 14,400. Its later
quests (2,200 / 2,800 / 3,400) already equal or exceed their nearby level
spans, so the requested targeted pass found no progression support for a
15–20% uplift. Retaining those values avoids worsening the explicit level-10
travel gap after step 6. The new village tasks become available at level 10
and provide optional local play once the player reaches the home-region
village; no introductory reward changed.

## Verification

- `tools/r15_quests/check_catalog.lua` loads the real registry and content with
  bounded engine stubs, validates all sockets/objectives/prerequisites, checks
  the source-derived local target/clock catalog and emits the canonical count
  line `quests=102;r14=66;r15=36;npcs=30;routes=6;local_per_route=6;local_per_poi=2;items=12;kills=24`.
- Development runtime: `luajit tools/r15_quests/check_catalog.lua .`.
- Plain Lua 5.1 parsing covers both changed Lua files. `content.lua` emits no
  `SETGLOBAL`. The standalone fixture's four expected writes install its engine
  stubs: `grug_core`, `core`, `ItemStack` and `grug_quests`.
- The five repository Lua sweeps and explicit tool-file sweeps are recorded in
  the final lane handoff. The coordinator owns the single final PUC/LuaJIT
  micro-KAT pair; this lane ran no PUC runtime.

Runtime acceptance remains a fresh-world GUI check: verify the six new village
NPCs appear on `quest_local`, each POI giver offers two optional tasks at the
documented gate, day/night targets can advance their matching objectives, camp
bandits count across both roles, and the Human quest reward receives +10%.
