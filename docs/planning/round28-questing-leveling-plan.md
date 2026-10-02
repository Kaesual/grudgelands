# Round 28 — playtest fixes, mob behaviour, class slots and the world-wide questing and leveling redesign

Decided with the user on 2026-10-01 after a playtest with friends on a fresh
server world (2026-09-30). Coordinator: Claude (Opus 5.5). Routing (user,
2026-10-01): the coordinator orchestrates; **GPT-6 Astra** (Codex CLI,
`-m gpt-6-astra`) writes the game design and the art and serves as the
coordinator's sparring partner; **Opus 5.5** implements Tracks A, B and E and
is the **only** reviewer (no Sol), including for Astra's design and art.
Go-ahead given on 2026-10-01. Rulings below are the contract
for the lanes; implementation agents do not invent design beyond them, and
design agents stay inside the frame of Section C.

The user asked that every lane know *why* it builds what it builds. Each
section therefore states the reason first. When a lane meets a case the
rulings do not cover, the reason decides; if the reason does not decide
either, the lane stops and reports.

## Goals

1. **Questing and leveling feel good, varied, exciting and replayable across
   the whole world.** A first character learns a lot; a second character
   started "from zero" profits from that knowledge (where to farm what, what
   a mob's name means, which zone suits which level).
   *Why:* the playtest felt like grinding. Measured: the ten start-town
   quests give 540 XP of the 8100 XP needed for level 10 (6.7 %; two more
   quests need level 10 to accept); kills to L10 are about 102. There is no
   quest with minimum level 13–19, zones 41–60 and the islands have no quests
   at all, and start-zone kill quests ask for 3–5 mobs anywhere (the optional
   zone filter `objective.zone`, `grug_quests/state.lua:265`, is unused there).
   The "three level bands per zone toward the front" rule sounded right in
   theory but does not feel right in play.
2. **Zones are planned as closed units with their own progression**, with
   several distinct spawn areas per zone, mob sub-types that make the
   variety readable, and quests that fit those areas exactly.
3. **Professions are self-contained.** No profession needs another
   profession's product. Variety comes from loot tables per tier band:
   enchant and profession inputs combine **loot and mining** (and
   gathering).
   *Why:* forcing players to have items made by another profession turned
   out to be much worse in practice than expected.
4. **Fix the playtest bugs and feel problems** (Rulings 1–33).
5. **Mobs behave sensibly around roads and towns** as a soft tendency, not a
   hard rule, and stay near their spawn area.

## Facts this plan builds on

Measured from the code on 2026-10-01 (read-only research; line numbers may
drift). Lanes re-verify before relying on a detail.

- **Spawning.** mobs_redo ABM rows, rewritten by
  `grug_mobs/spawn_policy.lua` `prepare_spawn_row` (:596-668), gated by
  `spawn_allowed`, claims and `grug_mobs/density.lua` `density_allows`
  (:217-274). The density budget is already species-aware: each species has
  a weighted share, and a species below its old cap always refills. Killing
  every fox in a boar/fox area refills foxes, not boars. Palettes are per
  named zone (`ZONE_MOB_PALETTES`, SP:29-125); capital zones are empty in
  full (70–80 % of each capital zone is non-city land without mobs). Mob
  level comes from `grug_zones.mob_level_at` (continuous field; start-zone
  gradient `wp40/zones.lua:601-791`). `mob_nospawn_range = 24`
  (`minetest.conf:52`).
- **Roaming.** Random walk plus a wander leash to the spawn point
  (`_grug_home`, radius 32, `grug_mobs/aggro.lua:508-560`, straight
  `walk_toward` nudge at 1 Hz, idle mobs only). Pathfinding only in combat.
- **Camps.** `grug_mobs/camps.lua`: bandit camps respawn per slot after
  120–300 s; the four Mirefolk camps are **empty** (no camp fire is ever
  placed; the anchor roster `r7_anchor_roster.lua:73-77` lists only
  capital, outpost and bandit populations). Rares respawn after 2–4 h.
- **Protection.** Roads: `wp40/world_protection.lua` `ROAD_SIDE = 3`
  (:34), ±5 vertical; vegetation keeps `EXCLUDE_PAD = 2`
  (`road_layout.lua:105`) away from roads, so a 1-node ring of protected,
  undiggable plants exists today. Runtime query
  `grug_core.world_feature_at(pos)` → road/bridge/village/camp/poi;
  towns via `grug_zones.hard_protection_kind_at`.
- **XP.** Kill XP = `floor(10·L·tier_xp·1.5)` with L = min(mob, player+5)
  (`grug_mobs/levels.lua:121-127`, `init.lua:252-270`); level curve
  `100·(L−1)²` cumulative (`grug_xp/init.lua:5-21`); quest XP is a fixed
  integer per quest; gathering `factor × min(10·tier, L+5)` (ore 1.5, gem 3,
  fish 5).
- **Quests.** Objective types item/kill/talk only
  (`grug_quests/registry.lua:34`); kills match the entity name
  (`state.lua:266`) and credit every participant within 40 m; talk credit
  only on right-click of the target (`npc.lua:23-26`); no per-giver limit;
  no quest has more than one objective; 240 quests in total.
- **World.** 38 zones (`wp40/source/simple_map.lua:54-91`); six start zones
  (three per faction, one per race), each with an elder and a cook; per race
  a home track start (1–10) → home zone (11–20) → capital → 21–30 zone(s);
  31–40 contested zones per faction; 41–60 front zones and two islands with
  no quest givers and no roads. POI catalogue `wp40/r20_poi_catalog.lua`
  (villages, outposts, mines, bandit frontier, mirefolk, clash sites,
  dragons, apex camps, rare routes).
- **Enchants.** `grug_professions/enchants.lua`: input = family material +
  one reagent per tier for every stat (T1 coal lump); Woodcarver enchants
  also need Weaponsmith metal fittings (the only cross-profession
  dependency). Stat pools per family in `grug_quality/init.lua:54-72`.
- **Loot.** Static `drops` per mob definition, not tier dependent (zombies
  drop iron bars at 1/10 everywhere); the drop-hook registry
  `grug_mobs.registered_drop_hooks` exists and is empty.

---

## Section A — fixes and mechanics (Rulings 1–33)

### World, roads and mob behaviour

**Why:** roads and towns should feel safe to travel and rest in without
becoming a combat refuge, and plants that nobody may harvest should not exist.
Mobs should stay in "their" area so that zones keep their planned
progression. Everything here is a *tendency*: cheap, soft, never a hard
guarantee and never checked every tick.

1. **Road protection** reach becomes half width + **1** (`ROAD_SIDE = 1`);
   vertical ±5 unchanged. Vegetation keeps `EXCLUDE_PAD = 2`, which is now
   wider than the protection, so no plant grows (at mapgen or by renewal)
   inside protected road ground. Runtime only, no mapgen change.
2. **Push away from roads and towns.** Idle, free-roaming **aggressive** mobs
   (not neutral, not critters, not camp/POI-bound, not NPCs) probe every
   ~4–5 s eight points on a ring of radius = their `view_range`. If any
   point is road, bridge, start town, capital city or village (all bands),
   they walk away from the hits using the existing leash nudge. Never in
   combat; pursuit is unchanged (roads are no refuge). Hostile POIs
   (bandit camps, mirefolk, clash sites, bandit/poacher areas) do not push.
   Inside the leash radius the push wins, outside it the leash wins (no
   oscillation). Small overlaps for a while are fine.
3. **No spawns on protected ground.** Ambient non-critter spawns are refused
   on the exact protected surface: road corridor, bridges, village boxes,
   start-town footprint, capital city. No extra margin (a margin of aggro
   range would empty large areas because trails run everywhere; Ruling 2
   handles the rest). Critters may still appear in towns.
4. **Leash** stays anchored at the spawn point, radius 32. Spawn areas
   (Section B) are sized so that this keeps mobs inside their area; the
   "pull toward the own spawn area" the user asked for *is* this leash.
5. **Separation (keep it simple).** Physics already lets actors pass through
   each other (`collide_with_objects = false` since 2026-09-17), so mobs
   cannot stand *on* players; what players see is overlap. Rule: an engaged
   melee mob does not enter the target's own column (it holds about its
   contact distance), and engaged mobs that overlap each other drift apart
   sideways. 1 Hz at most, no pathfinding. If this grows beyond a small
   helper, stop and report.
