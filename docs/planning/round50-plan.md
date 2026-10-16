# Round 50 — Hotbar A/B, claim containers across map resets, the class-redesign page

Coordinator: Claude (Opus 5.5), planned with the user on 2026-10-16.
Status: **complete** on main, not pushed ([completion](#completion-2026-10-16)). Process: [round workflow](../process/round-workflow.md).

Released as **0.50.0**, a **compatible** release: from 0.49.1 there is no
migration step, no map reset and no new world. It is also the first version
whose migration tool packs claim containers before a map reset. Production
is on 0.48.1 and stays there until 0.50.0 (ruling 10). It then moves straight
to 0.50.0, across 0.49.0's map reset, and that reset packs its claims.

## 1. Lanes

| Lane | Goal | Wave | Implementer / reviewer (default) |
|------|------|------|----------------------------------|
| **HOTBAR** | Two hotbar layouts, A and B, switched in every form that shows the hotbar and in the E quick UI | 1 | Opus / Opus |
| **PTOOL** | The migration tool reads the old map before a map reset and packs every container in every claim; contract and declaration schema 3 | 1 | Opus / Opus |
| **PGAME** | The game side of packing: packed container items, the Claim Stone's take-only inventory, the first-start clean-up, the notices | 1 | Opus / Opus |
| **ART** | A page that shows the current planning state of the new skills and talents, with notes the user can leave | 1 | Opus / the coordinator checks and publishes |
| **PACCEPT** | End-to-end acceptance: a world built by the real 0.48.1 game, packed by the 0.50.0 tool, booted by 0.50.0; measured packing time; the fixture world for the platform | 2 (after PTOOL and PGAME) | Opus / Opus |

Every reviewer works in a fresh context that wrote none of the change.

## 2. Rulings

User, 2026-10-16.

**Hotbar A/B (HOTBAR)**

1. **A by default.** Every player, new and existing, uses hotbar A. B starts
   empty, with no skills and no items.
2. **Where to switch.** Wherever the hotbar is shown as part of a form:
   - every inventory page that shows it;
   - the station forms that show the bag since 0.49.1: furnace and
     workspaces, chests, bookshelf, vessels shelf and Claim Stone;
   - the mail Write tab;
   - the E quick UI.
3. **The study's recommendations are accepted:**
   - **Switching in combat** is allowed at any time. A switch cancels a
     pending cast, charge, draw, eating or held input, and needs a fresh
     press. Only an anti-spam limit applies: about one switch per 0.25 s.
     This is not a gameplay cooldown.
   - **Consumption order:** every consumer keeps today's order and takes from
     the inactive layout last. This covers crafting, quests, the Fallen
     Crown, housing fuel and ammunition.
   - **Vendor and repair:** the vendor's sell list leaves the inactive layout
     out; the repair quote includes it.
   - **The control** is two small buttons, "A" and "B", with the active one
     marked. It is not a dropdown.
   - The same skill may lie on A and on B.

**Claim containers across a map reset (PTOOL, PGAME)**

4. **The migration tool packs, not the game server.** At every map reset,
   while the server is stopped and before the map is emptied, the tool
   (`tools/migrate.py`) does three things:
   - reads the map database;
   - scans every housing claim exactly in its area: 101 × 101 nodes, from y
     −100 upward, only map blocks that exist;
   - prepares each owner's Claim Stone inventory for the next start.
5. **What is packed.**
   - **Every container:** chests, locked chests, bookshelves, vessels
     shelves and furnaces, each with its contents and fuel. In general this
     means every node that holds items (§3).
   - **The Claim Stone's remaining fuel** comes back as charcoal of the same
     burn time, **rounded up**.
   - **Ownership:** every container in a claim belongs to the claim's owner,
     whoever placed it.
6. **Packed containers are soulbound.**
   - **Where they may be:** only in the player's carried inventory. That is
     `main` with the hotbar, every bag, and hotbar B's hidden list.
   - **What is refused:** mailing, putting into chests or other containers
     (so containers never nest), dropping and selling. Dropping is
     *refused*: it does not destroy the item, unlike the Claim Stone today.
   - **Where they come from:** only from the Claim Stone inventory.
   - **Placing** one in the world restores a normal container with its
     contents. A locked chest belongs to whoever places it.
   - There is no other way to pick up a filled container.
7. **The Claim Stone inventory.**
   - It is take-only and waits indefinitely.
   - It is not reachable while the stone is in planning (draft) mode, only
     once the stone is activated with coal.
   - If the stone is destroyed or picked up, the inventory keeps what is
     still in it.
8. **Removed items** are taken out of the packed containers as part of the
   migration, before any player sees them. The tool cannot know the new
   version's items offline, so this runs at the first start (§3, the
   world marker).
9. **Baseline 0.48.1.** Migrations are planned only from 0.48.1 on, the
   production version; older worlds do not matter (there is no other
   production server). `--map-reset` on a world below 0.48.1 is refused.
10. **Production waits.** Production stays on 0.48.1 with no 0.49.x deploy
    and no manual map reset until 0.50.0.

**Platform agreement (kaesual-stack, 2026-10-16)**

The platform agreed to the proposal, with its own deviations. Grudgelands
accepted those. Records:
`~/projects/grudgelands-orchestration/r50/kaesual-contract-handoff.md` and
`kaesual-contract-reply.md`.

- **One tool run, `--world <dir> --map-reset`, before the emptying.** The
  pass packs first and then runs the due steps. It runs as the platform's
  existing migrate pass, so it comes with:
  - an automatic backup;
  - a "started" mark;
  - after any failure, the realm stays blocked until the backup is restored
    in place;
  - no automatic repeat.
- The tool runs first in every migrate pass. Steps never read the map.
- **The map is emptied only after exit 0** with the tool's `done` line, which
  carries `"map_reset": true`.
- **The gate:** the built-in pin's declaration carries `map_reset_pass`. The
  declaration is schema 3, and the producer and the index accept it.
- **The runner image** gets `python3-zstandard` from the same Debian
  snapshot (Python 3.13). Map access goes through `world.mt`'s
  `pgsql_connection` and the same `PGPASSFILE`. On a managed realm, mod
  storage is SQLite in the `mod_data` mount.
- **What else the tool must support:**
  - `--check --map-reset` proves read access to `blocks`: one row is
    selected and decoded.
  - A manual "Reset the map" on a world already at the tool's version, with
    no step due, still packs. It is never refused as "nothing to do".
- **Later resets append.** Uncollected containers from an earlier reset are
  kept. The tool numbers its own passes; the platform passes nothing.
- **Platform acceptance:** a 0.48.1 realm on Rehearsal with a claim, a filled
  chest, a locked chest and a lit furnace, upgraded to 0.50.0.

**The class-redesign page (ART)**

11. **An artifact** shows the current planning state of the new skills and
    talents. It shows:
    - per class, the skills and the talent trees with their numbers;
    - what is decided, what is only a candidate, and what is open;
    - the review findings and the user's decisions on them
      ([continuation](class-redesign/continuation.md)).

    The user can leave a **note** on every skill, talent and open decision.
    The notes are saved, and the coordinator can read them for the
    preparatory planning round.

**Decided during the round (user, 2026-10-16)**

12. **Talent unlocks place nothing** (D1 confirmed). A talent unlock never
    puts a skill on a hotbar; the player drags it from Talents & Skills.
    This supersedes Round 49's rule that a granted skill makes room on the
    hotbar for talent unlocks (`round49-gameplay-draft.md` ruling 10); the
    class kit grant keeps it. A talent that changes a skill **overwrites the
    old variant**: today such a talent keeps the skill's button and changes
    what it does, so it acts on A and B alike. When the class rework
    introduces a variant that is a different skill, it replaces the old one
    in place on every layout that holds it.
13. **Empty containers are packed too.** They come back as plain node
    items, not as packed containers: the first-start clean-up turns each
    empty packed container into its node's own item (an open or lit
    variant becomes the node it drops) and stacks equal items.
