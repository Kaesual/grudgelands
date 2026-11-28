# Round 89 — Shield feedback, home names and the arena's balconies

**Built 2026-11-28** ([Completion](#completion-2026-11-28)) on the local branch
`round89`, awaiting the user's test. Release 0.89.0, **migrate** from 0.88.0: no
map reset, but one declared migration step whose online part rewrites the
arena's two halls in place (the upgrade contract classifies a protected
composition rewritten inside its unchanged box as migrate, §5.9; the pattern
of 0.69.0). The round
shows how long an effect still runs on its icon, draws an active shield as a
bubble around the player, names the own home in the waypoint list and gives each
hall of the arena Breach Road a stair to a roofed balcony from which players
watch the field in safety.

## 1. Lanes and waves

| Wave | Lane | Deliverable | Model |
|---|---|---|---|
| 0 | BALCONYDRAFT | The design draft of stair and balcony for both halls, on a pick page for the user's go. Starts before the round, from main; tools only. | Astra |
| 1 | UI | The duration cover on every timed effect icon; the home's name in the waypoint list and on the map markers. | Opus |
| 1 | BUBBLE | The shield bubble (UI lane: merged only after the user's go on its screenshots). | Opus |
| 1 | REWRITE | The one-off rewrite of the two hall boxes in an existing world, built and proven against a test change of the templates. | Opus |
| 2 | HALLS | The approved draft in the game: both hall templates, the friendly boxes, the checks of Round 85, Help. Starts on the user's go on the draft. | Opus |
| last | D | The round's records. | Opus |

Wave 1's three lanes and the draft run at the same time; they share no file.
HALLS waits only for the user's go on the draft and for REWRITE's merge.

## 2. User rulings

1. **Duration on the icon** (2026-11-28). Every effect that runs out shows its
   remaining share as a cover on its icon, like the hotbar's cooldowns; the icon
   darkens clockwise as time passes. The caption under the icon stays as it is:
   the shield shows its remaining points, every other timed effect its
   countdown. No second caption line.
2. **Shield bubble.** A half-transparent bubble surrounds a player while a
   shield (an absorb) is active, for **every** shield: yellow-gold for the
   Priest's Shield, bluish for the Mage's Rime Mantle, white to light grey for
   all others (Hold Ground, Unbroken, Parry, Close Dance, Last Light). With
   several shields at once the bubble takes the colour of the **shield cast
   last**; there is never more than one bubble.
3. **The balcony.** Each hall gets a stair inside and, at roof level, a balcony
   out of the building toward the road. The balcony has a **roof of its own**
   and is closed toward the hall's roof, so on foot it is reached only by the
   stair; toward the field it is open behind a parapet. Stair and balcony are
   the faction's **friendly territory**, like the hall. The hall's roof and the
   balcony's roof stay contested ground: a player on a flying mount may land
   and mount there. This narrows Round 85 rulings 10 and 11 only by the new
   boxes.
   **The barrier** (2026-11-28, on the first draft): every open side of the
   balcony is closed by invisible solid blocks directly in front of the parapet,
   not in the gap above it. A player may stand on the parapet, but nobody jumps,
   shoots or heals out of the balcony and nothing comes in (no line of sight);
   spectators see through it. Glass is not wanted.
4. **No new PvP rule.** A player must flag by their own choice to attack an
   enemy in friendly territory; the balcony needs nothing further.
5. **No map reset.** The arena's outer measures do not change. Production runs
   0.87.0 on the map of 0.86.0; the halls are rewritten in place (§3).
6. **Home name.** The waypoint list shows the name the home carries
   (`grug_housing.home_name`) instead of "Your Claim Stone".
7. **Astra drafts the balcony**; the user looks at the proposal as an artifact
   before anything is built.
8. **The bubble's look** (2026-11-28, on the screenshots): the egg shape, not
   the sphere; the surface gets a texture so that it reads as a shield, not as a
   ball. The user picks from variants.

## 3. Shared conventions

- **The cover** (coordinator default). One more image element per status slot,
  drawn from the hotbar's existing cover frames mirrored, so no texture is
  added and no icon texture is recombined per step. The total duration of an
  effect is what the icon row saw when the effect (id and expiry) first
  appeared, so status sources need no change; a refreshed effect starts a new
  cover. Untimed effects show none. Writes only on a visible change, in the
  status pass's existing 0.5 s cadence.
- **The bubble** (coordinator default). One entity attached to the player,
  made when the first absorb appears and removed when the last one ends or is
  used up, on death and on leave; nothing saved. It is not shown to its own
  player in first person (the engine's default for attached objects), so it
  never covers the view; other players and the third-person camera see it. A
  low-poly sphere mesh and one texture per colour. The colour follows the id of
  the absorb added last (`shield_spell`, `rime_mantle`, else neutral).
- **The hall rewrite** (coordinator default). The pattern of Round 69's camp
  rewrite (`camp_rewrite.lua`, upgrade contract §5.9): once after the load,
  every cell of each hall's template box becomes what the new generation writes
  there, read back before the pending key goes. A declared step `0.89.0` of
  `tools/migrate.py` writes only the world marker; its world handler records the
  job, as 0.69.0's does. The arena is protected for
  every player, so no built cell has to survive. The two hall waystones keep
  working (the same node on the same cell, its travel state lives with the
  players). A fresh or reset map generates the new halls and never has the key.
- **The friendly boxes.** A hall's friendly territory becomes a short list of
  inclusive boxes (interior, stairwell, balcony up to the underside of its
  roof) in `breach_layout.lua`; `grug_pvp/rules.lua` already takes a list.

## 4. Lane goals

**BALCONYDRAFT.** A proposal the user can accept or correct: for each hall
where the stair stands, how it reaches roof level without a jump, how the
balcony sits toward the road, what its roof and its wall toward the hall's roof
look like, what a spectator sees from it, and which boxes are friendly. It
stays inside each hall template's box (21 × 19 × 31), keeps the waystone, the
arrival and the muster cells and the sills free, and uses shipped nodes only.
Both factions get the same function in their own style. Output: an offline pick
page with before and after, the draft templates in the tool's folder and a
report with the boxes in the layout's local coordinates.

**UI.** *Cover:* `grug_core/status.lua` (the slot's third element, the first-seen
duration), `status_icons.lua` (the pure frame arithmetic, with the mirrored
frame), `hud_layout.lua` if a geometry constant is needed; the cover frames stay
`grug_abilities`' textures. *Home name:* `grug_home/claim_home.lua` (the claim
waypoint's label), `grug_map/providers.lua` (the home marker and the waypoint
marker, label and tooltip); the greyed entry of a player without a stone keeps
"Your Claim Stone". The lane checks that a 24-letter name fits the list.

**BUBBLE.** The entity and its lifecycle beside the absorb bookkeeping in
`grug_core/combat.lua` (`add_absorb`, `get_absorb`, the soak, death, leave),
the mesh and three textures, and a screenshot probe (each colour, a small and a
tall race, mounted, at night) for the user's go. It reports what the bubble
costs: objects per shielded player, nothing per step.

**REWRITE.** The job for the two hall boxes: its request through the round's
migration world handler, the write, the read-back and the severe report, with
the test the migration rules ask for (a world of the version before, the new
version's boot, both halls equal to a fresh world's). Whether it generalises
`camp_rewrite.lua` or stands beside it is the lane's choice, reported before it
builds if it changes the camp job.

**HALLS.** The two templates as approved, the friendly boxes in the layout, the
territory and build fixtures and probes of Round 85 (`tools/r85_territory`,
`tools/r85_build`), the building-template gate, the Help paragraph and
`docs/design/pvp.md`. One engine boot shows a walk up the stair and the banner
on the balcony, under the roof and on both roofs.

**D.** CHANGELOG, STATUS (production is 0.87.0, the user 2026-11-28), the
design documents the lanes did not own, the Completion.

## 5. Rules

Every lane states its upgrade classification. The planned outcome is
migrate, because of REWRITE's job alone (upgrade contract §5.9); UI and BUBBLE
are expected compatible. BUBBLE and HALLS are merged only after the user's go on their pictures.
No lane changes a shield's numbers, a flag rule or the arena outside the two
hall boxes.

## 6. Verification

- Fixtures per lane: the cover's frame arithmetic and the first-seen duration
  (a refreshed effect, an untimed one, a source entry); the bubble's lifecycle
  (two shields, the colour of the last, used up, expired, death, leave); the
  waypoint label (own home, account home, no stone); the rewrite's test; the
  territory answers of every node of the new boxes and of both roofs.
- The seed fleet is not owed for a change inside the hall templates' boxes
  unless HALLS changes the layout's footprint or the writer's logic.
- **Human tests offered:** the cover's readability on the 40 px icons on desktop
  and web; the bubble in a fight with several shielded players; the walk to the
  balcony and the view of the field from it.

## 7. Orchestration and open points

- **Start state.** The round branch comes from main once Round 88 has landed
  (Round 88 changes `grug_core/combat.lua` and `status_icons.lua`, which UI and
  BUBBLE edit). BALCONYDRAFT touches only `tools/r89_balcony_draft/` and starts
  from main before that.
- **Shared files.** UI owns `status.lua`, `status_icons.lua`, `hud_layout.lua`,
  `grug_home`, `grug_map`; BUBBLE owns `combat.lua` and its new file; REWRITE
  owns the rewrite job and the migration handler; HALLS owns the templates,
  `breach_layout.lua`, `grug_pvp` and `help.lua`. Merge order: UI, REWRITE,
  BUBBLE (after the user's go), HALLS (after the user's go), D.
- **Compaction checkpoints:** after wave 1's merges; after HALLS; after D and
  the round-end run.
- **Decided during the round:** the draft (the user's go, possibly after a
  second pass); the bubble's opacity and colours on the screenshots.

## Completion (2026-11-28)

Five lanes and lane D: BALCONYDRAFT (GPT-6.2 Astra, two passes), UI, BUBBLE, REWRITE and
HALLS (Opus each), each code lane independently reviewed (Opus). Release **0.89.0**,
**migrate** from 0.88.0: REWRITE's declared step 0.89.0 alone (`tools/web_data/upgrade.json`
`migrate` gains "0.89.0"; `check_upgrade.py` PASS at 0.89.0); UI and BUBBLE are compatible,
HALLS is migrate through REWRITE's step (its node alone is compatible). Merge order into
`round89`: REWRITE, UI, BALCONYDRAFT, BUBBLE, HALLS, then lane D; the fixtures run after the
HALLS merge passed 6 of 6. Evidence: the lane folders `tools/r89_ui`,
`tools/r89_bubble`, `tools/r89_rewrite`, `tools/r89_balcony_draft` and `tools/r89_halls`.

**Saved keys:** `grug_mapgen` mod storage `hall_rewrite` (new, `"1"` while the rewrite is
pending; map-bound, cleared at a map reset in the same change), `grug_core`
`migrate_world:0.89.0` (written by the tool, deleted by the runner) and the tool's own
`world_version`. No player meta. The cover's start times, the first-seen table and the
bubble (`static_save = false`) live only in memory; the home name is read from the existing
claim record through `grug_housing.home_name`.

**What shipped:**

- **UI** (rulings 1, 6; §3 "The cover"): a third HUD element per status slot (z 2, scale
  40.25/96) draws `grug_abilities_cd_pie_%02d.png` mirrored (`status_icons.lua`
  `cover_step`/`cover_texture`, 72 frames); no texture added. A stored status keeps its own
  start (`started_us` in `set_status`; a repeated set with the same expiry keeps it); a
  status source's total is first-seen, and a refresh there is an expiry later by more than
  1.5 s, since three sources (the potion cooldown, the Deserter's Mark, the PvP flag) rebuild
  their expiry from whole seconds of another clock. Fix round: the heartbeat statuses
  `scorched` and `dragon_wrath` carry `no_cover` (`icons.has_cover`); `slowed` keeps its
  cover. HUD writes on the same probe, base against lane: a 10 s effect over 11 s 15 → 36
  (+20 cover, +1 offset: at most about 2 cover writes/s, one per pass), a 30 min effect over
  1801 s 625 → 698; 10 more HUD elements per player at the join. *Home name:* the claim row's
  `name` (`claim_home.lua`) is the waypoint's label, `providers.lua`'s home marker reads
  "Your home: <name>"; the Waystones tab's status column moves from 6.8 to 7.35 with a
  2.25-wide Travel button (a 24-W name, 360 px at 16 px, clears it with about 8 px to spare
  at 1280 × 720), and in the fix round the Expeditions tab's buttons share that column.
  Fixture `tools/r89_ui` (94 checks); `r26_status_icons` and `r45_pt9` updated. Docs:
  `inventory_equipment.md`, `home_travel.md`, `world_map.md`.
- **BUBBLE** (rulings 2, 8; §3 "The bubble"): `grug_core/shield_bubble.lua`, one attached
  entity per shielded player, coloured by the live absorb entry with the highest `seq`
  (`shield_spell` gold, `rime_mantle` frost, else plain); synced at the add, the capped add,
  the prune, the soak and a new `on_expire` of the `shield` status; removed on death and
  leave. The mesh is an egg, a 16 × 8 ellipsoid of 224 triangles, 1.7 × 2.1 nodes, centred
  0.93 above the feet; glow 6 (raised from 4 after the first capture), `automatic_rotate`
  0.5. Three looks rounds: round 1 the plain 32 × 32 tint (egg and sphere, two opacities);
  round 2 hex, panels and lattice at 128 × 64; round 3 web, marble and lightning (hex as the
  comparison row). The shipped look is **web**: many short, fine, irregular veins over a soft
  tint (alpha 32, thicker toward the poles), 256 × 128, 26.9 / 28.3 / 28.8 KB (gold, frost,
  plain; about 0.3 KB each in round 1), all from `tools/r89_bubble/gen_bubble.py`
  (`--check`). Cost: one object per shielded player, no step, globalstep or pass; a sync
  walks at most 7 entries and calls the engine only on a colour change. Fixture
  `tools/r89_bubble` (70 checks); capture boots of 24, 24 and 33 shots.
- **REWRITE** (§3 "The hall rewrite"): `grug_mapgen/hall_rewrite.lua` stands beside
  `camp_rewrite.lua` (untouched) with the same flow, its own key, log lines and severe key;
  `wp40/r89_hall_sites.lua` builds each hall box with the real `breach_model` and
  `breach_writer` and refuses a template whose box differs from 0.88.0's or a kept cell;
  handler `0.89.0` in `grug_core/migrations.lua`; `tools/migration/steps/v0_89_0.py` writes
  only the marker. The e2e `tools/r89_rewrite/run.sh`: on test templates 40 checks, 0 failed
  (361 s, after a first run of 36/40 with two harness defects); on the real templates
  (rerun by HALLS, killed between the halls) **40/0 in 373 s**: each box 12369 cells, write
  4.1 ms, emerge 4.9 s (Accord) and 0.3 s (Throng); **746 cells changed in the Accord's hall
  and 721 in the Throng's**, 55 each on both sides of the mapchunk border y = 128; both
  stones work, a visitor keeps the discovered Accord stone. Fixture
  `tools/r89_rewrite/portable_test.lua` (49552 checks after the fix round's refusal tests);
  `tools/r69_camp`'s last-entry assertion became a membership check;
  `tools/r43_mt/container_test.sh` 38 OK, 2 skipped. Docs: the upgrade contract (§3.2,
  §5.7, §5.8, §5.9), `modules/platform.md`, `modules/mapgen.md`, `upstream-workarounds.md`.
- **BALCONYDRAFT** (rulings 3, 7): the pick page `tools/r89_balcony_draft/` (`build.py
  --check`). First pass (f2c652fa): a three-wide stair from beside the waystone aisle, a
  square landing, sixteen half-node rises to a roofed balcony over one gate per hall, a
  7 × 9 deck, a solid wall toward the hall's roof. Second pass (6d1c12b1, the barrier): the
  rail one cell in, a 6 × 9 deck (two rows of six), 45 barrier cubes per hall, three parapet
  posts and two upper corbels removed to open the view; 40 stills.
- **HALLS** (rulings 3, 4; §3 "The friendly boxes"): both templates as drafted (byte-equal);
  `grug_mapgen:arena_barrier` (airlike, walkable, `pointable = "blocking"`, not diggable,
  light passes, no `grug_air`) and a wrapper of `core.raycast` in `world_nodes.lua` that
  points the barrier for every ray naming no pointabilities. Friendly boxes per hall in
  `breach_layout.lua` (`friendly`, the interior first), arena-local inclusive, Accord (the
  Throng mirrored in x and z): interior (31,7,−14)…(41,13,14) with the lower flight and the
  turn, upper stair (30,14,−14)…(37,18,−12), balcony (23,15,−14)…(29,18,−6); the barrier at
  x 22, y 14..18, z −14..−6. `grug_pvp` walks the list. The engine proof
  (`tools/r89_halls/proof.txt`): **66 passed, 0 failed, 4 findings** (two per hall), in
  short: walking, jumping from the rail, flying in, falling and pressing in, a flying mount
  out and in all stop at the barrier's faces; aim, heal and ranged rays and the turned-box
  ray end on the barrier (controls on the deck hit); a client's ray points nothing; a
  projectile is refused at launch; area anchors stop; a bandit archer has no sight and in
  8 s fires 0 arrows (control without the barrier: 4 arrows, 3 and 4 hits); the territory of
  stair foot, turn, upper stair, deck and rail top is friendly, in front of the barrier,
  both roofs and the gate court contested; no dark cell (deck 10 by day, 7 at night). The
  findings: a homing projectile already in flight follows its target through (hit at u
  22.4), and an area on the hall's roof 3 nodes away reaches the deck. The escape check
  (`check_escape.py`): no held position without suffocation; 76 (Accord) and 75 (Throng)
  positions open in 0.88.0 now have no way out, all suffocating (the review counted 26 per
  hall a player on foot could have stood on). Fixture `tools/r89_halls` (34719 checks);
  `r85_territory` and its `seeds.lua` build the list as `grug_pvp` does;
  `building_templates/check.py` 0 errors (`editor_palette.txt`, the barrier's `nodes.json`
  row). Help's arena paragraph, `pvp.md` §1 and §6.4, `world_zones.md`, `modules/mapgen.md`,
  `modules/combat-classes.md`.
- **Lane D:** the version, this section, CHANGELOG, STATUS, README's current state, the
  contract history's 0.87.0–0.89.0 lines, BACKLOG lines and `combat_ray.lua`'s comment that
  said no blocking node exists.

**Reviews:** UI MERGE (three Low: the looping heartbeat cover and the tabs' button columns,
both fixed in the fix round, and the shield's cover stopping short of full, documented in
`inventory_equipment.md`); the fix round checked by the coordinator. BUBBLE MERGE (one
cosmetic stale file name in a comment, fixed in the look round); the look rounds changed
textures and tools only and needed no new review. REWRITE MERGE (Medium, process: the six
old steps' `test_step.py` container runs are owed at the round end; Low: the box-pin and
kept-cell refusals untested and the crash docstring, both fixed in the test-only fix round).
HALLS MERGE (Medium and Low user questions: area effects across the barrier and players
stuck in the new stair cells; the homing projectile confirmed as a design rule; the raycast
wrapper recommended as built).

**The user's choices during the round (2026-11-28):** the plan agreed as migrate; the
balcony draft accepted, with the barrier of invisible solid blocks directly in front of the
parapet, not in the gap above it (ruling 3 extended), and its second pass accepted; on the
bubble the egg, not the sphere, with a surface texture so it reads as a shield (ruling 8),
then hex, panels and lattice rejected as too regular in favour of irregular fine veins, and
**web** accepted; the cover's strength kept as shot (the hotbar's 50 % black; about 70 % had
been proposed); the looping Slowed cover kept as built (no objection raised); after the
HALLS review the pictures accepted, players stuck in the new stair cells ignored with no
special handling, area effects through the barrier accepted, the raycast wrapper kept; the
go for the UI, BUBBLE and HALLS merges.

**Deviations from the plan:**

- The classification became **migrate** (the draft said compatible): the hall rewrite is a
  declared step (contract §5.9), corrected before the plan was agreed.
- Merge order REWRITE before UI (planned UI first): UI waited for the user's word on the
  cover; BALCONYDRAFT was merged before HALLS as the approved draft.
- The draft's second pass moved the rail one cell in (deck 7 × 9 → 6 × 9) so the barrier
  stays inside the hall template's box.
- HALLS installs a global `core.raycast` wrapper in `grug_mapgen/world_nodes.lua`, outside
  its file list's spirit: without it every server ray (aim ray, mob sight, shot locks, blink,
  area anchors) reads the "blocking" barrier as a clear line. The alternative,
  `pointable = true`, would outline the barrier under the crosshair on the deck.
- The cover's total is first-seen only for status sources; stored statuses keep their own
  start, and a source's refresh needs an expiry later by more than 1.5 s. The heartbeat flag
  lives in `status_icons.lua`'s registry, not in the owners' files.
- The bubble is an egg with veined 256 × 128 textures, not the low-poly sphere and plain
  textures of §3, and the `shield` status gained an `on_expire` (the status record expires
  with the last absorb before any value function runs).
- REWRITE stands beside `camp_rewrite.lua` instead of generalising it; HALLS also made the
  rewrite e2e's kill between the halls deterministic (its probe holds the second emerge).

**Human tests proposed by the lanes:** the cover's readability on the 40 px icons on
desktop and web; a fight with several shielded players on desktop and web (the colour
switches on a recast, the bubble vanishes on a break and on expiry); the walk up the stair,
standing on the rail and the view of the field, desktop and web; Blink from the deck toward
the field and from a flying mount toward the deck; a travel to and from both hall stones
after the rewrite (not run by REWRITE).

**Round-end gates** (the coordinator, on `round89` after lane D's merge): the full fixture
set once, 406 passed, 0 failed; `check_fresh_server.py`, `check_upgrade.py` (0.89.0 against
origin/main), `r28_design/validate.py --game` (0 errors, 18 warnings), `r29_e4/income.py
--check`, the bat mesh check and `r89_bubble/gen_bubble.py --check` pass;
`building_templates/check.py` passes (286 templates, 0 errors); a smoke boot on seed 88
passes; in the `debian:trixie` container the tool's tests (`r43_mt/container_test.sh`) and
the unit tests of the six old steps (r44, r45, r47, r48, r53, r67) pass. The whole-round
review of the merged branch said **LAND** (no Critical, High or Medium finding; two Low
ones fixed before the squash: the tools index line of the balcony draft and two comments
that called the bubble's mesh a sphere). Its note: the cover stops at 71 of 72 steps, so
"fully covered" leaves a 5° wedge clear, invisible at 40 px.

## Carry-overs

- **The raycast wrapper's owner:** a `grug_core` registry beside `aim_raycast`, installed
  before any other mod loads, would be a better home than `grug_mapgen/world_nodes.lua`.
  Its one gap: a caller that passes its own pointabilities gets the engine's "blocking"
  answer (a clear line); none does today. A modified client could still send punches
  without pointing (no server line-of-sight check; theoretical).
- **A homing projectile in flight** follows its target across the barrier (hit at u 22.4 in
  the proof), the design rule of `combat_stats.md` ("cover protects before launch only");
  launching through the barrier is refused.
- **Nametags from the balcony:** the road's centre is 28–33 nodes from the deck, beyond the
  25-node nametag range, so spectators see no names on the road.
- **"Home: Claim Stone"** still reads so on the Character page (`grug_inventory/pages.lua`
  home state), in the quickbar's heading (`grug_quickbar`) and in the innkeeper's "Your home"
  line; the claim row's `name` is there for them.
- **Covers after a relog:** a status source's cover (the potion cooldown, the Deserter's
  Mark) starts clear after a relog because the row first sees it then; so does the guild
  effect, re-set at the join (`grug_guild/effect.lua:497`). A source entry that drops off a
  full row (more than 10 effects) or is hidden by a false value also starts clear when it
  returns, and for 1–2 s movement-flag crowd control the first-seen total is low by up to
  one pass (0.5 s). A source could pass its own start.
- **The Slowed heartbeat causes:** the rime node (0.5 s on each 0.25 s sample,
  `boss_dragons.lua:365`), ice water (0.5 s on the 1 s tick, `:349`) and the treant's aura
  (1.2 s every 1 s, `night_families.lua:201`) re-set `slowed`, so its cover loops about every
  2 s while they last; the timed slows share the id and want the cover. A fix is the movement
  aggregator reporting heartbeat slows apart (owner files).
- **The shield's cover** can stop short of full: the `shield` status's expiry is the longest
  absorb's at the last add and is not shortened when that absorb is used up.
- **The Waystones list's width** assumes the fixed 53.3 px unit; below about 580 px window
  height or with a raised `font_size` a 24-W name reaches the Travel button.
- **The bubble:** after a non-last absorb ends, the colour and a bubble cleared from outside
  follow at the next status pass (up to about 0.5 s); the veins look slightly pixelated close
  up (the engine forces nearest-neighbour filtering on entities); the plain web bubble at 25
  nodes by day is a faint, lighter egg.
- **`gen_bubble.py --check`** compares PNG bytes and so depends on the Pillow version (12.3.0
  here).
- **`tools/building_templates/nodes.json`** is stale for older rounds (the claim and account
  stones, Expedition decor, aliases); HALLS added only the barrier's row.
- **Players stuck in the new stair cells** (the user: ignored): a character who logged out
  in 0.88.0 on one of about 26 standable positions per hall joins inside the stair,
  suffocates at 5 % per second and leaves by Return Home (30 min cooldown) or dies (10 %
  wear from level 10).
