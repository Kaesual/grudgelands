# Platform contracts

Part of the [module implementation guide](../module-guide.md), which indexes every
area. What the hosting platform and the website rely on: the world version and migrations, player meta read by external tools, the performance log lines, the web bridge and website accounts. Implementation seams and engine pitfalls only; the
[design docs](../../design/README.md) own the game rules. Source paths in code
spans are repository-relative.

Sections: [World version and migrations](#world-version-and-migrations), [Player meta read by external tools](#player-meta-read-by-external-tools), [Performance log lines](#performance-log-lines), [Web bridge](#web-bridge), [Website accounts](#website-accounts).

## World version and migrations

**Rules** (the working rules for this area; the checks to run after a change are in
[checks.md](../../process/checks.md)):

- A bag's size only grows at a join, so a smaller size needs a migration step
  ([inventory_equipment.md](../../design/inventory_equipment.md) §3).

- **Round 43** ([upgrade contract](../upgrade-contract.md) §5, which owns the
  rules; the tool's interface:
  [tools/README.md](../../../tools/README.md#the-migration-tool)).
- `grug_core/migrations.lua` (`grug_core.migrations`): `versions`, the
  declaration's `migrate` list the start guard reads (the runtime tree has
  no `tools/`; `tools/check_upgrade.py` parses this literal and proves it
  equal), and `handlers[version] = {world = fn(marker), character =
  fn(player, marker)}` for a step's online work. A new step adds its version
  here and, when it leaves online work, its handlers (in this file, above the
  registry: the guard collects them at load) and their fixture. The
  declared steps are 0.44.0, 0.45.0, 0.47.0, 0.48.0, 0.53.0, 0.67.0 and
  0.69.0; every one but 0.44.0, 0.67.0 and 0.69.0 leaves a character handler, run at the character's next join
  before every other join callback, and 0.69.0 leaves a world handler (it
  records the camp rewrite job that `grug_mapgen/camp_rewrite.lua` runs
  after the load; [upgrade contract](../upgrade-contract.md) §5.9). 0.45.0's hands craft-grid and
  `craftresult` leftovers over (give helper, output area, feet), refreshes
  first-tier weapons' capabilities and rebuilds gear tooltips (fixture
  `tools/r45_ms/portable_test.lua`); 0.47.0's rebuilds the stored
  capabilities of gathering tools (Round 47); 0.48.0's sorts `main[9..]`
  and the bags into the halved sizes and mails what no longer fits (Round
  48); 0.53.0's sends a character with a class the one chat line "Your
  talent points have been reset." and nothing else (Round 53, K11): the
  locked and transformed skills are the join's own `normalize_kit`, the
  lower maximum HP the stats' join clamp (fixture
  `tools/r53_ms/portable_test.lua`).
