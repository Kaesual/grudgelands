# Round 78 — Game-night fixes

Planned with the user on 2026-11-12 from the bug and wish list of a game night. Routing
(user's standing rule): one coordinator, lanes as subagents of the session model,
independent review of every lane with game logic. Version **0.78.0**, expected
**compatible**: no map reset, no migration step. Round 77 (claims kept over a map reset)
is reserved and not started; this round does not depend on it.

## How to add to this document

- A new ruling goes to §2 with its date. A lane goal changes in §4, a row in §1.
- A **ruling** is the user's, with its date. A **proposal** or **finding** is not a
  ruling until the user says so; a coordinator default is marked as such (§3.1).
- Name functions rather than line numbers.

## Why

The game night brought fourteen items: balance (potion cooldown, repair cost), bugs that
break the feel of fights (bosses standing inside the tank, free respawns into a running
boss fight, missing nametags, a key that misses presses), small world bugs (guards on lamp
posts, lanterns that drop in Expeditions, no towering, mounting on slopes, Ore Sense
marking ores the player may not mine) and two wishes (emotes, readable armor numbers).

## 1. Lanes and order

Start state: main `4a1e7581` (0.76.2). Integration branch `round78` in
`.claude/worktrees/round78`; every lane branches from it. One wave: the lanes share
almost no files (§3.3).

| Lane | Goal (§4) | Merge order | Review |
|---|---|---|---|
| SMALL | Potion cooldown 30 s and its status, repair ½, guard spawn spots, towering, Claim Stone anthracite, Ore Sense protection, flying mount retry | 1 | independent |
| TAGS | Nametags that never go missing; the E-key study | 2 | independent |
| EXPED | Immutable Expedition lanterns (and every node like them); the respawn lock | 3 | independent |
| ARMOR | Armor numbers ×10 with one decimal inside, outcomes unchanged | 4 | independent |
| BOSS | Stand-off distance and distance-based ranged/melee choice; friendly casts past hostile bodies | 5 | independent |
| EMOTE | Wave and Dance (and a seated Wave) from the quickbar | 6 | independent |
| D | Help text, design docs, completion, GUI checklist, status owners | after the merges | coordinator |

## 2. User rulings (2026-11-12)

1. **Potion cooldown 30 s** (was 60 s), shared by every potion as today.
2. **The potion cooldown shows in the status (effect) row** while it runs, with its
   countdown. This is an exception to Round 26 ruling 21 ("No cooldowns on the status
   row") for this one effect only; ability cooldowns stay off the row.
3. **Repair costs half:** the repair price factor goes from 1.0 to 0.5 ("a good start").
   Death wear (10 %) stays.
4. **Capital guards never spawn on the lamp posts** (or any other raised spot); they spawn
   at street level.
5. **Expedition lanterns are immutable**: a punch never drops them.
6. **Bosses keep a stand-off distance.** A boss stops in melee range with a small gap to
   its target (about one to two nodes), so the tank can handle it and the healer can
   target the tank, and only chases when it has to. A boss with a ranged and a melee
   attack chooses by distance: below a threshold it melees; above it, it shoots; beyond
   its shot range with line of sight it closes in until it can shoot; without line of
   sight it paths toward melee range and re-checks on the way (sight back and outside the
   melee threshold: it shoots, otherwise it melees). It never tries to stand in the
   target's node. **This applies to every mob with both attacks, not only bosses**
   (open world included).
7. **Nametags:** both suspected causes get fixed (a carrier lost and never rebuilt; a
   carrier that reaches a client before its parent). The user saw it most often with
   players arriving by waystone; mounting is suspected too; probably the tag was missing
   for everyone around.
8. **Towering works again:** the placing player's own body is exempt from the
   "no block where a body stands" rule. Other players and mobs still block.
9. **The Claim Stone activates with anthracite too** (charcoal and coal lumps already
   work).
10. **Emotes Wave and Dance** from the quickbar window. One click plays the animation once;
    walking or jumping interrupts it. On a mount: the upper body only (or not at all).
11. **Expedition respawn lock:** a player who dies in an Expedition while anyone in the
    Expedition is still in combat waits 10 s before the respawn; when the fight ends
    earlier, the respawn is free at once.
12. **Armor numbers ×10 with one decimal inside:** displayed ratings become ten times
    larger and finer (a T6 cloth chest shows 55 instead of 5), every damage reduction stays
    as it is apart from rounding. **Cloth keeps its curve** (the user, after looking at
    options for a steeper cloth curve: cloth wearers stay fragile).
13. **A flying mount that does not fit tries once more one node higher** before it refuses.
14. **Ore Sense never marks a deposit the player may not mine** (protected for them).
15. **Process:** the round runs in a local worktree; the coordinator reports when
    everything is done, and the user gives the go for the squash merge into main.

## 3. Shared conventions

### 3.1 Rules not covered by a ruling (coordinator defaults, the user may overrule)

- **Status icon** for the potion cooldown: the existing potion art on the neutral plate; no
  new art in this round.
- **Anthracite counts one for one** toward the five activation lumps, in any mix with
  charcoal and coal; it is spent last (it is the best refuelling fuel).
- **Land mounts are unchanged:** they have no room check (on purpose, for one-node
  tunnels), so they never refuse; the retry is for flying mounts only.
- **Friendly casts pass hostile bodies:** a heal or other friendly-targeted cast looks past
  mobs and hostile players to the first friendly player on its ray (nodes still block). A
  ray that finds no friendly player keeps today's fallback.
- **Mode thresholds** (BOSS): distances are measured horizontally, edge to edge (collision
  radii subtracted); melee below about 4 nodes, ranged above about 6 nodes, the gap between
  them keeps the current mode (no flip-flopping at the boundary); a mob in melee stops at
  about a one-node gap. These are guide values; the lane may tune per mob and reports
  what it chose.
- **Seated emote:** Wave plays seated on a mount (upper body); Dance is not offered while
  mounted.
- **The E key:** TAGS studies the cause and the options; a fix that changes a server
  setting or another project's client is the user's decision at the end of the round.

### 3.2 Facts found before the round (re-checked by each lane)

- Potion: `grug_traders.POTION_COOLDOWN` (`grug_traders/potion.lua`), used by the alchemy
  effects; the status row is `grug_core/status.lua` (`register_status_source`) with the id
  registry `icons.STATUS` in `grug_core/status_icons.lua` (a fixture forbids unlisted ids).
  The cooldown runs on `os.time()`, the status row on `core.get_us_time()`.
- Repair: `grug_repair.FACTOR` in `grug_repair/service.lua`; `cost = ceil(FACTOR × reference
  price × wear)`; the reference price carries quality ×1/3/6. Example: a tank in T6 Rare
  pays about 57 silver per death today.
- Guards: capital guards are a banner camp (`guard_accord`, `guard_throng`) placed by
  `grug_mobs/camps.lua` `free_spot_near`, which scans dy = 3 … −3 top-down and takes the
  first air cell over any non-air node; the lamp posts (`dressing.path_light`: two posts
  and a floor torch) match first.
- Lanterns: the Expedition templates use `grug_decor:xdecor_lantern_hanging` (attached_node
  = 4) under `grug_decor:xdecor_rope` (not walkable). Builtin `on_punchnode` →
  `check_for_falling` drops it, ignoring protection. A static city variant exists in
  `grug_decor/city_variants.lua`.
- Placement: `grug_core/placement.lua` (Round 72 PLACE) `body_in_cells` counts every live
  player including the placer.
- Claim Stone: `grug_housing.FUEL_ORDER` (activation) holds charcoal and coal only;
  `FUEL_ITEMS` (refuel) already takes anthracite at ×1.5.
- Ore Sense: `grug_guild/effect.lua` `ore_sense_find` has no protection check; Treasure
  Hunt in the same file has the helper `protected(pos, name)`.
- Flying mounts: `grug_mounts/entity.lua` `summon_position` checks one box at the player's
  position (`FLYER_ROOM_REFUSAL`). Both factions share the same flyer body.
- Boss AI: mobs_redo (`ENTITIES/mobs/api.lua`); `get_distance` is 3D origin to origin;
  the contact run stops at 60 % of reach (`grug_obstacle.should_close_contact`);
  separation (`separation.lua`, `holds_column`) runs for `ground_melee` (dogfight) only;
  dogshoot mobs switch ranged/melee by time (`dogswitch`: 10 s / 3 s); elite scale grows
  the collision box but not `reach`. Friendly casts take the first object on the ray
  (`grug_abilities/kits.lua` `aimed_target` → `grug_core.combat_ray`).
- Nametags: the engine tag is hidden on purpose (alpha 0); every name is a carrier entity
  (`grug_core/tag_carrier.lua`), attached to the player, non-static, with per-viewer
  observers and a foe twin. `grug_factions` `refresh_player_tag` returns early when the text
  is unchanged, so a lost carrier is not rebuilt until HP, level or faction change.
- E key: `grug_keys` reads `get_player_control_bits()` per server step (rising edge). The
  client reports controls every `dedicated_server_step` (0.09 s, `client.cpp`
  `m_recommended_send_interval`, unreliable packets), so a tap shorter than that is never
  seen.
- Player model: `grug_visuals_character.b3d` with baked pose clips (`POSE_CLIPS`,
  `grug_visuals/apply.lua`) generated by `tools/r33_c3/gen_cloak_model.py` and
  `tools/r40_an/make_poses.py`; `grug_visuals/poses.lua` plays them (`play_pose`); the web
  build exports the model (`tools/web_data/model/build_glb.py`).
- Armor: per piece `max(1, floor(total × share + 0.5))` (`grug_gear/init.lua`), reduction
  `R / (R + K)`, `K = 20 + 0.5 × attacker level (+8.5 per level above 60)`, cap 70 %
  (`grug_core/combat.lua`). Today, against a same-level attacker: cloth 16–24 %, leather
  up to about 46 %, metal up to about 54 % plus the shield.
- Death in an Expedition: respawn at the run's arrival waystone (`grug_expeditions/guard.lua`
  respawn home); no respawn delay exists anywhere. The death screen is server Lua
  (`builtin/game/death_screen.lua`): any quit of `__builtin:death` respawns.
  `grug_core.in_combat(player)` exists.

### 3.3 Shared files

- `mods/PLAYER/grug_inventory/help.lua`: a lane edits only the lines of its own topic
  (potion cooldown, armor formula, emotes); D adds the rest.
- `mods/CORE/grug_core/status_icons.lua`: SMALL only.
- `mods/PLAYER/grug_quickbar/`: EMOTE only.
- `mods/ENTITIES/mobs/api.lua` and the mob movement helpers: BOSS only.
- Alchemy and ability texts that print armor: ARMOR only.
- `tools/README.md`: one line per new tools folder (append-only).
- `game.conf`, `tools/web_data/upgrade.json`: coordinator only.

## 4. Lane goals

### SMALL

Seven small, independent fixes, each with the smallest change that meets the ruling:
the potion cooldown at 30 s and shown as a neutral status with its countdown while it runs
(rulings 1–2; every text that says 60 s follows); the repair factor 0.5 (ruling 3; the
income check `tools/r29_e4/income.py --check` runs); capital guards only at street level
on a walkable floor, never on posts or torches (ruling 4; guards already standing on a
post leave it or are replaced, whichever is cheaper, reported); the placer exempt from the
body rule (ruling 8) for every caller of the rule (doors, beds and the rest keep blocking
other bodies); anthracite in the Claim Stone's activation (ruling 9, §3.1); Ore Sense
picks only deposits the player may dig (ruling 14; inside an Expedition the run's
diggable ores stay markable); a flying mount retries one node higher before it refuses
(ruling 13, §3.1), with a raised attempt that needs room but no footing.

### TAGS

No player is ever left without a nametag for a viewer in range: a carrier that is gone,
invalid or detached is rebuilt (also right after a waystone trip, a respawn, mounting and
dismounting), and a viewer who gets a carrier before its parent still ends up seeing it
attached. The lane finds in the engine source how an attached child reaches a new
observer and quotes it, and builds the fix that the source supports; no new per-tick work
over all players beyond the existing observer pass. **The E-key study:** confirm the
cause in the engine source, measure or source the cost of each option (a lower
`dedicated_server_step`; a client that latches presses until its next report; anything
in the game itself), check whether Luanti upstream already latches presses, and recommend
one; no server setting changes in this lane.

### EXPED

Every node an Expedition template places is unchangeable by players except the
template's diggable list: the hanging lanterns (ruling 5) and every other node with the
same weakness (attached or falling nodes a punch or a neighbour change could drop) get a
static variant or a swap. Then the respawn lock (ruling 11): a player who dies inside a
run while any living member of that run is in combat sees a death screen with a 10 s
countdown and a disabled Respawn button; the button frees at 10 s or as soon as no living
member is in combat. Esc and a relog keep the lock with the remaining time; a player who
is no longer in the run (run ended, left) is free; deaths outside Expeditions keep the
builtin screen.

### ARMOR

Ruling 12. Armor ratings carry one decimal inside and display ×10 as whole numbers
everywhere a rating is shown (tooltips, the character page, affix lines and enchanting
labels, ability and talent texts, elixirs, the help formula). Piece values come from the
existing formula rounded to 0.1 instead of 1, with the per-piece floor kept at 1.0 (so
low-tier cloth does not drop). `K`, the cap and the reduction formula stay unchanged, so
reductions move only by rounding; saved affix values keep their format. Baked item
descriptions are refreshed by the existing regeneration paths; anything that keeps old
text (chests, stands, mail) is reported. Expected results, same-level attacker:

| Set | Today | New |
|---|---|---|
| cloth, ilvl 60 | 15 → 23.1 % | 156 → 23.8 % |
| leather, ilvl 60 | 42 → 45.7 % | 419 → 45.6 % |
| metal, ilvl 60 | 58 → 53.7 % | 577 → 53.6 % |
| cloth, ilvl 1 | 4 → 16.3 % | 40 → 16.3 % |

### BOSS

Ruling 6 and §3.1. No ground mob stands inside or on its target; a mob in melee holds a
small gap measured edge to edge, and its melee reach is measured the same way so its hits
still land (elite scale included). Mobs with both attacks choose by distance with
hysteresis, close in under line of sight when out of shot range, and path toward melee
without sight with periodic re-checks, as the ruling describes; the time-based switch goes
for them. Friendly-targeted casts find the first friendly player past hostile bodies
(§3.1). The pathing budget and the Expedition walk grid keep working; no new per-tick work
beyond the existing mob step. The report names the chosen distances per boss and the
behaviour of every Expedition boss.

### EMOTE

Ruling 10 and §3.1. Two new clips, Wave and Dance, and a seated Wave, baked into the player
model through the existing generators (their checks stay green; the web model export
follows). Two buttons in the quickbar window play them once; walking, jumping, an attack,
a cast or mounting interrupts them; other players see them. Dance is greyed out while
mounted. First version by feel; the user judges the look in the GUI test.

### D

Help text, design docs this round falsifies, the completion section, the GUI checklist and
the status owners (round workflow §4).

## 5. Rules

[Round workflow](../process/round-workflow.md), [AGENTS.md](../../AGENTS.md), Lua 5.1.
Focused fixtures per lane; the full fixture suite runs once at the round end, by the
coordinator. Maximum eight Lua processes across all agents. No sync to Luanti and no push
by any lane.

## 6. Verification and GUI checklist

Code: changed-file Lua check, each lane's fixture, the existing fixtures that test the
changed behaviour, `check_fresh_server.py`, the income check (SMALL), the model and web
export checks (EMOTE), one smoke boot per lane; at the round end the full fixture run and
`check_upgrade.py` on the round branch.

GUI checklist (desktop and web; the user). Items 1–13 are the plan's, refined from the lane
reports and reviews; 14 and 15 are new.

1. **Potion cooldown:** drink a potion: a "Potion cooldown" status (gold frame, potion
   picture) with a countdown appears and vanishes after 30 s; a second potion is refused
   while it runs. Relog while it runs: the status comes back with the time left.
2. **Repair:** repair a worn high-tier item: the price is half of 0.76.2's.
3. **Capital guards:** no guard on a lamp post or another raised spot; guards walk the
   streets. Guards that stood on a post before the update are on the street after the
   restart.
4. **Expedition nodes:** punch the hanging lanterns (in all three Expeditions) and a wall
   torch in The Second Shift: nothing drops. Right-click The Second Shift's bookshelf: no
   window. The Second Shift's wall torches still *look* hung from the ceiling (known,
   backlog): say whether it bothers you.
