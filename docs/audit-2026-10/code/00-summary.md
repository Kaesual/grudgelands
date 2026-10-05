# Code audit summary (October 2026)

Whole-codebase performance and bug review of the Lua game code, baseline
`0f169898` (2026-10-05, Round 36 pushed). Ten review lanes, then an
adversarial verification pass over every High finding and almost every
Medium one. Read-only: nothing under `mods/` was changed. Start with
[the audit README](../README.md) if you have not.

## At a glance

| Lane | Document | High | Medium | Low |
|---|---|---:|---:|---:|
| C1 Mapgen wp40, terrain | [01-mapgen-terrain.md](01-mapgen-terrain.md) | 0 | 7 | 10 |
| C2 Mapgen wp40, settlements | [02-mapgen-settlements.md](02-mapgen-settlements.md) | 0 | 4 | 8 |
| C3 Mapgen wp13 and the wp13/wp40 split | [03-mapgen-wp13.md](03-mapgen-wp13.md) | 0 | 5 | 10 |
| C4 Mob runtime (mobs fork, AI, lifecycle) | [04-mobs-runtime.md](04-mobs-runtime.md) | 2 | 8 | 6 |
| C5 Mob content, bosses, traders, projectiles | [05-mobs-content.md](05-mobs-content.md) | 1 | 6 | 13 |
| C6 Core, HUD, ambience, visuals, map | [06-core-hud-ambience.md](06-core-hud-ambience.md) | 1 | 4 | 11 |
| C7 Combat and progression | [07-combat-progression.md](07-combat-progression.md) | 1 | 3 | 12 |
| C8 Player systems | [08-player-systems.md](08-player-systems.md) | 2 | 7 | 7 |
| C9 Items, crafting, professions | [09-items.md](09-items.md) | 1 | 5 | 10 |
| C10 Cross-cutting architecture | [10-cross-cutting.md](10-cross-cutting.md) | 0 | 4 | 12 |
| **Total (rows)** | | **8** | **53** | **99** |