14. **The contents live outside the item.** A packed container carries only
    a reference, the node name, its description and its image. Its contents
    are stored in `grug_housing`'s mod storage and fetched when it is
    placed; then the stored contents are deleted. This keeps inventories
    small, also with written books.
15. **Whoever holds a packed container may place it.** Should one reach
    another player, it is still placeable, so nobody keeps an unplaceable
    item. If its stored contents are missing, it places as an empty
    container and the server logs a warning.

### Coordinator defaults

The user may overrule these.

- **D1 Starter kit and talent unlocks.** The base kit granted at character
  creation or a class choice goes onto the **active** layout, as today; B
  stays empty. Talent unlocks never place anything (study D3).
- **D2 Open windows and refresh.**
  - A switch re-shows the form it was made in.
  - Crafting jobs took their ingredients at start, and vendor rows refuse
    after a change, so no other window needs handling (study D4).
  - Both layouts' skill icons and cooldown overlays are refreshed on every
    sync pass (study D7).
- **D3 Soulbound in B.** The Claim Stone and the packed containers may lie in
  hotbar B's hidden list (study D10). B's list joins the carried lists of
  `grug_housing/soulbound.lua`.
- **D4 No transformation API now.** The study's
  `replace_representation` (study D11) waits for the class rework, which will be
  its first user.