6. **Environmental damage for mobs in percent of `hp_max`**, like players:
   sun (any mob with `light_damage > 0`) **5 %/s**; lava **20 %/s**;
   fire 10 %/s; water for water-hurt mobs 10 %/s; suffocation 5 %/s; fall
   damage `ceil(hp_max × (d − 6) / 20)` (same shape as players). Elite and
   rare tiers take **half**; bosses, kings and dragons are immune (dragons
   already are). Existing per-mob values become on/off switches. *Why:*
   high-level zombies were nearly immortal (L30 zombie: 764 HP, 6.4 min in
   sun).
7. **Knockback, melee only.** Strike and the melee swing skills push a normal
   mob back by `c × swing interval` with **c = 0.25 m per second** to start
   (dagger 0.7 s → 0.18 m, sword 1.0 s → 0.25 m, battle axe 1.4 s → 0.35 m).
   Knockback per second is therefore identical for every weapon (no
   kiting advantage), the battle axe still feels heavier per hit, the
   attack-speed affix shortens both, and weapon tier does not matter.
   It is a **position displacement** (a velocity would be overwritten by the
   next AI step once Ruling 8 removes the pause), horizontal only, and it
   happens only when the destination fits the mob's collision box (no
   walkable node) and has floor under it; otherwise there is no knockback.
   So mobs are neither pushed into walls (suffocation, Ruling 6) nor off
   ledges (percent fall damage). Several players hitting one mob add up their
   knockback; that is accepted (noted, theoretical). No knockback for elite, rare, boss, king or Kraken. c is one
   constant for the user to tune by feel. *Why:* hits felt weak after
   knockback was removed; the original abuse (backpedal so the mob never
   hits) stays impossible because mobs close at 0.6 m/s (4.6 vs 4.0) and
   0.25 m/s of knockback is well below that.
8. **Hits never stall a mob's attack clock.** No player hit (melee, ranged,
   ability; with or without knockback) pauses the mob's punch timer. Today
   every landed hit sets `pause_timer = 0.25` (`mobs/api.lua:3550`), which
   skips `do_states` and with it the attack timer. *Why:* several players
   hitting one mob otherwise stretch its attack interval a lot.
9. **Sizes.** The elite tier scale becomes **1.4 for all elites** (was 1.6).
   The king ends at a final `visual_size` of **1.6** (his base size is
   chosen so the elite scaling lands there; today base 0.71875 × 1.6 =
   1.15, `grug_mobs/bosses.lua:400`). Collision and selection boxes scale with the visual so boxes
   match the model (the king's box is far taller than his model today).
   Check throne rooms and doorways for the new sizes. *Why:* the king must
   read as the most powerful figure in the room; elite guards are too big.
10. **Health bars in world size.** All mob HP bars use world-sized
    dimensions (the explicit dragon path in `grug_core/tag_carrier.lua`
    already does). Today the ordinary path divides by `visual_size`
    (:167): fox bars are 1/10 size, serpent bars 2.7 nodes wide.
    **Hitboxes:** fox, wolf and every mob whose mesh clearly exceeds its
    box get a rotated selection box (as boar and ibex already have); the
    lane measures mesh bounds and lists every change.
11. **Gate guards** turn and walk together: the patrol step sets the new yaw
    instantly (or derives the velocity from the target yaw), and route
    carriers get `randomly_turn = false`. Cause: `walk_toward`
    (`grug_mobs/patrol.lua:40`) smooths the yaw over ~4 steps but builds the
    velocity from the old yaw, which is refreshed up to 1 s later.

### Combat input

12. **Charge** checks its destination with Blink's player-box helpers
    (`grug_abilities/blink.lua`); if blocked it searches back toward the
    caster along the approach line like Blink; with no room it fails with
    "Not enough room at target." and costs nothing (failed casts already
    keep cooldown and resource). Blink is unchanged (only Charge was
    observed). *Why:* Charge put players inside terrain next to small mobs
    in 1-node gaps, and they died.
13. **Skill failure messages are visible again**, on a fresh press only (not
    on held repeats), each message at most about once per second. They have
    been muted since `89f83fc9` (`input.lua:95` passes `quiet = true`), so
    "Not enough mana", "not ready" and "No room to blink" never show.
    Flipping the flag is not enough: `usable()` (`input.lua:91`) asks
    `api.can_cast` (ready, cast interval, affordable) and returns before
    `try_cast`, so the input gate itself must report the reason (and the
    same for `swing_ready`).
14. **LMB mode lock — probe first, then build.** At key-down the input
    decides the mode for the whole hold: **combat** when an attackable mob
    is under the crosshair (using combat-ray rules, so plants never hide a
    mob) or when it points at air or out of reach; **gather** when it points
    at a hand-diggable node within reach. Combat mode never digs and may
    switch targets freely (a mob dies, the next one steps in); gather mode
    never swings, even if a mob walks into the ray (so a passing neutral mob
    is not pulled by accident). Blink's 200 ms pending window stays. *Why:*
    while fighting, a slight miss started digging the block beside the mob.
    **Probe first:** the client predicts digging itself, so a refused dig
    may still show cracks (Round 24 saw this for protected nodes). Probe
    whether setting the wielded skill item's range to 0 in combat mode (as
    the bow does while drawing) prevents client digging without breaking
    swings. If cracks cannot be avoided, report to the user before building.
