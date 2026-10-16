# Fix round 0.49.1 — after the first 0.49.0 feedback

Coordinator: Claude (Opus 5.5), planned with the user on 2026-10-16.
Status: **agreed**, starts on the user's "go". Process:
[round workflow](../process/round-workflow.md).

Released as **0.49.1**, a compatible patch: 0.49.0 is pushed (origin/main
`bc1e6016`). Existing worlds play on: no migration step, no map reset, no new
world.

## 1. Lanes

| Lane | Goal | Wave | Implementer / reviewer (default) |
|------|------|------|----------------------------------|
| **MLEN** | Mail text limit: 4,000 characters, shown at the field, a too-long message refused instead of silently cut | 1 | Opus / Opus |
| **VIEW** | Every station form shows the whole combined bag (hotbar below, the rest scrollable above, three rows) | 1 | Opus / Opus |
| **DOOR** | A right-click anywhere on a closed door opens it, also with a dialog NPC behind it | 1 | Opus / Opus |
| **DROP** | Mob drops that sometimes slide slowly over the ground and cannot be picked up | 1 | Opus / Opus |
| **HKEEP** | Read-only study: keep the mapchunks of player housing at a map reset | 1 | Opus / the coordinator verifies |
| **WHEEL** | The floating wagon wheel in both PvP fortresses goes | 1 | the coordinator (one line) |
| **GAIT** | Guards (and the other humanoid NPCs) move their legs at a pace that fits their walking speed | 1 | the coordinator (animation values) |
| **ANIM** | Furnace fire and arrow animated over their duration; the form is re-sent only at a change of state | 2 (after VIEW) | Opus / Opus |

Every reviewer works in a fresh context that wrote none of the change.

## 2. Rulings

User, 2026-10-16:

**Mail (MLEN)**

1. **Limit 4,000 characters** for a message (was 1,500). This covers player
   letters, replies and messages to the admin.
2. **Hint under the message field** on both the **Write** tab and the
   **To the admin** tab. On Write it may share the postage line.
3. **Too long → not sent.** The draft stays as typed, and the status line
   says how long it is and what is allowed, e.g. "Too long, please shorten it
   (5,723 characters, 4,000 allowed)." Nothing is charged, and no attachment
   leaves its slot.
4. **Draft hard cap 10,000 characters.** Before the server keeps a draft or
   sends the form back, it cuts the text at 10,000 characters.
5. **Quote in a reply: at most 500 characters.** When the original is
   longer, the quote is cut and ends with " [...]". This applies to player
   replies and admin answers alike (`model.lua` `M.quote`, which so far
   fills up to the full body limit).

**Stations (VIEW, ANIM)**

6. **Station forms** show the whole combined bag like the Character tab:
   the hotbar at the bottom, above it the rest of the inventory, scrollable,
   three rows high. This applies to the furnace and to every other form that
   shows only `main` today: chests, the bookshelf, the vessels shelf, the
   Claim Stone form and the profession workspaces (`default/furnace.lua`,
   `default/chests.lua`, `default/nodes.lua`, `default/init.lua`,
   `vessels/init.lua`, `grug_housing/stone_form.lua`,
   `grug_jobs/workspaces.lua`). It is fixed everywhere at once, with one
   shared view.
7. **Furnace animation** as in §4 ANIM. The fire and the arrow are animated
   images over their duration, independent of each other, each with a
   buffer at its end like the crafting bar. The form is re-sent only at a
   change of state.

**World and interaction (DOOR, DROP, WHEEL)**

8. **Doors before NPCs.** A right-click on a closed door opens the door,
   whichever half is clicked, also when an NPC with a dialog stands behind
   it. Observed: the lower half works, the upper half opens the NPC dialog
   and the door stays shut.
9. **Sliding drops.** A player killed mobs whose drops sometimes, not
   always, slid slowly over the ground and could not be picked up. After a
   waystone teleport and coming back, they could be picked up. The player
   was near Bannerbreak Warhold (the Throng's PvP fortress, zone
   `kragmar_bannerbreak_mesa`). Whether the place matters is open. There is
   no more detail. Find the cause, then fix it.