5. **Towering:** jump and place a block under yourself; placing a block inside another
   player or a mob is still refused.
6. **Claim Stone:** activate with five anthracite, and with a mix of anthracite, charcoal
   and coal; the draft window's longer line fits.
7. **Ore Sense** near a claim or a town: no marker inside protected ground; inside an
   Expedition run its ores are still marked.
8. **Flying mount:** summon on a slope where 0.76.2 said "not enough room": it comes a node
   higher; under a low ceiling it is still refused.
9. **Nametags**, for viewers of both factions (the red foe tag too):
   - a new character right after creation, and a relogged character, show a tag to others
     at once, without taking damage first;
   - travel by waystone to other players: everyone sees your tag and you see theirs;
   - mount, ride and dismount: the tag stays the whole time;
   - die and respawn at the innkeeper, and in an Expedition: the tag is there on arrival.
   If a tag is still missing right after a waystone trip, report it (that would point to a
   third cause; the two known ones are handled).
10. **Expedition bosses:** Flintback stands about a node off the tank and its hits land; it
    shoots beyond about 6 nodes, melees within 4 and does not jitter in between. The same
    for Nemm; the Duewarden (melee only) holds the gap. Walk the tank into the boss: within a
    second it steps back. **The healer** aims at the tank through the boss: the crosshair
    turns green on the tank, and Heal, Shield and Mend land on the tank (never through a
    wall).
