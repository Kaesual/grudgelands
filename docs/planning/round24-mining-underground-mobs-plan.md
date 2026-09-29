# Round 24 — mining tiers, underground fill, start-zone mobs, small fixes

Decided with the user on 2026-09-28/29 after a playtest on a fresh server
world. Coordinator: Claude (Opus 5.5). Model routing follows the
[agent model policy](../process/agent-model-policy.md); the user decides per
session. Rulings below are the contract for the lanes; implementation agents
do not invent design beyond them. **Work starts only after the user's explicit
go-ahead.**

## Why

1. **Shallow ores are missing (measured bug).** Around the Orc start, 5–16
   nodes below the surface, coal reaches only 0.10–0.37 of the target density
   (target: 1 coal per 64 `default:stone`); it reaches 1.0 only ~65 nodes
   down. A 1×2 tunnel of 50 m at depth 3–10 sees no coal at all in 70–88 % of
   cases (intended: about 5 coal nodes). Iron, copper, tin and quartz are
   thinned the same way. Headless measurement, seeds 10536739806879207652 and
   4242424242, region x −256..256, z 2294..2806.
   - Cause: the Lua terrain there lies 10–40 nodes above native v7. The writer
     fills that gap with plain `default:stone` (opcode 27 `OP_TERRAIN_FILL`,
     `[−37, terrain_y−1]`, policy fill-void). Only stone that was native and
     unchanged is an ore host (`wp40/r6_settlement.lua:2712`, `:2721-2724`),
     and the strata bands (secondary rock, gravel, dirt/clay pockets to 40
     below the surface) also replace native stone only (`:174`). The fill
     therefore has no ores, no bands, no gravel and no caves.
   - Making v7 follow our height field is not possible: v7 takes only global
     noise parameters, and the Lua field is independent of them. Plateaus
     were measured and rejected
     ([mapgen-performance-exploration.md](../research/mapgen-performance-exploration.md):
     plateau 128 87.8 s, plateau 441 99.3 s vs 78.9 s current). The fill
     itself is improved instead.
2. **Depth rules feel wrong.** Pick access is limited by fixed y bounds
   (`grug_materials/mining.lua` `can_mine_natural_at`, `max_depth`). The
   client predicts digging only from item capabilities and node groups, so it
   shows cracks and the server resets the node at the end. Natural loose
   ground (dirt, sand, gravel, snow) currently requires a pick; shovels are
   refused (no `grug_pick_tier` group).
3. **Protected areas show cracks** (towns, POIs, foreign home territory). The
   client cannot know position or faction; this is an engine limitation.
4. **Start zones spawn mobs far above new-player level.** Each start sits
   mid-zone (Sunscar t ≈ 0.53). Only a 150-node ring is forced to L1–2
   (`wp40/zones.lua:623-651`); right behind it the zone field gives L7–9
   toward the front, L10 at ~275 nodes, and the neighbouring zone (Redtusk,
   Goldmead) starts at ~250–350 nodes with L11–13. Husks may spawn in
   Sunscar only at L≥7 (`grug_mobs/zero_asset_variants.lua:124-129`); the
   Hyena spawns only in Redtusk (min level 10) and wanders north, because idle
   wandering has no leash except for camp mobs (`grug_mobs/aggro.lua:488-496`).
5. **Some mobs roam at sprint speed.** mobs_redo uses `walk_velocity` for idle
   roaming. Bandit Archer, Poacher and Skeleton Archer have walk 4.0 (meant for
   keeping distance in combat), so they sprint while idle. Husks and melee
   Bandits have the same speeds as Zombies (walk 1, run 4.6).
6. **Quest tracker** is capped at 3 (`grug_quests/state.lua:108`, `:151`) and
   uses two lines per quest.
7. **Lava and drowning ignore the HP pool.** Lava deals a flat engine 8 HP/s
   (`default/nodes.lua:2433`, `:2479`), drowning a flat engine value; a L60
   character out-heals lava with an apple. Fall damage already scales with the
   actual `hp_max` (`grug_core/combat.lua:1753-1758`) and needs no change.

## Rulings

### Mining and tools

1. **Rock tiers replace depth bounds.** The fixed per-pick depth limits are
   removed. Six tier rocks, all "ordinary stone compressed by depth":
   - T1 `default:stone` (unchanged name), y ≥ −100;
   - T2 `grug_materials:t2_stone` (was `grug_materials:slate`), −101..−300;
   - T3 `grug_materials:t3_stone` (was `basalt`), −301..−500;
   - T4 `grug_materials:t4_stone` (was `granite`), −501..−700;
   - T5 `grug_materials:t5_stone` (was `emberrock`), −701..−1000;
   - T6 `grug_materials:t6_stone` (was `abyssal_rock`), below −1000.

   Tier N rock requires a pick of tier ≥ N. All six drop `default:cobble`, so
   no player can place hard rock. Display name is plain "Stone" with a tooltip
   line naming the required pick tier. Worlds are discarded: no aliases.
   T1 keeps the name `default:stone` (renaming it would touch too much; user
   agreed). The tier boundaries stay flat y planes (user: the look of the
   boundary in caves does not matter).