10. **Wagon wheel.** The floating wagon wheel in one corner of both PvP
    fortresses goes: that one placement, nothing else. Removing it changes
    only fortresses generated from now on. In the production world both
    fortresses already exist (0.49.0 map reset), so the admin digs the two
    wheels by hand after the update. There is no migration step, and 0.49.1
    stays compatible.

12. **Guards' walking legs.** When guards walk, on patrol or wandering, their
    leg animation is too fast. When they run, it fits.

**Study (HKEEP)**

11. **Keeping housing at a map reset.** The idea: at a map reset the admin
    chooses whether the mapchunks holding a player claim are kept. Whole
    chunks are enough; there is no need to cut to the claim's exact area.
    0.49.1 only studies this; the user decides after the report.

### Coordinator defaults

These are marked as such; the user may overrule them.

- **D1 Admin side.** On the admin page, the answer, the compose form and
  "All players" use the same 4,000 limit, the same refusal and the same
  10,000 draft cap. No extra hint there.
- **D2 Subject (60) and report note (200)** keep the current silent cut.
  They are single-line fields and nobody reported a problem.
- **D3 Letters written by code: no change.** NPC, level, quest, Lost and
  Found and system letters go through `grug_mail.send_system`. It cuts at
  the body limit as a safety net, and it keeps doing that. In practice it
  never cuts anything: our longest letter text is about 460 characters. The
  admin's own texts also pass through `send_system`, as the answer
  (`api.lua` `answer_ticket`) and the compose form for one player
  (`admin.lua`, the compose send). So they are checked against the limit
  *before* that call (D1), and a too-long admin text is refused there,
  not cut.
- **D4 Help.** The mail section of Help (`grug_inventory/help.lua`, mail plan
  §3.21) gets one sentence about the limit.
- **D5 Wording.** Hint: "Up to 4,000 characters." Refusal as in ruling 3.
  Numbers use a thousands separator, like the design doc. These are display
  texts; the coordinator checks them.
- **D6 Gait for every humanoid.** All humanoid NPCs share the character walk
  clip (frames 168–187) and walk at 1–1.5 m/s, with the clip at 30–40
  frames/s. They run at 4.6 m/s with the clip at 45–60 frames/s. So while
  walking, their legs move about 2.5 times faster for their speed than
  while running. Default: the same rule for all of them, not only the
  guards: bandits, mirefolk, leaders and bosses, settlement villagers,
  goblin miners and the night families. Vendors stand still and are not
  affected.

## 3. Shared conventions

- **Counting.** A message's length is `M.text_length(M.clean(body, ...))`:
  UTF-8 characters after cleaning, the same rule the store uses. A pasted
  text with colour codes counts what will be stored, not the raw bytes.
- **Why the 10,000 cap (security).** Luanti formspecs have no maximum length
  for `textarea[]` or `field[]`. The engine only drops a form submit whose
  fields total 640 KB or more (`serverpackethandler.cpp`,
  `pkt_read_formspec_fields`), and it does not limit how often a player
  submits. The mail window sends the form back after almost every click,
  with the draft in it (`window.lua`, the `register_on_player_receive_fields`
  handler). The cap keeps that reply at no more than about 40 KB (10,000
  characters at up to 4 bytes each). A reply is never larger than the submit
  that caused it, so the cap adds nothing a modified client could not
  already do. `M.truncate` stops at the cap, so Lua never walks a 640 KB
  input.
- **Enforced in the API, not only in the window.** `grug_mail.send_letter`,
  `send_ticket`, `answer_ticket`, `send_broadcast` and the admin compose path
  refuse a body over `M.BODY_MAX`; they no longer cut it. `send_system`
  keeps its safety cut (D3). The window only keeps the draft and shows the
  refusal.
- Stored letters, tickets and broadcasts need no migration: everything stored
  so far is ≤ 1,500 characters.