11. **Respawn lock:** die in a running boss fight while others still fight:
    - "Your group is still fighting." and a grey "Respawn in 10 s" counting down; the
      button does nothing while grey;
    - Esc brings the lock straight back with the time left;
    - at 0 the normal death screen replaces it without closing;
    - when the fight ends first (wipe or boss dead), the normal screen at once;
    - relog while locked: the lock with the remaining time;
    - die with nobody fighting, or outside an Expedition: the normal screen.
12. **Armor:** a T6 cloth robe at item level 60 shows "55 armor rating"; shields and pieces
    show ×10 numbers. Character → Stats "Armor: N" ×10; damage reduction unchanged apart
    from rounding. An armor enchant reads "+48 armor rating (T6)", the station "up to +48";
    Talents → Ironbound at 60 "+20 / +40 / +60 / +80 armor rating"; Rime Mantle and
    Unbroken "+100" / "+250 armor"; Stoneskin VI "+48 armor rating", also in the Effects
    tab and Help's formula. Expected: items in chests, on display stands, in mail, in the
    buy-back list and on the ground keep their old text until they reach your inventory
    and the next join or equipment change.
13. **Emotes:** E shows an Emotes section with Wave and Dance; a click closes the window and
    plays the emote once (Wave 2 s, Dance about 4 s). Walking, jumping or punching ends it
    at once, and the character is not stuck in the pose in third person. On a mount Wave is
    seated (legs on the saddle) and the seated pose comes back afterwards; Dance is greyed
    ("Not while riding.") and a click on it changes nothing. A second player sees both.
    Judge the look of Wave and Dance (first version by feel). Known: a seated Wave keeps
    playing while you ride on, and an attack while seated does not end it: acceptable?