- **D5 One packed item.** A single generic item,
  `grug_housing:packed_container`, carries:
  - the node's name;
  - its item lists;
  - a short description that the game fills in at the first start, such as
    "Packed Chest, 14 stacks".

  It uses the container's own image through the item-meta image override
  where the engine supports it; otherwise it uses a neutral icon. No new art.
- **D6 Unknown or changed containers.** If a packed node is no longer
  registered, or if a restored list is smaller than the packed one, the extra
  stacks are not lost. The first-start clean-up moves them into additional
  packed chests in the Claim Stone inventory.
- **D7 State that is not restored:**
  - a furnace's burning process (it comes back unlit, with its fuel in the
    fuel list);
  - a locked chest's former owner;
  - a node's facing (the new placement faces like any placement).

  Personal workspace records exist only at public stations, which are not in
  claims. If one is found anyway, its items are packed into a chest
  (ruling 5: everything belongs to the owner).
- **D8 Notices.** A player with waiting containers gets one notice at join:
  "Belongings from the old map wait in your Claim Stone." The Housing
  Steward says the same. Help gets one sentence each about Hotbar A/B and
  about packed containers.
- **D9 Wording.** Display texts are written by the lanes. The coordinator
  checks them from the screenshots.

## 3. Shared conventions (PTOOL ↔ PGAME)

PTOOL writes these and PGAME reads them; both lanes build to them in
parallel. A lane that finds a reason to change one of them asks the
coordinator first.

- **Claims:** `grug_housing` mod storage, `claim:<id>`, the pipe-separated
  `v2|owner|x|y|z|placed_at|activated_at|paid_until|expired_for…` record
  (`registry.lua`). The area is `x ± 50`, `z ± 50`, from `y = −100` upward
  (`M.RADIUS`, `M.MIN_Y`). Only blocks present in the map database are read.
- **What holds items:** the node inventory of every node in the area that
  has one: the node's lists in its metadata. Personal workspace records are
  handled as in D7. PTOOL lists the containers it finds by node name and
  count.
- **Recovered entries:** `grug_housing` mod storage, key
  `recovered:<player>:<seq>:<n>`. Each value is one item string:
  - either a `grug_housing:packed_container` with item meta `node` (the node
    name) and `lists` (a `core.serialize`d table of list name → item
    strings), plus `seq`;
  - or plain charcoal stacks, from the Claim Stone's fuel: the claim's
    remaining paid time (`paid_until` minus the wall-clock time of the pass)
    divided by charcoal's burn time (`M.LUMP_SECONDS`), rounded up. Fuel
    burns into `paid_until` as soon as it is added, so the stone's fuel slot
    only displays that time and adds nothing.

  A pass only adds keys. The game deletes a key when its item is taken.
- **Pass sequence:** `grug_housing` key `pack_seq`, which the tool
  increments.
- **World marker:** `grug_core` mod storage key `map_reset_pack:<seq>`. At
  the next load, after the map-reset clears and before any player joins, the
  game's handler:
  - removes items the running version does not register from every
    recovered entry of that pass;
  - applies D6;
  - writes the descriptions (D5);
  - deletes the marker after it succeeds;
  - is safe to run again (upgrade contract §5.6).
- **Survives the reset clears:** the `recovered:*` keys and `pack_seq` are
  not map-bound. The map-reset clear of `grug_housing` (`M.map_reset`) leaves
  them alone.
- **Tool output** (agreed with the platform):
  - `pack_start`, then `pack_done` with
    `"counts": {"claims", "players", "containers", "items", "charcoal",
    "blocks_read"}`;
  - then the usual step events, then `done` with `"mode": "migrate"`, the
    target and `"map_reset": true`;
  - `"backends"` names `map`;
  - refusal reason `pack_baseline` for a world below 0.48.1.