2. **Resources:** every ore and gem requires the pick of the layer where it
   first appears (unchanged registry `harvest_tier`): coal, copper, tin, iron,
   quartz T1; gold, citrine, garnet, jade T2; silver T3; emberglass, diamond,
   sapphire, ruby T4; abyssal crystal T5. This holds at any depth (coal exposed
   at −600 is minable with a T1 pick). Tool-metal ores are therefore mined one
   tier below the gear they make.
3. **Too weak a pick cannot dig at all**, for rock and for resources. The
   "shatter" path (dig without drop) is removed.
4. **Engine-native gating:** node `level` groups and tool `maxlevel` so the
   client predicts it and shows no cracks. This deliberately reverses the WP43
   rule that fails startup on any non-zero `level` group
   (`grug_materials/audit.lua`); the audit is rewritten to check the new
   contract. A higher pick digs lower rock faster (the engine divides dig time
   by the level difference; keep or tune per-tier times on top).
5. **Loose ground** (dirt and its variants, sand, gravel, clay, snow, mud,
   mesa clay, ash ground and the other entries of `NATURAL_GROUND_NODES`
   except stone) has no level and no tool gate. Bare hand and the equipped
   skill hand dig it; a shovel is faster than a pick of the same tier; a
   higher shovel is faster than a lower one (VoxeLibre model). Picks keep
   digging loose ground more slowly than a same-tier shovel. Shovels get their
   tier groups (the WP29 TODO in `grug_materials/mining.lua`).
6. **Wood is not gated.** A better axe chops faster; axes get tier groups
   too. Check whether tier groups on axes and shovels change the
   concentrated-zone cultural-source rule (`grug_gathering/harvest.lua:77-96`),
   which today reports `resolver_unavailable` for tierless axes and shovels.
7. **Immediate hints on punch** (rate-limited, one line):
   - protected node, with the reason: e.g. "Town – protected",
     "Landmark – protected", "Accord home territory – protected",
     "Throng home territory – protected";
   - rock or resource too hard: e.g. "Requires a T3 pick".

   Server protection checks stay authoritative. The protection cracks remain
   (engine limit); no per-player capability swapping. Verify that the client
   still sends a punch for a node it predicts as undiggable
   (`reference_projects/luanti/src/client/game.cpp` `handleDigging`); if it
   does not, report instead of building a workaround.
8. **Decorative rocks:** new `grug_materials:slate`, `grug_materials:basalt`
   and `grug_materials:granite`, clearly different in look from stone. Any pick
   digs them, they drop themselves (building variety), no ores grow in them.
   They occur only in irregular nests and in the sparse mountain layers
   (ruling 12). Assign the names only after the tier-rock rename in the same
   change set.

### Underground fill (the gap between native v7 and our surface)

9. The fill does not need to resemble v7; the transition to native v7 may cut
   through veins, caves or bands. It stays algorithmically cheap.
10. **Ores in fill:** the existing resource pass (same budget per 16³ cell,
    same veins) accepts terrain-fill `default:stone`. Ores stay in
    `default:stone` only (not in layer rocks).
11. **Strata bands in fill:** the existing bands (secondary rock, gravel,
    dirt/clay pockets, to 40 below the surface) also replace fill stone, so
    fill and native stone look the same near the surface.
12. **Mountain interiors** (fill deeper than the band depth): sparse,
    cheap horizontal layers: rock chosen from y plus a smooth per-column
    offset, a few nodes thick, a small zone palette (the decorative rocks plus
    zone rocks such as sandstone or desert stone in the badlands), and
    occasional gravel or dirt pockets from a coarse 3D lattice. **Do not
    overdo it:** stone stays clearly dominant. First version by feel, with
    renders of a cliff and a tunnel for the user.
13. **No caves in fill.**
14. **Decorative nests at depth:** native blob ores (engine, cheap) for the
    three decorative rocks in `default:stone` and the tier rocks, each with a
    preferred depth range, sparse.
15. Lava stays as it is (engine: only in flooded large caves in chunks fully
    below y −255).

### Art