- **Cause first** for DOOR and DROP: the lane reproduces the observation and
  names the cause in its report before it fixes anything.

## 4. Lane goals

### MLEN — mail text limit

Raise the message limit to 4,000 characters (ruling 1) and add a draft cap
of 10,000 (ruling 4) in `mods/PLAYER/grug_mail/model.lua`, as
`M.BODY_MAX` and a new `M.DRAFT_MAX`. The draft handlers stop cutting at the
body limit and cut at the draft cap instead: `keep_drafts` in `window.lua`
for `mail_body` and `admin_body`, and `keep_drafts` in `admin.lua` for
`mail_admin_answer` and `mail_admin_body`. The senders named in §3 refuse an
over-long body with the ruling 3 message and leave the draft and the
attachments untouched.

The Write tab and the To the admin tab show the hint (ruling 2, D5) without
moving other elements in a way that clips at the usual GUI scales. Also
apply the ruling 5 quote cut, the D4 help sentence and the
`docs/design/mail.md` limits line.

Tests: extend `tools/r48_mail/portable_test.lua`.

- **Part A:** the length rule at 4,000 and 4,001, UTF-8 counting and the
  draft cap.
- **Part B:** a refused letter charges nothing and keeps its stacks.
- **Part C:** a refused ticket, answer, admin letter and broadcast, and the
  quote at 500 characters with " [...]" (and without it for a short
  original).
- **Part D:** the hint on both tabs, a refusal keeps the draft, and a
  12,000-character submit comes back at 10,000.

Screenshots of both tabs from `tools/r48_mail/capture.sh` (with `LC_ALL=C`)
for the coordinator and the user.

### VIEW — the combined bag in every station form

Every form in ruling 6 shows the player's whole combined bag through
`grug_inventory.inventory_view`. That means `main[9..]` and the equipped bags
as one scrollable flow, three rows visible, with the hotbar `main[1..8]`
below and outside the scroll area, as on the Character tab and the mail
Write tab. The view needs a third mode next to `full` (7 rows) and `short`
(2 rows) in `grug_inventory/ui.lua` (`VIEW_ROWS`, `SCROLL_FIELDS`). Each form
moves to the formspec version and coordinates the view uses. Shift-click
rings reach the bags too, as `rings` does in `grug_mail/window.lua`.

Two points need care:

- **Per viewer.** Each form is built per viewer, because bags differ per
  player. `default.node_formspec` already passes the player to the builder.
  The profession workspaces build their own forms (`grug_jobs/workspaces.lua`
  `formspec(ctx)`).
- **Re-shows.** `node_formspec` re-shows the form to open viewers whenever
  it changes. Until ANIM lands, that happens every second while the furnace
  burns. The scroll position has to survive those re-shows (the `ui.lua`
  comment on the scroll position explains what the client sends).

Tests: a fixture that builds every form in ruling 6 for a player with 0, 1
and 4 bags and checks the lists and the rings. Screenshots of each form with
bags, and of the burning furnace, for the coordinator and the user.

### DOOR — doors before NPCs

The lane reproduces the observation first: a door with a dialog NPC behind
it, clicked in the lower and in the upper half. The background:

- A door is the bottom node with a selection box two nodes high
  (`doors/init.lua`, `selection_box` up to 3/2), plus `doors:hidden` on top
  with `pointable = false`.
- The engine's raycast (`environment.cpp` `continueRaycast`) adds objects
  first. It then tests nodes only up to the voxel of the nearest object
  hit, widened by the largest selection box.
- Two candidates: the NPC's selection box pokes through the door panel, or
  the raycast misses the tall box from the upper voxel. The lane finds out
  which.

The fix belongs in our code. For example, the NPC right-click hands the
click to a closed door between the clicker's eye and the NPC, through one
helper shared by every NPC with a dialog. If the cause is an engine bug, it
goes into `docs/technical/upstream-workarounds.md`.

Tests: a fixture or a headless probe covering both halves, both sides of
the door, an open door (the NPC answers) and no door (the NPC answers).

### DROP — sliding drops that cannot be picked up