## 4. Lane goals

### HOTBAR — two hotbar layouts

Build rulings 1–3 and D1–D4 on the Hotbar A/B study
(`~/projects/grudgelands-orchestration/r46/research/research-hotbar-ab.md`).
The study was made on main `b47fdc7c`, before Rounds 47–49 changed the bags,
the station views and the starter hotbar. **Re-check every touch point
first** and report what changed. The study's representation is recommended:
a second player list (`grug_hotbar_store`, eight slots) plus the A/B label in
player meta. A switch swaps it with `main[1..8]` in one step and never
yields.

What must hold:

- Existing characters keep their hotbar as A, untouched. B appears empty.
  Compatible: no step, a lazy `set_size`.
- **Skills:**
  - `normalize_kit` must not wipe B's skills; this is the study's highest
    risk.
  - The same skill may lie on both layouts.
  - The skill item guards (`bound_items.lua`) keep a skill out of every
    other list.
- **Lists:**
  - The inactive layout never takes in new items (`ordered_slots`).
  - Every consumer that counts or takes (the study's a1–a12) handles it as
    ruling 3 says, with counting and taking changed together.
  - Death, the map reset's player part and the soulbound guard (D3) cover
    the new list.
- **Where the switch appears:**
  - The buttons appear in every form of ruling 2 through **one** shared
    element. For the station forms this is VIEW's `station_formspec` in
    `grug_inventory/ui.lua`.
  - A switch re-shows that form, keeps the bag view's scroll position, and
    never moves an item the form is holding.

Proof:

- A fixture `tools/r50_hotbar/portable_test.lua` covering the switch, the
  guards, every consumer's order, an existing character's join, skills on
  both layouts, and the switch in each form.
- Screenshots of the inventory page, a station and the E quick UI with B
  active.
- One smoke boot.
- The docs that change: `inventory_equipment.md` (the hotbar) and the Help
  sentence about the two layouts (D8).

### PTOOL — packing in the migration tool

Build rulings 4, 5, 8 and 9, the platform agreement and §3 in
`tools/migrate.py` and `tools/migration/`:

- **Read-only map access** for `backend = sqlite3` (`map.sqlite`) and
  `postgresql`. It reads by position ranges per claim and never writes,
  deletes or alters map rows.
- **The block decoder** for map block format 29: zstd through
  `compression.zstd` on Python 3.14, or else `zstandard`, imported lazily as
  psycopg is. It reads the node-name mapping and the node metadata with its
  inventories. Each part is verified against the engine's code
  (`reference_projects/luanti/src/mapblock.cpp`, `nodemetadata.cpp`,
  `inventory.cpp`).
- **Packing:** every container in every claim area, plus the fuel-to-charcoal
  rule. The output is the §3 entries.
- **The command line:**
  - `--map-reset`, which packs first and then runs the due steps, in one run;
  - `--check --map-reset`, which selects and decodes one block;
  - the `pack_baseline` refusal;
  - the agreed output lines.
- **Safety:** the pass is safe on a world it already packed and then
  restored. Before writing it proves the write path, as the tool does today,
  and its post-step checks cover the new writes.
- **Contract and declaration:**
  - `docs/technical/upgrade-contract.md`: §1 (the order: the tool first,
    then the emptying), §3 (the pre-reset pass), §5 (map access, the mode,
    the output) and §5.8.
  - The declaration goes to schema 3 with `"map_reset_pass": "0.50.0"`.
  - `tools/check_upgrade.py` and its self-test accept and check schema 3.

Proof (fixture and scripts under `tools/r50_ptool/`):

- **Unit tests** of the decoder against blocks the engine wrote. A small
  world generated by `tools/luanti_headless.sh` is enough for this, with a
  disposable probe that places containers with known contents, including a
  written book and a quality item with metadata.
- **The tool on that world**, on SQLite and on PostgreSQL. The PostgreSQL
  run uses the container setup of `tools/r45_ms/run.sh`. Every recovered
  entry must be equal on both backends.
- The refusals, `--check --map-reset`, and a world with two passes (append).
- **Measured:** packing time and the blocks read per claim.
- **Size:** the largest packed item, a 32-slot chest of written books, is
  measured in bytes. If it exceeds what the engine sends in one inventory
  update without trouble, the lane reports it before working around it.

### PGAME — packed containers and the Claim Stone inventory

Build rulings 5–8, D5–D8 and §3 in `grug_housing` and in `grug_core`'s
migration runner:

- **`grug_housing:packed_container`:**
  - It is soulbound (group `grug_soulbound`), so the existing guards
    already keep it out of chests, stations, mail, trades and the inbox.
  - Its `on_drop` **refuses** the drop and does not destroy it (ruling 6).
  - Its tooltip shows the contents.
  - Placing it uses the node's own placement, so protection and
    `on_construct` behave as usual, and then fills the lists. A failed
    placement keeps the item.
  - A locked chest is owned by the placer.
- **The Claim Stone inventory:**
  - one per player, built from the `recovered:*` entries, take-only and
    scrollable;
  - shown in the active stone's form (`stone_form.lua`), never in the
    draft's;
  - taking an item removes its entry;
  - it survives picking up or losing the stone, because the entries belong
    to the player.
- **The world-marker handler** (§3), run in `grug_core`'s migration runner
  after the map-reset clears and before joins, plus D6.
- **The notices** of D8.
- **The docs** that change: `housing.md` and the Help sentence about packed
  containers (D8).

Proof:

- A fixture `tools/r50_pgame/portable_test.lua` covering:
  - the guards: drop, chest, mail, sell, inbox and bags;
  - placing and restoring every container kind with exact contents;
  - the take-only inventory and its draft gate;
  - the marker handler with an unknown item, an unknown node and a shrunken
    list;
  - a rerun of the handler;
  - entries surviving `M.map_reset`.
- Screenshots of the stone's form with recovered items and of a packed
  item's tooltip.
- One smoke boot.

### ART — the class-redesign page

Build ruling 11. The sources are:

- `docs/planning/class-redesign/` (README, the four class candidates,
  balance, implementation design, the reviews and `continuation.md`, which
  wins where it decides against a candidate);
- `docs/planning/class-redesign-handoff.md`;
- `TODO-design-classes.md`;
- `docs/design/ability_targeting.md`;
- for comparison with what ships today, `docs/design/skill_trees.md` and
  `combat_stats.md`.

What the page must do:

- One view per class: the skills (base kit, talent unlocks), the talent tree
  as a graph with ranks and effects, and the key numbers.
- Every element carries a status: **decided**, **candidate**, **open** or
  **changed by continuation.md**. The review findings (H1, M2–M8) and the
  user's decisions appear where they apply. A separate view lists the open
  points of the preparatory planning round (`continuation.md` §5).
- **Notes** on every skill, talent and open point. They are stored with the
  page, so they persist and the coordinator can read them later.
- Names flagged for renaming in the design review are marked as such.

The lane writes the page and its data file and reports how it was built
from the sources. It changes nothing in the repository. The **coordinator**
checks the page against the sources and publishes it.

### PACCEPT — end to end (wave 2)

After PTOOL and PGAME have merged (scripts and receipts under
`tools/r50_paccept/`):

1. Build a world with the **real 0.48.1 game** (a worktree at `1ef11b5e`):
   one claim with a filled chest, a locked chest, a lit furnace with input
   and fuel, a bookshelf with a written book, a vessels shelf, Claim Stone
   fuel, and a second claim of another player.
2. Run the 0.50.0 tool with `--map-reset`, on SQLite and on PostgreSQL.
3. Empty the map as the platform does.
4. Boot 0.50.0 with the raised `grug_reset_world`.
5. Join and check that every container waits in the right player's Claim
   Stone inventory once the stone is active, placeable and with exact
   contents, and that the charcoal count is right.

Also:

- **Measured** packing time for that world, reported for the platform.
- The world, packaged as the platform's fixture (agreed; not required by
  them).