14. **Open-world mobs with both attacks** (Bandit Archer, Skeleton Archer, golems, the
    kings): no 10 s / 3 s rhythm; they shoot at range and melee up close. On a 3-high
    tower you stay out of a melee mob's reach; a target that hops down from a ledge is met
    in melee.
15. **Help** (I → Help): the potion belt line names the 30-second cooldown and its status;
    the death line names the Expedition respawn wait; the emotes are on the E line; the
    armor formula is in the shown units (`rating / (rating + 200 + 5 x attacker level)`).

## 7. Orchestration notes

- Start: main `4a1e7581`, `round78` from it; private folder
  `~/projects/grudgelands-orchestration/r78/` (briefs, reports, handover).
- Process budget: the shared queue `r45/lua_run.sh`, eight Lua processes.
- The user gives the go for the squash merge after the coordinator's final report.

## Completion (2026-11-12)

All six lanes are merged into `round78` at `6bfde270`; this lane D runs on it (branch
`r78-d`). **Nothing is on main and nothing is pushed:** `round78` lands on main as one
squash commit (0.78.0) after the round-end full run and the user's go (ruling 15). Every
lane had an independent review; EXPED, BOSS and EMOTE also a fix round, EXPED and BOSS
with a delta review.

Round-end full run (coordinator, `round78` at `6bfde270`): 349 passed, 5 failed (`r30_p2`,
`r37_mb`, `r39_wm`, `r45_art`, `r75_art`). Fixed by the lanes: four stale fixture stubs or
pins (`r30_p2`, `r37_mb` BOSS; `r39_wm` EMOTE; `r75_art` EXPED) and one code fix
(`expedition_variants.lua` passed `assert`'s second value to `table.copy`, EXPED). After the
fixes the five plus every Round 78 fixture and `r44_pp`: 12/12 PASS. `check_fresh_server.py`,
`check_upgrade.py` (0.78.0 against `origin/main`) and one smoke boot of `round78`: PASS.

**0.78.0 is compatible:** no step, no map reset, no new world. Every lane report says
compatible, and lane D's reading agrees: definitions, display text, runtime state and two
new node registrations, nothing in world generation. **No new saved key.** Existing keys
the new code reads: player meta `grug_traders:potion_cd` (now also read by the status
source), mob staticdata `_grug_camp_pos`, `_grug_patrol_route` (read only) and
`dogshoot_switch` (same meaning, re-decided on the first attack step), item meta
`description`, `grug_ench`, `_grug_armor_rating` and `grug_ilvl` (same format; the
description is rewritten by the existing regenerate path). Runtime only: the respawn lock
table, `temp.grug_street_checked`, `temp.grug_ds_blind`, `temp.grug_ds_unreached`.
Expedition runs open at the update end with the restart; a box with old lanterns is
rewritten at its slot's next preparation. `check_upgrade.py` against `origin/main`
(0.76.2) passes; `check_fresh_server.py` passes.

### Lanes

`round78`'s first-parent merges from the plan `6921b1db` (lane tip in brackets):

| Lane | Merge | What | Review |
|---|---|---|---|
| ARMOR | `947b8f4c` (`e4b609f0`) | `grug_gear.format_armor`, pieces to 0.1 with a 1.0 floor, every display site through the helper | MERGE (no findings) |
| EMOTE | `7ae524c2` (`e1465b70`; first build `fe494262`) | Wave, Dance, the seated Wave baked into the player model; `play_emote`; the quickbar's Emotes row | MERGE (2 Low); fix for Low 1 (`_grug_phase`), Low 2 to the backlog |
| SMALL | `742abbab` (`700e4f6e` = `f863e37b` + `round78`) | The seven small fixes | MERGE (no findings) |
| TAGS | `8fed60ef` (`d3dff093`) | Lost carriers rebuilt in the 1 Hz pass, the re-ensure hook; the E-key study | MERGE (minor notes) |
| EXPED | `0c4f4378` (`40b32b8d`; first build `055de6c1`) | `STATIC` swaps, `grug_decor` expedition variants, `respawn_lock.lua` | MERGE AFTER FIXES (Esc re-show); delta MERGE |
| BOSS | `6bfde270` (`bdd69c5f`; first build `dac2b2ac`, merge `23f57593`) | Edge distance, stand-off, distance mode, separation for all ground melee, friendly ray | MERGE (2 Low); fix; delta MERGE |
| D | this branch, `r78-d` | Mod map, help text, release 0.78.0, this completion, the checklist, BACKLOG | coordinator |

The plan's merge order (SMALL first) changed: lanes merged as their reviews came back, and
a later lane with overlapping files had `round78` merged in before its review.

### What shipped, with numbers

Fixture numbers on the fixture's fake engine.

- **SMALL** (`r78_small`, 96 checks): `POTION_COOLDOWN` 30 and the status source
  `potion_cooldown` (neutral plate, potion image; refreshed at once); `grug_repair.FACTOR`
  0.50 (`income.py --check` PASS: income +1.5 % to +2.7 % per band, every price within
  20 %); guard posts at banner level 0, −1, +1 on a walkable floor and
  `grug_mobs.guard_to_street` once per activation (so the 0.78.0 restart moves every
  raised guard); `body_in_cells(cells, except)` skips the placer by name; anthracite last
  in `FUEL_ORDER`; Ore Sense asks `core.is_protected` (at most 16 checks per mark); a
  blocked flyer retries one node up. 11 related fixtures updated or re-run, 11/11 PASS.
- **TAGS** (`r78_tags`, 55 checks; fails A and D on the base code): cause 1 found and
  reproduced by one probe boot: the carrier made at join dies at the character-creation
  waiting point (0, 31000, 0), where no block is loaded (`serverenvironment.cpp`
  `deactivateFarObjects`), and the early return in `refresh_player_tag` kept it gone. The
  1 Hz pass now replaces a gone, invalid or detached player carrier (waiting while
  `core.get_node_or_nil` is nil); `refresh_player_tag` re-ensures it after grug_home
  teleports, a respawn, mounting and dismounting. 12 fixtures that load the real files
  PASS.
- **E-key study** (`~/projects/grudgelands-orchestration/r78/reports/ekey-study.md`): the
  client samples aux1 per frame and reports one snapshot every `dedicated_server_step`
  (0.09 s, about 0.1 s at 60 fps) in an unreliable packet; a 60 ms tap is missed about
  40 % of the time, an 80 ms one about 20 %. Neither 5.18 nor upstream master latches
  presses. **Recommendation: a client latch** (keys that went down since the last report
  ORed into the next one; about 10–15 lines in `client.cpp`), as a patch in the web fork
  now and proposed upstream for desktop; keep `dedicated_server_step` at 0.09 (0.05 costs
  about 1.8× the per-step work under load and only halves the window). No game or server
  change was made. **The user's decision is open.**
- **EXPED** (`r78_exped`, 926 checks): three static swaps instead of one: the hanging
  lantern → the city copy, `default:torch_wall` → `grug_decor:expedition_torch_wall`,
  `default:bookshelf` → `grug_decor:expedition_bookshelf`; every cell of every template at
  every tier passes builtin `falling.lua`'s rules. The respawn lock overrides
  `core.show_death_screen`: its own form with a grey "Respawn in N s" while a living member
  of the run fights, freed at 10 s or at the first tick after the fight; Esc re-shows at
  once (fix round). 5 related fixtures 6/6 PASS with the own one.
- **ARMOR** (`r78_armor` PASS; two selections, 15/15 after stub fixes): before → after
  (shown), same-level attacker, item level 60: cloth 15 → 156 (23.1 → 23.8 %), leather 42
  → 419 (45.7 → 45.6 %), metal 58 → 577 (53.7 → 53.6 %); cloth at 1: 4 → 40 (16.3 %).
  Over item levels 1–70 every change stays within the old half-point rounding; the largest
  are +2.2 pp (cloth 31), −1.6 pp (leather 21) and −1.3 pp (cloth 65). The cloth curve is
  unchanged (ruling 12). `item_tiers.md`'s generated blocks re-run (`build_doc.py --check`
  CURRENT).