The lane reproduces the observation first. It looks at drops on flat
ground, on slopes and against cliffs, and in and around Bannerbreak Warhold
as the reported place (ruling 9: whether the place matters is part of the
question). The coordinator's read-only leads are hypotheses, to be
confirmed or refuted:

- **Drift in the air.** Mob drops and coin bags start with up to ±0.5 m/s
  sideways (`mobs/api.lua` item drop, `grug_mobs/aggro.lua`
  `drop_coin_bag`). The builtin item (`builtin/game/item_entity.lua`
  `on_step`) does nothing while `moveresult.collides` is false ("items
  should probably decelerate in air"). So the sideways speed lasts until
  the item collides. A resting place that never counts as a collision would
  give exactly a slow, endless slide.
- **Spawned inside a node.** A mob dying against a cliff can drop inside a
  solid node. The push-out (`is_stuck` / `force_out`) moves the item with
  physics off and can repeat node by node.
- **Pickup through a server ray.** A left-click on an item picks it up only
  if the server's own ray hits it within hand range (`grug_abilities/input.lua`
  `activate`, then `pickup_delegate`). If the client shows a moving item
  somewhere other than the server's position, the server ray misses, and
  nothing happens. A teleport makes the client load the object again at the
  server's position. That would fit "pickable after coming back".

The fix belongs where the cause is. Two examples: drops that settle, and a
pickup that accepts the punched item within range even when the server ray
misses it.

Tests: a fixture or a headless probe for the case found, plus the plain case
(a drop on flat ground, picked up at once). If nothing reproduces within the
budget, the lane reports its measurements and a defensive fix proposal, and
stops there for the user's decision.

### HKEEP — keeping player housing at a map reset (read-only study)

The question: can a map reset keep every mapchunk that holds a player claim
(80 × 80 × 80 nodes at `chunksize = 5`), so bases survive while the rest of
the world is generated anew? The study changes no code. It writes a report
and may run headless experiments on throw-away worlds (within the mapgen
test-run budget). The report answers:

1. **Engine:** are kept chunks safe from the regenerated neighbours? This
   covers the one-block overgeneration shell, `blitBackAll` and the
   generated flags, decorations, trees, and our Lua writers in
   `on_generated` and after it. Is a whole chunk column needed, or only the
   chunks the claim's height reaches?
2. **Layout conflicts:** which parts of a new layout can fall into a kept
   chunk (settlements, POIs, PvP fortresses and camps, roads, rivers,
   mailboxes, quest targets, waypoints, dragon islands)? Can they be
   computed from the layout caches before generation, so a conflicting
   claim falls back to today's behaviour?
3. **Seams:** what a terrain-changing reset leaves at the kept chunks'
   borders, and whether a tool can tell the admin beforehand (for example by
   comparing heights at the borders).
4. **Map-bound state:** the housing registry (`registry.lua` `map_reset`),
   `grug_mobs` records, static objects in kept blocks, the world
   preparation plan, protection layers, and the owner's relocation and
   travel home.
5. **Platform:** how the platform empties the map today (the upgrade
   contract §3). A proposal for a new reset mode "map reset, keep housing"
   and its tool: the kept chunks computed from `grug_housing` mod storage,
   then every other block deleted, with the admin's choice and a report of
   kept and dropped bases.
6. **Proposal:** lanes, rough effort, risks, and what the user has to
   decide.

Output: `docs/research/housing-keep-reset-study.md`. The coordinator checks
the report's central claims against the code and the engine source before
the user decides.

### WHEEL — the floating wagon wheel

Remove the one placement
`put(-15,1,15,"grug_decor:cottages_wagon_wheel")` in
`mods/MAPGEN/grug_mapgen/wp40/r31_pvp_poi_blueprint.lua`. First check that
both fortresses come from this blueprint and that this line is the floating
wheel. The fortress blueprint's existing fixture, if there is one, runs
once.

### GAIT — walking legs that fit the speed