15. **Mining has no critical hits**; nothing to change. The observed "crit"
    was the hold switching from digging to a swing when a mob crossed the
    ray (Ruling 14 removes that).

### Player, death and stations

16. **Respawn: one teleport, no launch.** Respawn goes straight to the bound
    innkeeper (no intermediate start-town hop); the player is held in place
    (no gravity, no movement, through `grug_core.movement` so other speed
    effects are not overwritten) until the destination area is emerged, then
    released. `teleport()` (`grug_home/travel.lua:5-13`) never adds a
    velocity derived from the server-side `get_velocity()`: after a lethal
    fall the server still holds the pre-impact speed, so
    `add_velocity(-get_velocity())` launched the player upward by about
    that speed and the second fall killed them again (and could repeat on
    the second teleport). Fix the same pattern in
    `grug_mounts/entity.lua` `zero_player_velocity` and
    `grug_classes/selection.lua`.
17. **Death messages name the shooter.** Projectiles resolve `_grug_source`
    (and `owner_id`) to the mob's display name; if the shooter is gone, a
    readable fallback ("an arrow", "a fireball"). Same for the bog witch's
    bottle and dragon breath. Boss-encounter death counting resolves the
    source too.
18. **Stations drop their contents when dug.** Furnaces, dual furnaces,
    brewing stands and profession stations can be dug at any time by anyone
    the normal protection allows (open world: no special rule; claims: the
    claim's rights; foreign home territory: the territory rule). Digging
    drops every node list **and** every player's saved workspace record, as
    `on_blast` already does (`grug_jobs/workspaces.lua:446-459`). Authored
    public stations stay undiggable. *Why:* the empty-only rule blocked
    digging, even by the owner, because of other players' invisible
    leftovers.

### UI

**Why:** messages in the top-left chat area are easy to miss; several labels
and layouts confused the playtesters.

19. **Riding trainer** always shows all four tiers, each with a state: Owned,
    Buy <price>, "Requires level N", or "Learn <previous tier> first"
    (greyed). Purchase errors use the flash line, not chat.
20. **Message feed above the HP bar** (above the skill-name row): at most
    3 lines, each visible about 2.5 s, newest at the bottom, darkened shortly
    before it disappears (HUD text has no alpha fade). Content: XP gains
    (merged within ~1.5 s), item pickups and loot (merged per item, e.g.
    "+3 Light Leather"), quest progress (a quest's line **replaces** its own
    previous line), fishing catches ("Caught <fish> (+N XP)"). Colours by
    kind (loot white, XP purple, quest yellow). Level-up is a separate large
    centre message. **No chat copy** of any of these. A6 exposes the feed as
    an API (`grug_core.feed(player, kind, text, key)`) and switches today's
    callers; later lanes call the API. The fishing
    `grug_abilities.notify` call moves into the feed.
21. **"Damage reduction"** replaces "Own-level reduction"; tooltip: "Armor
    reduction against an enemy of your level. Higher against lower-level
    enemies, lower against higher-level ones."
22. **Quest tab spacing:** the description, objective and reward textareas
    move right of the list (legacy coordinates: textareas subtract the
    padding, labels do not; today they overlap the list by 0.06) and the
    title label aligns with them.
23. **Professions tab** in the character page next to Stats and Effects: per
    known profession its tier, crafts in the tier / needed for the next, and
    a note when the character level caps the tier.
24. **Recipe books:** profession books list the full T1–T6 catalogue;
    locked recipes are greyed, and the per-tier line shows "N locked"
    instead of "undiscovered". Basics discovery is unchanged. (Bug today:
    `recipe_discovered` returns true for every profession recipe,
    `grug_jobs/ui.lua:265`, so every count is 0, and locked recipes vanish.)

### Classes and equipment

**Why:** the Scout has two kinds of skills but one weapon slot; its melee
skills currently swing with the bow's damage and speed (bug). A visible
per-class offhand makes the slot's purpose obvious, and then it is fair for
every class that both slot items always count.

25. **Offhand per class** (same `grug_weapon` / `grug_offhand` lists,
    class-specific acceptance, label and ghost image):
    - Warrior: shield (only Warriors may equip shields);
    - Mage and Priest: "Caster offhand" (spellbooks);
    - Scout: **melee weapon** (sword or dagger); the Weapon slot is shown as
      "Ranged" and accepts bows. For the Scout the bow no longer counts as
      two-handed.
    - Both slot items always count toward stats (as `equipment_totals`
      already sums every slot).
    - Scout bow skills read the ranged slot; Strike, Opening and every melee
      skill read the melee slot (bare hand if empty). Loose's draw speed uses
      only the bow's own attack-speed affix (today it sums all equipment).
      First- and third-person views show the item of the selected skill's
      slot (`def.slot`; the `"offhand"` path exists). Wear follows the slot
      that acted.
    - Starter Scout: bow in Ranged, Bronze Sword in Melee.
26. **Quiver becomes a Scout-only slot** beside the equipment slots, holding
    up to **500 arrows**; arrows stack to **100** in any inventory; clicking
    the quiver takes up to 100 arrows as one stack. Shots draw from the
    quiver first, then `main`. The quiver item and its Leatherworker recipes
    are removed (no replacement; the Leatherworker keeps bags). The starter
    arrows go into the quiver. The existing `QUIVER_LIST`
    (`grug_inventory/bags.lua`) may carry it (for example 5 stacks of 100) as
    long as the player sees one slot. Arrows enter by drag and shift-click and
    by pickup when the quiver has room; on death the quiver behaves like the
    equipped items.

### Professions

27. **Cooking:** remove the six direct grid routes that duplicate a raw
    assembly (Hearty Stew, Pumpkin Stew, Forager's Pot, Marsh Roast,
    Kelp-Wrapped Roast, Grand Feast). Finished dishes of that line come only
    from "Raw X" in the oven; the other twelve dishes stay as they are.
28. **Enchant inputs, self-contained.** The Weaponsmith metal fittings leave
    every Woodcarver enchant. New schema for every profession:
    **own profession material + one loot item of the tier (per stat) + one
    mining or gathering item** (may come from an earlier tier, may be a gem
    or an alloy ingredient such as a tin or copper bar). Few new universal
    reagents anyone can make (for example "Glittering Tin" from tin and
    quartz), used sparingly. The Goldsmith may refine base gems further for
    its own recipes. Varied without being tedious. Mechanism in Lane B5,
    content in C1.
29. **Critters are never kill targets:** no kill objective may target a critter
    (load-time check, Lane B4). B4 also removes the two human targets that
    name `grug_mobs:wild_turkey` today (`grug_quests/content.lua:67-68`), so
    the check passes before the start-zone rewrite.

### XP and leveling

**Why:** a level-3 mob giving three times the XP of a level-1 mob is not
justified, and the early game must not feel like grinding.

30. **Kill XP** (normal tier) `M(L) = 25 + 5·L` with L = min(mob level,
    player level + 5): L1 30, L2 35, L3 40, L10 75, L30 175, L60 325 (user,
    2026-10-01). This replaces the old `10·L·1.5`; a level-3 mob gives 1.33×
    a level-1 mob instead of 3×. Tier multipliers (elite ×4, rare ×6), the
    gray rule and the participant split stay.
31. **Level curve** XP(L → L+1) = `M(L) × k(L)`, rounded to tens, with
    `k(L) = 8 + 0.29·(L − 1)` same-level kill equivalents per level: early
    levels go fast, then it slows linearly to about 25 at level 59 (user,
    2026-10-01). To level 10: 4.2k XP (82 kill equivalents); to 60: about
    194k XP (968). With quest rewards around 40 % of the XP, a player kills
    about 0.6 × k mobs per level: about 5 for level 2, about 49 to level 10
    and about 580 to level 60 (today 102 and 757 pure kills). Level cap 60
    unchanged; fresh world, nothing migrates.
32. **All other XP in kill equivalents.** Quest XP = authored weight ×
    `M(quest level)`; gathering XP = ratio × `M(min(reference level,
    player level + 5))` with ore 0.10, gem 0.20, fish 0.33 (today's ratios);
    reference levels as today. Retuning the curve later is then one edit.
33. **Questing covers the band** (rough guides, not gates; corrected after
    review, see below). What decides whether a zone feels like grinding is
    how much of a band's XP comes from *doing quests*: the quest rewards
    **plus** the kills and gathering the quests require. Targets: questing
    covers about **90 %** of the XP in start zones and about **80 %** in
    other zones with quest givers; free grinding is the rest. Quest rewards
    alone then land around 35–45 %. The C0 ledger template budgets every
    band before any content is written: XP needed, kill equivalents demanded
    by kill quests, reward weights, gathering. A zone must not overshoot its
    band (players would leave the start zone at level 15). The human +10 %
    quest bonus stays. *Correction (user, 2026-10-01):* the discussion first
    said "60 % from quest rewards in start zones", which would push players
    far past level 10 inside the start zone. **Budget for start zones:**
    4.2k XP (82 kill equivalents) to level 10; quest rewards about 40 %
    (≈ 33 kill equivalents), quest kills and gathering about 50 % (about
    40–45 kills at levels 1–9 including the kills behind drop requests), free
    play about 10 %. Kill counts follow from that
    budget: about **five kill quests per start zone** (one per geographic
    area, not one per day/night rule) with 8–10 targets (5 for scarce targets
    such as crabs); further mob contact comes through drop requests. The C0
    ledger is binding for the exact counts.

---

## Section B — the framework (Rulings 34–47)

**Why:** the design round (Section C) writes content for 38 zones. Content
must be data that drops into a fixed framework, one data file per zone, so
many content lanes can run in parallel without touching each other's files,
and so that later tuning is a data edit, not a code change. The exact
interfaces are frozen in the C0 framework document before Track B starts.

### Spawn areas

34. **Spawn areas replace the level field for mobs.** Per zone a list of area
    rules, each relative to an anchor (start anchor, capital anchor, village,
    outpost, mine, camp, POI or rare pad): shape (radius/ring, a band along
    the zone's front axis, a side by ±x), host (refined in the design frame §4.6:
    atlas biome ids plus a shore flag), clock (day, night, both), species with
    weights, a **fixed level range**, optional caps and respawn settings.
    Areas may overlap; every zone has a catch-all rule so no land is empty;
    capital zones get areas outside the city. The density budget keeps its
    species-aware refill, evaluated over the species eligible at the point.
    Areas cover **surface land** in zones whose data defines spawn areas. Unchanged
    and still on the level field: underground spawns and their depth term,
    water spawns and swimmers (Kraken), rares, vendors and guards, and the
    mapgen content (plants, ores). Camp and bandit levels move to their
    areas. The per-mob start gates (`start_band`, Sunscar husk, Silverleaf
    poacher) are replaced by areas in zones whose data defines areas. **Fallback:** a
    zone whose data defines no spawn areas keeps today's palette and level
    field (the trigger is "areas defined", not "file exists"), so `main`
    never has empty zones while content lanes are still running. The doc rule
    "three bands toward the front" (`world_zones.md:83-123`) is replaced for
    mobs in zones with areas. Density counting spans 128 nodes, more than one
    area; area caps and E2's reachability measurement account for that.
35. **Mob sub-types** are separate registrations from the family factories
    (same mesh): own entity name, size factor (model and box together),
    disposition (neutral = yellow, aggressive = red, automatic), level range
    and drop family. The display name and tint may vary per zone (a
    "Small Boar" in Kapok reads "Small Jungle Boar") while the entity name
    stays the role, so quest kill matching by entity name keeps working.
    Names follow the design frame §5 (user, 2026-10-02): signal words
    (Small/Young, Large/Aggressive/Monstrous, Braindead/Sluggish, Confused)
    only in the start zones, one ladder for all six starts; everywhere else
    a unique descriptive name per sub-type. Light humour is welcome
    ("Braindead Zombie", "Cairn Zombie"). New names are added to
    `grug_mobs/disposition.lua`.
36. **Loot by band.** Drops come from a family table keyed by the mob's
    level band (1–10 → T1, 11–20 → T2 …). Each family has one or two
    signature items per band plus generic drops (meat, leather, cloth).
    Metal drops are rare and tier-matched (zombies in 1–10 drop bronze bars
    rarely, never iron bars). Quest-only drops (Ruling 41) go through
    the drop-hook registry.
37. **Bandits, poachers and mirefolk without POIs.** These spawn in areas
    around a defined point (with or without a camp structure), free, no
    leash beyond the normal one. Area spawns keep a minimum player distance
    of 16 (not 24), and the area is sized so that about two players do not
    block its spawns (radius about 35–40). The four Mirefolk camps get such
    areas. Camp-type respawn timers drop to **30–60 s**.
38. **Elite leaders** at fixed spots with about **5 min** respawn are the
    climax of quest lines. Rares are **not** quest targets; they stay a
    knowledge reward (fixed routes, 2–4 h).

### Quests

39. **Travel quests** credit their talk objective on accept, so the
    destination NPC shows the yellow "?" at once; the HUD reads
    "Travel to <NPC>". The turn-in still needs the visit.
40. **Givers and lines.** At most **two quest givers per hub** and at most
    **two parallel lines per giver** (so at most four active quests per
    hub). This is content structure (linear chains with prerequisites), not a
    new limit mechanism. In start towns: the **elder** gives kill quests and
    tool/ore/bar requests; the **cook** asks for coal, meat and the zone's
    mob drops.
41. **Objective features:** item groups ("any log"); several objectives per
    quest (HUD in one compact line: "Wood Axe 0/1, Wood Pickaxe 0/1");
    quest-only drops (an item drops only while the quest is active, through
    the drop-hook registry; it is rolled **per eligible participant** who has
    the quest and goes straight into that player's inventory, so groups do
    not compete for it); kill objectives limited to a spawn area.
    Load-time validation: kill targets are not critters, each target spawns
    in the referenced area, and its level range fits the quest level. No
    node-interaction and no arrival objectives.
42. **Repeatable quests** carry a cooldown and are labelled **"Repeatable"**
    in the dialog, the quest log and the HUD. They may appear in zones 1–40
    and at the front. They are given by existing NPCs (no new nodes).
43. **Front zones 41–60 and the islands** get both: quests from 31–40
    outposts and capitals that send players into the front zones (turn-in
    back at the giver), and repeatable bounties. No new mapgen, POIs or
    roads in this round.
44. **Race tracks stay separate.** Quests do not send players into another
    race's 11–20 zone; contested zones 31–40 are shared per faction as
    today.
45. **Quest texts teach.** They mention where and when (day/night) the
    targets live, and introduce mechanics on the way (sun burns zombies,
    raw food goes into the oven, which pick a rock needs).

**Content migration (single owner per step).** Each zone gets two data
files: `spawns` (palette, areas, sub-type choices) and `quests`. B1 creates
every zone's `spawns` file from today's palette, without areas (so the
fallback applies), and owns those files until it merges; B4 splits the
existing quests mechanically into every zone's `quests` file (same behaviour,
same ids) and owns those until it merges. From then on each content lane
owns both files of its zones completely: it adds areas to `spawns` (which
switches the zone to areas) and replaces the old quests in `quests`. No lane
edits another zone's files. The world is fresh
(no XP or quest migration; the `level_from_xp` square-root shortcut is
replaced with the new curve).

### Not in this round

46. **Outpost seed** (a player-placed seed in contested land that spawns
    workers who build a small fort, stoppable by killing the workers and
    destroying the seed): future package, recorded in BACKLOG; specified
    after the playtest of this round's front quests and bounties.
47. New POIs, new roads, mapgen changes, WP42 war squads, the Nether (V2).

---

## Section C — the design round (Astra)

**Why a design round:** the user's start-zone concept (C2 input below) was
an example, not a special case. Every zone should work that way within its
own frame. Large models often deliver better results on creative tasks, and
Astra's budget is effectively unlimited. Design is written as data plus
short prose and reviewed independently. The user approves C0 and the C2
sample before the bulk is written; C1 is reviewed by Opus and shown to the
user together with C2.

### Design principles (binding for every design lane)

1. **Readable, consistent rules instead of special cases.** Names carry
   meaning; day/night patterns are the same world-wide (rats, undead and
   robbers at night; grazing animals by day); a family drops the same
   *kind* of item in every band and the band decides the tier. A second
   character knows where to farm what.
2. **One rhythm per hub.** Each hub (start town, village, outpost, mine,
   capital service area) has at most two givers with two parallel lines;
   each line ends in a small climax (an elite leader, a camp, a mining
   task); the quest area is visibly "in front of the door".
3. **Replay through the race tracks.** Each race has its own path to 30
   (start → home zone → capital → 21–30). A second character of the same
   faction with another race sees largely different levels up to 30, so
   the six tracks share a skeleton but differ in stories, mobs and climaxes.
4. **Choice from 21.** Where a faction has several 21–30 zones, quest lines
   point to more than one.
5. **Reward knowledge.** Fixed elite and rare places, memorable loot
   sources for enchant inputs, quest texts that teach mechanics.
6. **More quests are not automatically better.** Fewer, clearer lines with
   higher kill counts that the spawn areas can actually serve, inside each
   band's XP budget (Ruling 33): about one kill quest per geographic area,
   the C0 ledger decides the counts.
7. **Use what exists.** Existing POIs, sockets, NPCs and models; no mapgen;
   mob variety through sub-types (size, name, tint), not new models.

### Limits (binding)

- ≤ 2 givers per hub, ≤ 2 parallel lines per giver.
- Loot items: each family has at most two signature items per band, and
  **enchant inputs are chosen from those signature drops** (no extra
  enchant-only drops). New universal reagents: at most about two per tier.
  C1 reports the world-wide count of new items (that is also C4's icon
  count) before C2 starts.
- Aggressive areas are planned with Ruling 2 in mind: mobs still spawn up
  to the protected edge (Ruling 3), but idle aggressive mobs drift about
  their `view_range` (6–16) away from roads, towns and villages. An area at
  a town's edge (the C2 night rats) therefore holds its aggressive mobs some
  10–16 nodes out; that is intended, not a reason to move the area. C0
  gives designers road and town distances so no aggressive area lies mostly
  inside that drift band.
- Kill counts must be reachable in their area (measured in Lane E; crabs
  may need 5 instead of 10).
- Quest share targets from Ruling 33; XP from Rulings 30–32 (weights, not
  raw numbers).
- Every area, quest, mob and item is data in the C0 formats, one zone file
  per zone.

### C0 — framework document (coordinator, user approval)

The coordinator writes `docs/planning/round28-design-frame.md` plus the data
schemas: spawn-area rule format, sub-type format, loot-family format, enchant
recipe format, quest line format (with weights), zone file layout, naming
conventions, the measured zone facts each designer needs (anchors, POIs,
biomes, beaches, current mob families, existing NPCs and sockets), and the
leveling ledger template. The user approves C0 before Track B and C1 start.

### C1 — catalogues (Astra, Opus review)

Global catalogues all zones draw from: mob sub-types for all bands (names,
size, disposition, levels, family), loot items and family drop tables per
band, the enchant recipe table T1–T6 (Ruling 28), new universal reagents,
quest weight calibration (Ruling 32/33), and the repeatable bounty rules.

### C2 — sample track: Human (user approval)

Zone files for **Dawnmere Fields** (1–10), **Goldmead Vale** (11–20),
**Highcourt** (capital zone outside the city) and **Whitebridge Shire**
(21–30), with spawn areas, sub-types, quest lines, texts, drops and the
leveling ledger. The user approves this sample before C3. Binding input,
the user's start-zone concept (adapt to Dawnmere's real geometry; Accord
faces the Battlegrounds toward +z, the ocean is behind toward −z):

