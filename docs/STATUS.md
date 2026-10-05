# Project status

Updated 2026-10-06. This is the delivery pointer, not another game specification.

- **Round 37 "Audit fixes" complete locally, not pushed**
  (2026-10-06, [plan, completion and GUI checklist](planning/round37-plan.md#completion-2026-10-06)).
  Every lane is merged on main (last lane F, `27e5db87`, then this
  documentation lane D), each code lane and each non-trivial docs lane
  independently reviewed by Opus; 106 fixtures pass, `validate.py --game`
  0 errors, `income.py --check` passes. The round fixes the
  [October 2026 audit](audit-2026-10/README.md)'s code packages P1–P5, the
  mapgen win MGT-02 with P7, the sound question P9 and the documentation
  packages A–F. Lane MG changed the generator's code but not its output
  (`seed_fleet quick` 100 of 100, every roster hash unchanged), so **no
  fresh world is needed beyond Round 36's**; the round-end `full` seed
  fleet runs on `27e5db87` (its result: the completion's "Round end"
  line).
  - **Combat (CB, MB):** durability as its own cheap event (weapon wear
    217 → 14 µs, a taken hit with armour 296 → 31 µs), the max-HP clamp
    is not damage (mounts, the quest use-hold, shields), one knockback
    rule, the dead WP38 path removed; a hit retargets a mob only through
    threat, the full swing animation, the elite wind-up freezes its facing
    and pauses its attacks ([combat_stats.md](design/combat_stats.md)).
  - **Mobs and bosses (MP, F):** one liveness rule for named rares and
    dragons, authored actors outside the mob cap, a restart keeps the
    world's mobs, Bone Call capped, royal guards return, the side shots of
    the breath fan and the King's volley fly straight; start zones fight
    alone, the Salt Reef Lurker on the 51–60 coasts.
  - **Interaction and polling (IX, PO, F):** right-click with seeds, a
    bucket or the rod, tall crops, the furnace form, grass and moss on
    authored ground, the water-guard loop (1560 reverts in 120 s → 0);
    the minimap and quest markers update only on change, the tracker,
    discovery and Claim Stone scan do less (all Lua at 100 stand-ins
    98.9 → 82.5 ms/s); the minimap always at normal quality.
  - **Mapgen (MG):** no decoration halo (planner −8 %, byte-identical),
    one shared world assembly, tracebacks kept, the seed fleet plans and
    writes five real chunks per seed (about 25 s per seed).
  - **Sound (SN):** the user's picks for the dragon's return and the Rift
    Spawn's fuse and burst.
  - **Documentation (DA–DF):** status synced, AGENTS.md slimmed to working
    rules with the [round workflow](process/round-workflow.md) and one
    owner per fact, a player README with [CHANGELOG.md](../CHANGELOG.md)
    and version 0.37.0, the world, player and item design docs against the
    code.
  - Next: the user's GUI test (desktop and web build, two clients for the
    group fight and knockback), together with Round 36's, which is still
    open; then Round 38 "Mob names"
    ([draft plan](planning/round38-mob-names-plan.md)), which also fixes
    the quest kill-credit bug the user met.

- **Round 36 "The main questline" (WP9) delivered and pushed**
  (2026-10-05, [plan, completion and GUI checklist](planning/round36-plan.md#completion-2026-10-05)).
  Every lane is merged on main (last the text pass T, `5069b5a5`, then the
  follow-up lanes below, last RD `fef94a6a`), each code and data lane
  independently reviewed by Opus (W2, which only turns blocks, without a
  separate review); 96 fixtures pass, `validate.py --game` 0
  errors; pushed by the user on 2026-10-05 (`1e8a975d`, then `0f169898`
  with the follow-up lanes). GUI test open. **A fresh world is required**,
  made on `fef94a6a` or later (the decor pass, the dragon arenas and the
  follow-up lanes' benches, ground cover and roads are world generation).
  Seed fleet: `quick` 100 of 100 for lanes G, W, W3 and RD; the round-end
  `full` owed after W3 and RD ran at the start of Round 37 on `0f169898`:
  **303 of 303 seeds build**, 0 failed ([Round 37 plan](planning/round37-plan.md)
  §7). WP9 delivered, and WP13's POI review.
  - **The main line (S, E, Q0, Q-A, Q-T, T):** each faction's three
    chapters from its fortress Warmaster at 41, 46 and 53 and a group
    finale at 60, on the approved
    [story bible](planning/round36/story-bible.md) (the Undertithe and its
    branded coin): the front climaxes folded in, a solo captain's orders
    from an enemy war camp on The Shattered Line, a traitor in each
    fortress's own pay line, ten corrupted sub-types with one ember tint,
    the "use at a place" objective with twelve quest objects seen only by
    their quest's holders, a turn-in hook and three achievements with
    cloaks (a faction's row hidden from the other faction); 540 quests
    (+25). Texts by GPT-6 Astra, reviewed by Opus with the user's picks
    ([quests.md](design/quests.md), [story.md](design/story.md)).
  - **The rift (R):** a void crack at Tombroad Ambush (11 % of the maximum
    HP per second, swim out) and Isquarre the Tithe-Eater, a level-60
    elite at twice an elite's health for two or three players, back after
    5 minutes, two blue or gold items once per 24 hours; war commanders
    Greyvow and Stonegrudge in two enemy war camps
    ([world.md](design/world.md) §4b, [pvp.md](design/pvp.md) §6.2).
  - **Fixes (F) and classes (K):** crosshair and click share one target
    predicate with an "Evading" notice; free mobs run home only from
    outside their 32-node wander radius; the level-up banner names talent
    points; Priest heals and absorbs grow with gear Intelligence, the
    Scout's damage set matches the Warrior's, spells floor once after the
    level scalar ([combat_stats.md](design/combat_stats.md)).
  - **Dragons (G):** wider ember fissures, larger ice fields, ice water
    back after 2 minutes and a telegraphed wing gust that pushes players
    about 6 nodes.
  - **Decor pass (P, W; WP13):** every POI rendered on a review page for
    the user's verdicts, then a theme per POI kind instead of the old block
    formations, small touches on every house of the POIs, start towns and
    capitals, benches turned the right way, no window blocked
    ([settlements.md](design/settlements.md) "Decor pass").
  - Prices re-derived after the new quest copper (Expert Riding 1g29s,
    Master Riding 7g38s, the 41–50 respec 5s25c, the crown 1g48s). A second
    text review of the other quest texts landed as `6794af6e` (136 Opus
    suggestions, all accepted by the user; catalogue regenerated in
    `1e8a975d`).
  - **Follow-up lanes from the user's first look** (merged 2026-10-05
    evening, [completion](planning/round36-plan.md#follow-up-lanes-2026-10-05-evening)):
    an LMB held across a hotbar switch goes on with the new skill after it
    stayed selected 0.2 s, and digging goes on across a switch (F2); every
    bench keeps its back to the wall beside it and looks out (W2); the
    protected band round start towns and capitals grows low ground cover,
    still no trees (W3); roads no longer trace the ground's one-node dither
    (`C_STEP` 0.05 → 0.5, no lone half-step bumps or holes; RD).
  - Next: the user's GUI test (desktop and web build, two clients for the
    rift), still open; Round 37's lane F took the user's rulings of
    2026-10-06 instead. The main-menu background waits for the user's
    screenshot.

- **Round 35 "Fixes and character creation" delivered**
  (2026-10-05, [plan, completion and GUI checklist](planning/round35-plan.md#completion-2026-10-05)).
  Every code lane is merged on main (last lane B, `a15bd0ae`), each
  independently reviewed by Opus; 84 fixtures pass; pushed by the user on
  2026-10-05 (`7c4cad0a`). No mapgen change. The fixes come from the user's
  Round 34 GUI test.
  - **Aiming (T):** the server's aiming rays test rotated selection boxes
    in Lua (an engine bug since Luanti 5.12 misreads them), so held casts
    and swings no longer miss zombies, crocodiles and other turned mobs
    (zombie 62 of 288 probe rays → 0, crocodile 32 of 192 → 0); about
    +22–45 µs per ray. The new
    [upstream-workaround list](technical/upstream-workarounds.md) records it
    with the emerge-thread pin.
  - **Music (M):** only in the six capitals, one rotation each, either music
    or the ambience bed (a 3 s crossfade), 5 s between tracks, 35 % by
    default; no music in start towns or elsewhere
    ([sound.md](design/sound.md)).
  - **Small fixes (F):** a break sound when gear breaks (the user's pick),
    a clearly broken look, the bare hand for a skill without a weapon, dig
    sounds for ores, coal, gems and sand, flint removed, quest lists
    coloured by status with "(R)" and read-only quest text.
  - **Character creation (C):** faction, race, class and look in one window;
    nothing is stored before "Create character" ([world.md](design/world.md) §7).
  - **Mobs and economy (E):** night mobs leave at dawn unless fighting or
    within 32 nodes of a player; the rat, crab, fox, crocodile, zombie and
    outlaw drop outliers lowered, band medians unchanged.
  - **Talents (B):** 13 flat talent values became level-proof percentages,
    and the user's picks from a review of all 64 talents
    ([skill_trees.md](design/skill_trees.md) §2.10).
  - Next was the user's GUI test (desktop and web build); its first
    findings joined Round 36 (lane F).

- **Round 34 "Sound" delivered**
  (2026-10-04, [plan, completion and GUI checklist](planning/round34-plan.md#completion-2026-10-04)).
  Every lane is merged on main (last lane S1b, `b0d648f5`), each code
  lane independently reviewed by Opus; every shipped sound was picked by the
  user on a listening page; 77 fixtures pass; pushed by the user on
  2026-10-05 (`86d7c4c5`). No mapgen change.
  Rules: [sound.md](design/sound.md); credits: [CREDITS.md](../CREDITS.md).
  - **Effects (S1a, S1b):** `grug_sounds` with a one-line play helper and
    the formspec click; cues for NPC roles, quests, trade, progression,
    crafting, items, mounts, travel, fishing and the Enable PvP button; hits
    by weapon kind, dodge, block, death, one cue per ability theme, mob
    voices in 22 families, dragon and King cues. Many events stay silent by
    the user's choice (quest accept, drops, crit and others). 118 files,
    1.49 MB.
  - **Ambience and music (S2):** `grug_ambience`: a quiet bed per region,
    night, cave, deep underground and sea (towns at half gain), distant
    thunder on the dragon islands, loops at forges, hearths and flowing
    water; four music pools (Land, Front and sea, Underground, Town; since
    Round 35 music plays only in the capitals) whose 16 tracks are pushed
    to a player only while music is on; a main-menu theme; Help → Sound,
    `/music`, `/ambience`. First-join media 14.10 →
    20.82 MB; the music (30 MB) is never part of it.
  - **Fixes (F1, F2):** mobs follow their target through water in combat and
    swim back to land; text boxes sized to their text; each tier's Caster
    dish costs the most; the Bag of Coins (withdraw and deposit, money
    between players); map markers for the Crownbinder and the Decor
    Merchant; the damage fit keeps attribute fractions; encounter adds drop
    no gear; Wyrmglass thin ice breaks 1 s behind a runner.
  - Late fixes: rivers never cover a POI core (about 1 % of random seeds
    failed to load since Round 29), a reusable seed fleet
    (`tools/seed_fleet/run.sh`), the Wisp's blink never lands in water.
  - Next was the user's GUI test (desktop and web build); its findings
    became Round 35.

- **Round 33 "Items, professions and achievements" delivered**
  (2026-10-04, [plan, completion and GUI checklist](planning/round33-plan.md#completion-2026-10-04)).
  Every lane is merged on main (last lane C5, `16c498b9`), each code
  lane independently reviewed by Opus; the data lane DS approved by the user
  through its preview; 72 fixtures pass, `income.py --check` passes again;
  pushed by the user on 2026-10-04, after Rounds 30–32. **A fresh world is
  required** (the cultural materials leave the mapgen). Numbers in [item_tiers.md](design/item_tiers.md).
  - **Drops (C1):** at most one item per kill, normal 5/2/1 % white/blue/gold,
    named, elite, zone leaders and war-camp captains 10/10/5 %; Kings,
    dragons and the General two blue or gold items at item level 65/70 with
    T7 enchants; bags as 0.1 % world drops; shields, spellbooks and trinkets
    in the pool; every equipment slot requires min(item level, 60); blue
    sells ×3, gold ×6; the Kraken Guard a level-70 elite without XP or drops.
  - **Professions (C2, C4):** Alchemy is a secondary beside Cooking with its
    own book slot; progress only from real recipes; enchant values grow with
    item level up to the tier's cap, the tier shows in the tooltip, T7 from
    boss drops and the crown; a weaker overwrite is warned; each profession
    upgrades its families to the tier's top; bows go to the Leatherworker,
    spellbooks to the Tailor; removed: cultural materials and finishes, the
    PvP counter, the Warding Draught, grips, reagents, apothecary gear,
    Ornament Components ([professions.md](design/professions.md)).
  - **Vendors, combat and capitals (C5):** vendors sell T1 bases only and buy
    back all gear; repair ×1.00; Healing and Mana Potions I–VI with one 60 s
    cooldown; crit ×2 with 0.05 % per Dexterity point; the Crownbinder (crown
    1g 48s plus a Fallen Crown) and the Decor Merchant in every capital
    ([economy.md](design/economy.md), [combat_stats.md](design/combat_stats.md)).
  - **Cloaks and achievements (C3):** 17 per-character achievements unlock
    41 cosmetic cloaks painted by GPT-6 Astra; an Achievements tab and a
    cloak dropdown on the Character page; the cloak swings on the player
    model ([character_visuals.md](design/character_visuals.md) §5b).
  - Next was the user's GUI test (with Rounds 30–32); its findings and the
    Bag of Coins became Round 34's fix lanes beside sound.

- **Round 32 "Fixes, preparation and research" delivered**
  (2026-10-03, [plan, completion and GUI checklist](planning/round32-plan.md#completion-2026-10-03)).
  Every code lane is merged on main (last lane F4, `2f709fbc`), each
  independently reviewed by Opus (F3's third pass and F2's last small
  commit checked by the coordinator); 66 fixtures pass; pushed 2026-10-04. No
  mapgen change: the Round 31 fresh world serves the GUI test.
  - **Map and HUD (F1):** the minimap zoomed ×2 (a 440-node window; the base
    map unchanged); hostile camps (bandit and Mirefolk) as a red "X" on the
    Map tab instead of the quest giver's "!"; the zone banner and the
    minimap line coloured by the territory at the player's position (green
    friendly, yellow contested, red enemy, y ≤ −501 contested) with the
    line "Friendly Territory" / "Contested Territory (PvP)" / "Enemy
    Territory (PvP)" in place of Round 31's subtitle
    ([world_map.md](design/world_map.md)).
  - **LMB hold and quest labels (F2):** one gather/combat state machine: a
    gather hold turns into combat when a hostile (neutral mobs too, players
    only when both are flagged) comes into the crosshair and reach, and
    back once that foe is gone; self and support skills fire only on a
    fresh press ([classes.md](design/classes.md#left-click-and-held-input));
    kill objectives name the mob as its zone shows it, kept by two new
    validator rules ([quests.md](design/quests.md)).
  - **Playtest fixes (F3):** combat notices and the personal notices
    (item-use and equip refusals, mount and talent notices, boss loot) in
    the message feed instead of chat; the quest log in one text field with
    Track on HUD and Abandon in one row.
  - **Performance (F4):** the Map tab builds at most two forms per 0.1 s
    pass, the party HUD polls in five slots, camps and leaders tick in zone
    slices (100 stand-ins: Map tab step maximum 34.5 → 13.4 ms, party HUD
    16.2 → 4.3 ms).
  - **Studies (R1–R3, read-only):**
    [performance review](research/perf-review-2026-10-r32.md) (50/100
    stand-ins; memory and first-join media notes for a playtest server),
    [sound research](research/sound-research-2026-10.md) (sound is V1; seven
    decisions open), [items and professions analysis](research/items-professions-analysis-2026-10.md)
    (16 questions for a design session).
  - The user tested it with Rounds 30, 31 and 33 (the findings fed Round
    34); the round counts as GUI-accepted (the user, 2026-10-05). The
    items design session became Round 33, sound Round 34.

- **Round 31 "PvP, appearance and clean-up" delivered** (2026-10-03,
  [plan, completion and two-client GUI checklist](planning/round31-plan.md#completion-2026-10-03)).
  Every lane is merged on main (last lane Q, `699a2002`), each
  independently reviewed by Opus except the small follow-ups M2 and G2
  (checked by the coordinator); pushed 2026-10-03. WP41 delivered and WP42's
  PvP-POI part; rules in [pvp.md](design/pvp.md). A fresh world is required.
  - **Geographic PvP (P1, P2, P1b, P1c; WP41):** PvP only between two
    flagged enemy players; the flag comes from contested ground or enemy
    territory, the "Flag me for PvP" button (60 s) and PvP contact (60 s);
    only own peaceful land clears it; an unflagged enemy is no target; one-way
    support whose refusal costs nothing; 10 s PvP combat; logout in PvP
    combat is death with kill credit; contested depth from T4 (y ≤ −501).
    A PvP tab with the button, the state and statistics, two status icons,
    a banner subtitle and the target-frame marker. PvE combat unchanged
    (within noise); location tick 53 µs per second for 50 fake players.
  - **Faction filter (N):** NPC services, quest givers and waystones serve
    only their own faction; map and minimap show own-faction NPC markers
    plus every king and both dragons, and hide the enemy's settlement icons
    (war camps stay).
  - **PvP POIs (S, M, M2, G, G2, Q; WP42 part):** Ashenward Bastion and
    Bannerbreak Warhold (49 × 49, one gate, 12 elite guards, a level-65
    General with two bodyguards, three quest givers, a Quartermaster, the
    seventh waystone, a trail to the middle road) and 16 Battlegrounds camps
    with garrisons in the camp's race and band and named captains (leaders,
    not elites); protection + 10 nodes, no hostile spawns; 24 fortress
    quests from level 40 (8 solo camp raids, 3 ordinary, 1 entry per
    faction; 515 quests in total). Several secondary roads and trails
    re-route round the new POIs (0–6 per seed); the middle road keeps its
    course. Quest share: the user chose lower raid weights (3/4).
  - **Appearance (A, B):** body features chosen once at creation (skin tone,
    hair colour, hairstyle, eyes, a race feature), NPC looks rolled once,
    helmets with a face window, equal hitboxes for every race and for the
    mounts of each tier; enchant colours as thin stripes at 50 % on items,
    held and dropped stacks, worn armour and the kings' weapons, with a
    legend at the enchanting stations
    ([character_visuals.md](design/character_visuals.md)).
  - **Dragon arenas (DA2):** round arenas of radius 40 on local ground; the
    edge is the leash (reset, full heal, flight home); ice water 250/s and
    frost terraces on Wyrmglass, ember fissures 350/s and trunks on
    Stormscale; the dragon's wrath 500/s for participants outside
    ([world.md](design/world.md) §4b).
  - **Clean-up (C) and names:** the query caches dropped after a first
    start's build (heap at the first step 149 → 110 MiB), held objective
    counts capped, the turn-in refresh, the zone-grid encode in the pcall,
    `tools/run_fixtures.sh` (63 fixtures pass); Heal, Shield, Mend and Ice
    Nova replace another game's spell names; neutral wording instead of a
    commercial MMO's terms; captain and General names by GPT-6 Astra.
  - Final engine check (2026-10-03, main 699a2002, seed 42): PASS 7/7 — boot clean (cold 38.3 s to listening, heap 111 MiB; second boot 7.3 s, 67 MiB); both fortresses 19/19 NPCs with mixed faction races, camps with leader-captains (×1.5 HP, ×1.15 size), gate trails, protection margin, 7th waystone, no hostile spawns inside; flag logic 9/9 incl. y −500/−501 under a capital; faction filter (enemy settlement icons hidden, 8/8 enemy war camps shown, enemy givers/vendors refuse); looks persist and vary (13/13); enchant colours on dropped, wielded and worn gear; Wyrmglass arena floor of local ground, hazards and protection to ±40; 515 quests load. Cosmetic: frost terraces merge into the floor where the ground reaches their height (57 of 409 columns); fortress quest givers' nametags fixed after the check.
  - The user tested it with Rounds 30, 32 and 33 (the findings fed Round
    34); the round counts as GUI-accepted (the user, 2026-10-05).
    Seed-dependent POI placement was set aside (2026-10-03); Round 32
    followed.

- **Round 30 "Performance and clean-up" delivered** (2026-10-02,
  [plan, completion and playtest checklist](planning/round30-plan.md#completion-2026-10-02)).
  Every lane is merged on main (last lane P2, `b64709d7`), each
  independently reviewed by Opus; pushed 2026-10-03. Numbers are each lane's
  before/after comparison on its own probe, never targets.
  - **Quest state and map UI (P1, P1b):** a decoded quest-state cache and one
    marker pass for all givers (minimap 55.8 → 9.3 ms/s, quest HUD 17.1 →
    6.5 ms/s at 40 stand-ins); the Map tab sends at most every 2 s and only
    on a change (17.2 → 0.93 ms/s, 179 → 33 KB/s); **Return home** moved to
    the Character page (user ruling); quest markers and NPC tags follow held
    objective items and level-ups within about 1.5 s
    ([world_map.md](design/world_map.md), [home_travel.md](design/home_travel.md)).
  - **Region-map cache and boot memory (P3):** the region maps and the Map
    tab's zone grid are read from the world folder on a later start (warm
    boot 15.3 → 7.2 s), only the compact maps stay in memory (Lua heap
    127.6 → 70.5 MiB), boot peak memory 2.12 → 1.76 GB
    ([spawn_regions.md](design/spawn_regions.md#cache-and-memory)).
  - **Mob pathing and spawning (P2):** A* inside about 3 ms per server step
    with waits after a failed search, and **mobs give up a target they cannot
    reach** after three failed searches (dragons only wait, kings only drop
    the target; 40 blocked chasers 6.83 → 0.68 ms per step); no per-step
    `get_properties()` (garbage 7.75 → 4.93 MiB/s); 56 of 88 spawn rows
    retired and the rest in three merged ABMs (block scans 404 → 104 per
    second); the `general_attack` eye-height bug fixed
    ([combat_stats.md](design/combat_stats.md), [biomes_mobs.md](design/biomes_mobs.md) §4).
  - **Per-player ticks (P4):** a crafting lookup index (200 → 5 µs), the
    crosshair state every 0.15 s (14 → 7.7 ms/s standing), tag carriers in
    eight slots, the flight-border sweep 268 → 43 µs, fewer crop-soil timers.
  - **Island landings (L):** a sand beach and a wooden pier at each of the
    four dragon-island landings; the islands get no paths or roads by design
    ([boats.md](design/boats.md) §7.1).
  - **Clean-up (C):** the legacy quest fields removed (unknown fields stop the
    load), the stale fixtures repaired, the riding-tier purchase fixture, no
    craft warnings at boot; the **Dawnmere NPC duplication** found and fixed
    (start NPCs could come back twice after an early block unload).
  - **Band smoothing (E):** band-4/5 loot medians 39.0 → 43.6c and 147.6 →
    119.5c; Expert Riding 1g37s, respec 31–40 2s and 41–50 6s
    ([economy.md](design/economy.md)).
  - **Final engine check PASS** (seed 42, 2026-10-03): cold boot stores
    both caches (region hook 8.8 s, "listening" 40.0 s); the second boot
    hits them (3.3 ms, "listening" 6.9 s, heap 71 MiB after GC); log free
    of ERROR and craft warnings; four landings with pier and beach
    (Stormscale south also has a natural walkable slope up); surface,
    cave and bay spawns with at most one mob per merged trigger;
    Dawnmere 13 NPCs, no duplicates after reloads; boxed-in target given
    up and searches drop to 0, a target on a bottom slab is chased.
    The user tested it with Rounds 31–33 (the findings fed Round 34); the
    round counts as GUI-accepted (the user, 2026-10-05).

- **Round 29 "Economy and travel" complete and pushed** (2026-10-02,
  [plan, completion and playtest checklist](planning/round29-plan.md#completion-2026-10-02)).
  Every lane is merged on main (last lane D, `e512bb5c`), each
  independently reviewed by Opus; the user tested it on a fresh world and
  pushed it. The quest lanes were merged
  together after the user approved a sample per track.
  - **Quests (Q1–Q9, T):** 491 quests in 42 zone files replace the 240
    legacy quests: one track per race from the start zone to its heartland
    (Human 54, Dwarf 58, Elf 71, Undead 53, Orc 48, Troll 63), the contested
    31–40 zones (35 / 30) and the 41–60 front with repeatable and island
    bounties (40 / 39). Seed-dependent directions are placeholders filled
    from the spawn regions; fixed compass words fail the load; copper comes
    from the quest's weight; the front budget counts two repeats per bounty.
    Every target forms on six seeds
    ([quests.md](design/quests.md)).
  - **Economy (E1, E4; WP44 delivered):** one price module for every
    payout (loot and gathered goods by class and tier, processed goods by
    their inputs, 5 % buy-back on vendor goods), shelves by the vendor
    rule, the Common gear axis 25c … 25s, repair at crafting stations in an
    active claim; riding 1s10c / 7s / 1g37s / 7g33s, boats 1s10c / 7s,
    respec 15c … 12s from a per-band income estimate
    ([economy.md](design/economy.md)).
  - **Travel (B, W, A; WP17 delivered):** boats as water mounts from the
    Shipwright in every capital (L15 and L30), waystones in all six capitals
    and starts with instant free travel between discovered stones, the
    Kraken Guard at 10 nodes/s in deep ocean
    ([boats.md](design/boats.md), [world.md](design/world.md) §6).
  - **Mapgen bundle (M-res, M-geo):** gems by depth (T1 Citrine … T6
    Diamond), `apex_sockets` removed, mapgen band data (Causeway 41–50,
    Gravesalt and Skyglass 51–60), the Battlegrounds about 50 % larger with
    a middle road from Highcourt to Gor Drazhak. A fresh world is required.
  - **Spawn playtest fixes (P):** no spawn puff, leader HP 1.5×, the Basics
    book's tiers (T6 shows 36 recipes).
  - **Performance review** (read-only):
    [perf-review-2026-10.md](research/perf-review-2026-10.md); its lanes
    P1–P4 and the user's rulings became Round 30.
  - **Final engine check PASS** (seeds 42 and 20261002): middle road,
    Battlegrounds borders, bands, moved sites, channel, waystones and
    Shipwrights, gems by band, clean load. Finding: the dragon-island boat
    landings were mostly a one-node shore strip below high cliffs (piers
    and beaches in Round 30).

- **Round 28 complete and pushed** (2026-10-02,
  [plan, completion and playtest checklist](planning/round28-questing-leveling-plan.md#completion-2026-10-02)).
  Every lane is merged on main (last lane W1 `f35998d5`), synchronized to
  Luanti and pushed. Each lane was independently reviewed by Opus.
  - **Track A (playtest fixes):** road protection half width + 1 and idle
    aggressive mobs walk away from roads and towns; mob environmental damage
    in percent of max HP, melee knockback as a small displacement, hits never
    stall a mob's attack clock, simple separation; elites at scale 1.4,
    kings at size 1.6, world-sized HP bars, rotated selection boxes; Charge
    checks its landing
    room, failure messages are back, the LMB lock decides combat or gather at
    key-down; one respawn teleport without launch, death messages name the
    shooter, stations drop their contents when dug; the message feed above
    the bars, riding trainer states, "Damage reduction", the Professions tab
    and "N locked" recipe books; per-class offhand (shield, caster offhand,
    Scout melee), Scout ranged and melee slots and the Scout-only quiver.
  - **Track B (framework):** data-driven mob sub-types and loot by level band
    with a participant drop hook; kill XP `M(L) = 25 + 5L` and the curve
    `M(L) × (8 + 0.29(L − 1))` (4,200 XP to L10, 194,220 to L60), quest and
    gathering XP in kill equivalents; quests as per-zone JSON with item-group,
    multi-objective, area and quest-drop objectives, repeatables, travel
    credit on accept and load-time validation; self-contained professions
    (no metal fittings, data-driven enchant inputs, six duplicate cooking
    routes removed) ([progression.md](design/progression.md),
    [quests.md](design/quests.md), [biomes_mobs.md](design/biomes_mobs.md)).
  - **Catalogue:** 195 sub-types (49 named leaders, 18 elites), 119 loot
    items with 89 new icons, drops and enchant inputs per band; signal words
    (Small, Large, Braindead …) only in start zones, a unique name everywhere
    else.
  - **Spawn regions:** every one of the 38 zones spawns its surface mobs
    from a rule recipe built on the seed's own terrain (32-node cells, belts,
    terrain kinds, camps and leaders by rule; leaders 1.15× size and 2× HP,
    1.5× HP since Round 29), with
    the border rule across zones ([spawn_regions.md](design/spawn_regions.md)).
    The Broken Causeway plays 41–50, Gravesalt Escarpment and The Skyglass
    Canopy 51–60 (gameplay band; the mapgen is unchanged).
  - **Players see:** each objective's target level range in the quest log
    and offer; the zone or town name under the minimap, zone markers on the
    Map tab and a short entry banner ([world_map.md](design/world_map.md)).
  - **Interim (resolved in Round 29):** the 240 legacy quests stayed until
    new quest files replaced them; the Causeway's plants and ores followed
    31–40 until the mapgen band data. The quest content per race track, the
    front and island quests moved to Round 29
    ([quests plan](planning/round29-quests-plan.md#1-why-this-is-its-own-step))
    with the [economy](planning/economy-vendor-plan.md),
    [boats and waypoints](planning/travel-boats-waypoints-plan.md) and a
    mapgen bundle.
  - The spawn playtest (2026-10-02) fed Round 29 (findings P1–P4).

- **Round 27 delivered and pushed** (2026-09-30, WP50,
  [plan, completion and playtest checklist](planning/round27-minimap-plan.md#completion-2026-09-30)).
  Lanes M (`cda93c90`) and D merged on main; fully pushed (in `9dd85b6e`).
  The Round 26 playtest fix for capital walls (no gaps at gatehouses, fewer
  walls in rivers) is merged as `1ff541e4`; follow-ups in the BACKLOG.
  - **M:** our own round, north-up minimap in the native minimap's box
    (about 900 nodes, snapped to a coarse grid so the client texture cache
    grows only per cell) with quest givers by state, the Housing Steward,
    trainers, innkeepers, home and party members with rim arrows; native
    minimap off; a "Show minimap" switch on the Map tab. `grug_map_quality`
    normal (1080×960, about 10 s, 0.92 MB) or high (3600×3200, about 56 s,
    6.93 MB), sent as 512 px tiles; hillshade, 16/64-node contours and a
    stone tint; region-label scrollbar fix
    ([world_map.md](design/world_map.md)).
  - **D:** documentation of the Lane M facts and WP50 closure.
  - **Glide follow-up** (merged as `9c8ece8c`,
    [follow-up](planning/round27-minimap-plan.md#follow-up-gliding-minimap-2026-09-30)):
    the arrow stays centred and the map glides under it every server step
    inside a pewter bezel; about 880 nodes, one texture per 6 (normal) or 16
    (high) base-pixel cell, high at half resolution; about 3.7–3.9 times the
    snapped HUD traffic.
  - The user's playtest led to the glide follow-up; the round counts as
    GUI-accepted (the user, 2026-10-05).

- **Round 26 delivered** (2026-09-29,
  [plan, completion and playtest checklist](planning/round26-capitals-housing-cleanup-plan.md#completion-2026-09-29)).
  All lanes are merged on main: S `377e7cd4`, R `4e88234c` with the Troll follow-up `ed7d79a1`, I `abaaa262`, W `ce2264e9`, D (branch `r26-d-docs`). Pushed.
  - **S:** a placed Claim Stone is a half-transparent draft that protects
    nothing and crumbles after 5 minutes unless activated with 5 lumps; the
    only lock is 12 hours without pick-up after activation; the Housing
    Manager is now the Housing Steward; `/claim_remove`; snow in the arrival
    cube can be dug ([housing.md](design/housing.md) §§2a, 3, 5).
  - **R:** mobs_redo utility items and silver-sandstone recipes removed, all
    tier tools under `grug_materials:` with 12 aliases, the two surface
    critters at 0.75 density (WP28 delivered); Trolls also get +50% food
    healing.
  - **I:** the status icon row above the skill bar (green/red/gold frames,
    at most 10, no cooldowns), a combat icon right of the health bar instead
    of the "Combat" text, Character page Stats/Effects tabs and class icons
    in the party HUD and Group page (audit D10;
    [inventory_equipment.md](design/inventory_equipment.md) §5).
  - **W:** more irregular, still star-shaped capital outlines at about the
    same area, a character per capital, towers at bends and gatehouses, and
    a replan when a named building is dropped (2 → 0 of 200 seeds; planning
    5.7 → 6.2 s per seed, preparation 14.5 → 14.9 CPU s; engine check seed
    42 PASS 36/36) ([world_zones.md](design/world_zones.md) §12).
  - **D:** documentation after the
    [work-package audit](planning/wp-audit-2026-09-29.md) and its
    [user decisions](planning/wp-audit-2026-09-29.md#user-decisions-2026-09-29),
    then the lane facts.
  - Playtested 2026-09-29; the round counts as GUI-accepted (the user,
    2026-10-05).

- **Round 25 delivered:** Claim Stone housing (WP24,
  [housing.md](design/housing.md)): one free, soulbound stone from the
  Housing Steward in each capital from level 20; a 101 × 101 claim column from
  y = −100 up in the own L11–30 home zones, 16 nodes clear of settlement cores
  and hard footprints; coal or charcoal fuel as a "paid until" time (a full
  slot lasts about a month); Interact/Everything permissions with a
  right-click and node-inventory guard; stone form, Character-page status;
  the stone as travel home with an arrival cube; no hostile spawns in active
  claims; housing masks removed. Roads, bridges and POI, village and camp
  cores are protected for everyone, with hint reasons ("Road – protected").
  The capital planner places required and named buildings before fill: load
  failures 1.3 % of seeds → 0 of 200, capital layouts changed. All nine lanes
  merged on main (`7ca48666`), independently reviewed and synchronized
  to Luanti on 2026-09-29. Pushed.
  [Plan, completion and playtest checklist](planning/round25-housing-plan.md#completion-2026-09-29).
  Its first playtest's follow-up rulings 30–33 fed Round 26; the round
  counts as GUI-accepted (the user, 2026-10-05).

- **Round 24 delivered, pushed and accepted:** tier rocks with engine-native pick gating
  replace depth bounds and shatter (loose ground by hand or shovel, axe and
  shovel tiers, protection and pick hints on punch, tool level requirements);
  the terrain fill hosts ores and bands (coal near the Orc start 0.10–0.37 →
  0.90–1.05 of target at 5–16 depth), with mountain and cliff layers,
  decorative nests and output-identical P8 speedups (about 20 % less Lua
  mapgen time); start-zone level gradient, 32-node idle wander leash, calm
  roaming pace, filled thin spawn cells and a per-zone mob density budget
  (about 1.5×); gathering XP; ten one-line tracked quests; lava and drowning
  scaled to max HP; hard protection from 100 below each footprint's placement
  height instead of y ≥ −700; housing areas as ordinary terrain; pausable
  character creation. All 13 lanes reviewed and merged (`1e338503`) and
  synchronized to Luanti on 2026-09-29. Pushed with the playtest
  protection-hint fix and the Round 25 plan as `d4eaffff`; accepted by the
  user.
  [Plan, completion and playtest checklist](planning/round24-mining-underground-mobs-plan.md#completion-2026-09-29).

- **Round 23 delivered:** full-column world preparation (a finished
  full-world preparation leaves nothing to generate for walking, diving or
  flying; fast path for air chunks), habitat-driven vegetation renewal
  replacing the exact-baseline ecology (saplings behind `grug_tree_regrowth`),
  and capital walls (Highcourt core wall, Lethariel curtain, Kezamba palisade,
  taller cores, closed Nhal Veyr bars, walls end at lake shores). All lanes
  independently reviewed, merged and synchronized to Luanti.
  [Completion and GUI checklist](research/round23-completion.md),
  [plan](planning/round23-world-life-plan.md). Phase 2 (tree line
  with shrub band and snow caps, forests and clearings) and the lake-wall
  playtest fix are merged (`f54c299d`) and synchronized. Pushed 2026-09-28.

- **Playtest fixes 2026-09-28 delivered:** food click/hold input,
  server-side node UIs, crosshair range feedback with own crosshair, 2.5 s bow
  draw with damage curve and power ring, eating visual, movement stances,
  swimmers stay in water, fish drop, first-person rod, recipe-book ingredient
  navigation, Blink targeting; follow-up bow tuning, eating ring and immediate
  combat exit. Eight lanes independently reviewed, all probes and a headless
  boot passed on merged main `fede63db`; synchronized to Luanti.
  [Receipt and GUI checklist](research/playtest-fixes-2026-09-28.md). Pushed
  2026-09-28.

- **Round 21 startup correction:** fixed the missing fish disposition and native
  arrow recipe catalog binding; real isolated server startup and 200-arrow craft
  passed. Merged as `f00433c7` and synchronized.
  [Receipt](research/round21-startup-fix.md). Pushed 2026-09-24.
- **Round 21 delivered:** terrain/POI access, resource calibration,
  furnaces, aquatic detail and feedback fixes. Independently reviewed, final
  gates passed, merged as `96c40fa3` and synchronized to Luanti on 2026-09-24.
  [Receipt](research/round21-completion.md), [playtest](research/round21-playtest.md),
  [execution state](planning/round21-state.md). Pushed 2026-09-24.
- **Round 20 delivered:** 240 quests, all 100 anchor art slots, contextual
  input and equipment/UX fixes. Independently reviewed, final gates passed,
  merged as `8308229f` and synchronized to Luanti on 2026-09-24. Pushed
  2026-09-24.
  [Completion receipt](research/round20-completion.md),
  [playtest checklist](research/round20-playtest.md),
  schematic POI gallery (`tools/r20/evidence/pois/`, retired in Round 22;
  git history keeps it).
- **Documentation consolidation:** complete with independent Astra PASS;
  [receipt and coverage](maintenance/documentation-round.md). Its findings
  list is [archived](archive/maintenance/findings.md) (its open items are
  fixed in code, D3 moved to the BACKLOG); open design questions are in the BACKLOG
  ([Audit 2026-10 open questions](../BACKLOG.md#audit-2026-10-open-questions)).
- **Latest game:** main carries Round 37 (`27e5db87` and lane D), on top
  of Round 36 with its follow-up lanes (`0f169898`), Rounds 20–35 and the
  2026-09-28 playtest fixes. Round 37 is not pushed; everything up to it
  is: the user pushed Round 36 on 2026-10-05 (`1e8a975d`, then `0f169898`
  with the follow-up lanes); origin/main then took the October 2026 audit
  and the Round 37 plan (`211229e2`). Round 29
  was tested by the user on a fresh world (2026-10-02), the user's Round 33
  findings became Round 34's fix lanes, the Round 34 findings Round 35 and
  the first Round 35 findings Round 36's lane F; Rounds 25–35 count as
  GUI-accepted (below). The 2026-09-30 playtest with friends fed Round 28,
  the 2026-10-02 spawn playtest Round 29. Fresh-world development
  remains in force.
- **Technical reviews/gates:** recorded PASS for those delivered candidates;
  not a fresh certification of arbitrary later changes.
- **Preparation performance follow-up:** the bounded two-request pipeline
  completed the same measured prefix in a further 24% less time than the prior
  40 ms scheduler. Its native emerge worker reached 99.43% of one core over the
  matched steady interval. Completed preparation remains inactive during later
  on-demand cave generation; engine tick/thread settings are unchanged.
  Independent review, native comparison, two-pending stop/resume and final
  interpreter parity passed. Merged to main and synchronized; pushed
  2026-09-23. Receipt:
  [full-speed follow-up](research/pregen-fullspeed.md). Prior measurement: [scan-budget follow-up](research/pregen-scan-budget.md).
- **GUI acceptance:** Rounds 25–35 count as GUI-accepted (the user's
  ruling of 2026-10-05, [Round 37 plan](planning/round37-plan.md) §2.3.5);
  Round 24 was accepted earlier, and its build contains Rounds 20–23 and
  the 2026-09-28 playtest fixes. **Rounds 36 and 37 are open.** The
  [Round 37 checklist](planning/round37-plan.md#gui-playtest-checklist)
  covers group fights and taunts, the elite wind-up, the swing animation,
  mounts and shields when a buff runs out, durability, knockback, the
  breath fan and volley, Bone Call and royal guards, a server restart,
  right-click with seeds, buckets and the rod, the furnace book, ground
  growth, the minimap and Claim Stone, the New World dialog and Help →
  About, the new sounds, the start zones, the Reef Lurker and the
  minimap at high quality (desktop and web build, two clients). Round 36
  with its follow-up lanes F2, W2, W3 and RD (the user's test is under
  way): the
  [Round 36 checklist](planning/round36-plan.md#gui-playtest-checklist)
  covers both main lines from 41 to the finale, quest objects and places,
  the corrupted sub-types, the commanders, the rift and Isquarre (two
  clients), achievements and cloaks, the evading mobs and the talent-point
  banner, Priest heals, the dragon arenas, the decor pass, the new
  prices, and the follow-up lanes' held button across a hotbar switch,
  benches, ground cover and roads (desktop and web build, a world made on
  `fef94a6a` or later). The accepted rounds' checklists: the
  [Round 35 checklist](planning/round35-plan.md#gui-playtest-checklist)
  covers aiming at turned mobs, gear breaking, the empty hand, dig sounds,
  the quest dialog, night mobs at dawn, loot, talent tooltips, capital
  music and the new character creation (desktop and web build); the
  [Round 34 checklist](planning/round34-plan.md#gui-playtest-checklist)
  covers sound (desktop and web build), mobs in water, the text boxes, the
  Bag of Coins, the service markers and the thin ice; the Round 31–33
  checklists are linked from their entries above; the
  [Round 30 checklist](planning/round30-plan.md#playtest-checklist)
  covers the Map tab rate, quest markers, Return home on the Character page,
  mobs giving up, spawns, crafting, the crosshair, island landings, prices
  and the faster second start; the
  [Round 29 checklist](planning/round29-plan.md#playtest-checklist)
  covers quests, economy, gems, prices, the Battlegrounds, boats and
  waystones (tested by the user 2026-10-02), the
  [Round 28 checklist](planning/round28-questing-leveling-plan.md#playtest-checklist)
  covers the spawn regions, fixes, slots, feed and zone names, the
  [Round 27 checklist](planning/round27-minimap-plan.md#playtest-checklist)
  covers the minimap and map quality, the
  [Round 26 checklist](planning/round26-capitals-housing-cleanup-plan.md#playtest-checklist-fresh-world)
  the capitals and Claim Stone activation, the
  [Round 25 checklist](planning/round25-housing-plan.md#playtest-checklist-fresh-world)
  the rest of housing; earlier rounds keep their own checklists. The walk
  of the Round 20 POI art (audit E2) became Round 36's review page and
  decor pass; the reworked places are in its checklist.
- **Remote observation:** every round up to Round 36 and its follow-up
  lanes is pushed (origin/main `0f169898`, 2026-10-05; `211229e2` since with
  the audit and the Round 37 plan); Round 37 is local.
- **Release:** unreleased fresh-server development. The Nether is expansion
  content. [First-public-release gates](../BACKLOG.md#first-public-release-gates)
  remain open.

Older deliveries: [R18](research/round18-completion.md),
[R17](research/round17-completion.md), [R16](research/round16-completion.md),
[R15](research/round15-completion.md), [R14](research/round14-completion.md),
[R13](research/round13-completion.md), [R12](research/round12-completion.md),
[R11](research/round11-completion.md). Read these for evidence or provenance,
not to reconstruct the current rules from successive overrides.