16. **Tier rocks:** same stone, visibly "more compressed" with depth — e.g.
    the `default_stone` base, progressively darker (roughly −8 % at T2 to
    −40 % at T6), a slight cool tint, a denser fine-crack overlay. First
    version by feel with a comparison render; if no convincing design language
    emerges, all six stay identical (user accepts that).
17. **Ores vs gems:** gems must read clearly different from ores (VoxeLibre gem
    style is the reference; e.g. its diamond ore). Silver and quartz must not
    look alike. VoxeLibre media is CC BY-SA 4.0 (Pixel Perfection, see its
    `LEGAL.md`); extract the mineral motif as a transparent overlay, tint it,
    and composite it on our stone (its stone background differs from
    `default_stone`). Provenance in `LICENSE-media.md` as for existing
    VoxeLibre assets. An ore is the same node at every depth, so deep ores
    show the light `default_stone` background inside dark tier rock; this is
    accepted (no per-tier ore variants).

### Mobs

18. **Start-zone level gradient:** in a start zone the level rises from the
    start toward the faction front; band 3 begins only shortly before the
    front. The area behind the start (home-facing coast) is band 1. The
    150-node L1–2 ring stays, with no jump behind it. Other zones keep their
    current gradient. Report the zone-border step (e.g. Sunscar 10 → Redtusk
    12–13) with numbers; do not change it without a ruling.
19. **Wander leash:** idle wandering of free-roaming mobs stays within a radius
    around the spawn point. **No chase leash:** combat pursuit keeps the
    existing ambient pursuit policy (`combat_stats.md` "Ambient pursuit
    policy": 15-second incoming-damage clock plus target movement, then return
    to spawn). Camp mobs keep their own rules.
20. **Speeds:** every mob roams at a calm walk speed and uses its full speed
    only in combat. Archers and poachers keep 4.0 for kiting in combat only.
    Combat run speeds stay (melee 4.6 against the player's 4.0, so kiting
    stays non-trivial).
21. Husk quest text (`grug_quests/content.lua:309`, "level-3-and-up flats")
    matches the new gradient.
22. **Stale chase references** are updated to the current policy:
    `biomes_mobs.md:369` (soft de-aggro 25 m as a general rule), `:487`
    (grazer "ordinary chase (45 m, soft de-aggro at 25 m)"), `:531` (view-range
    rationale "gives up a chase at 45 m and leashes at 40"); check
    `scout.md:304`, `mounts.md:12` and the historical wording in the
    `VENDOR.md` mobs row (patch f). The Kraken Guard rules in `world.md` are
    bespoke and stay.

### Quest tracker and environmental damage

23. **Tracker:** up to 10 tracked quests (one named constant, also in the
    auto-track on accept and in the log notice). One line per quest: the
    objective only (e.g. "0/4 Bring Raw Meat"), no quest title. A quest ready
    to turn in shows "Return to <quest giver>". Identical objectives of two
    quests may look the same (accepted). Check the minimap does not overlap.
24. **Lava:** 20 % of the actual `hp_max` per second. **Drowning:** 10 % of the
    actual `hp_max` per second. Armor does not reduce either. The absorb
    shield does not absorb fall, lava or drowning damage. Use the actual pool
    (`player:get_properties().hp_max`), like fall damage and suffocation.
    Players only; mob damage unchanged.

### Follow-up rulings (2026-09-29, after Lanes A, C, D, E merged)

25. **Start-zone gradient also drives mapgen content:** level-banded plants,
    vegetation resources and every other consumer of the zone content level
    follow the Ruling 18 gradient in start zones (byte identity was never
    required; pins are regenerated, mapgen time reported as a comparison).
26. **Mob level ranges stay a design tool, expressed in bands.** Husk in
    Sunscar from band 2 (L4+) instead of L≥7; the Husk quest moves to level 5.
    Every band of every start zone has enough day and night spawns, and no
    start-zone quest targets mobs outside its level.
27. **Mob density is a per-zone budget**, independent of how many species a
    zone allows (mobs_redo caps each species separately today, so a zone with
    few eligible species is empty). Baseline density rises to about 1.5× as a
    first value by feel; before/after measured in short engine runs.
28. **Gathering XP:** every natural ore or gem node and every caught fish
    gives XP = factor × min(reference level, player level + 5); reference
    level = top of the tier's level band for ores and gems (T1 10, T2 20 …
    T5 50), top of the water's zone band for fish (10 … 60); factor 1.5 per
    ore node, 3 per gem node, 5 per fish. No gray rule: T1 always gives XP.
    Factors live in one place. No anti-cheat (no autoclicker checks).