- **First area:** the side of the start town away from the Battlegrounds
  (−z for Accord, +z for Throng) up to about the middle of the town (in z).
  By day **Small Boars** (neutral, L1–3, slightly smaller model and box),
  at night **Large Rats** (aggressive, L1–3). First kill quests here, plus
  logs, a Wood Axe and a Wood Pickaxe for the first gathering quests.
- **Home beach** (the easy side, toward the ocean): **Small Crabs** by day
  (neutral, L3–5), the first zombies at night (aggressive, L3–5, e.g.
  "Braindead Zombie").
- **Toward the Battlegrounds**, possibly split into ±x areas: by day
  **Aggressive Boars** (aggressive, L5–7) and **Young Foxes** (neutral,
  L5–7) around the town's x; at night "Sluggish Zombies" with "Monstrous
  Rats" or "Aggressive Rats" (aggressive, L5–7).
- **Beaches toward the Battlegrounds** (further out): **Monstrous Crabs** by
  day, **Monstrous Drowned Zombies** at night (aggressive, L7–9).
- **Finale near the border** to the next zone: a bandit area ("Confused
  Bandits", L9–10) around a defined point; no POI needed.
- **Four lines** (2× kill, 2× gather, at most two per giver; split in the
  design frame §2.5): elder: hunt line (kills) and tools line (tools, ores,
  bars); cook: pantry line (mob-drop requests) and kitchen line (coal, meat). First kill quests "Kill 10 Small Boars"
  ("During the day, Small Boars have been stealing our crops south of
  Dawnmere …") and "Kill 10 Large Rats" ("Large Rats have been reported to
  roam south of Dawnmere after nightfall …"). First gathering quests
  "Bring a Wood Axe and a Wood Pickaxe" and "Bring 5 logs of any tree".
  More candidates: Stone Axe and Stone Pickaxe, 5 coal lumps, 10 raw meat,
  5 copper and 5 tin bars, 5 bronze bars, 5 crab legs, 5 fox tails.
- **Loot ideas** (T1): boar tusk, light leather, raw meat (both boar
  sub-types drop the same); rat fur patch, rat tail; zombie: rotten flesh,
  broken tooth, rare bronze bar; crab eye (e.g. T1 Int/Mana enchants); fox
  tail; bandit talisman. Higher zombies: foul flesh and humorous items
  (rusted braces, smelly sock, tattooed skin patch), all crafting inputs.
- The same concept, adapted, applies to every start zone (race-specific
  families such as Plague Boar, Jungle Boar, Sun-Dried Husk, Scorpion,
  Viper keep their identity) and, in its own frame, to every other zone.

### C3 — remaining tracks (Astra, parallel, Opus review)

After C2 approval, in parallel: the five other race tracks (start, home
zone, capital zone, 21–30 zones), the six 31–40 contested zones (one per
race, Stormvault … Thunderroot), and the front: The Broken Causeway (41–50 since 2026-10-02,
shared), the 41–60 zones and the islands (quests from 31–40 outposts and
capitals plus bounties). Each lane delivers its zone files and its part of
the leveling ledger; a final consistency pass checks names, items and
weights across lanes.

### C4 — art (Astra, Opus review)

Inventory icons for every new loot item and reagent (native 16×16): generate
large, downscale and quantize to the existing item style. Astra delivers the
originals, the downscaled PNGs and a manifest (as in `tools/r26_icons/`)
under `docs/planning/round28/art/`; Lane E1 adapts the `prepare.py` step,
places the textures in the mods and adds the CC0 rows to
`LICENSE-media.md`. A
**probe set of six icons** goes to the user first. Mob variants use size and
tint only (no new skins; mob UV layouts do not suit image generation).

---

## Lanes

| Lane | Scope | Model | Depends on |
|---|---|---|---|
| **P — Process docs** | Astra into the model policy (role, review), Codex CLI facts refreshed (0.159.3, default model, Sol 6.x slugs) | coordinator, Opus review | — (with this plan) |
| **A1 — Roads and roaming** | Rulings 1, 2, 4 | Opus | — |
| **A2 — Mob physics** | Rulings 5–8 (`mobs/api.lua`, new `grug_mobs/separation.lua`) | Opus | — |
| **A3 — Mob looks** | Rulings 9–11 | Opus | — |
| **A4 — Combat input** | Rulings 12–15 (Charge and messages first, then the LMB probe; build only after the probe report) | Opus | — |
| **A5 — Player and stations** | Rulings 16–18 | Opus | — |
| **A6 — UI** | Rulings 19–24 | Opus | — |
| **A7 — Class slots** | Rulings 25–26 | Opus | A6 merged before A7's review (both edit `pages.lua`) |
| **C0 — Frame** | design frame and schemas | coordinator | user approval |
| **B1 — Spawn areas** | Rulings 3, 34, 37, 38 (`spawn_policy.lua`, `density.lua`, `camps.lua`) | Opus | C0, A1 merged |
| **B2 — Sub-types and loot** | Rulings 35, 36 (family factories, disposition, drop tables, the drop-hook API in `aggro.lua`'s drop section) | Opus | C0, A1 and A3 merged |
| **B3 — XP** | Rulings 30–33 (`grug_xp` incl. `grug_xp.quest_reward(level, weight)`, kill XP in `levels.lua`, gathering, fishing), `progression.md` | Opus | C0, A3 and A6 merged (`levels.lua`, feed calls) |
| **B4 — Quest system** | Rulings 29, 39–42, the per-zone split of quest content (content migration) | Opus | C0, A6 merged; uses B1's area lookup, B2's drop-hook API and B3's reward helper (merges after B1, B2, B3) |
| **B5 — Professions** | Rulings 27, 28 (mechanism, fittings removed) | Opus | C0 |
| **C1a/C1b — Catalogues** | Section C1 (world catalogue; economy catalogue), then one editor pass | Astra (2 lanes) | C0 |
| **C2 — Human track** | Section C2 | Astra | C1 reviewed |
| **C3a–e — Race tracks** | the five other race tracks | Astra (5 lanes) | C2 approved |
| **C3f — Contested** | the six 31–40 zones | Astra | C2 approved |
| **C3g — Front** | Broken Causeway, 41–60 zones, islands, bounties | Astra | C2 approved |
| **C4 — Art** | probe set, then the full set | Astra | C1 item list |
| **E1 — Catalogue content** | C1 into the framework: sub-types, items, drops, enchants; placeholder icons swapped for C4's set when delivered | Opus | B1–B5, C1 |
| **E2 — Human track content** | C2 zone files, measurement (kill reachability, leveling ledger) | Opus | E1, C2 |
| **E3… — Track content** | one lane per C3 deliverable | Opus | E1, C3 part |
| **D — Integration docs** | STATUS, README, BACKLOG, ROADMAP, AGENTS; design docs (`world_zones`, `biomes_mobs`, `quests`, `progression`, `combat_stats`, `items_crafting`, `professions`, `classes`, `scout`, `inventory_equipment`, `world`) | Opus | last |

**Waves.**
1. P (with the plan); A1–A7 start together; the coordinator writes C0.
2. After C0 approval: C1, and each B lane as soon as its A dependencies in
   the lane table are merged.
3. After C1 review: C2 and the C4 probe set; E1 once B1–B5 are merged.
4. After C2 approval: C3a–g in parallel, E2, C4 full set.
5. E3… in parallel as C3 parts are reviewed.
6. Integration, measurements, docs, sync, playtest.

**File ownership.** A1 owns `wp40/world_protection.lua` and the roam code in
`grug_mobs/aggro.lua`; A2 owns `mobs/api.lua` and the new
`grug_mobs/separation.lua`; A3 owns `levels.lua` tier visuals,
`tag_carrier.lua`, `patrol.lua` and the selection-box edits; A6 and A7 share
`grug_inventory/pages.lua` (A6 merges first); B1 owns `spawn_policy.lua`,
`density.lua`, `camps.lua`; B2 owns the family factories, `disposition.lua`
and the drop section of `aggro.lua` (after A1 and A3 merged); B3 owns
`grug_xp` and the XP part of `levels.lua` (after A3); B4 owns `grug_quests`
and calls B3's reward helper and B2's drop-hook API. A lane that must touch a
shared file (`grug_mobs/init.lua`, `start_zone_families.lua`) merges `main`
before its review. Content lanes E* write only their zone files and
catalogue data.

## Coordination

- **Opus lanes** (Tracks A, B, E, D): native subagents in their own
  worktrees and branches; an independent Opus review per lane in a fresh
  context; review findings are hypotheses to verify; theoretical findings
  are noted, not escalated into fix rounds.
- **Astra lanes** (Track C): Codex CLI per
  [cross-cli-orchestration.md](../process/cross-cli-orchestration.md),
  `-m gpt-6-astra -c model_reasoning_effort=high` (xhigh for C1/C2),
  own worktree and branch, design files only under
  `docs/planning/round28/…` (prose plus data in the C0 schemas), no mod files
  and no code; the E lanes port the design into the zone data files. Every brief
  repeats: reports go to the `-o` path only; never launch Codex, Claude or
  any other agent; stop and report under "## Blockers / questions" instead
  of guessing. Image generation with Codex's built-in image tool (feature `image_generation`) for C4; never reasoning effort `ultra` (it delegates).
- **Review of Astra's work** by a fresh native Opus subagent against the
  design principles, limits, the C0 schemas and the code facts.
- Lanes other than D do not edit BACKLOG, README, ROADMAP, AGENTS or
  docs/STATUS and never sync.
- Checks: portable fixtures first; engine runs only through
  `tools/luanti_headless.sh` (`LC_ALL=C`), short (≤ 5 min), `pgrep -f
  '^luanti.bin'` clean afterwards; no PUC; at most eight concurrent Lua or
  engine runs.
- Performance is reported as comparisons, never as targets; clearly more
  complexity or a noticeably slower game goes to the user.
- **Measurements in Lane E2 and later** (rough guides, not gates): a
  leveling ledger per track (XP per band from quests, kills, gathering;
  quest share vs Ruling 33); spawn reachability per kill quest (how long
  10 targets take for one and for two players, from area size, caps and
  respawn).
- Afterwards: fresh world, playtest. The completion section and the playtest
  checklist are added at the end of the round.

## Completion (2026-10-02)

The user ended Round 28 on 2026-10-02. Every lane below is merged on main
(last lane W1 `f35998d5`, the frame note on island flight `3f1405e5`); each
was independently reviewed by Opus and passed the gates the coordinator ran
on main after every merge (all `tools/r28_*/portable_test.lua`,
`tools/r28_design/validate.py`, `tools/check_fresh_server.py`, a headless
boot). Pushed up to `9dd85b6e` (the loot icons); N1 and everything after it
are local.

**How the round changed course.** Ruling 34's anchor-relative areas
(Lane B1) shipped as a framework, but the user rejected the C2 sample's
hand-placed circles and rectangles: maps differ per seed, and the fallback
still covered most land. The coordinator designed the replacement with the
user: rule-based spawn regions built from each zone's terrain (Lane S1,
[spawn_regions.md](../design/spawn_regions.md)), reviewed as images on
several seeds; they replace the areas. GPT-6 Astra kept the catalogue and the art and may write
quest texts; it no longer designs spawn distributions.

### Shipped, by lane

- **A1** (`b140c76e`): road protection half width + 1; idle aggressive mobs
  walk away from roads, bridges, villages and towns (rulings 1, 2, 4).
- **A2** (`d24259ec`): mob environmental damage in percent of max HP, knockback
  as a 0.25 m × swing-interval displacement, hits never stall the attack
  clock, simple separation (rulings 5–8).
- **A3** (`eaecdcb6`): elites at scale 1.4, kings at size 1.6, world-sized
  HP bars, rotated selection boxes, gate guards turn and walk together
  (rulings 9–11).
- **A4** (`71ac0d12`, `c4681c82`): Charge checks its landing room, failure
  messages on a fresh press, the LMB mode lock (rulings 12–15).
- **A5** (`d6cdf9c0`): one respawn teleport without launch, death messages
  name the shooter, stations drop their contents when dug (rulings 16–18).
- **A6** (`722d90d5`): the message feed (`grug_core.feed`), riding trainer
  states, "Damage reduction", quest tab spacing, the Professions tab, "N
  locked" recipe books (rulings 19–24).
- **A7** (`d7257e20`): per-class offhand, Scout ranged and melee slots, the
  Scout-only quiver (500 arrows, stacks of 100) (rulings 25–26).
- **C0** (`b00b5d2b`, `4addee02`, `d1c15097`, `7b824394`, `be8776ba`): the
  [design frame](round28-design-frame.md), zone atlas, mob catalogue and
  design tools (`tools/r28_design`).
- **B1** (`79cd2878`): per-zone spawn data, protected-surface refusal, area
  camps and leaders, 30–60 s camp respawn (rulings 3, 34, 37, 38).
- **B2** (`23585cec`): data-driven sub-types, loot by band, family alerts,
  the participant drop hook (rulings 35, 36).
- **B3** (`510944fe`): kill XP `25 + 5L`, the curve `M(L) × (8 + 0.29(L − 1))`,
  quest and gathering XP in kill equivalents (rulings 30–33).
- **B4** (`55cab977`): quests as per-zone JSON (240 migrated), item-group,
  multi-objective, area and quest-drop objectives, repeatables, travel
  credit on accept, new givers, load-time validation (rulings 29, 39–42).
- **B5** (`2efa3b79`): self-contained professions, data-driven enchant inputs,
  six duplicate cooking routes removed (rulings 27, 28).
- **C1 and E1** (`d6a60168`, `7a11bb07`): Astra's catalogue shipped as game
  data with loot prices (tier = copper, a placeholder) and ingredient tiers.
- **C4 / E1b** (`9dd85b6e`): 89 loot icons by Astra, style approved by the
  user; originals archived outside git.
- **N1** (`3ec3516b`): the naming rule of frame §5 applied (51 roles, 18 zone
  variants, 3 items) with a review page.
- **S1** (`c8afa5c7`): rule-based spawn regions (32-node cells, belts by area
  share, terrain kinds, camps and leaders by rule, direction phrases), the
  Dawnmere recipe approved on six seeds, the region renderer
  (`tools/r28_regions`); every zone runs to its round level; leaders 1.15×
  and 2× HP.
- **M1** (`c7c56a5d`): zone or town name under the minimap, zone markers with
  name and level band on the Map tab, "King of <city>", a debounced 1.5 s
  entry banner ([world_map.md](../design/world_map.md#zone-and-town-names)).
- **Q0** (`cb2b7703`): each objective's target level range in the quest log
  and offer dialogue.
- **S2-core** (`1a68c018`): entry borders, core exits, one-belt recipes,
  camps on existing camp POIs, the batch renderer.
- **S2c, S2b, S2a** (`789a8130`, `39a2bb11`, `38e1da4b`): recipes for the
  front zones and dragon islands, the 16 Kragmar and the 15 Elandor zones;
  Gravesalt Escarpment and The Skyglass Canopy play 51–60; blight-ground
  zombies and leaders are sunproof; legacy kill quests take the recipes'
  sub-types.
- **W1** (`f35998d5`): the world view (`tools/r28_world`) and the border rule
  applied to every zone including the fronts; The Broken Causeway plays
  41–50 with its own sub-types; the seed-aware quest-target check (73
  objectives fine, 22 accepted `W-recipe-target`, none missing). The mapgen
  output is unchanged against `9dd85b6e`.
- **D**: this section, STATUS, README, BACKLOG, ROADMAP, AGENTS, the module
  guide and the design index.

Result: 195 sub-types (49 named leaders, 18 elites), 119 loot items, every
T1–T6 enchant stat item dropped by at least one recipe role, and all 38
zones on spawn recipes.

### Moved to Round 29

Section C's quest content (C2/C3 and E2/E3: new quest files per race track,
the contested zones, the front lane with island quests and bounties) moves
to Round 29, "Economy and travel" (`docs/planning/economy-vendor-plan.md`
§10, agreed with the user on 2026-10-02). Why:

- **Parallel work.** The quest lanes touch the same things as the economy
  lanes (quest copper on the cutover column), WP17 (boats are the only
  access to the island quests) and the mapgen bundle (Causeway and
  Gravesalt/Skyglass band data, the wider Battlegrounds). One round runs
  them side by side and prepares one fresh world.
- **Spawn playtest first.** Quests reference region kinds; the user wants to
  see the new distribution in play before quest content is written on it.

Until then the 240 legacy quests stay, with their oversized XP and 22
accepted `W-recipe-target` warnings. A small quest-core step opens the
quest work: direction placeholders filled per seed, a load check against
fixed compass words, and the cutover copper column.

### Open items

In [BACKLOG](../../BACKLOG.md#round-28-carry-overs-and-round-29): the outpost
seed (item 46), elite ideas never shipped, the loot text pass, six sub-types
no recipe uses, steep zones without generated camp cells, clustered camps in
Mournfen and Bannerbreak, the Q0 and M1 review notes. Branches: `r28-c2`
(Astra's Human route) stays unmerged as content input; `r28-c4` and
`r28-e1b-icons` must never be merged (icon originals in their history).

### Playtest checklist

On a fresh world:

1. **Start zone:** Small Boars by day and Large Rats at night near the start
   town; levels rise toward the next zone; crabs on the beaches by day,
   zombies at night; a bandit camp with its chief near the exit. Every zone
   should feel populated, with no empty land.
2. **Names:** the zone or town name under the minimap; a short banner when
   you enter a zone or town; zone markers on the Map tab with name and level
   band; "King of <city>" on a king's marker.
3. **Quests:** the quest log and offer show each target's level range; kill
   quests count the named sub-types. Legacy quests still give too much XP.
4. **Mobs:** idle hostile mobs keep away from roads and towns but chase you
   across them; melee hits push a normal mob back a little; zombies burn in
   the sun in about 20 seconds, not minutes; elites, kings and leaders have
   their new sizes; HP bars look the same size on every mob.
5. **Combat input:** Charge into a tight spot fails with "Not enough room at
   target."; "Not enough mana" shows; holding LMB on a mob never digs, on a
   block never swings.
6. **Death and stations:** a lethal fall respawns once at your innkeeper
   without a second death; a death by arrow names the shooter; a dug furnace
   drops its contents.
7. **UI:** the feed above your bars (XP, loot, quest progress), the riding
   trainer's four tiers, the Professions tab, "N locked" in recipe books.
8. **Classes:** Warrior shield, caster offhand, Scout bow in Ranged and a
   sword in Melee, the quiver slot (stacks of 100).