Counts are table rows after verification. Several rows describe the same
defect seen from different lanes (see [Duplicates](#same-defect-reported-by-several-lanes)),
so the number of **distinct** High defects is **five**. No Critical finding:
nothing found crashes the server in normal play, loses player data or damages
towns/POIs.

Verification outcome for High and Medium rows: 48 confirmed, 7 partly
confirmed (a sub-claim refuted or the cost overstated), 0 refuted, 5 not
verified (PLY-05 … PLY-09, Medium, verification was scoped to High plus the
bug-type Mediums). Several severities were lowered in verification; the tables
in the lane documents already show the final value, and each checked finding
carries a `Verification (phase 2)` line with the evidence.

## The five High defects

1. **Every hit runs the whole equipment-change fan-out** (PLY-01 = CORE-01 =
   CMB-02 = ITM-01, *partly confirmed*). `grug_repair` `wear_stack` runs on
   every landed outgoing action and every non-lethal hit taken, rebuilds the
   stack tooltip about three times, then calls
   `grug_inventory.equipment_changed(..., "durability_metadata")`. That drops
   the armour/affix caches and runs all seven consumers: `apply_stats`
   (with `get_properties`), `grug_abilities` (mana clamp, HUD, description sync
   walking main plus four bags, a second walk for weapon wear),
   `grug_visuals.apply`, and the Character page rebuild — which runs whenever
   Character is the *selected* sfinv page, i.e. by default, open or not.
   Verified estimate: about 0.25–0.5 ms Lua per weapon-wear event,
   0.15–0.3 ms per armour-wear event, scaling with players × hits.
   *Refuted sub-claim:* there is no network broadcast — the engine drops
   unchanged `set_properties` and unchanged formspecs.
   **Better:** treat durability as its own, cheap event. Consumers that do not
   depend on durability return early on that reason (as `grug_gear` already
   does); the tooltip is written once; the caches stay valid. Effort S–M.
2. **A max-HP buff expiring dismounts the rider** (PLY-02, *confirmed*). When a
   food (tier 3+) or Elixir of Vigor buff ends, the engine clamps HP via
   `set_hp`; every `on_player_hpchange` handler sees a negative change. The
   mount handler (`grug_mounts/entity.lua:697`) treats it as damage and
   dismounts — a flying rider drops mid-air without ground search. The same
   cause cancels quest "use" holds (`grug_quests/use.lua:300`).
   **Better:** ignore `reason.type == "set_hp"` from the max-HP clamp (or mark
   the clamp in `apply_stats`) in both handlers. Effort S.
3. **Every hit retargets the mob to the hitter** (MOB-01, *confirmed*). The old
   mobs_redo retaliation block (`mobs/api.lua:3845-3854`) runs after the
   project's threat check and overrides it, so threat, the 120 % hysteresis and
   the taunt lock do nothing in group fights.
   **Better:** route retaliation through the threat table; decide the policy
   first (open question for Jan in C4). Effort S once the policy is set.
4. **The melee swing animation is overwritten one step after the punch**
   (MOB-04, *confirmed*). The 2026-09-16 contact-run patch writes `stand`/`run`
   every step in reach; nothing holds the punch animation. One GUI look advised.
   Effort S.
5. **The rare watchdog spawns duplicate named rares** (MOC-01, *confirmed*).
   A rare counts as lost after 2–4 h of game time without being seen, also
   while no player was near; `seen_at` is not persisted; the scan only sees
   active objects while "near" means 120 nodes and the rare patrols routes up to
   ~160 nodes apart. Nothing removes duplicates on reload. A second Grimtusk is
   a realistic outcome on a long-running server.
   **Better:** persist liveness and dedupe on activation (the rare removes
   itself if its id is already alive), count absence only while players are in
   range. Effort M.

## Same defect reported by several lanes

Treat each group as one item when planning fixes. The lane documents keep their
own rows so each area reads completely.

| Defect | Rows | Final severity |
|---|---|---|
| Equipment-change fan-out per hit | PLY-01, CORE-01, CMB-02, ITM-01 | High |
| Furnace recipe book pushed away every second | PLY-03, X-01 | Medium |
| Emerge keeps ~310–410 MiB of settlement cells (the `build = function() return source end` closure pins them) | MGS-01, W13-01 (see also MGT-06, Low) | Medium |
| Per-chunk asserts stop the server; the seed fleet never runs `plan_slice` or the writer | MGT-01, MGS-02 | Medium |
| Dragon `alive` flag without liveness check; removal at `mob_active_limit` loses it forever | MOB-03, MOC-03 | Medium |
| Capital collar materials declared in two files | MGS-03, W13-06 | Low |
| Runtime assembly copied into six tool harnesses | MGT-07 (Medium), MGS-10 (Low) | Medium |
| mobs_redo is a hard fork, not a vendored copy | MOB-08, X-06 | Medium |
| Overrides that only work because of the current mods-loaded order | PLY-08, X-05 | Medium / Low |
| Per-race material tables in five places | MGS-04, W13-04 | Medium |
| Unapproved sounds play outside `grug_sounds` | MOC-07 (code), DP-05 (docs) | Medium |

## Proposed fix packages

Ordered by value for effort. Each package is small enough for one round lane.
The verification lines in the lane documents give the exact evidence.

**P1 — Player combat hot path** (High). Equipment fan-out per hit (above);
PLY-02 dismount on max-HP clamp; CMB-01 PvP Strike fallback takes the legacy
path (loses `melee_damage_add`, weapon wear, Battlebeat); CMB-04 builtin
knockback on refused punches and at full strength on every PvP cast; then
delete the unreachable WP38 machinery (CMB-03, ~300 lines) once CMB-01 no
longer routes into it.

**P2 — Mob combat behaviour** (High). MOB-01 retarget-on-hit (policy from Jan
first), MOB-04 swing animation, MOB-07 elite telegraph cone tracks the target
during the wind-up, MOB-02 the one-line `follow` fix (every idle mob scans all
players once a second; Medium after verification), MOB-05 `get_staticdata`
clearing `attack`/`state` on mid-life engine saves.

**P3 — Mob persistence and encounters** (High/Medium). MOC-01 rare duplicates,
MOB-03/MOC-03 dragon liveness, MOB-06 shutdown culls mobs activated after the
player joined (confirmed in code; one headless restart test advised), MOC-02
uncapped Bone Call summons that survive the reset, MOC-06 royal guards that
stay dead until a King reset.

**P4 — Small player-visible interaction bugs** (Medium, each S).
ITM-03 seeds/bucket/fishing rod swallow right-clicks on doors, chests and
stations (a water bucket places water in front of a chest); ITM-02 orphaned
tall-crop tops cannot be dug; PLY-03 furnace book; X-02 grass-spread and moss
ABMs from minetest_game green authored town ground and moss cobble roads;
MOC-05 dragon rime/scorch turn snow, plants and water into air (arenas only);
CORE-02 water-guard flow/revert loop about once a second with a block resend
(frequency in a real world unmeasured).

**P5 — Per-player polling** (Medium). CORE-04 minimap full update for every
player every step with no early-out (R32 study: 23–25 ms/s at 100 stand-ins);
CORE-05 never-freed minimap client textures (documented trade-off, cost
unmeasured); PLY-04 Claim Stone scans 10,201 columns before the cheap cube
check, repeated on a held click; PLY-05 inventory polling for quest tracker and
discovery; PLY-06 `marker_states` walks all 540 quests per player per second.

**P6 — Mapgen performance and memory** (Medium). MGT-02 set the decoration
halo to 0 in runtime mode: verified byte-identical candidates in 131/131 chunk
columns, saves 6–25 % of planner plus column-source time (cheapest win in the
audit). MGS-01/W13-01 drop the pinning closure and the duplicate start copies
(about 7–10 % of the 2.9–3.3 GB emerge high-water mark; GC pauses are not
player-visible). W13-02 skip the composition rebuild and hash on a layout-cache
hit (~4 s of boot). MGT-04/MGT-05 surface-only passes and the P9G rescan in
chunks far from the surface. MGS-03 palette rebuilt for all 118 settlements per
non-air chunk (0.77 ms JIT).

**P7 — Mapgen robustness** (Medium). One seed-fleet extension that runs
`plan_slice` and the writer on the pure parts (MGT-01/MGS-02); keep tracebacks
(the wrappers rethrow with `error(result, 0)`); collapse the six harness copies
of the runtime assembly into one (MGT-07). MGT-03 (trees crossing a chunk
border are dropped: 47 % of emergent and 27 % of jungle-tree candidates,
treeless bands at y ≡ 15..50 mod 80 and along chunk borders) is accepted by the
contract; whether players notice is Jan's call.

**P8 — Structure and legacy** (Medium/Low, larger, no gameplay change).
The wp13/wp40 split no longer matches what lives where — C3 has a staged merge
plan (W13-05) and lists ~600 dead lines inside live files; mobs_redo as an
owned fork with ~1,000 lines of dead API (X-06/MOB-08); 16 undeclared upward
dependencies in `mod.conf` (X-07); tooltip text with 3–4 writers that strip
each other's lines (ITM-04); tool lifetimes in six places (ITM-05); ITEMS mods
`dofile` grug_jobs files (ITM-06); duplicated guards and NPC-service rules
(PLY-07, PLY-09); two `mob_level_at` functions with different meaning (X-03,
Low after verification: today they never disagree).

**P9 — Sounds.** Jan accepted the inherited sound set as is (2026-10-05,
see [docs/00-summary.md](../docs/00-summary.md#decisions-for-jan)). Open:
whether the repurposed inherited files count too — `mobs_spell` as the dragon
return warning (gain 1.0 out to 160 m) and the Rift Spawn fuse and burst play
raw outside `grug_sounds` and are in no `approved.txt` (MOC-07). If not, they
need a listening page or go silent.

## Checked and found solid

Worth knowing so nobody re-audits these: money, Bag of Coins and trader
transactions (server-side prices, atomic money, refunds — no dupe vector);
quest turn-in and its preflight; housing protection cost; per-player cleanup on
leave in every lane; no modifier applied twice in the damage pipeline; every
drop-list, shelf and recipe item resolves to a registered item; every Lua-built
texture name exists; no stray globals, one global per mod, no `minetest.`
namespace, every file parses; every change under `mods/BASE` carries a
`GRUG PATCH` marker and is listed in VENDOR.md; explosions and fire cannot
reach towns or POIs (three independent guards); faction naming is clean in
`mods/`. Placement code sorts before iterating string keys — this matters
because LuaJIT's `pairs()` order over string keys differs between processes
(measured by C2; the rule is not yet in `luanti-lua.md`, MGS-11).

## Where the time goes (reference)

Every lane document ends with a **hot-path inventory**: each per-step,
per-chunk and per-event path in its area with a cost class, including the ones
that are fine. [10-cross-cutting.md](10-cross-cutting.md) has the repo-wide
inventories: all globalsteps, ABMs/LBMs, multi-registrant callbacks, mod
storage users, engine overrides, and the mod dependency graph.

Measurements in this audit are LuaJIT runs of the real Lua files in isolation
and reasoning from engine source; no engine run, no profiling under load.
Figures are comparisons, not targets.

## Full index

All code findings, sorted by final severity. Verification is shown for High
and Medium; `—` means not verified.

| ID | Sev | Category | Title | Verification | Lane |
|---|---|---|---|---|---|
| MOB-01 | High | Bug | Every accepted hit retargets the mob to the hitter, overriding threat, hysteresis and the taunt lock | Confirmed | [04](04-mobs-runtime.md) |
| MOB-04 | High | Bug | Melee swing animation is overwritten one server step after the punch (contact-run patch) | Confirmed | [04](04-mobs-runtime.md) |
| MOC-01 | High | Bug | Rare watchdog spawns duplicate named rares after a few hours without visitors | Confirmed | [05](05-mobs-content.md) |
| CORE-01 | High | Perf | Every settled swing/cast fires the equipment seam; consumers rebuild the Character formspec, recompose the look, re-apply stats | Partly confirmed | [06](06-core-hud-ambience.md) |
| CMB-02 | High | Perf | Every landed or received hit runs the full equipment-change fan-out (durability write) | Partly confirmed | [07](07-combat-progression.md) |
| PLY-01 | High | Perf | Every hit dealt or taken runs the full equipment-change chain: Character page rebuild, `get_properties`, an unconditional `set_properties` broadcast, ability description sync | Partly confirmed | [08](08-player-systems.md) |
| PLY-02 | High | Bug | Any drop of max HP (a food or Vigor buff expiring) dismounts the rider; on a flying mount the rider falls | Confirmed | [08](08-player-systems.md) |
| ITM-01 | High | Perf | Every hit and every action rebuilds the worn item's tooltip three times and fires the full equipment-change fan-out, which also empties the armour and enchant caches | Partly confirmed | [09](09-items.md) |
| MGT-01 | Medium | Agent-trap | Any per-chunk tripwire stops the server, and no seed run exercises the per-chunk path | Confirmed | [01](01-mapgen-terrain.md) |
| MGT-02 | Medium | Perf | The R6 decoration planner builds a 2-cell halo whose candidates the writer never places | Partly confirmed | [01](01-mapgen-terrain.md) |
| MGT-03 | Medium | Legacy | Owner-only writes drop every tree that crosses a chunk border: grid and contour stripes without trees | Confirmed | [01](01-mapgen-terrain.md) |
| MGT-04 | Medium | Perf | Surface-only passes run in every chunk, also far below or above the surface | Confirmed | [01](01-mapgen-terrain.md) |
| MGT-05 | Medium | Perf | P9G repeats its whole 2-D scan in every vertically active chunk and asks the analytic surface once per row | Confirmed | [01](01-mapgen-terrain.md) |
| MGT-07 | Medium | Duplication | The runtime assembly is copied into six tool harnesses; the seed fleet depends on one copy | Confirmed | [01](01-mapgen-terrain.md) |
| MGT-08 | Medium | Agent-trap | The analytic R5/P7 mirror duplicates the planner's seal and surface rules | Confirmed | [01](01-mapgen-terrain.md) |
| MGS-01 | Medium | Perf | Emerge keeps ~410 MiB of settlement cells: POI "laziness" is cosmetic, starts held three times | Confirmed | [02](02-mapgen-settlements.md) |
| MGS-02 | Medium | Agent-trap | Writer-time asserts stop the server and lie outside the seed fleet | Confirmed | [02](02-mapgen-settlements.md) |
| MGS-04 | Medium | Duplication / Legacy | Three ways to bind a settlement to its anchor; three POI builders; five per-race material tables | Confirmed | [02](02-mapgen-settlements.md) |
| MGS-05 | Medium | Agent-trap | Capital, start and anchor-table magic numbers repeated across files | Confirmed | [02](02-mapgen-settlements.md) |
| W13-01 | Medium | Perf / Legacy | Emerge keeps every start's and POI's cells up to three times (≈300 MiB measured; lazy POIs are not lazy) | Confirmed → Medium | [03](03-mapgen-wp13.md) |
| W13-02 | Medium | Perf | Main builds and hashes every composition on every boot, also on a layout-cache hit (≈3.5–4.3 s isolated) | Confirmed | [03](03-mapgen-wp13.md) |
| W13-03 | Medium | Agent-trap | 38 wp13 files claim a retired KAT "asserts/proves" invariants; the registry mirror tables in `parts.lua` have no check | Confirmed | [03](03-mapgen-wp13.md) |
| W13-04 | Medium | Duplication | Five sources of per-race materials (wp13 palette, r14, r20, r31, `SURFACE_TWIN`/`decor_kit.RACE`) | Confirmed | [03](03-mapgen-wp13.md) |
| W13-05 | Medium | Legacy / Agent-trap | The wp13/wp40 split no longer matches what lives where; misleading names; 24 wrapper files | Confirmed | [03](03-mapgen-wp13.md) |
| MOB-02 | Medium | Perf | `follow_flop` runs for every mob because `follow` is nil, not `""`: O(mobs × players) `get_pos` per second | Confirmed →  Medium | [04](04-mobs-runtime.md) |
| MOB-03 | Medium | Bug | At `mob_active_limit` (600), `mob_activate` permanently deletes reactivating authored mobs; a dragon deleted this way never respawns | Confirmed →  Medium | [04](04-mobs-runtime.md) |
| MOB-05 | Medium | Bug | `mob_staticdata` mutates the live mob (`attack = nil`, `state = "stand"`) on engine mid-life re-saves: a chasing mob drops its target | Confirmed | [04](04-mobs-runtime.md) |
| MOB-06 | Medium | Bug | Server shutdown runs the despawn-distance decision with players already gone: wild mobs activated after the player join are culled on the next start | Confirmed | [04](04-mobs-runtime.md) |
| MOB-07 | Medium | Bug | The elite/rare telegraph cone always points at the current target (the mob turns every step during the wind-up), so stepping aside never dodges | Confirmed | [04](04-mobs-runtime.md) |
| MOB-08 | Medium | Legacy | The vendored mobs_redo is a hard fork with about 1,000 lines of dead API and live leftover callbacks; the VENDOR.md update procedure no longer applies | Partly confirmed | [04](04-mobs-runtime.md) |
| MOB-09 | Medium | Agent-trap | Instance fields persist by default; nested userdata crashes the save; property-named fields bypass `self` on reload | Confirmed | [04](04-mobs-runtime.md) |
| MOB-11 | Medium | Agent-trap | Mob behaviour is layered over class, prototype, instance and API wrappers; the spawn row numbers are rewritten before the merge | Confirmed | [04](04-mobs-runtime.md) |
| MOC-02 | Medium | Bug | Undead King's Bone Call: unbounded, factionless summons that survive the encounter reset | Confirmed →  Medium | [05](05-mobs-content.md) |
| MOC-03 | Medium | Bug | Dragon `alive` flag has no liveness check: a dragon removed without `on_die` never returns | Confirmed | [05](05-mobs-content.md) |
| MOC-04 | Medium | Bug | Breath fan and King volley: all three projectiles home onto one target; breath `hit_node` is dead | Partly confirmed | [05](05-mobs-content.md) |
| MOC-05 | Medium | Bug | Dragon rime/scorch replace buildable_to nodes (snow, grass, water) and turn them into air | Confirmed | [05](05-mobs-content.md) |
| MOC-06 | Medium | Bug | Royal guards killed without a King reset stay down until the King resets or dies | Confirmed | [05](05-mobs-content.md) |
| MOC-07 | Medium | Bug | Unapproved sounds outside `grug_sounds`: dragon return warning, Rift Spawn fuse and burst | Confirmed | [05](05-mobs-content.md) |
| CORE-02 | Medium | Bug/Perf | Guarded water boundary can loop forever: flow → Lua revert → engine re-queues → flow, every liquid tick, with block resends | Confirmed | [06](06-core-hud-ambience.md) |
| CORE-04 | Medium | Perf | Minimap does a full update for every player every server step, also when nothing moved | Confirmed | [06](06-core-hud-ambience.md) |
| CORE-05 | Medium | Perf (client) | Minimap builds a never-freed client texture every 13 nodes (normal) / 16 nodes (high); tens to hundreds of MB per long session | Confirmed | [06](06-core-hud-ambience.md) |
| CORE-06 | Medium | Agent-trap | Status reads expire records and fire `on_expire` + modifier callbacks; unknown modifier keys silently refuse the whole status; `dodge_percent` status term is dead | Confirmed | [06](06-core-hud-ambience.md) |
| CMB-01 | Medium | Bug | PvP Strike fallback (Loose or a cast skill wielded) takes the legacy proportional path: loses `melee_damage_add`, durability, trinket proc | Confirmed | [07](07-combat-progression.md) |
| CMB-03 | Medium | Legacy | WP38 tool/fist accumulator, wear accumulator and ordinary-input clock are unreachable (≈300 lines plus misleading comments) | Confirmed | [07](07-combat-progression.md) |
| CMB-04 | Medium | Bug | Builtin engine knockback still fires on refused or suppressed player punches, and at full strength on every PvP cast | Confirmed | [07](07-combat-progression.md) |
| PLY-03 | Medium | Bug | At a furnace or dual furnace, the recipe-book button opens the book, then the workspace form pops back every second | Confirmed | [08](08-player-systems.md) |
| PLY-04 | Medium | Perf | Claim Stone placement scans all 10,201 columns before the cheap cube check; a held right-click repeats it about 4×/s | Confirmed | [08](08-player-systems.md) |
| PLY-05 | Medium | Perf | Per-player inventory polling: quest-tracker holdings at 2 Hz, discovery scan of every list at 0.5 Hz and after every inventory action | — | [08](08-player-systems.md) |
| PLY-06 | Medium | Perf | `marker_states` recomputes every quest of both factions once a second per player, with a meta read per offerable quest | — | [08](08-player-systems.md) |
| PLY-07 | Medium | Duplication | The soulbound guard and the bound-skill guard implement the same three seams twice, with diverging coverage | — | [08](08-player-systems.md) |
| PLY-08 | Medium | Agent-trap | Global API monkeypatches and wrappers whose correctness depends on the mods-loaded order | — | [08](08-player-systems.md) |
| PLY-09 | Medium | Duplication | Five NPC-service session and permission implementations with diverging reach, socket and faction rules | — | [08](08-player-systems.md) |
| ITM-02 | Medium | Bug | Tall crops (cane, bamboo, corn) leave upper nodes that cannot be dug when the root goes without `dig_crop` | Confirmed | [09](09-items.md) |
| ITM-03 | Medium | Bug | With seeds, a bucket or the fishing rod in hand, a right-click never reaches the node's `on_rightclick` (doors, chests, stations, harvesting regrowing crops) | Confirmed | [09](09-items.md) |
| ITM-04 | Medium | Agent-trap | Tooltip is a layered string with 3–4 writers that remove each other's lines by pattern; line order depends on the path | Confirmed | [09](09-items.md) |
| ITM-05 | Medium | Duplication | Tool and gear lifetimes are in six places (two of them dead); the wear-remainder arithmetic exists three times | Confirmed | [09](09-items.md) |
| ITM-06 | Medium | Agent-trap | ITEMS mods execute grug_jobs files: station nodes registered by grug_brewing, a grug_jobs API defined by grug_professions | Confirmed | [09](09-items.md) |
| X-01 | Medium | Bug | Furnace workspace re-shows its form every second and pushes the recipe book (or any other form) away | Confirmed →  Medium | [10](10-cross-cutting.md) |
| X-02 | Medium | Bug | Vendored grass-spread and moss ABMs rewrite authored settlement ground and cobble roads | Confirmed | [10](10-cross-cutting.md) |
| X-06 | Medium | Legacy | mobs_redo is a de facto fork, not a vendored tree with a wrapper | Confirmed | [10](10-cross-cutting.md) |
| X-07 | Medium | Agent-trap | `mod.conf` understates coupling: 16 undeclared upward references, three lookup idioms | Confirmed | [10](10-cross-cutting.md) |
| MGT-06 | Low | Perf | The emerge environment retains ~220 MiB of full-volume buffers, two of them pure shadow copies | Partly confirmed, severity changed to Low | [01](01-mapgen-terrain.md) |
| MGT-09 | Low | Bug | The surface-skin opening reads the VM shell: emerge-order dependent at chunk borders |  | [01](01-mapgen-terrain.md) |
| MGT-10 | Low | Bug | A plant rooted on a lower chunk's surface ignores a skin opening there |  | [01](01-mapgen-terrain.md) |
| MGT-11 | Low | Perf | Decoration placement builds every template cell and draws every probability before the cheap rejections |  | [01](01-mapgen-terrain.md) |
| MGT-12 | Low | Legacy | The R5 adapter runs on a shadow VM with a second resolve pass and a full-run prewarm |  | [01](01-mapgen-terrain.md) |
| MGT-13 | Low | Perf | The column-cache hit path validates and `unpack`s on every call |  | [01](01-mapgen-terrain.md) |
| MGT-14 | Low | Legacy | Evidence, capture and replay machinery no tool uses still lives in the production modules |  | [01](01-mapgen-terrain.md) |
| MGT-15 | Low | Agent-trap | "Disabled" headers, R-number names and dual-meaning fields mislead |  | [01](01-mapgen-terrain.md) |
| MGT-16 | Low | Duplication | Small helpers copied per module (P9G digest, heap sort, seed phase, steep memo) |  | [01](01-mapgen-terrain.md) |
| MGT-17 | Low | Legacy | Surface-cave planning is dead code behind an always-nil query and an undocumented setting |  | [01](01-mapgen-terrain.md) |
| MGS-03 | Low | Agent-trap / Perf | Plot-collar palette declared in two places, checked only at generation, rebuilt per chunk for all 118 settlements |  | [02](02-mapgen-settlements.md) |
| MGS-06 | Low | Agent-trap | Start cook/oven sockets hard-coded twice, by two different rules, with no clearance check |  | [02](02-mapgen-settlements.md) |
| MGS-07 | Low | Duplication | PvP fortress gate side computed twice; only one copy honours a `turns` override |  | [02](02-mapgen-settlements.md) |
| MGS-08 | Low | Agent-trap | The terrain-damage guard (`world_alterable`) does not cover roads or POI boxes |  | [02](02-mapgen-settlements.md) |
| MGS-09 | Low | Legacy | The dragon arena's protection box comes from four written air cells |  | [02](02-mapgen-settlements.md) |
| MGS-10 | Low | Agent-trap | The seed fleet and three other tools hand-mirror `r7_runtime`'s assembly |  | [02](02-mapgen-settlements.md) |
| MGS-11 | Low | Agent-trap | `pairs` order varies per Lua state under LuaJIT; one POI builder sorts its palette with locale `<` |  | [02](02-mapgen-settlements.md) |
| MGS-12 | Low | Duplication | Byte-order compare and z/y/x cell sort copied 8+ times |  | [02](02-mapgen-settlements.md) |
| W13-06 | Low | Agent-trap | Collar materials are declared in `r7_capital_blueprint` and used in `r7_settlement`; a mismatch fails only in emerge at the first collar chunk |  | [03](03-mapgen-wp13.md) |
| W13-07 | Low | Perf | `palette.new` runs per settlement per non-air chunk (135×, ≈0.84 ms and ≈485 KiB garbage per chunk) |  | [03](03-mapgen-wp13.md) |
| W13-08 | Low | Agent-trap | wp40 patches the wp13 start compositions by coordinate (`r20_civic`, `START_TRAINERS`); no offline tool applies the patch |  | [03](03-mapgen-wp13.md) |
| W13-09 | Low | Legacy | About 600 lines of dead generators and constants in live files |  | [03](03-mapgen-wp13.md) |
| W13-10 | Low | Duplication | `less_bytes` ×6, `sort_cells_zyx` ×3, `rot` ×2; the comment justifying the copy is obsolete |  | [03](03-mapgen-wp13.md) |
| W13-11 | Low | Duplication | Capital service and inn plot ids copied into two other mods instead of read from `capital_services.lua` |  | [03](03-mapgen-wp13.md) |
| W13-12 | Low | Perf | Module re-instantiation: 969 `dofile` per env (parts 332×); ≈0.6 s and ≈19 MiB avoidable, output-identical |  | [03](03-mapgen-wp13.md) |
| W13-13 | Low | Perf | A capital core is built twice on a first start (`plan_all` core landing) |  | [03](03-mapgen-wp13.md) |
| W13-14 | Low | Perf | Lazy rebuilds likely thrash under the row-major preparation order; each rebuild re-hashes |  | [03](03-mapgen-wp13.md) |
| W13-15 | Low | Bug (latent) | The r14 POI builder sorts its palette with locale `<`; a PUC build in a non-C collation can refuse to load |  | [03](03-mapgen-wp13.md) |
| MOB-10 | Low | Perf | Each underground or water spawn attempt scans 33³ nodes for a repellent node that does not exist |  | [04](04-mobs-runtime.md) |
| MOB-12 | Low | Perf | Per-step allocations in the attack branch and the node-read wrapper |  | [04](04-mobs-runtime.md) |
| MOB-13 | Low | Perf | O(players²) per second in the region spawner and the camp and leader ticks; two 128-node scans per region spawn |  | [04](04-mobs-runtime.md) |
| MOB-14 | Low | Agent-trap | Misleading or stale comments: `do_punch` "if false returned", rares' `static_save` note, the explode fuse timer counted twice |  | [04](04-mobs-runtime.md) |
| MOB-15 | Low | Perf | Staticdata carries transient runtime state (`path.way`, timers, looked-at nodes): 1.3–2.1 KB per mob |  | [04](04-mobs-runtime.md) |
| MOB-16 | Low | Bug | `mob_pathfinding_enable` cannot be turned off (`get_bool(...) or true`) |  | [04](04-mobs-runtime.md) |
| MOC-08 | Low | Perf | Enraged dragon re-sends its full object properties every server step |  | [05](05-mobs-content.md) |
| MOC-09 | Low | Perf | Royal guards find their King with a radius-80 object scan every second |  | [05](05-mobs-content.md) |
| MOC-10 | Low | Perf | Projectile homing calls `get_properties()` per projectile per step |  | [05](05-mobs-content.md) |
| MOC-11 | Low | Perf | start-NPC heartbeat scans every settlement row in one step |  | [05](05-mobs-content.md) |
| MOC-12 | Low | Bug / Duplication | Oerkki and Wisp blink through walls and into claims; the blink is copy-pasted |  | [05](05-mobs-content.md) |
| MOC-13 | Low | Agent-trap | Explosion terrain safety rests on `is_protected(pos, "")`; mobs_redo promotes radius 0 to 1 | Confirmed | [05](05-mobs-content.md) |
| MOC-14 | Low | Agent-trap | Homing mob arrows silently ignore `hit_node`, `lifetime`, `drop` |  | [05](05-mobs-content.md) |
| MOC-15 | Low | Agent-trap | Lua `drops` shadowed by drops.json in 7 families; `FUNCTION_DROPS` lists 1 of 3 drop functions |  | [05](05-mobs-content.md) |
| MOC-16 | Low | Legacy | Vendor capital-offset fallback and its globalstep; stale "serves everybody" comment |  | [05](05-mobs-content.md) |
| MOC-17 | Low | Legacy | Inert camp fires in recipe zones keep their 30 s timer; `place_camp` is unused |  | [05](05-mobs-content.md) |
| MOC-18 | Low | Bug | Queued boss loot only arrives at the next join |  | [05](05-mobs-content.md) |
| MOC-19 | Low | Legacy | `grug_projectiles` dead fields: `_grug_travelled` stays 0, `_grug_max_distance` unread |  | [05](05-mobs-content.md) |
| MOC-20 | Low | Bug | Potion refusals go to chat, not the message feed |  | [05](05-mobs-content.md) |
| CORE-03 | Low | Bug | Turning off `grug_atmosphere_enabled` or `grug_atmosphere_zones` silently mutes all region, night and underground beds and the dragon-island thunder | Confirmed →  Low | [06](06-core-hud-ambience.md) |
| CORE-07 | Low | Perf/Legacy | Wield entity polls for orphaning in a per-step `on_step`; `on_detach` exists. The 1 Hz wield poll allocates an ItemStack per player even when nothing changed |  | [06](06-core-hud-ambience.md) |
| CORE-08 | Low | Perf | `get_properties()` on recurring paths (eye position per crosshair refresh, HP bar per injured mob per second, homing per projectile step, environment damage per player per second) |  | [06](06-core-hud-ambience.md) |
| CORE-09 | Low | Agent-trap | Seven protection predicates with subtly different meaning |  | [06](06-core-hud-ambience.md) |
| CORE-10 | Low | Agent-trap | World clock is driven by writing `time_speed` into the global settings every second |  | [06](06-core-hud-ambience.md) |
| CORE-11 | Low | Bug | Positional sounds share one server-wide rate-limit key per event |  | [06](06-core-hud-ambience.md) |
| CORE-12 | Low | Bug | Dying in the rift's void (any `grug_pool_damage` node) prints a fire death message |  | [06](06-core-hud-ambience.md) |
| CORE-13 | Low | Duplication | Three independent per-player zone/territory samplers (location, atmosphere, grug_pvp) |  | [06](06-core-hud-ambience.md) |
| CORE-14 | Low | Duplication | Per-module HUD diff caches and copy-pasted slot schedulers |  | [06](06-core-hud-ambience.md) |
| CORE-15 | Low | Legacy | Unused exports and compatibility adapters |  | [06](06-core-hud-ambience.md) |
| CORE-16 | Low | Bug | Atmosphere mood and ambience bed run for players in character creation (at the engine spawn), which location deliberately skips |  | [06](06-core-hud-ambience.md) |
| CMB-05 | Low | Agent-trap / Duplication | Combat accessors are monkey-patched across mods; the armor-rating formula exists twice | Confirmed →  Low | [07](07-combat-progression.md) |
| CMB-06 | Low | Bug | Lowering `hp_max` with an active shield eats shield points (`set_hp` reason is absorbed) |  | [07](07-combat-progression.md) |
| CMB-07 | Low | Bug | Player nametag shows a stale max HP after gear, talent or buff changes |  | [07](07-combat-progression.md) |
| CMB-08 | Low | Perf | Party HUD calls `get_properties()` per member per member every 0.5 s |  | [07](07-combat-progression.md) |
| CMB-09 | Low | Perf | The 20 Hz input pass reads the wielded stack three times and runs a combat ray every pass while LMB is held |  | [07](07-combat-progression.md) |
| CMB-10 | Low | Bug / Design | Relog resets every ability cooldown and refills mana; talent and trinket ICDs persist |  | [07](07-combat-progression.md) |
| CMB-11 | Low | Duplication | Persisted-ICD and "below X % after a punch" triggers are hand-written four and three times |  | [07](07-combat-progression.md) |
| CMB-12 | Low | Agent-trap | Stale consumer map in `EFFECT_KEYS`; `post(context)` handed to a parameter named `action_id` |  | [07](07-combat-progression.md) |
| CMB-13 | Low | Bug | Mend ticks on a global 3 s phase, not from the cast |  | [07](07-combat-progression.md) |
| CMB-14 | Low | Bug | Loose tooltip promises a target requirement and a fixed 2.5 s draw that the code does not have |  | [07](07-combat-progression.md) |
| CMB-15 | Low | Naming | `/faction` prints the raw id ("the accord faction") |  | [07](07-combat-progression.md) |
| CMB-16 | Low | Perf | `guard_destinations()` walks every registered node on each Skills page render and each join |  | [07](07-combat-progression.md) |
| PLY-10 | Low | Perf | Quest state is one ever-growing blob; each crediting kill deep-copies and re-serializes it (122 µs and 17.6 KB at 450 completed) |  | [08](08-player-systems.md) |
| PLY-11 | Low | Perf | A Scout's every shot rebuilds and re-sends the Character page (the quiver total label changes) |  | [08](08-player-systems.md) |
| PLY-12 | Low | Duplication | Four Character-page refresh paths and two polls, each with its own change test |  | [08](08-player-systems.md) |
| PLY-13 | Low | Legacy | Personal notices still go to chat in several mods, against the feed rule |  | [08](08-player-systems.md) |
| PLY-14 | Low | Legacy | Dead alias `invalidate_armor` (no caller) and history-heavy comments in `equipment.lua` |  | [08](08-player-systems.md) |
| PLY-15 | Low | Duplication | Seven hand-written "give or drop at feet" sites with different list coverage |  | [08](08-player-systems.md) |
| PLY-16 | Low | Perf | A 10 Hz all-player control and wielded-item poll only for the "weapons go in the hand slots" hint |  | [08](08-player-systems.md) |
| ITM-07 | Low | Duplication | Vendor Weak Healing Potion copies the alchemy potion logic; it sends refusals to chat and has no level gate |  | [09](09-items.md) |
| ITM-08 | Low | Legacy | Nine "derived consumer" meta keys are written on every tooltip rebuild and never read |  | [09](09-items.md) |
| ITM-09 | Low | Legacy | Dead data and dead overrides (REFINEMENTS, fish `on_use`, axe and shovel `uses`, edits of later-removed blocks) |  | [09](09-items.md) |
| ITM-10 | Low | Bug | Placing a slab on a slab uses up the item even when the placement fails |  | [09](09-items.md) |
| ITM-11 | Low | Agent-trap | Gathering catalog: hand-kept manifest digest, plus source-file digests nothing checks |  | [09](09-items.md) |
| ITM-12 | Low | Duplication | grug_artisans repeats grug_professions' helpers and audit with different duplicate-item rules; small tables and helpers are copied across files |  | [09](09-items.md) |
| ITM-13 | Low | Perf | Armour totals are read through the tooltip builder; the shield rating is recomputed on every hit taken |  | [09](09-items.md) |
| ITM-14 | Low | Perf | Every node dug with a tool rebuilds the tool's whole tooltip and serializes the stack twice |  | [09](09-items.md) |
| ITM-15 | Low | Agent-trap | Crafted and rolled equipment and tools store a `tool_capabilities` snapshot in their meta, so later definition retunes never reach existing stacks |  | [09](09-items.md) |
| ITM-16 | Low | Duplication | Two fuel systems: furnaces use their own table, the brewing stand uses engine fuel recipes; charcoal works in one only |  | [09](09-items.md) |
| X-03 | Low | Agent-trap | Two `mob_level_at` APIs; spawn checks use the field, gameplay uses the overlay |  | [10](10-cross-cutting.md) |
| X-04 | Low | Agent-trap | Engine functions and every node definition are patched from feature mods, with no inventory | Confirmed →  Low | [10](10-cross-cutting.md) |
| X-05 | Low | Agent-trap | `on_mods_loaded` overrides that replace callbacks depend on undeclared load order |  | [10](10-cross-cutting.md) |
| X-08 | Low | Legacy | Self-pinned digests and magic population counts turn data edits into startup crashes |  | [10](10-cross-cutting.md) |
| X-09 | Low | Duplication | Give-or-drop reimplemented with four different policies |  | [10](10-cross-cutting.md) |
| X-10 | Low | Duplication | Small helpers copied across mods (esc, first_line, now, deep copy, service gate) |  | [10](10-cross-cutting.md) |
| X-11 | Low | Legacy | Settings that no longer switch anything (R8 cave writer, native baseline) |  | [10](10-cross-cutting.md) |
| X-12 | Low | Legacy | Names that no longer describe the code |  | [10](10-cross-cutting.md) |
| X-13 | Low | Perf | Redundant per-player polling (weapon hint 10 Hz, discovery full-inventory scan 2 s) |  | [10](10-cross-cutting.md) |
| X-14 | Low | Legacy | Mixed formspec coordinate systems (sfinv legacy + v3/v4/v6) |  | [10](10-cross-cutting.md) |
| X-15 | Low | Legacy | Dead vendored code shipped and loaded |  | [10](10-cross-cutting.md) |
| X-16 | Low | Convention | Style drift: 12 files use one-space indentation and `;`-chained lines |  | [10](10-cross-cutting.md) |