- **BOSS** (`r78_boss`, 108 → 129 checks with the fix round; `r72_ranged` 220): reach =
  `reach − radius − 0.3` edge to edge horizontally (a height difference up to 1.1 is free,
  more counts whole), stop gap 1 node, melee below 4, ranged above 6, kept in between;
  hidden targets re-checked every 1 s. Expedition bosses on flat ground, every swing
  landing at the stop:

  | Boss | Stops off the target | Edge reach | Mode |
  |---|---|---|---|
  | Flintback | 0.93 | 2.4 | ranged/melee by distance (shot range 20) |
  | Nemm | 0.84 | 2.4 | ranged/melee by distance (shot range 24) |
  | Duewarden | 0.65 | 2.2 | melee only |
  | Stone Golem (test vault) | 0.64 | — | — |

  `r72_ranged` base vs branch: cover 12.7 → 14.6 m walked (the 1 s re-check), ledge 3 → 5
  shots. Per-step decision cost 2 → 5 ns (micro benchmark); no new globalstep.
- **EMOTE** (`r78_emote`, 123 → 134 checks with the fix round): the player model grows from
  301 KB to 379 KB, frames 0–645 (wave 485–544, wave_sit 545–604, dance 605–645); frames
  0–484 byte-identical. All model checks (`make_poses.py`, `gen_cloak_model.py`,
  `build_glb.py`, `check_glb.py`, offhand) PASS; 7 related fixtures PASS. Six captures in
  `~/projects/grudgelands-orchestration/r78/emote-shots/`.