- Optionally, the same with an unknown item planted in a chest (the marker
  removes it).

## 5. Rules

- Lanes follow [AGENTS.md](../../AGENTS.md) and the
  [round workflow](../process/round-workflow.md) §3 per-lane gates.
- Fixtures are sized to the change: a lane runs its own fixture and the
  ones that test the changed behaviour. The full fixture run happens once
  per lane, at the end.
- No seed fleet: no lane changes terrain, placement or writers.
- The migration tool stays Python standard library. The exceptions are
  psycopg (PostgreSQL) and zstandard (map blocks on Python 3.13), both
  imported lazily, and nothing from PyPI. The tool never writes map rows.
- Logic changes are independently reviewed, including fix deltas. The
  coordinator checks only text, colour or layout deltas itself.
- Research findings and study touch points are hypotheses until checked
  against the code.

## 6. Verification

**Round end (coordinator):**

- full fixtures, `check_upgrade.py` (0.50.0 against origin/main, schema 3),
  `check_fresh_server.py`, one smoke boot, and PACCEPT's result;
- the release files: the `game.conf` version, `tools/web_data/upgrade.json`,
  CHANGELOG, STATUS, README and the AGENTS pointer;
- the platform gets the 0.50.0 commit for its pin, the measured packing time
  and the fixture world.