The guard (`grug_mobs/guard.lua`) walks at 1.2 m/s with the walk clip at 30
frames/s, and runs at 4.6 m/s with it at 45 frames/s. One 20-frame step
cycle covers 0.8 m walking and 2.0 m running. The running pace looks right
(ruling 12), so it is the reference. The walk speed becomes
`run_speed × walk_velocity / run_velocity`, times about 1.2 because a
walking stride is shorter, rounded: for the guard about 14 frames/s instead
of 30. A mob whose walk and run velocities are the same (the settlement
villagers) uses the guard's rate per m/s.

The same rule applies to every humanoid in D6: `bandit.lua`,
`mirefolk.lua`, `bosses.lua`, `start_villagers.lua`, `goblin_miners.lua`,
`night_families.lua`, wherever the shared walk clip is set. The clip choice
(`grug_mobs.walk_animation`, Round 41) stays as it is. This is a first
version by feel, and the user fine-tunes it in the GUI test. It changes only
animation values, so the coordinator does it on main without a lane
review.

### ANIM — furnace animation instead of a re-send every tick

Today the furnace's node timer ticks every second, and every tick changes
the fire and arrow percentages. So `node_formspec.refresh` sends the whole
form, the bag view included, every second.

The crafting bar shows the alternative (`grug_jobs/ui.lua` `progress_bar`).
It is an `animated_image[]` with one fill frame per step, plus half as many
full frames as a lag buffer, and it runs over 1.5 × the job time.
`frame_start` puts it at the elapsed fraction at each build. So the server
only re-sends at the start and at the end.

The furnace gets two such elements:

- the **fire**, running over the current fuel's burn time;
- the **arrow**, running over the current item's cooking time.

Each element starts at its own fraction at every build, so the two stay
independent. A re-send at an item's end starts the fire at its current
frame, and a re-send at a new fuel starts the arrow at its own.

**When to re-send.** Only at a change of state: an item done, a new fuel
lit, the furnace starting or stopping, an input taken out. The `refresh`
comparison must ignore the frames, which change on every build. A state key
from the furnace's own data is one way.

**Buffer.** Each strip ends with buffer frames that hold its final picture:
the arrow full, the fire at its lowest flame, never empty. The timer only
notices an end at its next one-second tick. For very short times (a fuel
that burns 1–2 s), a buffer that is a fixed share of the duration is
shorter than that tick. The lane gives the buffer a minimum length, so a
short fuel does not flicker empty.

**Textures and reuse.** The fire and arrow frame strips are generated
textures like the crafting bar's: a generator script, with the license
following the furnace textures. The profession workspaces' furnace forms
(`grug_jobs/workspaces.lua`) use the same fire and arrow. They get the same
animation through one shared helper.

Tests: a fixture for the frame start at given fractions, and for the re-send
points over a scripted burn (fuel ends mid-item, item ends mid-fuel, a short
fuel). Screenshots, and a short look at a running furnace for the user.

## 5. Rules

- Lanes follow [AGENTS.md](../../AGENTS.md) and the
  [round workflow](../process/round-workflow.md) §3 per-lane gates.
- Fixtures sized to the change: a lane runs its own fixture and the ones
  that test the changed behaviour. The full fixture run happens once per
  lane, at the end.
- No seed fleet: no lane changes terrain, placement, footprints or writers.
  WHEEL removes one decoration inside a blueprint.
- Logic changes are independently reviewed, including fix deltas. The
  coordinator checks only text, colour or layout deltas itself.
- Research findings are hypotheses until checked against the code. A
  refuted lead is not fixed.

## 6. Verification

**Round end (coordinator):** full fixtures, `check_upgrade.py` (0.49.1
against origin/main), `check_fresh_server.py`, one smoke boot. The release
files as for 0.48.1: the `game.conf` version, `tools/web_data/upgrade.json`
(version only, no new entries), CHANGELOG, STATUS, README and the AGENTS
pointer. The CHANGELOG notes that the admin removes the two wheels by hand
(ruling 10).

**GUI checklist (user):**