- **D:** mod map rows, `module-guide.md` (the stale 60 s), help text (the potion cooldown
  and its status; the Expedition respawn wait), release files. `r44_pp` (pins the help
  text) PASS.

### The user's decisions during the round

§2 (rulings 1–15, 2026-11-12), among them: the cloth curve stays (ruling 12); the round
ends with the coordinator's report and the user's go for the squash merge (ruling 15).

### Coordinator decisions on the lanes' questions (from the handover)

- **SMALL:** guard spots keep the ±1 levels (outposts on slopes need them; street level is
  tried first, over 90 % of spots); Ore Sense keeps its cap of 16 protection checks per
  mark. Both to be told to the user.
- **TAGS:** cause 2 accepted as refuted (the review confirmed it independently).
- **EXPED:** the lock's clock runs on while the player is offline; a freed lock stays free;
  the Second Shift torch look goes to the backlog (to be told to the user).
- **BOSS:** the 0.5 m/s push-back of a tank walking into a boss and the shared one-node stop
  for pure melee mobs are kept.
- **EMOTE:** a repeated click on the playing emote is ignored, the other emote replaces it,
  at most one start per second (lane's choice, accepted).

### Deviations

- **Nametag cause 2 was refuted by the engine source,** so nothing was built for it
  (ruling 7 asked for both): a child whose parent is unknown waits for it
  (`content_cao.cpp`), the parent's init data lists its children, and adds and object
  messages share reliable channel 0. GUI item 9 would show it if wrong.
- **Three static node swaps instead of one:** besides the lanterns, The Second Shift's 29
  wall torches with param2 0 (droppable) and its bookshelf (open to anyone's books) got
  static copies.
- **The realm website's model (glb) is unchanged:** `build_glb.py` exports only stand and
  walk, so the website shows no emotes (its `--check` stays current). The game's desktop
  and web clients get the emotes from the player model (b3d) like every other clip.
- **Guards:** existing raised guards persist in staticdata, so `guard_to_street` (in
  `guard.lua`, outside SMALL's list) moves them once per activation instead of a respawn.
- **Merge order** followed the reviews, not §1's numbering.

### Open for the user

- The GUI test (§6, 15 items, desktop and web), the emotes' look among them.
- The E-key decision: the client latch as a web-fork patch and an upstream proposal (study
  above); `dedicated_server_step` unchanged.
- The coordinator defaults above that the user may overrule (guards ±1, Ore Sense cap, the
  offline lock clock, the torch look).
- Backlog notes from the reports and reviews:
  [BACKLOG](../../BACKLOG.md#round-78--game-night-fixes-gui-acceptance-pending).