- `grug_core/world_version.lua` (`grug_core.world_version`), loaded first in
  `grug_core/init.lua`: the record `world_version`, new-world recognition
  (`is_new_world`), the guard (`decide`: newer world or a step between
  refuses the start), the test hook (`grug_test_migrations`), the world
  markers (`run_world`, in `register_on_mods_loaded` after every map-reset
  clear), the packing passes' markers `map_reset_pack:<seq>` (`run_packs`,
  right after, through the one handler `register_pack_handler` takes:
  grug_housing's `clean_pass`, Round 50) and the character markers
  (`run_character`, moved to the first join callback as registered, so the
  engine profiler's wrapper survives). Pure
  parts are tested on stubs by `tools/r43_gs/portable_test.lua`.
  `check_fresh_server.py` refuses marker keys anywhere else.
- **The tool** `tools/migrate.py` (entry) and the package `tools/migration/`:
  `cli.py` (command line, events, exit codes, the step loop with one
  transaction per backend, the check mode), `world.py` (`world.mt`, the
  SQLite and PostgreSQL backends, the engine's table layouts, locks),
  `data.py` (the step's `World`: characters, meta, inventories, positions,
  auth and privileges, mod storage, markers, `raw(kind)`, the limit checks),
  `codec.py` (`serialize`/`deserialize`, JSON, `ItemStack`), `steps/`
  (`v<major>_<minor>_<patch>.py`; `v0_44_0.py`, the first, removes mount
  items and skills outside the hotbar; `v0_45_0.py` deletes the mixtures,
  empties the craft grid and `craftresult` into free slots and pins the 0.44.0 item level on
  unmodified gear; `v0_47_0.py` and `v0_48_0.py` only mark every
  character for their online part; `v0_53_0.py` deletes
  `grug_classes:talents`, `grug_classes:respec_used`, every
  `grug_classes:talent_ready:<id>`, `grug_classes:unbroken_ready` and
  `grug_classes:untouchable_ready`, removes the retired skills
  `grug_abilities:{cinderfall,glacial_ward,pinning_shot}` from `main`,
  `grug_hotbar_store` and the bags, writes an inventory only when it
  changed and marks every character; `v0_67_0.py` refunds every metal rod
  as ceil(N / 2) bars of its metal in the inventories, the jobs' `consumed`
  stacks, `grug_housing`'s `recovered:*` and `packed:*` keys and
  `grug_mail`'s mailboxes, offline only, [upgrade contract](../upgrade-contract.md)
  §5.8; `v0_69_0.py` only sets the world marker for its online part). Python 3.13, standard library; `psycopg` 3 imported only for
  PostgreSQL. Unit tests: `tools/r43_mt/test_migrate.py` (the container run
  `tools/r43_mt/container_test.sh`; against a copy of the declaration with
  an empty `migrate` list); end to end with the engine:
  `tools/r43_it/run.sh` (the mechanism) and each step's own test
  (`tools/r44_ms/run.sh` for 0.44.0, `tools/r45_ms/run.sh` for 0.45.0,
  `tools/r47_ms/run.sh` for 0.47.0, `tools/r48_bags/run.sh` for 0.48.0,
  `tools/r53_ms/run.sh` for 0.53.0, `tools/r67_craft/run.sh` for 0.67.0,
  `tools/r69_camp/run.sh` for 0.69.0:
  unit tests and an end-to-end run from a world of the previous release).

## Player meta read by external tools

### The contract

- **An external contract (Round 39):** the realm website reads these
  player-meta keys straight from the world database's `player_metadata`
  and never runs game code; it treats every value as untrusted. They are
  **not renamed or reformatted without notice**: a change raises the
  appearance's `v` or is announced to the website, and is documented here.
  Values reach the database with the engine's player save (players whose
  meta changed, every `server_map_save_interval`, and on leave). A missing
  row is the state before the first write. Plan:
  [round39-web-data-plan.md](../../planning/round39-web-data-plan.md) §2–§3;
  the exported tables (ids with display names, the grammar, the model):
  [tools/web_data/README.md](../../../tools/web_data/README.md).

  | Key | Type | Values | Owner, writer |
  |---|---|---|---|
  | `grug_factions:faction` | string | `accord`, `throng` (`grug_core.factions`); missing: no faction yet | `grug_factions.set_faction`: "Create character" (`grug_classes/selection.lua`) and the admin `/faction` |
  | `grug_classes:race` | string | `human`, `dwarf`, `elf` (The Accord), `orc`, `troll`, `undead` (The Throng); missing: none yet. The game counts a race of the other faction as unset (`grug_classes.get_race`), possible only after an admin `/faction` | `grug_classes.set_race`: "Create character" and the admin `/race` |
  | `grug_classes:class` | string | `warrior`, `mage`, `priest`, `scout`; missing: none yet. Never changes once set (no class change, admins included) | `grug_classes.set_class`: "Create character" only |
  | `grug_xp:level` | decimal integer string | `1` .. `60` (`grug_xp.MAX_LEVEL`); missing: level 1 | `grug_xp`: `set_int` in `set_xp` (every XP change; `add_xp` goes through it) and on every join, derived from `grug_xp:xp` with the current curve. XP stays the authority; `get_level` never reads this key. A realm moved across a curve change needs a new server or a migration step ([upgrade contract](../upgrade-contract.md) §1) |
  | `grug_visuals:appearance` | compact JSON string | the format below; missing: no apply yet (the first join writes it) | `grug_visuals.apply` (`apply.lua`, built in the pure `appearance.lua`) |
  | `grug_accounts:character_id` | string | 32 lower-case hex digits (`[0-9a-f]{32}`); missing: not joined since 0.79.0 | `grug_accounts` (`init.lua` `ensure_id`): written at the character's first join with 0.79.0, also during character creation, and never changed or rewritten ([web-accounts.md](../web-accounts.md) §2: the website binds only an id this table shows) |

### The appearance record

- **The appearance** (`APPEARANCE_VERSION` 3 since Round 55, which added
  `textures.offhand` and `textures.wings`; a version 2 value is rebuilt at
  the character's next join, and until then a website reads it as version 3
  with both `none`, [web export](../../../tools/web_data/README.md#version-2-appearances).
  Version 1 had
  no `textures.armor`, its body carried the old armour overlays, and it is
  rebuilt at the character's next join; until then a website shows it
  without armour, [web export](../../../tools/web_data/README.md#version-1-appearances)):
  what the game draws, with
  the final texture strings, so the website never ports the composition.
  Keys in this order, compact (no whitespace):

  ```json
  {"v":3,"race":"dwarf","look":{"tone":2,"hair":3,"style":1,"eyes":2,"feature":4},
   "cloak":"hunter_2","visual_size":{"x":0.9,"y":0.9,"z":0.9},
   "textures":{"body":"(grug_visuals_skin_mask.png^[multiply:#d8a07c)^grug_visuals_dwarf_body.png^…",
     "cloak":"grug_achievements_cloak_hunter_2.png",
     "armor":"((grug_armor_leather_sleek_chest.png^(grug_armor_leather_sleek_chest_ench.png^[verticalframe:2:0^…))^[hsl:0:-80:-35^[cracko:1:4)",
     "offhand":"none","wings":"none"},
   "slots":{"chest":{"item":"grug_gear:chest_leather_sleek","broken":true,"enchant":["dex"]},
     "mainhand":{"item":"grug_gear:bow_embersteel","broken":false,
       "enchant":["dex","attack_speed_percent"],"pose":"bow",
       "image":"grug_gear_bow_alder.png^[colorize:#b94a24:38^(grug_gear_bow_alder_ench.png^[verticalframe:2:0^[multiply:#20dea2^[opacity:128)^…"}}}
  ```

  (shortened at `…`; whole values from `luajit tools/r39_wm/portable_test.lua
  . examples`). `race` is the race the body is drawn as: a character without
  one (before "Create character") is drawn `human`. `look` holds the five
  option indices of that race (`grug_visuals.LOOKS`, option 1 where none is
  stored). `cloak` is the selected cloak id of `grug_achievements`
  (`catalog.lua`) or `none`; `textures.cloak` its texture or `none` (the game
  then draws the builtin `blank.png`). `visual_size` is the race's stature on
  all three axes (`grug_visuals.RACES`). `textures.body` is the model's first
  texture (the skin under the armour boxes), `textures.cloak` its second,
  `textures.armor` its third (the armour atlas of the worn pieces, `none`
  when nothing is worn: the game then draws `blank.png`); the fourth, the
  weapon card, is empty in the world and not stored (the main hand's image
  is `slots.mainhand.image`). `textures.offhand` is the fifth (a shield's
  or spellbook's layer, [offhand format](../offhand-format.md) §5, §7) and
  `textures.wings` the seventh (the cloak's wing texture), each `none` when
  empty and always `none` while the setting `grug_offhand_visuals` is off;
  the sixth, the Scout's back card, is not stored (it follows the hotbar):
  a reader derives it as the bow (`slots.mainhand`), the blade
  (`slots.offhand`) when the bow is shown in the hand
  ([web export](../../../tools/web_data/README.md#the-offhand-look)). `slots` holds the equipment slots
  `head`, `chest`, `legs`, `feet`, `mainhand` (the Weapon slot; a Scout's
  bow) and `offhand` (a shield, a spellbook, a Scout's melee blade), each
  `{"item", "broken", "enchant"}`; an empty slot is absent. `enchant` lists
  the piece's enchant stat ids (`grug_gear.ENCHANT_ORDER`: `str`, `dex`,
  `int`, `max_hp_percent`, `max_mana_percent`, `crit_percent`,
  `attack_speed_percent`, `dodge_percent`, `armor_rating`), the prefix's
  first; an item has at most one per channel and never one stat twice. The
  two hand slots add `pose` (`grug_visuals.POSE`: `tool`, `edge_down`,
  `bow`, `upright`, `forward`) and `image`, the item's image as the engine's
  wielditem draws it: the stack meta's `wield_image`, else the
  definition's `_grug_world_wield_image` (the image the game's hand entity
  shows for an item whose own wield image is turned for the first-person
  hand), else the definition's `wield_image`, else the stack meta's
  `inventory_image`, else the definition's; enchant colours and the broken
  look included. The offhand slot is stored whether or not the offhand look
  draws it; the item a player holds (a pickaxe, a skill's slot item)
  is never stored, and trinkets have no visual.

### When it is written

- **When it is written:** `apply` runs on join, respawn, race and class
  choice, the stored look, every equipment change but pure wear and
  trinkets, a cloak choice and a dismount; it compares a small key
  (compose's key, the cloak and its wings, the armour's item names and enchant ids, both
  hand slots' item, broken state, enchant ids and image) and builds the
  JSON only when that changed, then writes it only when it differs from the
  stored value. The wield poll never writes it.

### Guarantees

- **Guarantees** (asserted by `tools/r39_wm` over every look of every race
  bare and under the worst armour, every cloak, every hand item and every
  offhand layer plain, enchanted and broken): every texture string is at most
  `grug_visuals.APPEARANCE_TEXTURE_MAX` = 2,048 bytes (measured worst case
  1,164, a body; the armour atlas 1,062, a hand image 268, an offhand layer
  258, a cloak 44) and the whole value at most `APPEARANCE_JSON_MAX` =
  7 × 2,048 + `APPEARANCE_JSON_OVERHEAD` 2,048 = 16,384 bytes (measured
  upper bound 4,145, 1,037 outside the texture strings). Every texture string parses under the **closed grammar**
  `grug_visuals.APPEARANCE_TEXTURE` (`appearance.lua`, the one definition):

  ```
  chain    = part { "^" part }        the first part is never a modifier
  part     = file | "(" chain ")" | "[" modifier
  modifier = name { ":" argument }
  ```

  Groups nest at most 3 deep (`max_depth`; 4 and `[mask` in version 1); nothing is escaped (no `\`, and
  no file name or argument contains `^ : ( ) [`). A file is
  `[a-z0-9_]+\.png` and exists in `mods/PLAYER/grug_visuals/textures`
  (skin, look and armour layers), `mods/PLAYER/grug_achievements/textures`
  (cloaks) or `mods/ITEMS/grug_gear/textures` (hand items and their enchant
  masks). The modifiers with their arguments (`int`: an optional `-` and 1–3
  digits, −999..999; `color`: `#rrggbb`, lowercase hex; each kind's Lua
  pattern and limits are data in `APPEARANCE_TEXTURE.args`): `[colorize:color:int`,
  `[cracko:int:int`, `[hsl:int:int:int`, `[multiply:color`,
  `[opacity:int`, `[verticalframe:int:int`. `[cracko` draws the engine's
  `crack_anylength.png` (listed as `engine_files`), which no string names.

## Performance log lines

- **0.66.1** (`grug_perf`, a CORE mod): the game's performance numbers for
  the hosting platform, written to the server log as `[GRUG-PERF]` lines
  (the platform's log shipper reads them, like `[GRUG-SEVERE]`). **The line
  format is a fixed contract (v1):** fields may be added, never renamed,
  removed or reinterpreted; a new field gets a row below and a fixture
  check.
- **The format.** `core.log("action", ...)`; the message starts with exactly
  `[GRUG-PERF] ` (one space) followed by one JSON object and nothing else.
  Every number is finite and ≥ 0; integer fields are written as integers
  (`minimap_us` and `minimap_bytes` may exceed 2^31, the others fit in 32
  bits); `profiler` is a real boolean; the three round-trip fields are absent
  (never `null`) without measured players; the whole line stays under 4096
  bytes (a minute line is about 400). Numbers are rounded to one decimal
  (0.1 ms, 0.1 s). A line that breaks a rule is stored as plain text by the
  parser and the dashboard silently gets nothing, so `grug_perf/lines.lua`
  writes 0 for any value that is not a finite number ≥ 0. The parser keeps
  at most 2 `minute`, 12 `spike` and 2 `profile_saved` lines per log minute;
  the game writes at most one `minute` per 60 s, one `spike` per 10 s and
  one `profile_saved` per interval (≥ 1 minute).
- **`kind = "minute"`**, once per 60 s of server steps (times in ms unless
  the name says otherwise):

  | Field | Type | Meaning |
  | --- | --- | --- |
  | `v` | int | `1` |
  | `kind` | string | `"minute"` |
  | `span_s` | number | seconds the line covers (about 60; the sum of its steps' intervals) |
  | `steps` | int | server steps in the span |
  | `step_p50`, `step_p95`, `step_max` | number | step interval (nearest rank) |
  | `spikes` | int | steps over the spike threshold |
  | `spike_ms` | number | the threshold in force (250) |
  | `max_lag` | number | `core.get_server_max_lag()` at the end of the span |
  | `players` | int | players online at the end of the span |
  | `objects` | int | active objects, players included (`core.object_refs`) |
  | `luaentities` | int | active Lua entities (`core.luaentities`) |
  | `rtt_p50`, `rtt_max` | number | the players' average round trip (`avg_rtt` of `core.get_player_information`), median (nearest rank) and maximum; absent without players |
  | `jitter_max` | number | the players' average jitter (`avg_jitter`), maximum; absent without players |
  | `minimap_us` | int | Lua microseconds the minimap spent in the span (`grug_map.minimap.stats.us`) |
  | `minimap_changes` | int | HUD changes the minimap sent in the span |
  | `minimap_bytes` | int | estimated wire bytes of those changes |
  | `lua_kb` | int | `collectgarbage("count")` |
  | `profiler` | bool | whether `profiler.load` is on |

  The minimap fields are the difference of grug_map's cumulative counters
  since the last line (the first line counts from the load); 0 without
  grug_map, which knows nothing of this mod (`grug_perf` reads its table
  with `rawget`; `optional_depends` only orders the load).
- **`kind = "spike"`**: `v`, `kind`, `step_ms` (the long step), `players`,
  `objects`, `luaentities`. A step over 250 ms (`monitor.SPIKE_MS`) writes
  one, at most one per 10 s; the spikes in between still count in the
  minute's `spikes`.
- **`kind = "profile_saved"`**: `v`, `kind`, `file`, the base name of the
  saved profile, matching `^profile-\d{8}T\d{6}\.json$` (the engine's name
  for a JSON save without a filter, written into the world folder).
- **What a step interval is:** the `dtime` a globalstep receives. The engine
  measures each server step whole with its own clock, unclamped and
  unsmoothed, and passes it on unchanged (read in Luanti 5.17, line numbers
  of then: `src/server.cpp:136-170`, `:152`; `src/serverenvironment.cpp:1073`;
  `src/script/cpp_api/s_env.cpp:134-143`), so a long step arrives whole in
  the next step's `dtime` and the monitor needs no clock call. The interval
  includes the server's wait for the next step (`dedicated_server_step`,
  0.09 s by default), so an idle server's p50 is about 90 ms; a step that
  overruns it shows as a longer interval.
- **The settings** (`settingtypes.txt` "Server performance", read at load; a
  change needs a restart): `grug_perf_monitor` (bool, default **true**) and
  `grug_perf_profile_minutes` (int, default **0** = off; acts only while the
  engine's `profiler.load` is true).
- **The monitor's cost rule:** per step one recorded interval and a few
  counts (`grug_perf/monitor.lua` `new`: no clock call, nothing per player or
  object, no allocation once the sample array has grown to a minute's
  steps); once a minute it sorts the minute's samples and walks the
  connected players and the object tables (`grug_perf.census`). With the
  setting off the mod registers no globalstep. Measured costs: the
  [0.66.1 entry in the archived status](../../archive/status-through-round-79.md).
- **The periodic profile save:** every N minutes `grug_perf` calls the
  engine's own `/profiler` command definition
  (`core.registered_chatcommands.profiler.func`, registered by
  `builtin/profiler/init.lua:25-50` before any mod loads) with `save json`
  and then `reset`, finds the file by the save's second (the engine names it
  by `os.date("%Y%m%dT%H%M%S")`, `builtin/profiler/reporter.lua:226-268`;
  never from the translated chat reply) and logs `profile_saved`. A failed
  save warns once until a save works again. With `profiler.report_path`
  set, the files land in that subfolder (a warning at load says so).
- Pure parts: `lines.lua` (the contract's fields, rounding, the builder) and
  `monitor.lua` (the recorder, the summary, the file detection), tested with
  `init.lua` on a stub engine by `tools/r661_perf/portable_test.lua`; the
  measuring probe is `tools/r661_perf/run.sh`.

## Web bridge

`grug_bridge` (0.69.1) is the game's side of the [web bridge
contract](../web-bridge.md). Without the HTTP API or either setting it registers
nothing and logs one line, so local and browser worlds play as without it.

- **`link.lua`** is the exchange and free of engine calls, as are `mirror.lua` and
  `bans.lua`; `init.lua` passes in what they need, so `tools/r691_bridge` runs the
  shipped files. Events are encoded when queued: one that cannot be written is lost
  alone and never blocks the queue. The request is assembled from those strings,
  which also keeps its byte bound exact and writes empty lists as `[]`. A queued
  event is valid UTF-8 (`L.valid_utf8`): the JSON writer copies bytes, `M.clean`
  checks only the byte count against the lead byte (`grug_core.text.utf8_whole`,
  shared with the account cleaner, 0.81.0), so an overlong form or a surrogate
  still passes and a text stored before 0.81.0 may hold stray bytes, and a
  bridge refusing that body would stop the queue.
- **Errors** never reach the engine: `core.after` and the HTTP callback run in the
  server step, where an uncaught error ends the server, so every hook, command and
  callback is caught and the exchange goes on. Requests set `quiet`: otherwise the
  engine logs an error for each failed fetch.
- **The mail mirror** hears `grug_mail.store.register_on_saved(kind, func)`, the
  one hook in `grug_mail`: every change of the ticket and broadcast lists ends in
  their save, pruning at a read included. It compares each entry with the last sent
  one, so it needs no knowledge of who changed what.
- **The ledger** of command ids stays in memory on purpose ([contract](../web-bridge.md#commands)).
- **Commands** treat their arguments as untrusted and return result codes; a grant
  goes through the same paths as `/money`, `/xp` and a letter's attachments.
- **Website accounts** (Round 79, capabilities `accounts` and `accounts.password`;
  Round 86 `rewards.defaults`, [contract](../web-accounts.md)): `link.lua` adds
  `accounts_version` (`grug_accounts.accounts_version()`, the reported one) to every request,
  the reward catalogue to a boot's first request and every one until a 200 answers it
  (and again on `resync: ["reward_catalog"]`), and `character_id`/`account_id` to the
  online rows; it hands the response's `accounts` list to `grug_accounts.apply_list`
  after the ban list and before the commands. `commands.lua` runs
  `account.link_answer` (into `grug_accounts.link_answer`) and `account.set_password`:
  the auth entry must exist (`core.get_auth_handler().get_auth`, never
  `set_player_password` alone, which would create a login), the binding must name the
  account, and the entry's form is checked by decoding and re-encoding both base64
  parts before `core.set_player_password`. The bridge calls only `grug_accounts`'
  bridge functions; the rules live there.
- **A command that answers later** (Round 83): `Link:command` hands each type a
  `defer` function. A type that calls it gets `done(code, message)`, which logs the
  one line and keeps the result exactly once (a second call is ignored and logged);
  until then the ledger entry has no result, so a repeated delivery stays silent. A
  deferred command lost in a shutdown or crash stays unanswered (the website marks
  it `unknown` at the next boot).
- **`character.delete`** (Round 83, capability `characters.delete`,
  [contract](../web-bridge.md#amendment-2026-11-18-characterdelete)) lives in
  `delete.lua`: at arrival the checks, the refusals and the deadline, then the name
  is blocked at pre-join (any letter case) and the answer waits. An online character
  is disconnected with `core.disconnect_player`; the deletion then waits until
  `core.get_player_by_name(name) == nil` **and** `core.objects_by_guid[name] == nil`
  (the engine saves a leaving player after its leave hooks and only then drops the
  object, whose guid is the name; a removal before that would be undone by the save).
  Then one call runs every clear of the registry (`grug_core.character_delete`, the
  [rule](../module-guide.md#rules-for-every-mod)), a `core.after` waits one
  mod-storage commit (`server_map_save_interval` + 0.5 s), and one call runs the
  clears again, `core.remove_player` and `core.remove_player_auth` and answers. The
  clears start only while `max(10, commit wait + 4)` seconds remain before
  `expires_at`, so nothing destructive runs after it. A character back in the game
  between the steps (a connection that passed pre-join before the deletion) is
  disconnected again and the sequence goes on from the wait. Every deferred step
  runs under `pcall` and answers `error` on failure. The login guards: the pre-join
  block during a deletion, the refusal of a tombstone beside a used login
  (`grug_accounts.half_deleted`), and the `record_login` guard
  ([workarounds](../upstream-workarounds.md)) with a join hook that sends a
  character without a login away and removes its record by the same sequence.
  `init.lua` publishes the command table as `grug_bridge.commands` for the fixture
  and the engine probe.
- **Tests:** `tools/r691_bridge`: `portable_test.lua` on a stub engine (Round 83:
  section C's deferred answer, I `character.delete`, J the mail clears), `run.sh` a
  real server and client against `fake_bridge.py` (also `--accounts`, the website's
  part of accounts for the GUI test); `tools/r83_del`: the per-mod clears on their
  real code, and `run.sh` the end-to-end deletion with a search of the world.

## Website accounts

`grug_accounts` (Round 79) is the game's side of [website accounts](../../design/accounts.md),
phase 1 ([contract](../web-accounts.md)). The website owns accounts, bindings and rewards;
the mod keeps the website's list and never writes a binding.

- **Pure files:** `model.lua` (the list's validation, persistence and index, the id
  index, the counting rule, the notices) and `flow.lua` (the link by code: states,
  the per-state answer table, both timeouts and the attempt limit on an injected
  clock and `core.after`) take every engine call from `init.lua`, so
  `tools/r79_acc` runs the shipped files. No globalstep: an open request waits on a `core.after`
  timer that re-arms for its current state.
- **The API** (other mods): `enabled()` (the bridge attached and a list held,
  the held version > 0; the Account tab's `is_in_nav`), `character_id(player)`,
  `account_of(name)` → nil or `{id, name}` (the counting binding, for offline names
  through the index), `in_creation(player)` (no class or faction yet, or still waiting
  for the arrival: `grug_classes:arriving` is read directly, there is no accessor),
  `can_link(player)` → ok, reason, `has_reward(name, id)`, `rewards_of(name)` → list of
  `{id, kind, name}` in catalogue order, `register_reward(id, {kind, name, icon, hint,
  description?})` (load time only; `catalog()` lists them, only `id`, `kind` and `name`
  go to the website), `default_rewards()` (Round 86: the first `DEFAULTS_SHOWN` = 4 ids
  of the list's `default_rewards` the catalogue knows, in the order sent, as catalogue
  entries; display only), `register_on_change(fn(names))` after a list was applied,
  `register_on_defaults(fn())` after an applied list changed the default rewards (its own
  signal: a defaults-only change names no character, and grug_bridge resends the
  online list on `register_on_change`), and the
  link flow `link_state(player)` → `{state, account_name?, message?, expires_at?}`
  (`idle`, `checking`, `offer`, `confirming`, `linked` as the one-off success line,
  `refused`; the page's own refusals appear as `refused` with a message), `request_link`,
  `confirm_link`, `cancel_link`, `register_on_link_state(fn(player))`. `WEBSITE` is the
  one address the page names (`WEBSITE_URL` the one its buttons open), `CODE_BUTTON`
  the website's label of the button that creates a link code ("Create Character", Round
  86 ruling 3). The bridge alone calls `attach(push_event)`,
  `apply_list(list)`, `link_answer(args)`, `catalog_rows()` and `accounts_version()`.
- **The list's version** (Round 86, [contract](../web-accounts.md) §5.1): `model.lua`
  keeps `default_rewards` (well-formed ids, each once, in the order sent; an unknown id
  stays stored) and stores it with every list it applies, as an empty list when the
  website sent none. A stored list without the field was applied before the game
  reported `rewards.defaults`: `accounts_version()` then reports 0 while the game keeps
  applying and showing the held list (`enabled()` reads the held version), and the next
  list is applied whatever its version, the held one too; from then on the real version
  is reported, also when that list had no field. A list whose version equals the held
  one changes nothing once reported. `forget` rewrites the stored list with its fields,
  the mark included.
- **Linked or not** is `account_of`, from the list only; the flow's `linked` state is
  only the success line. `apply_list` ends the open request of a character the list
  binds, reports the notices of online characters and then runs the change callbacks.
- **Notices** compare the list with player meta `grug_accounts:seen`
  (`<account id>|<reward,...>`) at every apply, join and arrival, and wait while
  `in_creation` holds; rewards are read live and never copied into player meta.
- **The Account page** (`page.lua`, an sfinv page; its caption row is in
  `grug_inventory/navigation.lua`) is a view: it shows `account_of`, `link_state`,
  the `can_link` reason, `default_rewards` before linking and `rewards_of` after it,
  with the catalogue's icon and hint, in the layout "The Charter" (the mock-up
  builder's coordinates and text sizes, `tools/r84_account_mock/layouts.py`, times the
  text scale; centred lines are flat buttons without a background, a text that would
  not fit shrinks or wraps by a rough width per character). It re-sends itself on
  `register_on_link_state`, `register_on_change` (the named characters),
  `register_on_defaults` (every open Account page) and the arrival, only while it is
  shown and once per action; a click on a centred text, an inert button or Open
  website (`button_url`, the client opens it) re-sends nothing. The typed code and the offered account's
  name live in the sfinv context (never stored or logged). During creation it shows
  only the `can_link` line (the user, 2026-11-15).
- **Saved keys:** mod storage `list` (the applied list, serialized; since 0.86.0 with
  `default_rewards`) and
  `id:<lower-case name>` (the character id or `tombstone`, written by
  `grug_accounts.forget_character` at a deletion, Round 83);
  player meta `grug_accounts:character_id` ([external
  table](#player-meta-read-by-external-tools)) and `grug_accounts:seen`. Mod storage and
  player meta are saved on separate timers, so a crash can lose one; the id adoption and
  the "meta wins" rule recover it ([contract](../web-accounts.md#2-terms) §2).
- **Without the bridge** the mod loads, keeps its stored list, grants its rewards and
  sends nothing; the tab stays hidden.
- **Logs:** link requests, confirmations, bindings and password changes at `action`
  with the name and the account id; never a code or a password entry.
- **Tests:** `tools/r79_acc` (the model and the flow), `tools/r79_page` (the page and the
  account cloak), `tools/r80_rewards` (the linked page holding every reward),
  `tools/r86_account` (the default rewards, the reported version, the redraw, the page's
  states; `capture.sh` shoots the page at 1366 x 768 and 1920 x 1080),
  `tools/r691_bridge` (the bridge side and the engine scenario).
