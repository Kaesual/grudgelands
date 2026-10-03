# Round 31 — PvP, appearance and clean-up: round plan

Coordinator: Claude (Opus 5.5), 2026-10-03. Status: **complete locally
2026-10-03** ([completion and GUI checklist](#completion-2026-10-03)); approved
by the user 2026-10-03 (wave 1 go; decisions in §6).

This plan schedules agreed inputs; it does not repeat their rulings:

| Input | What it decides |
|---|---|
| [pvp-plan.md](pvp-plan.md) | geographic PvP (WP41) rulings 1–24, coordinator defaults, `grug_pvp` API, lanes 31a (P1, P2, N) and 31b (S, M, G, Q), tests, GUI list; §6 asks for NPC appearance randomization |
| BACKLOG [Round 31 clean-up lane](../../BACKLOG.md#round-30-carry-overs) | the Round 30 code follow-ups |
| BACKLOG "Dragon arena design iteration" | a small design step for the two dragon arenas |
| Appearance package (user, 2026-10-03, this document §2) | character customization at creation, NPC look randomization, enchant colours on gear |

Routing (user, per session): Claude orchestrates; **Opus implements and
reviews** (independent Opus review per lane, never the implementer);
**GPT-6 Astra** only art and texts (quest texts, captain names; art only if
the generator's output is too plain and the user asks for it).

Round 30 is complete but not yet GUI-tested by the user. Round 31 lanes
branch from main after Round 30; findings of that test become a small fix
lane of this round.

## 1. Lanes

| Lane | Content | Main files | Depends on |
|---|---|---|---|
| **P1** PvP core | pvp-plan §4 and lane P1: `grug_pvp` state, location tick, button, contact, 10 s PvP combat, logout death, death clear, kill credit, stats, combat wiring | new `grug_pvp`; `grug_abilities/init.lua`, `kits.lua`, `scout.lua`; `grug_core/combat.lua`, `combat_ray.lua`, `death_messages.lua` | — |
| **P2** PvP UI | pvp-plan lane P2: PvP tab, status icons, banner subtitle, target-frame marker | `grug_pvp/page.lua`, `hud.lua`; `grug_core/status_icons.lua`; `grug_map/location.lua`; `grug_mobs/target_frame.lua` | P1's API (stubbed until P1 merges) |
| **N** Faction filter | pvp-plan lane N: NPC services and quest givers serve only their faction; map and minimap markers filtered by NPC faction (enemy kings and dragons stay visible) | `grug_quests/npc.lua`, `grug_mobs/start_*`, `grug_map/providers.lua`, `minimap.lua`, `page.lua` | — |
| **C** Clean-up | BACKLOG "Round 31 clean-up lane": drop the zone-query caches after a cold region build, held objective counts capped at `min(count, needed)`, `changed()` also after a failed turn-in reward, the zone-grid encode assert inside the pcall, one runner for every `tools/*` fixture with its arguments | `grug_mobs/spawn_regions*.lua`, `grug_quests/state.lua`, `hud.lua`, `grug_map/location.lua`, new `tools/run_fixtures.sh` | — |
| **A** Character appearance | §2.1: layer system, generator art, preview sheet for the user's approval, then the creation dialog and the NPC look roll | `grug_visuals/compose.lua`, `apply.lua`; `grug_classes/selection.lua`; `tools/wp13/gen_character_visuals.py`; `grug_mobs` guard/villager/vendor/royal visuals | two stages, the user approves the preview between them |
| **B** Enchant colours | §2.2: stat colour table, gear masks, preview sheet for the user's approval, then item and body colouring | `grug_visuals/compose.lua` (after A's layer seam), `grug_quality` / `grug_professions/enchants.lua`, gear textures, a mask tool | stage 2 after A's compose change |
| **DA** Dragon arenas | §2.3: design proposal with pictures for both arenas (preview page, §2.4); implementation only after the user's choice | design doc first; later `grug_mapgen/wp40` arena blueprint, hazard nodes | the user's choice |
| **S** PvP POI structures | pvp-plan lane S in two stages: stage 1 the fortress layout and the two camp layouts with pictures (preview page, §2.4) for the user's approval; stage 2 the blueprints | `grug_mapgen/wp40` blueprints beside the bandit camps, `r20_poi_catalog.lua` | stage 2 after the user's approval |
| **M, G, Q** PvP POIs | pvp-plan 31b: placement and spacing (M), garrisons and generals (G), POI quests with Astra texts (Q) | as pvp-plan §5 | M and G after S stage 2; Q after G |
| **F** Round 30 playtest fixes | whatever the user's Round 30 GUI test finds | — | the test |
| **D** Documentation | pvp-plan docs lane plus `character_visuals.md` (layers, options, enchant colours), `inventory_equipment.md`, BACKLOG/ROADMAP/README/STATUS | docs | end of round |

Changes against the pvp plan, with reasons:

- **pvp-plan §6 (NPC look randomization) goes into lane A.** *Why:* players
  and NPCs share one composition function and one option table; two lanes
  would build the same thing twice.
- **G uses A's look roll** for camp guards, fortress elites and generals
  (fortress guards roll a race of their faction; town NPCs stay within their
  settlement's race). *Why:* the user's constraints in pvp-plan §6.

## 2. Appearance package (user rulings, 2026-10-03)

### 2.1 Characters and NPCs (lane A)

1. **Layer system with own art.** The technique of VoxeLibre's `mcl_skins`
   (a mask coloured by texture modifier plus a greyscale shading layer,
   composited into one 64×32 skin; the same UV layout as ours), our own CC0
   art generated by extending `tools/wp13/gen_character_visuals.py`
   (`paint_head`, `paint_hair` split into layer files). No VoxeLibre art, no
   clothing categories (race dress and armour cover the body). *Why:*
   licence-clean, fits our races, one function for players and NPCs.
2. **Categories and option counts** (first version):

   | Race | Skin tones | Hair colours | Hairstyles | Eyes | Race feature (lower face) |
   |---|---|---|---|---|---|
   | Human | 4 | 6 | 4 | 3 | stubble / short beard / moustache |
   | Dwarf | 3 | 5 | 3 | 3 | beard: full / braided / forked / short (hair colour) |
   | Elf | 3 | 5 | 4 | 3 | ear style or face marking |
   | Orc | 3 greens | 4 | 4 (topknot, mohawk, shaved, braids) | 3 | tusks small / large / broken, or war paint |
   | Troll | 3 | 5 | 4 | 3 | tusk size |
   | Undead | 3 | 4 | 3 | 3 glow colours | exposed jaw / stitches / sunken nose |

   Skin tones stay within the race's look (orcs green, trolls blue-grey).
   **Only body features are customizable** — no capes, no clothing, no
   headwear. Every character wears its race's one default dress (one per
   race, as today), which armour covers later anyway.
3. **Helmets:** layer order skin → eyes → hairstyle → helmet → lower-face
   feature. A helmet hides the hairstyle; eyes and the lower-face feature stay
   visible through one shared face-window mask applied to every helmet
   overlay at composition (no helmet art repainted).
4. **One body model, equal hitbox.** All races keep `character.b3d`; each
   race may scale the model a little (visual only, as today: dwarf 0.90 …
   troll 1.12). **Collision and selection boxes are identical for every
   race** (fairness); a fixture asserts it.
5. **Creation dialog** after the class choice, the last step before spawn:
   one page, ◀/▶ per category, a random button, a rotating full-body
   `model[]` preview; "Confirm — cannot be changed later". The look is stored
   once in player meta and is **immutable** (no command, no wardrobe).
   Fresh-server mode: no default migration for old characters.
6. **NPCs** roll a look once at first appearance and keep it in a saved field
   (the bandit race-roll pattern): town and capital NPCs and guards within
   their settlement's race, fortress guards a random race of their faction,
   royal guards race layers plus a tabard, kings a fixed look.
7. **Preview first:** stage 1 delivers the layer art and a preview page
   (every race, every option, with and without helmet, a grid of random
   NPC looks). The user approves or corrects; stage 2 builds the dialog and
   the NPC roll on the approved art.

### 2.2 Enchant colours on gear (lane B)

1. Every armour and weapon texture gets **two non-overlapping pixel groups**:
   group A for the prefix, group B for the suffix. Unenchanted items look as
   today.
2. Each of the **9 affix stats** (Strength, Dexterity, Intelligence,
   maximum HP, maximum Mana, Crit, attack speed, Dodge, armour rating;
   `grug_quality/init.lua`) has one fixed colour; the prefix stat
   colours group A, the suffix stat colours group B. The nine colours are
   chosen to stay distinguishable, also for red-green colour blindness. A
   legend in the enchanting dialog.
3. The colour shows on the inventory icon and the wielded weapon (per-stack
   image meta, which the wield entity already honours) and on the armour
   worn on the body (composition key includes the colours). Helmet colours
   apply only to the visible part (face window, §2.1.3).
4. Named mobs and kings get fixed or rolled colours, visual only (their
   drops are unchanged); ordinary guards and mobs stay plain.
5. **Masks** are derived by a script from each texture's colour clusters
   (accents → A, fittings → B) and checked on a **preview page** (every item
   plain and with sample colours) that the user approves before stage 2.

### 2.3 Dragon arenas (lane DA)

A short design proposal for both arenas (Wyrmglass ice dragon, Stormscale
jungle dragon): today's shape with pictures, two or three hazard concepts per
dragon (for example lava or ice pits, spiked pillars, cover, height steps)
with how each changes the fight, protection (the 32-node core is protected;
whether the fitting ring up to 96 nodes needs it too), and the effort. The
user picks; implementation follows in wave 2 if it stays small, otherwise
Round 32.

### 2.4 Approvals and scope (user, 2026-10-03)

- **The user approves four designs from pictures before they are built:**
  the character layers and options (A stage 1), the enchant colours on gear
  (B stage 1), the fortress and the two camp layouts (S stage 1), and the
  dragon arena concepts (DA). Each preview is a private artifact page the
  coordinator publishes (as the Round 29 quest sample); the user approves or
  corrects in the chat, the coordinator records the ruling in this plan.
- **If a package grows too big,** the coordinator brings it to the user,
  and the two decide together which part moves to Round 32. No lane cuts
  scope on its own.

## 3. Waves

**Wave 1 — 31a and the design stages (8 lanes):** P1, P2, N, C, A
stage 1, B stage 1, S stage 1, DA proposal. *Why:* P2 builds against P1's
API from the start; A, B, S and DA start with art, layouts and previews,
which touch no shared code, so the user's approvals are ready when wave 2
starts; C's files are small edits beside N and P2 (contact points below).

**Wave 2 — as approvals and merges arrive:** S stage 2 after its approval,
then M and G in parallel, Q after G; A stage 2 after its approval; B stage 2
after its approval and A's compose change; DA implementation if chosen and
small; F once the user has tested Round 30. At most eight lanes at once.

**Wave 3 — integration:** one fresh-world engine check, D, sync, the user's
GUI test with two clients.

Contact points:

- **C ↔ N ↔ P2:** `grug_quests/state.lua`/`hud.lua` (C) beside
  `grug_quests/npc.lua` (N); `grug_map/location.lua` (C's assert, P2's
  banner subtitle). Whoever merges second rebases; no shared functions.
- **A ↔ B:** both extend `compose.lua`. A owns the layer seam (the spec's
  `look` field and the cache key); B adds its colour layers on top after A
  merges.
- **A ↔ G:** G calls A's look roll; until A's stage 2 merges, G uses the
  current race skin.
- **P1 ↔ Round 30:** the crosshair throttle and ray reuse of Round 30 stay;
  P1 classifies an unflagged enemy as no target inside that code.

## 4. Rules for every lane

- AGENTS.md; `tools/check_lua.sh` on every changed Lua file; LuaJIT only.
- Headless only through `LC_ALL=C tools/luanti_headless.sh` under
  `chrt --idle 0`, own run root, kill only your own run, `pgrep` clean
  afterwards; never the user's Luanti folder.
- Mapgen (S, M, DA): a few engine runs of at most about 5 minutes over a
  chosen region; one final check of about 15 minutes; never a full world.
- Fresh-server mode: no migrations, no compatibility code.
- Numbers are comparisons, never targets; noticeably slower or much more
  complex → back to the coordinator. PvE combat must not notice PvP
  (pvp-plan's guiding rule): P1 reports a PvE combat micro run before/after.
- Quest lanes (Q): the Round 29 quest-lane rules (six seeds, no doubled
  locations, places only as placeholders, no fixed compass words, protected
  title prefixes in the Astra brief).
- Art: generator output CC0 with `LICENSE-media.md` rows; no third-party art
  without a licence row.
- Agents never push; the coordinator merges after review, the user pushes.

## 5. Verification

Offline per lane: pvp-plan §8 (flag-state test, spacing check), A (option
table per race, layer order, face window, equal hitbox fixture, immutable
look after creation, NPC look persistence), B (colour table, masks
non-overlapping and inside the texture, unenchanted icons byte-identical,
per-stack image on enchant change), C (each follow-up with a fixture; the
fixture runner passes on main).

Engine: one boot per code lane; S/M/DA small region runs; final ~15 min
check (a fortress and two camps, faction filter on map, a created
character's look on a second boot, enchant colours on a dropped and a
wielded item).

User: the four preview pages (A, B, S, DA, §2.4) during the round; GUI at the end
pvp-plan §9 (two clients) plus: creation dialog and confirm; look kept after
relog; helmet hides hair but not eyes and beard/tusks; NPC variety in a
town and a capital; enchanting changes the item colours in inventory, hand
and body; a named mob and a king look distinct; the Round 31 clean-up items
need no GUI check.

## 6. User decisions (2026-10-03)

1. **Wave 1 go** with P1, P2, N, C, A stage 1, B stage 1, S stage 1 and the
   DA proposal.
2. **pvp-plan coordinator defaults accepted:** no innkeeper in the fortress,
   one Quartermaster, camp garrisons 4/5 guards plus a captain, respawn about
   2/5 min, generals respawn like kings, POI quests counted in the front
   ledger.
3. **Previews for approval** of fortress and camps, dragon arenas, character
   layers and enchant colours (§2.4); a package that grows too big is split
   with the user, the rest moves to Round 32.
4. **Customization covers body features only** (§2.1.2).

### Preview rulings (user, 2026-10-03, after wave 1)

5. **Character layers (A) approved** for the first version. One check in
   stage 2: on several pictures (mostly metal helmets) the back and side of
   the head look transparent; find out whether that is the preview renderer
   or a real gap in the composed skin, and fix it if real.
6. **Fortress and camps (S) approved** with every first proposal on the
   page; fortress size **49 × 49**.
7. **Enchant colours (B) need another design round:** the items, armour
   most of all, look too colourfully pixelated. Smaller pixel groups
   throughout and the colours overlaid at **50 %** strength; a new preview
   before stage 2 (GPT-6 Astra may help with the art if needed). The
   colours are visual **accents, never a redesign** of the base item; a
   narrow stripe is usually enough. **Second preview approved** for the
   first version: variant N (thin stripes, about 7 % of an icon and 4 % of a
   worn overlay per group, 50 % strength), the nine colours unchanged, no art
   pass.
8. **Mounted hitbox:** every tier-2 mount gets the same collision and
   selection box (fairness, as §2.1.4); the flying mounts of tiers 3 and 4
   are equalised across the factions too.
9. **Healer fallback:** support that is not allowed on the aimed ally (an
   unflagged healer aiming at a flagged ally) does nothing and costs nothing,
   instead of falling back to the caster.
10. **Target frame:** an enemy who cannot be fought shows grey (as built).
11. **Dragon arenas (DA), redesigned by the user:**
    - The arena floor uses the local ground (stone, grass and so on) instead
      of dirt, with a lightly randomized edge so it does not read as a placed
      square; the floor may be gently undulating (mapgen), never rough.
    - **Bigger arenas that show the dragon's leash:** the arena's clear edge is
      the leash. When the dragon has no active hostile target left inside its
      arena, the fight ends: the dragon heals fully and flies back to its spawn
      point. (This replaces the Round 30 "dragons only wait" rule for dragons;
      kings keep theirs.)
    - **Ice (Wyrmglass):** breaking ice that turns into ice water — fixed
      damage per second suited to level 60 (about 250/s), not reduced by
      armour, plus a slow; flat frost terraces, clearly distinct from the
      breaking ice. **No ice pillars** (cover and dragon pathing).
    - **Jungle (Stormscale):** glowing ember fissures framed by basalt, about
      350/s, no slow; fallen trunks **one node high** — a small obstacle players
      jump over, which the dragon walks or flies over; not cover.
    - Coordinator defaults (veto welcome): the proposal's height fix (a
      player inside the arena is a target whatever their height) and
      protection for the whole arena, so the hazards cannot be dug out.
    - **Fight participants** (user, after the DA2 review): players who take
      part in a dragon fight (damage or threat on the dragon or its whelps,
      hit by them, or support on a participant) are flagged for that fight;
      while it runs, a flagged player outside the arena circle takes 500
      damage per second. The flag ends when the dragon dies, or at once when
      all players have left the arena and the dragon resets. (This answers
      the healer standing outside the invisible edge.)
12. **PvP POI placement** (user, after the lane-M preview): the fortresses
    lie on the Battlegrounds side of their zone; close to the middle road,
    but the road's course has priority and a narrow side road connects the
    gate; no hostile spawns in fortresses and camps, roaming mobs are nudged
    away from them (chasing in combat is allowed); the map looks the same
    for both factions, only the icons differ: every enemy settlement and POI
    icon (towns, capitals, outposts, the fortress) is hidden, the enemy
    kings, both dragons and the enemy Battlegrounds camps (quest targets)
    stay visible; a fortress cut into a slope is fine within
    limits, and placement checks the relief.
13. **Skill names** (user): skills that carried another game's exact
    spell names are renamed — the priest's direct heal, absorb shield and
    heal over time are now Heal, Shield and Mend (Mend: coordinator default),
    the mage's frost root is Ice Nova; Smite stays for now;
    generic words such as "Sprint" or "Heal" are fine even where other games
    use them too.
14. **General's drops** (user): the normal PvP drops plus a raised chance of
    an enchanted high-level item.
15. **Fortress spot and depth PvP** (user, after the M rework): a fortress
    may lie further from the road where that gives a better spot — near the
    Battlegrounds and the road, but a fitting place beats reshaping terrain;
    the road is flair. PvP in the depths starts at depth tier T4 (land at
    y ≤ −501) instead of T5 (y ≤ −701): under peaceful areas T1–T3 stay
    protected from enemy players like the surface (no mining, no combat),
    own-faction players are flagged by depth only from T4, and from T4 down
    every player may dig and place blocks.
16. **Camp captains and camp quests** (user): a camp captain is not an
    elite; it gets the start-zone bandit leaders' mechanic (1.15× size, 1.5×
    HP) on a normal-tier body, and the camp raid quests are solo quests.

## 7. Orchestration notes (for the coordinator)

- **Start state:** main `4b06f9c9` or later (local,
  not pushed; Round 30 synced, the user's Round 30 GUI test pending → lane F).
- **Worktrees** `.claude/worktrees/r31-<lane>` on branch `r31-<lane>`, copy
  `tools/bin/` into each (ignored by git). Two-stage lanes keep their
  branch; stage 2 continues the same agent (SendMessage) or a fresh one with
  the approved preview noted in its brief.
- **Briefs** in `~/projects/grudgelands-orchestration/r31/`: start from
  `r30/common-brief.md` and `r30/review-common.md` (update round, base
  commit, plan path; keep the rules), one brief per lane naming the plan
  sections it implements. Copy `r30/engine_run.sh` (measuring-run
  semaphore) to `r31/` with its lock path changed. Log every merge, ruling
  and open note in `~/projects/grudgelands-orchestration/r28/HANDOVER.md`
  under a new "ROUND 31" heading.
- **Astra:** `~/projects/grudgelands-orchestration/run_astra.sh 31 <lane>`
  with the brief at `r31/astra-<lane>/brief.md` (texts: captain and general
  names, POI quest texts; art only on the user's request). Quest briefs carry
  the Round 29 quest-lane rules (§4) and protect the title prefixes.
- **Previews:** lanes write a static HTML page (pictures embedded) into
  their worktree's scratch area; the coordinator publishes it as a private
  artifact and asks the user.
- **Merge order:** P1 before P2's final merge; C, N any time after review;
  A stage 2 before B stage 2; S stage 2 before M and G; G before Q; D last.
  Every lane gets an independent Opus review before merge; findings are
  hypotheses until verified.
- **Fixtures:** several `tools/*/fixture.lua` need the repository path as an
  argument until C's runner lands; `tools/r30_p3/run.sh` takes seeds.
- **Final:** one fresh-world engine check (~15 min), D, sync with
  `tools/sync_to_luanti.sh`, the user's two-client GUI test; the user pushes.

## Completion (2026-10-03)

Every lane below is merged on local main (last lane Q, `699a2002`). Each
lane was independently reviewed by Opus (the Astra names by GPT-6.1 Sol),
except the two small follow-ups M2 (a coordinate and tool change) and G2,
which the coordinator checked, and the user's wording clean-up; the
coordinator ran the portable fixtures after the merges
(`tools/run_fixtures.sh`, 63 of 63 on `699a2002`). Not pushed. Lane F did not run: the user's Round 30 GUI test is
still open and can share the fresh world of this round's test. After
`699a2002` the user settled the quest-share question (option (b), see Q).

Final engine check: (coordinator fills in)

### Shipped, by lane

Numbers are each lane's own probe before and after, same seed and area
(comparisons, never targets).

- **P1 PvP core** (merge `fb7f50fc`): the new mod `grug_pvp` with the
  pvp-plan §4 API plus `register_on_change` and `count_npc_kill`; the
  location flag sampled once a second (sticky over ocean), the 60 s button
  and contact flags, 10 s PvP combat through a per-call combat-timer
  duration, death clear, logout death with kill credit and its death
  message, the ruling-16 counters and `/pvpstate`. Contact is detected in
  one place, the hp-change modifier (so absorbed hits count too); the gate
  sits in `valid_target`, the swing handler, the impact re-check of
  `deal_ability_damage` and the crosshair ray (reason `protected`).
  **PvE combat unchanged** (medians, engine micro run): `valid_target`
  against a mob 0.123 → 0.117 µs, the crosshair ray onto a mob 8.03 →
  8.18 µs, a mob's hit through the hp-change chain 16.5 → 16.9 µs,
  `in_combat` 0.049 → 0.050 µs, all within noise; an enemy player's hit
  16.1 → 19.0 µs. **Location tick:** 53 µs per tick for 50 fake players
  (1.06 µs each), 74.5 µs for 100, once a second
  ([pvp.md](../design/pvp.md)).
- **P2 PvP UI** (`b1e651f8`): the PvP tab right after Group (button, state
  with reason and seconds, PvP combat line, the seven counters; re-sent
  once a second only while its text changes), the status icons
  `pvp_contested` and `pvp_tagged` with countdown, the zone banner's red
  subtitle "Contested Territory — PvP enabled" / "Enemy Territory — PvP
  enabled" (the flight warning moves one line down), the target frame's
  "(flagged)" / "(protected)", red only while both can fight.
- **N faction filter** (`f53411a1`): `grug_factions/service.lua` — quest
  givers, vendors (profession vendors take their settlement's faction),
  trainers, the Shipwright, innkeepers, Housing Stewards and waystones
  serve only their own faction, with one refusal line at most every 2 s;
  map and minimap NPC markers per viewer faction (every king and both
  dragons stay), service and quest lists split per faction once at load;
  a faction change refreshes both maps.
- **C clean-up** (`6176efc4`): the world session's query caches dropped at
  the first server step (seed 12345, Lua heap at the first step: first
  start **149 → 110 MiB**, later start 71 → 65 MiB; region maps and zone
  grid identical); held objective counts capped at what one quest takes;
  `changed()` after a failed turn-in reward; the zone-grid encode failure
  inside the pcall (more than 255 zones: used, not stored);
  `tools/run_fixtures.sh` runs every portable fixture (52 at the time, 63
  at the end of the round), and `r23_renewal`/`r23_tree_line` now exit 1 on
  failure.
- **A character looks** (stage 1 art, stage 2 `c8f1d45f`): 84 generator
  layer files (14.9 KB, CC0) on the `mcl_skins` technique — skin tone,
  eyes, hairstyle, lower-face feature per race (counts as §2.1.2); the
  composition order with the shared helmet face window; the look step of
  character creation (◀/▶ per category, random, rotating preview, one
  confirm, stored for good); NPCs roll a look once (settlement race, or a
  race of the faction; mixed garrisons by `npc_race{mixed = true}`); royal
  guards in the tabard, kings a fixed look with tabard and crown; the
  painted race and royal skins removed; every armour piece in its own
  parentheses, which fixes the Silversteel `^[hsl` reaching the skin. The
  head that looked transparent under metal helmets in the stage-1 preview
  was dark chain mail on the dark preview background; every head pixel of
  the composed skin is opaque. Equal collision and selection boxes for every race (fixture)
  ([character_visuals.md](../design/character_visuals.md) §1).
- **B enchant colours** (stage 1 and the second design round, stage 2
  `ceb7a2c0`, review notes `a25acde3`): nine stat colours
  (`grug_gear/enchant_colors.lua`, apart also for red-green colour
  blindness), 185 generated two-group masks as thin stripes (about 7 % of
  an icon and 4 % of a worn overlay per group, round 1: 17 % and 12 %), laid
  over at 50 % (opacity 128); the colours on the inventory icon, the held
  and dropped item (per-stack `inventory_image`, removed for a plain
  stack), the worn armour (a helmet's cut by the face window) and the six
  kings' weapons; a 3 × 3 legend at every enchanting station
  ([character_visuals.md](../design/character_visuals.md) §5a).
- **S PvP structures** (`aff55ae8`): the fortress blueprint (49 × 49,
  curtain wall, one gate, keep, barracks, store, armoury, drill yard,
  waystone pad) and the two camp layouts (23 × 23, 27 × 27) in all six race
  palettes; the catalogue `r31_pvp_catalog.lua` (2 fortresses, 16 camps,
  camp bands, the per-world camp race through SHA-256: 18 layouts over 18
  seeds after the review fix); fitting profiles; the roles general,
  bodyguard and captain.
- **P1b** (`8c8be805`): a support cast the flag rules out is refused and
  costs nothing (ruling 9); every tier-2 mount uses the Courser's collision
  box and one selection box; tiers 3 and 4 share one flyer body (1.8 wide,
  1.65 high) per tier; riderless capital displays keep each model's own box
  ([mounts.md](../design/mounts.md)).
- **Names** (`8c289878`): 2 Generals and 48 captain names by GPT-6 Astra
  (`docs/planning/round31/pvp-names.json`), reviewed by GPT-6.1 Sol.
- **Neutral wording** (`a2b5e246`): references to a commercial MMO and its
  publisher removed from docs and metadata; no game name changed.
- **DA2 dragon arenas** (`d3fda6c1`, proposal in
  [round31-dragon-arenas.md](round31-dragon-arenas.md)): round arenas of
  radius 40 (82 × 82 protected) on local ground with a gently swelling
  floor and rim stones; the edge is the leash (a player inside is a target
  at any height, one outside is vetoed, cannot hurt the dragon or hold its
  threat); a fight without a hostile inside resets, heals and flies home;
  Wyrmglass breaking ice (ice water 250/s and a slow) and frost terraces,
  Stormscale ember fissures (350/s) and one-high trunks; the dragon's wrath
  (500/s to participants outside, bypasses absorb). Fixture 7446 checks
  ([world.md](../design/world.md) §4b).
- **Skill names** (`d9cbc018`, plans `61db78e4`): Heal, Shield, Mend and Ice
  Nova (ids `heal`, `shield_spell`, `mend`, `ice_nova`) replace another
  game's spell names; Smite stays.
- **M PvP placement** (`36e21da9`, re-pick M2 `61b669bd`): anchors 101–118;
  Ashenward Bastion (136, −488) and Bannerbreak Warhold (−80, 632) on the
  Battlegrounds half of their zone, dry and flat (relief at most 33 and 24
  on six seeds), 51–134 and 20–45 nodes off the middle road, which keeps
  its course on all six seeds (maximum deviation 0), with a gate trail;
  the 16 camps per zone and faction (nearest PvP pair 223 nodes, at least
  120); protection + 10 nodes (`fortress`, `war_camp`); no hostile ambient
  spawns and roamers nudged away; seven waystones per faction; settlement
  icons per viewer faction (`grug_map/settlement_icons.lua`). Lane M first
  reported one rerouted outpost trail; the review found that several
  secondary roads and trails take another course per seed (0–6 on the six
  seeds); the docs say so ([world_zones.md](../design/world_zones.md) §16).
- **G garrisons** (`0160cde6`, G2 `92834cfe`): `grug_mobs/pvp_garrison.lua`
  (pure rules over the catalogue and the names); fortress 12 guards
  (2 gate, 10 inner) level-60 elite of mixed races, the General (level-65
  elite, king chassis without crown, his seat king's weapon colours) with
  2 bodyguards; camps 4/5 guards in the band and the named captain, after
  the user's ruling a normal-tier leader (1.15 × size, 1.5 × HP); respawn
  fortress guards 3–6 min, camp guards 100–140 s, captains 270–330 s, the
  General's group like a king's; kill counting for the PvP tab; the
  General's gear roll on an enemy player's kill (item level 65, 60 %
  uncommon, 25 % rare).
- **P1c** (`f01021fe`, notes `81265c06`): `CONTESTED_DEPTH_Y = −501` for PvP
  and for digging/building by either faction (was −701).
- **Q fortress quests** (`699a2002`, texts by GPT-6 Astra): 12 quests per
  faction from level 40 — 8 solo camp raids (guards and captain within the
  camp's area), 3 ordinary fortress quests, 1 entry quest from an outpost;
  garrison kill objectives with the enemy-faction check
  (`E-garrison-faction`), PvP POIs as placeholder targets; 0 missing targets
  on six seeds; 515 quests in total. **Quest-share ledger** (`ledger.py
  --game --track <race> --repeat 2`, solo questing share, target in
  brackets): before Q human 40→50 77 % (70), 50→60 103 % (70), orc 74 %,
  85 %; with Q human 108 %, 123 %, orc 102 %, 104 %. **User ruling
  (option b):** the raids' reward weights 5 (picket) / 6 (war camp) → 3 /
  4 (coordinator commit on main after `699a2002`); then human 30→40 134 %
  (80), 40→50 104 %, 50→60 119 %; orc 30→40 120 %, 40→50 98 %, 50→60
  101 %. Most of the rest is the raid targets' kill XP, not the reward
  weights; the human 50→60 overshoot predates the round (103 %).
- **D**: this section, [pvp.md](../design/pvp.md), the pvp-plan docs lane,
  the status files, the module guide and AGENTS.

### Rulings made during the round

§6 holds them in full; in short:

1. Wave 1 go (P1, P2, N, C, A1, B1, S1, DA proposal).
2. pvp-plan coordinator defaults accepted (no innkeeper in the fortress,
   one Quartermaster, camp garrisons 4/5 + captain, respawn about 2/5 min,
   Generals like kings, POI quests in the ledger).
3. Previews before building; a package that grows too big is split with
   the user.
4. Customization covers body features only.
5. Character layers approved; the transparent-head check (no gap: dark
   chain mail on a dark preview background).
6. Fortress and camps approved, fortress 49 × 49.
7. Enchant colours: accents, never a redesign; round 2 approved (thin
   stripes, 50 %, colours unchanged, no art pass).
8. Equal mount boxes for tier 2, and per tier for the flyers of tiers 3/4.
9. A refused support cast does nothing and costs nothing.
10. An enemy who cannot be fought shows grey in the target frame.
11. Dragon arenas redesigned (local ground, bigger arena = leash, reset heal
    and fly home, ice water 250/s + slow, frost terraces, no pillars, ember
    fissures 350/s, trunks one high; height fix and whole-arena protection;
    the dragon's wrath 500/s for participants outside).
12. PvP POI placement: fortresses on the Battlegrounds side, the road has
    priority, a side road to the gate; no hostile spawns in fortresses and
    camps; enemy settlement and POI icons hidden (kings, dragons, enemy
    war camps stay); a fortress in a slope within limits.
13. Skill renames: Heal, Shield, Mend, Ice Nova; Smite stays.
14. The General's drops: PvP drops plus a raised chance of an enchanted
    high-level item.
15. Fortress spot before road distance; PvP and building rights in the
    depths from T4 (y ≤ −501), T1–T3 under peaceful land protected.
16. Camp captains are leaders, not elites; camp raids are solo quests.

After `699a2002` (user): option (b) for the quest share — raid weights 3/4.
Coordinator defaults noted to the user: a healer joins a dragon fight only
within the arena radius + 15; the wrath bypasses absorb; unflagged enemies
block the crosshair ray like friendly players; kill credit only to online
attackers. Fixed positions for the PvP POIs this round; seed-dependent
placement is an open decision before the next round (BACKLOG).

### Open items

In the [BACKLOG](../../BACKLOG.md#round-31-carry-overs): seed-dependent POI
placement (a decision before the next round); the enchantment and
item-level revision; the quest XP share above 100 % in several bands; the
remaining first-start heap (about 45 MiB above a later start, the
grug_mapgen first-start load, not caches); the grug_mapgen warm-load
proposal (#22, still the user's call). For the GUI test (notes, not
reproduced as faults): the tab order (Quests and Group sit behind Map;
pre-existing, the Map tab has no ordering hook), 10 survival tabs at
1280 × 720, the flight warning's 4 px headroom at 720p and GUI scale 1,
the per-tier selection box of the tier-3/4 flyers (sized for the highest
seat), the capital mount displays' boxes and name tags, Dragon Rime on
thin ice, the refreeze radius of broken ice, a breath splash just outside
the rim (damage without a fight flag), Mend ticks after the helper's flag
ends (allowed by ruling 6), a profession vendor outside a settlement would
serve everyone (none exists). The enchant masks keep their source
texture's licence (CC BY-SA derivatives, not CC0). The seed-42 gate-walk
warning of the M probe was a probe artefact (the path is open).

### GUI playtest checklist

Two Flatpak clients on one local server and a **fresh world** (Round 31
changes the mapgen: PvP POIs, dragon arenas, roads): one Accord and one
Throng character at level 40+ and one low-level character. Helpers:
`/xp give`, `/teleport`, `/pvpstate` (privilege `server`).

PvP (pvp-plan §9 as built):

1. **Own peaceful zone, both unflagged:** the enemy is no target (neutral
   crosshair; target frame grey with "(protected)"); Ice Nova next to them
   does nothing to them; nothing is paid.
2. **"Flag me for PvP"** on the PvP tab: the "PvP flagged" icon counts down
   from 60 s, the tab shows "Flagged for N s"; still no hits until the
   other is flagged too; both flagged → the frame turns red, hits land.
3. **Contested zone** (a 31–40 zone): banner subtitle "Contested Territory
   — PvP enabled" and the contested icon; fight; walk back into own
   peaceful land right after → stays flagged for 60 s after the last hit.
   Walk out without fighting → safe at once.
4. **Enemy start zone or capital:** "Enemy Territory" subtitle and icon;
   enemy guards attack; their unflagged low-level players cannot be hit
   and cannot hit you.
5. **Healer:** an unflagged priest aiming Heal, Shield or Mend at a flagged
   friend gets "You must be flagged for PvP to support a flagged ally.",
   no mana spent, no self-heal; after the button the cast works and keeps
   the priest flagged by contact.
6. **PvP combat:** after a PvP hit no mount, no eating, no travel home and
   no waystone for 10 s; the PvP tab shows the combat line.
7. **Logout death:** log out during a fight; the other sees the kill and
   "… fled the fight and fell."; the logged-out character starts dead and
   respawns at the innkeeper.
8. **Boats:** from the own coast unflagged at sea; arriving at a dragon
   island flags; sailing home keeps the flag until own land.
9. **Flight** from own land into contested ground and back without
   dismount; warning and dismount at enemy peaceful land.
10. **Depth:** under the enemy's capital at y −500 its own players stay
    safe (you are flagged as in enemy territory) and you cannot dig; at
    y −501 both are flagged and anyone may dig and place.
11. **Faction filter:** enemy quest giver, vendor, trainer, innkeeper and
    waystone refuse ("… I serve only The Accord."); map and minimap show
    no enemy NPC markers except the enemy kings and both dragons; the
    enemy's starts, capitals, villages, outposts and fortress have no icon,
    the enemy war camps do.
12. **PvP tab statistics** after kills, killing blows, deaths and kills of
    enemy guards, captains, a General or a king.
13. **Fortress** (both): one gate held by two elites, ten elites inside,
    the General with two bodyguards and his coloured weapon, three quest
    givers and the Quartermaster; the waystone is in the list (7 entries);
    the enemy's stone is inert; the gate trail reaches the middle road;
    flying over the wall works; no hostile mobs spawn inside.
14. **Camps:** both factions' picket and war camp in each Battlegrounds
    zone, in race materials; own guards friendly, enemy guards hostile;
    the named captain a little larger than his guards (1.15 ×) with more
    HP, not elite; guards back after about 2 min, the captain after about
    5; spacing feels right.
15. **Fortress quests:** from level 40 the three givers offer the camp
    raids (solo), the ordinary quests and the entry quest from an outpost;
    credit only for guards and the captain of the named camp.

Appearance and colours:

16. **Creation:** after the class the look page — ◀/▶ per category,
    random, rotating preview, "Confirm — cannot be changed later"; the
    look is the same after a relog.
17. **Helmet:** hides the hair but not the eyes and the beard, tusks or
    ears.
18. **NPC variety:** varied looks within the race in a start town and a
    capital; fortress guards of mixed races; kings and the General
    distinct.
19. **Enchant colours:** enchanting changes the item's colours in the
    inventory, in the hand, dropped on the ground and on the body (armour);
    the legend at the station fits next to the repair button; kings and
    the General hold coloured weapons.

Dragon arenas (both):

20. Round arena on local ground, rim stones at the edge; pull the dragon
    and step outside: it stops, heals and flies home; shooting from outside
    does nothing; standing high inside it still attacks.
21. During a fight, step outside the rim (or heal from outside): warning,
    "Dragon's Wrath" status, 500 per second until you return.
22. Wyrmglass: stand still on thin ice (breaks after 1.5 s, ice water 250/s
    and slow, refreezes); Stormscale: an ember fissure (350/s), jump a
    trunk.

Interface:

23. **Tabs:** the survival tab header (10 tabs) fits at 1280 × 720; note
    the tab order (Quests, Group, PvP, Map).
24. Status icons and the banner subtitle are readable; the flight warning
    sits below the subtitle.

The Round 31 clean-up items (lane C) need no GUI check.