29. **Tool level requirement:** tools of material tier T2 need level 5, T3
    level 15, T4 25, T5 35, T6 45; wood, stone and bronze tools have none.
    Enforced server-side in the central mining decision for picks, shovels and
    axes, with a flash hint ("Iron Pick requires level 5"); the client still
    shows cracks in that rare case (engine limit, accepted).

30. **Protection depth follows the placement:** capitals, start towns, POIs
    and every other hard-protected footprint are protected from a fixed depth
    of 100 nodes below their placement height (the anchor/centre surface y)
    upward, instead of the global y ≥ −700. Below that, digging, ores, gems,
    rock layers and nests follow the normal rules (the old "ore-free to −700"
    under start towns is removed). Upward protection stays unbounded.
    Everything below the bound is treated as normal ground, caves included:
    cave content (world-content cave rows), cultural reservations and hostile
    spawns follow the usual rules there (user, 2026-09-29).

31. **Thin start-zone cells are filled** (palette/clock changes only, no new
    species): Sunscar scorpions also spawn by day from band 2, and the plains
    runner becomes fighting prey instead of a critter; Kapok vipers also spawn
    by day from band 2 and the jungle lynx from band 2–3 (not only L10). Band 1
    by day stays peaceful in the Dwarf, Human and Elf start zones.

32. **Character creation can always be paused** (user, 2026-09-29): Esc
    really closes every creation dialog (faction, race, class, waiting
    screen); nothing reopens by itself, so the next Esc reaches the native
    game menu (settings, exit). The player stays safe in creation stasis.
    While creation is unfinished, the inventory key opens the current step
    (the player's inventory formspec is that step; a screen hint says
    "Character creation paused – press I to continue"). When preparation
    finishes while the waiting screen is open the next step replaces it;
    when it was dismissed only the hint changes. Every choice, including the
    class chosen while the arrival area still loads, is stored in player data
    at once, so a reconnect continues at the first missing step. No kick
    button.

## Lanes

| Lane | Scope | Depends on |
|---|---|---|
| **A — Mining rules** | Rulings 1–8: tier-rock rename (incl. the mapgen-side node names and native-allowlist digest so the game boots), `level`/`maxlevel` gating, depth rules and shatter removed, shovel and axe tiers, loose ground and hand, audit rewrite, punch hints (protection reason, pick tier), docs (`items_crafting.md`, `VENDOR.md` rows, WP43 notes) | — (merges first) |
| **B — Underground fill** | Rulings 9–15: ores and bands in fill, mountain-interior layers, decorative nests, mapgen pins and known-answer tests, before/after measurement with the coal probe method (target: coal per 64 stone near 1.0 in the 5–16 band near the Orc start; baseline probe, patch and logs archived outside the repo in `~/projects/grudgelands-orchestration/r24/coal-probe/`) | A's rename (branch from it); design and fixtures can start in parallel |
| **C — Art** | Rulings 16–17 and the decorative rock textures, license rows, comparison renders | names fixed above; parallel to A/B, A registers with placeholder tiles |
| **D — Mobs** | Rulings 18–22 | — |
| **E — Tracker and damage** | Rulings 23–24, `combat_stats.md` environmental section | — |
| **D2 — Start-zone follow-up** | Rulings 25–26, 31 | D merged |
| **F — Density, gathering XP, tool levels** | Rulings 27–29 | A, D merged |
| **B2 — Cliff layers, P8 speedups** | Ruling 12 extended to steep faces (user, 2026-09-29), output-identical vein speedups | B merged |
| **G — Protection depth** | Ruling 30 | B2 (same ore host code) |
| **G2 — Normal caves below protection** | Ruling 30 addendum (cave content, cultural reservations; hostile spawns in F) | G merged |
| **H — Pausable character creation** | Ruling 32 | — |

## Coordination

- Lanes work in their own worktrees and branches, do not edit `BACKLOG.md`,
  `README.md`, `ROADMAP.md`, `AGENTS.md` or `docs/STATUS.md` (the coordinator
  updates those at integration) and do not run `tools/sync_to_luanti.sh`.
- Every lane gets an independent review before merge; review findings are
  hypotheses to verify, theoretical findings are noted, not escalated into
  fix rounds.
- Performance is reported as comparisons, never as targets; clearly slower
  mapgen or much more complexity goes to the user.
- Engine runs: portable fixtures are the main proof; a few engine runs of at
  most ~5 minutes each, one final run of ~15 minutes over a chosen region for
  Lane B; no full-world runs. `tools/luanti_headless.sh` (isolated user path,
  `LC_ALL=C`), `pgrep -f '^luanti.bin'` empty afterwards. Mapgen work runs no
  PUC.
- Afterwards: fresh world (the user discards test worlds), full preparation,
  playtest.