1. Write tab: the hint is readable under the message field, and nothing
   overlaps at your GUI scale.
2. Write tab: paste a text of more than 4,000 characters and send. The letter
   is not sent, the status line names the length and the limit, the text and
   the attachments are still there, and no postage is paid.
3. Shorten it to 4,000 characters or fewer and send: the letter arrives
   complete.
4. To the admin: steps 1–3 the same way. The full text shows on the admin
   page.
5. Paste more than 10,000 characters and click any button: the text comes
   back cut at 10,000, and Send refuses it as in step 2.
6. Answer a long admin message, and reply to a long letter: the quote is
   cut at 500 characters and ends with " [...]", and the answer goes out.
7. Furnace, chest, bookshelf, vessels shelf, Claim Stone and a profession
   workspace, with bags equipped: the hotbar is at the bottom, and the rest
   scrolls in three rows above it. Shift-click moves items between the
   station and the bags. While the furnace burns, the scroll position stays
   where you left it.
8. Furnace and a profession furnace: the fire and the arrow run smoothly.
   When an item is done mid-fuel, the fire does not jump. When a new fuel is
   lit mid-item, the arrow does not jump.
9. Kill mobs in several places, including near Bannerbreak Warhold: no drop
   keeps sliding, and every drop can be picked up at once.
10. A closed door with a dialog NPC behind it: right-click the upper half and
    then the lower half. The door opens both times, and no dialog appears.
    With the door open, the NPC answers.
11. Both PvP fortresses: no wagon wheel in the air. In the existing world,
    check this after digging them by hand (ruling 10).
12. Guards on patrol and wandering, then chasing: the legs fit the pace both
    times. The same for a bandit, a villager and a leader. If the pace is
    still off, give the coordinator a number (faster or slower).

## 7. Orchestration

- **Start state:** main at the commit that adds this plan, on `bc1e6016`
  (0.49.0, pushed).
- **Model routing:** the user decides per session. The default is that
  Claude coordinates and Opus implements and reviews.
- **Worktrees and briefs:** `.claude/worktrees/r491-<lane>`, branch
  `r491-<lane>`, for mlen, view, door, drop, hkeep and anim. WHEEL and GAIT
  are committed by the coordinator on main, before the wave 1 worktrees are
  created. Private folder:
  `~/projects/grudgelands-orchestration/r49.1/`. The lane-start checklist
  applies to every launch, reviewers and fix rounds included.
- **Process budget:** wave 1 runs five agent lanes at once. Headless Lua
  runs stay within the parallel limit, and fleets run under `chrt --idle`.
- **Shared files and merge order:**
  - MLEN owns `mods/PLAYER/grug_mail/*`, the mail sentence in
    `grug_inventory/help.lua`, `docs/design/mail.md` and `tools/r48_mail/`.
  - VIEW owns the forms of ruling 6 and the new view mode in
    `grug_inventory/ui.lua`.
  - DOOR owns the NPC right-click handlers (`grug_mobs`, `grug_traders`,
    wherever a dialog opens), a new shared helper and, if needed,
    `doors/init.lua`.
  - DROP owns the item-drop and pickup code it finds at fault
    (`mobs/api.lua`, `grug_mobs/aggro.lua`, `grug_abilities/input.lua`,
    `default/item_entity.lua`).
  - HKEEP writes only its report.
  - WHEEL owns its one line.
  - GAIT owns the walk animation values of the files in D6. They are on
    main before the lanes branch, so DOOR and DROP rebase over them without
    conflict.
  - ANIM starts after VIEW has merged. It owns the fire and arrow parts of
    `default/furnace.lua` and `grug_jobs/workspaces.lua`, a new shared
    helper and its textures.

  `grug_inventory` is shared by MLEN (`help.lua`) and VIEW (`ui.lua`), which
  are two different files. Merge MLEN, then VIEW, then ANIM. DOOR and DROP
  both may touch `grug_mobs`: whichever merges second rebases onto the
  first. The rest merge in any order.
- **Decided during the round:** the hint's exact position, from the
  screenshots.