**GUI checklist (user):**

1. An existing character: the hotbar is unchanged and is layout A. Switch to
   B: the hotbar is empty. Switch back: everything is there.
2. Put a skill and some items on B. Switch on the inventory page, at a
   furnace, at a chest, in the Write tab and in the E quick UI. The form
   stays open, and the bag view keeps its scroll position.
3. Switch during a fight and in the middle of a cast: the cast is cancelled
   and nothing breaks. Rapid clicking switches about four times a second at
   most.
4. Crafting, ammunition and quest turn-ins take from the active layout
   before the inactive one. The vendor does not list B's items; the repair
   quote includes them.
5. A new character: the starter kit is on A, and B is empty.
6. On a test world: build a claim with containers, run the map reset as on
   the platform (PACCEPT's script), then join. A notice says your belongings
   wait. The Housing Steward says the same.
7. Place the new Claim Stone: in draft mode the recovered inventory is not
   shown. Activate it with coal: the inventory appears, take-only, and the
   charcoal is there.
8. Take a packed chest: it cannot be dropped, mailed, put into a chest or
   sold. It moves between the hotbar, the bags and hotbar B.
9. Place it: a normal chest with exactly the old contents. The same for a
   locked chest (now yours), a furnace (unlit, with its fuel and input), a
   bookshelf with a written book (the text is intact) and a vessels shelf.
10. Pick up the Claim Stone with items still waiting, place it again and
    activate it: the items are still there.
11. The class-redesign page: every class, the talent trees, the statuses and
    the open points are readable. A note you leave is still there after a
    reload.

## 7. Orchestration

- **Start state:** main at the commit that adds this plan, after 0.49.1
  (`2b82dae7`, not pushed). On the user's "go", the coordinator bumps the
  version to 0.50.0 (schema 2, compatible) before the worktrees are created.
  PTOOL then moves the declaration to schema 3.
- **Model routing:** the user decides per session. The default is that
  Claude coordinates and Opus implements and reviews.
- **Worktrees:** `.claude/worktrees/r50-<lane>`, branch `r50-<lane>`.
  Private folder: `~/projects/grudgelands-orchestration/r50/`. The
  lane-start checklist applies to every launch.
- **Process budget:** wave 1 runs four lanes. Headless and PostgreSQL runs
  go through the shared queue.
- **Shared files and merge order:**
  - HOTBAR owns:
    - `grug_inventory` (`storage.lua`, `ui.lua` for the switch element,
      `hotbars.lua` new);
    - the consumers of the study;
    - `grug_abilities`' kit normalisation;
    - `grug_quickbar`;
    - the hotbar list in `grug_housing/soulbound.lua` and the activation-fuel
      consumer in `grug_housing/api.lua` (study a7).
  - PGAME owns `grug_housing` (except the one soulbound list line),
    `grug_core`'s marker handler and `housing.md`.
  - PTOOL owns `tools/migrate.py`, `tools/migration/`, the contract,
    `upgrade.json` and `check_upgrade.py`.
  - ART writes outside the repository.
  - HOTBAR and PGAME both touch `grug_housing` (`soulbound.lua`,
    `api.lua`, and the stone form only if the shared switch element needs
    it) and `grug_inventory/help.lua` (one sentence each). Whichever merges
    second merges main first. PTOOL and PGAME merge in either order. PACCEPT starts after
    both.
- **Decided during the round:** the packed item's icon fallback (D5), from
  the screenshots.

## Completion (2026-10-16)

All lanes merged on main, each code lane independently reviewed (Opus),
fix deltas reviewed again; the ART page checked by the coordinator against
the sources and published as a private claude.ai artifact.

| Lane | Merge | Outcome |
|------|-------|---------|
| PGAME | `819bd253`, delta `dfbcffae` | `grug_housing:packed_container` (soulbound, refused drop, the node's own image), the active stone's Belongings tab (take-only, partial takes), the marker handler in `grug_core/world_version.lua` after `run_world` (a failure stops the load and keeps the marker; undecodable lists stop it too). Delta (rulings 13–15): contents in `packed:<player>:<seq>:<n>[.<k>]`, the item keeps `ref`, `node`, `seq`, description and image; empties and stations the game cannot restore as themselves come back as their dropped node item, stacked in `recovered:<player>:<seq>:0.<k>`; any holder places; missing contents place empty with a warning |
| PTOOL | `398c8f1e`, delta `be339ee3` | `tools/migration/mapblock.py` (read-only SQLite and PostgreSQL map access, format-29 decoder verified against the engine), `pack.py` (one transaction, read back before and after), `--map-reset`, `--check --map-reset`, refusals `pack_baseline`, `pack_pending`, `map_empty`, `map_block`; declaration schema 3 with `map_reset_pass` 0.50.0; contract §1, §3.2, §3.5, §5. Delta: empty containers packed too |
| HOTBAR | `bd212678` | `grug_hotbar_store` (8 slots) and the A/B label; one switch element in every inventory page, every `station_formspec` form incl. the Claim Stone and its Belongings tab, the mail Write tab and the quick menu; 0.25 s limit, cast/draw/eat cancel; consumers take from the hidden layout last; vendor leaves it out, repair includes it; `normalize_kit` per layout; talent unlocks place nothing |
| ART | — (outside the repository) | the [Class Redesign Board](https://claude.ai/artifact/G2wFpJVxhLq46htZwcogXR): 352 elements with status and source, both trees per class as graphs, findings and decisions, the 68 open points; notes stored in the page's database (collection `notes`) |
| PACCEPT | `ef646f83` | a world built by the real 0.48.1 game, packed by the 0.50.0 tool in the runner image, the map emptied as the platform does, 0.50.0 booted twice per backend: 122/122 checks on SQLite and PostgreSQL; `reset_like_platform.sh` for the GUI test (12/12 own checks) |

**Measured (PACCEPT, two claims, 2,177 map blocks):** the tool run 0.090 s
on SQLite and 0.165 s on PostgreSQL wall clock, the pass itself 0.053 s and
0.062 s (about 25 µs per block); the largest packed item string 905 bytes,
the largest stored contents 1,439 bytes. A 32-slot chest of different
10,000-character books: 324,206 bytes as the tool writes it, 1,153 bytes
after the first-start clean-up. The platform fixture (the 0.48.1 world, a
PostgreSQL dump in the platform's layout, the receipt and the expected
counts, 12 MB) is kept outside the repository for the platform.

**Decided during the round:** rulings 12–15 (§2). The packed item's image
is the node's own cube (D5). Only the five container kinds are restored as
themselves; a filled station of another kind comes back as its item plus a
packed chest of its contents. A second pass while a marker is pending, or a
pass on an emptied map, is refused. The coordinator added a CHANGELOG
placeholder at the start (`318ccefb`), fixed two contract text points
(`b46e86a2`) and put the quick menu's hint on two lines (`d9fb6a1c`).

**Round-end gates on main `f2a65fee`:** full fixtures 203/203,
`check_upgrade.py` (0.50.0, schema 3, against origin/main `bc1e6016`),
`check_fresh_server.py`, `export.lua --check`, `test_pack.py`,
`test_reset_like_platform.sh` and a 120 s smoke boot PASS. `mods/` +1,310
−111 lines in 28 files.

**Backlog notes from the reviews:** waiting entries of an older pass are
not re-cleaned when a later version removes an item (a later item-removing
step must cover `recovered:*` and `packed:*`, contract §1); shift-click from
the Belongings tab fills only `main`; the join notice is a feed line that
may pass during the relocation hold (the Steward and the tab remain); the
bag resize's fail-safe drop could drop a packed item (as the Claim Stone
today); a key-opened locked chest's form has no switch; plain and packed
chests share an icon in the Belongings tab (the tooltip tells them apart);
the `r48_bags` engine e2e fails two checks since Round 49 (the guard
message, the Claim Stone expected in `main[9..]`), on the base as well.

The user's GUI checklist is §6 above; item 6 runs
`tools/r50_paccept/reset_like_platform.sh <world copy> <server.conf>` and
then a terminal server with `--config <server.conf>`.

