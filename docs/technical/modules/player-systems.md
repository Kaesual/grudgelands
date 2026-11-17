# Player systems

Part of the [module implementation guide](../module-guide.md), which indexes every
area. Quests, parties and clans, mail, housing, travel, mounts and the atlas. Implementation seams and engine pitfalls only; the
[design docs](../../design/README.md) own the game rules. Source paths in code
spans are repository-relative.

Sections: [Quests](#quests), [Parties](#parties), [Mail](#mail), [Housing](#housing), [Travel](#travel), [Mount runtime](#mount-runtime), [Atlas](#atlas), [World atlas rules](#world-atlas-rules).

## Quests

**Rules** (the working rules for this area; the checks to run after a change are in
[checks.md](../../process/checks.md)):

- Quest files that require each other change together.
- Other mods hear turn-ins through `grug_quests.register_on_turn_in`, never a second
  completion path; "use at a place" is an objective, never a node.
- The main line's spine is pinned by the fixtures `tools/r36_qa` and `tools/r36_qt`.
- A foreman the story names carries that name through `FOREMAN_TITLES`
  ([miners_guild.md](../../design/miners_guild.md) §2).

- **Quests (Round 14):** `grug_quests` owns a strict registry, 20-slot player-meta
  journal, kill/item/talk/use objectives and claim-once turn-in with main/owned-bag
  inventory preflight. The per-mob eligible damage/effective-heal participant
  set grants credit independently of party membership and gray-XP suppression.
  `npc_by_socket` keys actual settlement identity plus socket id, never terrain
  anchor ids. Marker children partition observers through the existing tag
  carrier's one-second 25/30 hysteresis pass; no independent player scan.
  Quest UI tracks up to ten selected quests (`grug_quests.MAX_TRACKED`, one objective line each) and stores its HUD preference.

### Quest data, objectives and texts

  Since Round 28 the content is data: `data/zones/<zone>.quests.json` and
  `<zone>.front.quests.json` (Round 58: also the two guild files, whose
  zone is a guild id, `charter_of_stone` / `oathdelvers`), read by `loader.lua`, checked by `validate.lua`
  (structure at load, roles/areas/levels/items once every mod loaded; every
  finding names file and quest); quest NPCs bound to sockets are in
  `npcs.lua`, new givers at free quest sockets come from the files. Since
  Round 38 kill credit and quest drops count by the mob's shown name
  (`state.lua` `mob_counts`: `objective.name_set[mob.description]`); the
  roles and area (`<zone>/<kind or camp>` of the zone's spawn recipe,
  [spawn_regions.md](../../design/spawn_regions.md)) select those names once at
  load (`labels.lua` `Q.target_names`, kept as the objective's `names` and
  `name_set`; `E-no-name` when a role selects none); quest-only drops use
  `grug_mobs.register_participant_drop_hook`; weight rewards
  `grug_xp.quest_reward`. `labels.lua` words an objective for the dialogue,
  log, tracker and feed (item names only, never tooltip text) and carries
  each objective's target level range, computed once at load by
  `validate.lua` (Lane Q0), widened for a kill to every slot bearing its
  names; a kill target is named by those names (fixtures `tools/r32_f2`,
  `tools/r38_b1`; the guarantee `tools/r38_names/guarantee.py`;
  `tools/r28_design/validate.py` `E-item-source-drop`). It
  also fills the quest text placeholders (Round 29
  Q1): titles (`{name:...}` only) at load, texts on first display through
  `grug_mobs.spawn_regions.describe`, cached per quest (`Q.quest_text`);
  `registry.lua` computes the copper of a quest without `rewards.copper`
  (`quest_copper`). Since Round 36 `use.lua` owns the "use at a place"
  objective's runtime: the object kinds (`data/use_objects.json`, loaded
  before the quest files), one quest object per use point (`Q.use_key`:
  place, object, label) while a player who still needs it is within
  `LEADER_RANGE`, its observers set per player, the per-player pass once a
  second in five slots and the hold pass every 0.1 s only while a hold runs;
  `state.lua` keeps the needed points per raw state (`Q.use_needs`) and
  credits a finished hold (`Q.credit_use`); places resolve through
  `labels.lua` `Q.use_place` (a clash site `grug_mobs.spawn_regions
  .clash_site`, a recipe quest place `zone_place`/`place_spot`; since Round
  59 a town place `socket:<settlement key>/<socket id>` through the
  settlement socket registry, a socket of role `quest_place` whose cell the
  object stands in, cached once found). `validate.lua` checks
  `E-free-follow-ups` per faction in its world pass (`V.free_follow_ups`,
  the givers' factions resolved), the other free-play rules in its
  structure pass.

### Shared quests, acceptance and rewards

  Since Round 57 ([quests.md](../../design/quests.md) "Shared quests") a
  definition holds `variants` (per giver zone: givers, turn-ins, giver
  roles, its own resolved objectives and quest drops, text; the counts and
  rewards are the quest's); `def.giver_variant` maps a giver to its
  variant, and `def.npc`, `def.turnin_npc`, `def.objectives` and
  `def.quest_drops` read the first variant's. `validate.lua` `V.variants`
  builds them from a file (the loader and the checks share it),
  `registry.lua` `Q.bind_role_givers` binds role givers at mods-loaded
  after `resolve_npc_factions` (which also keeps each NPC's `race_id` for
  the per-race texts). The active entry keeps `variant` and `giver`;
  `state.lua` `Q.variant_of(def, entry)` is the one lookup (an entry
  without them reads as the first variant), `Q.turns_in_at`,
  `Q.turnin_for` and `Q.active_entry` serve the dialog, the HUD and the map.
  `Q.accept(player, id, npc)` takes the giver, `Q.turn_in(player, id,
  choice)` the picked reward; `Q.reward_stacks` makes every reward through
  `grug_items.make_stack` (grug_quality: fixed enchants at the quest's
  reward level, the receiver's tooltip), and the dialog's choice tooltips
  are `grug_items.tooltip_text` (the shared helper, also the recipe
  details'). `npc.lua` `Q.category_list` builds the Story category of the
  dialog and the quest log. Fixture `tools/r57_qsys`. Round 65:
  `registry.lua` `Q.acceptance_level(level)` (level − 2, at least 1) derives
  `def.min_level` (a registration naming one is refused; quest data names
  only `level`); `Q.npc_quests(player, npc)` returns the listed rows (ready,
  available, active, sorted by status, level, title) and the hint level (the
  lowest acceptance level the player's level alone holds back), and
  `Q.marker_states` gives a giver without rows `locked` only when that level
  is at most `Q.SOON_LEVELS` (2) above the player's. Fixture
  `tools/r65_quest`.

### Turn-in hook, state cache and markers

  `Q.register_on_turn_in(fn(player, id, def))` fires once per completed
  turn-in, after the state and rewards are stored (grug_achievements'
  `quest:` and `quest_tag:` counters); fixture `tools/r36_e`. Since Round 30 `state.lua` caches each player's decoded
  state keyed by the raw meta string: readers share that table and must
  never write into it, mutating paths take a copy (`editable`) and `save`
  re-caches. Marker consumers ask `Q.marker_states(player)` once for every
  giver (memoized until the raw state changes or `Q.markers_changed`
  resets it, Round 37; a value is a status or, for a story quest, its
  `story_<status>` variant, `Q.marker_parts` splits it, Round 57): the
  minimap, the only consumer that registers
  `Q.register_on_markers_changed` (since Round 44 the map window too: it
  sends itself again while open, throttled); the NPC tags, read on the 1 Hz
  carrier pass. `Q.markers_changed` fires on a
  quest change, a held objective-item change (the tracker's `Q.journal_key`
  poll, `hud.lua`, five 0.1 s slots; counts capped at what one quest takes,
  Round 31; without an active item objective the poll reads no inventory,
  Round 37) and a level change (fixtures `tools/r30_p1`, `tools/r31_c`,
  `tools/r37_po`).

### Load checks and garrison objectives

  Unknown quest fields stop the load (`E-unknown-key`, Round 30). Round 31:
  quest NPCs get their faction at load and serve only it; a kill objective's
  area may be a PvP garrison (`pvp_garrison.area_roles`, guard and captain
  roles, since Round 36 the war commander where a camp has one, the giver of
  the other faction: `E-garrison-faction`); kill
  credit counts the garrison post's name (Round 38: `G.slot`'s `name_key`,
  the guards' slot in `data/names.json`, a captain's race name;
  `{captain:<camp key>}` in texts). Placeholders may name a
  PvP POI by its settlement key. The design tools mirror it
  (`tools/r28_design`: `r28common.pvp_pois` reads the tiers from
  `G.slot`); fixture `tools/r31_q`. The
  catalog requires only V1 overworld content; the Nether is reserved for the
  first expansion. Quest item labels use concise names rather
  than stat/durability lines; worn matching stacks remain valid turn-ins.

### System quests

  Since Round 48 a **system quest** (`register_quest` with `system = true`
  and a `turnin_text`; no NPC, objectives, quest drops or repeat,
  [quests.md](../../design/quests.md) "System quests") is registered by its
  own mod: `validate_registry` skips its NPC checks, no NPC lists or marks
  it, the journal row carries `turnin_text`, which `hud_line` shows instead
  of "Return to <NPC>" and `grug_map/quest_box.lua` writes into the text
  field (the status label stays empty). Its mod accepts it with `Q.accept`
  (`Q.log_full` asks the `Q.MAX_ACTIVE` = 20 limit first) and turns it in
  with `Q.turn_in`, the one completion path. The only one is grug_mail's
  `mailbox_visit` (below, "Mail"); the Python quest tools read only the zone
  files (fixture `tools/r48_quest`).

## Parties

- **Parties (Round 14):** `grug_parties` persists parties of 2–10 same-faction
  members and their leader in mod storage. Offline membership/leadership lasts
  indefinitely. Invitations are ephemeral inviter-bound records; a second
  member creates the party, one remaining member dissolves it. No party XP,
  loot or quest-credit rules. UI actions resolve rendered stable identities,
  then core APIs revalidate current authority. HUD HP writes are compare-first.
  The saved color preference defaults to By class; an explicit All green choice
  persists. Since Round 32 (perf review R2) `hud.lua` polls each player every
  0.5 s in one of five 0.1 s slots (`slot_of`, assigned at join), skips a
  player without a party through `grug_parties.in_party` (membership only,
  no view built) and recomputes the row layout only on a window change
  (fixture `tools/r32_f4`). Since Round 81 (audit P5-03) a party's members
  share their party's slot (`grug_parties.party_id`) and the poll builds
  the party's view once for all of them; the Party HUD switch and the
  health colours are read from player meta once per session and kept by
  their setters; a level change is told to the player's party, the player
  and the holders of its invitations only (P5-04; the Social tab follows
  the roster change). `grug_parties.member_names` gives the names alone,
  without a view's engine reads. Current geometry and offline presentation:
  [parties.md](../../design/parties.md). Since Round 67 the same poll draws
  the invitation box for a player without a party who holds invitations
  (`grug_parties.newest_invitation`, a read of the session table; geometry
  `hud_layout.invite_box`). The Social tab (`ui.lua`) keeps one shared
  roster of the online players, dropped at every
  `register_on_roster_change` event (`init.lua` raises it on join, leave,
  faction, class, race and level changes and on every party event but
  invitations and the reason `display`, the Party HUD switch and the health
  colours); each viewer whose current sfinv page is Social is asked
  once per server step (`core.after(0)`) and sent at most once per
  `SEND_GAP_US` (2 s), the owed send by one `core.after`; a scrollbar move
  holds sends for `QUIET_US` (0.5 s); the PvP section's countdown goes
  through the same limiter (`grug_parties.social_resend`). The coalescing state lives in the
  sfinv context; every build counts as a send. Favourites are player meta
  `grug_parties:favorites` (a serialised sorted name list). Fixture
  `tools/r67_social`. Since Round 76 the tab has four cards and one row
  style (`row_list`, `column_heads`, `member_cells`, shared with the clan
  card), each scrollbar's position kept through `grug_parties.kept_scrolls`;
  `init.lua` holds the `/p` party chat. Fixtures `tools/r76_social` (the tab)
  and `tools/r76_clan` (`/p`).
- **`grug_clans` (Round 76):** clans ([clans.md](../../design/clans.md)).
  `init.lua` holds the state (mod storage `clans`, validated at load, the
  name index derived), the rules (only the `can_*` functions decide; each
  action asks them again and answers `ok, message`), the session
  invitations (one `core.after` per invitation, no globalstep), `/c` and the
  presence lines. `grug_clans` depends on `grug_parties`, never the other
  way (an optional dependency would be a cycle the engine refuses), so
  `social.lua` installs the clan card and the Online Players' mark and Clan
  button as `grug_parties.clan_section` (as `grug_pvp` installs
  `pvp_section`); `ui.lua` draws without it. Clan changes re-send the Social
  tab through the party limiter: membership, role, presence and the switch
  every viewer (`grug_parties.social_resend_all`), level, class and
  invitations only the named players. Since 0.76.1 the card's online rows
  end in the party's Party button (`grug_parties.can_invite` and `invite`,
  called directly), drawn after the row's pick through `row_list`'s
  `list.over` so it takes its own clicks. Fixtures `tools/r76_clan` (rules,
  storage, chat) and `tools/r76_social` (the card).

## Mail

- **`grug_mail` (Round 48, [mail.md](../../design/mail.md)):** one global
  `grug_mail`; `model.lua` is the pure model (no engine calls; letters,
  tickets, broadcasts, limits, expiry, pages, postage, unread count, report
  rules; fixture `tools/r48_mail`), `store.lua` the storage, `api.lua` the
  API below, `window.lua` the mailbox window, `admin.lua` the Admin Mail
  tab; `texts.lua`, `letters.lua` and `quest.lua` the game's own letters and the starter quest (below).
  Depends on `grug_core`, `grug_money`, `grug_inventory`, `grug_factions`,
  `grug_classes`, `grug_xp`, `grug_map`, `grug_quests`, `grug_mounts`,
  `grug_housing` and `sfinv`, so it loads after all of them (and with
  `grug_map` after `grug_home`).

### Mail storage

- **Storage:** offline player meta cannot be written (`ObjectRef:get_meta`
  needs a live object, `l_object.cpp` `l_get_meta`), so mail lives in the
  mod's storage, `core.serialize`, each key read and written whole:
  `box:<name>` (a player's letters, newest first), `sent:<name>` (the
  text copies of a player's sent letters, newest first, at most
  `model.SENT_LIMIT` 50; Round 66; kept apart from the box, which every
  inbox access reads whole; a missing key is an empty list), `tickets` (the admin
  inbox, every player's messages), `broadcasts`, `factions` (the recipient
  index: lower-case name → `{name, faction}`, written at
  `grug_factions.register_on_faction_chosen` and at every join) and
  `next_id` (one monotonic counter for letters, tickets and broadcasts). The
  per-player read set of the broadcasts is player meta
  `grug_mail:broadcasts_read` (written only while the player is online).
  Expired entries (30 days, `os.time()`) are pruned whenever a key is read;
  there is no pass over every player. A read hands out a fresh table; the
  last four keys read keep their stored string and an untouched decoded
  copy, so a read of an unchanged string copies instead of decoding again
  (Round 81: one mailbox click reads the box up to five times). Not map-bound: no
  `grug_core.map_reset.clear` ([upgrade contract](../upgrade-contract.md) §3.2).
  Stored attachments are item strings (`ItemStack:to_string()`), so item
  meta survives; a future item-removal step scans them and the list
  `grug_mail_out` (upgrade contract §1). Sent copies hold display names
  only, never item strings, so no item step touches them.

### The mail API

- **The API** (the contract lanes ADMIN, QUEST and BAGS build on):
  - `send_letter(player, to_name, subject, body)` — player mail: a
    created character of the sender's faction (the index), never the
    sender, not into a mailbox at 50 player letters; postage `5 + 30 ×
    stacks` for the four `grug_mail_out` slots as they are at the call,
    and the slots leave with it in one `grug_money.take_with_inventory`
    call (Round 49: no quote). A body over `model.BODY_MAX` (4,000
    characters after cleaning) is refused before anything is taken, never
    cut (0.49.1; `model.check_body`). The sender keeps a text copy in
    `sent:<name>` (Round 66; `model.sent_copy`, `model.keep_sent`).
    Returns ok, message ("Letter sent to X. Postage paid: 65c.").
  - `sent(name)` and `delete_sent(player, id)` (Round 66) — the sent
    copies (a fresh table) and deleting one by its letter's id.
  - `send_system(to_name, kind, from_label, subject, body[, stacks])` —
    `kind` "admin" (always shown from "Server Admin", whatever the label) or
    "npc"; always delivered (no limit, faction or postage), to an indexed
    name in any letter case or any name `core.player_exists` knows, also
    offline and during a join. `stacks`: up to four `ItemStack` strings,
    stored and taken like player attachments; only the 0.48.0 bag migration
    passes them (admin letters carry no items). Returns `true` and the
    new letter id, or `false` and a reason (unknown recipient, unknown kind,
    more than four stacks); never nil, so a caller that retries on anything
    not truthy (the 0.48.0 bag migration) never sends a letter twice. The
    body is cut at `BODY_MAX` as a safety net; the admin's own texts
    (`answer_ticket`, the compose form) are checked before this call.
  - `open_mailbox(player, pos)` — the mailbox node's right-click (lane
    WORLD's `grug_mapgen:mailbox`, `grug_mail.MAILBOX_NODE`); runs the
    `register_on_mailbox_open(fn(player, pos))` callbacks, then shows the
    window. `mailbox_label(pos)`: the `display_name` of the settlement whose
    `waypoint` socket lies within 16 nodes (collected at mods-loaded).
  - `unread_count(name)` (unread letters plus, for an online player, unread
    broadcasts) and `refresh_count(name)`, which hands the count to
    `grug_map.minimap.set_mail_count(name, n)` when that function exists
    (lane HUD); called at every change and at join.
  - Tickets: `send_ticket(player, topic, subject, body, mailbox)`,
    `report_letter(player, id, reason, note, mailbox)` (a "Player report"
    ticket with a frozen `report` copy of the letter), `tickets()`,
    `ticket(id)`, `close_ticket(id, admin_name[, answered])`,
    `answer_ticket(id, admin_name, body)` (an admin letter "Re: <subject>",
    then closed as answered) and `delete_ticket(id, by_name)` (gone for
    everyone). A ticket stores the header the admin sees (mailbox, version,
    level, faction, race, class, position). Every message, report, answer,
    closing and deletion is one `core.log("action", "[grug_mail] ...")` line.
    `send_ticket` and `answer_ticket` refuse a body over `BODY_MAX` like
    `send_letter`.
  - Broadcasts: `send_broadcast(subject, body, admin_name)` (returns the id,
    or false and the refusal for a body over `BODY_MAX`), `broadcasts()`,
    `delete_broadcast(id, admin_name)`, `read_broadcast(player, id)`.
  - The window and the Admin Mail tab keep typed message texts up to
    `model.DRAFT_MAX` (10,000 characters; Luanti limits only a whole form
    submit, 640 KB), and `model.truncate` reads at most 4 bytes a character
    of its input. `model.quote` quotes at most `QUOTE_MAX` (500) characters
    of the original, a cut one ending in " [...]".
  - Letters: `open_letter(player, id)` (marks read), `take_all(player, id)`
    (`grug_inventory.fits` first, then `give`; all or nothing),
    `delete_letter(player, id)`, `return_attachments(player)` (the slots
    through `give`; leftovers stay).

### The attachment list

- **The attachment list `grug_mail_out`:** four slots of the player's own
  inventory, sized at join (where stacks a disconnect left also go back),
  drawn only on the Write tab. Not a carried list
  (`grug_inventory.carried_lists`), so selling, crafting, the sort and the
  migrations never touch it, and no detached inventory is involved (a
  disconnect loses nothing). The existing allow callbacks refuse what must
  not go there: `grug_housing/soulbound.lua` (only `main` and the bags) and
  `grug_skills/bound_items.lua` (skills only on the hotbar); the fixture
  runs both. The Write tab rings
  `grug_mail_out` → the shift-click inbox → `main`, and each bag into the
  slots.

### The starter quest and the game's letters

- **The starter quest and the game's letters** (lane QUEST,
  [mail.md](../../design/mail.md) §8): `texts.lua` holds the user's picked
  texts (copied, never reworded); `letters.lua` sends them through
  `send_system`, `{player}` and `{capital}` (the `display_name` of the
  settlement in the `capital` slot of the player's race,
  `grug_core.settlement_socket_settlements`) filled at send time: the
  welcome letter (`send_welcome`) at `grug_classes.register_on_arrival` and
  at every join, the level letters (`send_level_letters`, `LEVEL_LETTERS`)
  from `grug_xp.register_on_level_change` (once per jump and at every join
  with `old_level = nil`), the riding letter while
  `grug_mounts.owned_tier_ids` holds none of `RIDING_TIERS`, the steward's
  while `grug_housing.player_claim(name)` is "never", and the Expedition
  Registrar's at level 20 always (Round 72). `quest.lua` registers
  the system quest `mailbox_visit` (`STARTER_QUEST`), grants it at arrival
  and join (`grant_starter_quest`) and turns it in from its own
  `register_on_mailbox_open` callback, posting the completion line to the
  feed (key `quest:mailbox_visit`). All of them act only for a created
  character (`character_ready`: class and faction). One player-meta flag
  each, set once done or no longer useful (the quest's also when the log
  was full): `grug_mail:quest_granted`, `grug_mail:welcome_sent`,
  `grug_mail:letter_riding`, `grug_mail:letter_housing`,
  `grug_mail:letter_registrar`. Fixture
  `tools/r48_quest`.

### The mailbox window

- **The window** (`grug_mail:mailbox_<serial>`, formspec v6 at the inventory
  window's size, the short inventory view on Write): every event re-checks
  the mailbox node at the opening position and a living player within 6
  nodes, else the window closes and the slots go back. Typed text is kept
  from every event and written back as the fields' defaults; the window is
  never resent on an inventory move (a resend drops unsent text), which is
  why the Write tab shows the postage rule, not a figure, and Send charges
  the slots as they are at the click (Round 49). The two Send buttons carry
  the draw's serial (`write_send_<n>`, `admin_send_<n>`): a click from a
  form already replaced (a double click) acts on nothing and only redraws.
  The Write tab's rings put `grug_mail_out` right after `main` and after
  each bag (the engine follows the first entry naming the source list). The focus
  sits on an invisible button at every send ("UI and formspecs").

### The Admin Mail tab

- **The Admin Mail tab** (`admin.lua`, lane ADMIN): the privilege
  `mail_admin` (`give_to_admin`, not
  `give_to_singleplayer`) and the sfinv page `grug_mail:admin`
  (`grug_mail.ADMIN_PAGE`), last in `grug_inventory.TAB_ORDER`, `is_in_nav`
  only with the privilege, no inventory view (`show_inv = false`). The
  privilege's `on_grant` / `on_revoke` redraw the inventory formspec (a
  revoke leaves the page through `sfinv.set_page`) and return nothing, so
  `core.run_priv_callbacks` still runs the global callbacks. The page state
  lives in the sfinv context (`context.grug_mail_admin`: view, filter, page,
  selection, drafts); `grug_mail.admin_fields` re-checks the privilege on
  every event (without it: a warning line, the page left, nothing done).
  It calls only the stores: `tickets`, `ticket`, `answer_ticket`,
  `close_ticket(id, admin, false)`, `delete_ticket`, `send_system(name,
  "admin", ...)` (no stacks), `send_broadcast`, `broadcasts`,
  `delete_broadcast`; `grug_mail.admin_header(ticket)` formats the frozen
  header. The sending buttons carry the draw serial
  (`mail_admin_<answer|close|send>_<n>`); a click whose serial is not newer
  than the last successful send's is dropped with its fields. Answer, Close
  and Delete also carry the id of the message they were drawn for
  (`mail_admin_answer_<n>_<id>`, `mail_admin_delete_<id>`); a click whose id
  is not the current selection (a row chosen in between) is dropped with its
  fields too. Typed text is
  kept from every event of the page and written back as the fields'
  defaults. Fixture `tools/r48_admin` (the real sfinv and
  `grug_inventory/ui.lua`).

## Housing

- **Housing (Round 25, Round 26 drafts):** `mods/PLAYER/grug_housing` implements
  [housing.md](../../design/housing.md). One global `grug_housing`; each file has
  one owner lane so the lanes work in parallel:
  - `registry.lua` + `api.lua` (Lane A): the pure claim model and the
    interface contract — registry in mod storage (format v2) plus a claim grid
    index, placement validation, the protection check with permissions, fuel
    as `paid_until`, the soulbound `grug_housing.STONE_ITEM`
    (`grug_housing:claim_stone`) and the draft node
    `grug_housing.DRAFT_STONE` (`grug_housing:claim_stone_draft`), drafts
    (`DRAFT_SECONDS = 300`), activation (`ACTIVATION_LUMPS = 5`, charcoal
    first, Anthracite last at one lump each), the pick-up lock (`PICKUP_LOCK_SECONDS = 43200`), destruction
    times, the arrival cube and no renewal in active claims.
    Contract: `claim_at(pos)` (claim `{id, owner, center, placed_at,
    activated_at, paid_until}` or nil; `activated_at` 0 is a draft),
    `is_active`, `is_draft`, `draft_remaining`, `pickup_wait`,
    `remaining_seconds`, `permission(claim, name)` →
    `"owner"`/`"everything"`/`"interact"`/nil, `player_claim(name)` → claim
    plus state `never`/`carried`/`placed`/`destroyed`/`removed`/`needs_stone`,
    `issue_stone`, `can_receive_stone(player)` (ok, or false and the
    reason the Steward shows in place of its button, Round 49), `activate`, `add_fuel(claim, count, itemname)` (per-item
    seconds `FUEL_ITEMS`, cap `FUEL_CAP_SECONDS`, Round 47),
    `fuel_seconds`, `fuel_room_seconds`, `pick_up`, `set_permission`,
    `arrival_pos`, `register_on_claim_changed(fn)` with events `placed`,
    `activated`, `fuel`, `permission`, `picked_up`, `destroyed`, `removed`,
    `draft_expired`, `expired`. Constants `RADIUS = 50`, `MIN_Y = −100`.
    For the minimap's claim preview (0.50.2): `claims_in(min_x, min_z,
    max_x, max_z)` (the claims whose square meets the rectangle, by id,
    from the claim grid), `claim_set_version()` (changes on every create
    and remove, load and map reset), `column_problem(faction, water, zone,
    territory)` (validate's column rule for one column; `territory` false
    judges the zone alone), `SETTLEMENT_MARGIN` and `placement_world` (the
    world queries validate asks).
  - `stone.lua`, `stone_form.lua`, `protection.lua`, `soulbound.lua`: the
    stone and draft nodes with draft and fuel expiry, the stone forms, the
    `is_protected` wrapper with the arrival cube, the soulbound items. The
    5 s pass (Round 81, audit P4-02) starts each cycle with the draft and
    expiry scans, which the registry answers from its draft set and the
    next possible expiry without walking every claim, and checks the stones
    in eight slices of the id-ordered claims (copied again only after a
    claim came or went); each claim is checked once per cycle, a new one
    from the next cycle on.
  - `admin.lua` (Round 26): `/claim_remove <player> | here | orphans`
    (`server` privilege).
  - `packed.lua`, `recovered.lua` (Round 50): the soulbound
    `grug_housing:packed_container` (as the tool writes it: meta `node`,
    `lists`, `seq`; cleaned: `node`, `ref`, `seq`, description and image,
    its contents in this mod's storage under `ref`; placing restores the
    container through `core.item_place_node`, fills its lists from the
    contents and deletes them; `CONTAINER_LISTS` holds the restorable kinds
    with their list sizes) and the Claim Stone inventory: the tool's
    entries `recovered:<player>:<seq>:<n>` in this mod's storage, read
    through `grug_housing.recovered` (`entries`, `count`, `take`), and
    `clean_pass`, the handler of the world marker `map_reset_pack:<seq>`
    (unknown items out, D6's extra chests under `<n>.<k>`, the contents
    moved to `packed:<player>:<seq>:<n>[.<k>]`, empty containers as their
    nodes' items stacked under `<seq>:0.<k>`, descriptions and images),
    plus the join notice. The stone form shows the entries as the active stone's
    Belongings tab. Fixture `tools/r50_pgame/portable_test.lua`.
  - `interaction.lua` (Lane B): the generic right-click and node-inventory
    guard installed at `register_on_mods_loaded`, and the "Home of <owner> –
    protected" reason for `grug_core.protection_hint`.
  - `interface.lua`, `manager.lua` (Lane C): the stone formspec (set as
    `grug_housing.open_stone_interface`), the Housing Steward (internal socket
    role id `housing_manager`) and the character-page status.
  - Home-stone travel (Lane D) lives in `grug_home`, which reads the claim
    through the contract above.

## Travel

**Rules** (the working rules for this area; the checks to run after a change are in
[checks.md](../../process/checks.md)):

- All travel (home return, respawn, waystones) goes through `grug_home/travel.lua`; boats
  are water mounts in `grug_mounts`.

- **Travel (Round 29, WP17):** `grug_home/travel.lua` owns one travel path
  (dismount, emerge, deferred re-validation, safe arrival) used by home
  return, respawn and waystone travel (`grug_home.travel(player, trip)`).
  `waypoints.lua` builds the registry from the mapgen's `travel_waypoint`
  sockets (six capitals, six start pads and, since Round 31, the two PvP
  fortresses' sockets, registered after the twelve home locations; seven
  stones per faction), discovers a stone by proximity
  (once a second, on the player's join slot since Round 81) or right-click,
  keeps the per-character list in player meta (decoded once per session
  and kept by `discover`, its only writer; `grug_home.known_waypoints`)
  and opens the travel form
  (`grug_home.use_waystone`); the refusals are pure rules in
  `waypoints_core.lua`. Since Round 72 the form has the tabs Waystones and
  Expeditions; the second is filled by `grug_expeditions` through
  `grug_home.register_expedition_tab` (rows and enter, every rule theirs; since
  Round 72.1 also `actions` and `act`, the owner's run below the rows with its
  state and its leader's Finish or Cancel, a button's `confirm` asked first, and
  since Round 72.2 its `role`, a `grug_core.ui.button_style` role: "confirm"
  green, "danger" red; `grug_home.refresh_expeditions(wanted)` redraws open
  tabs once, at the stone only, and `grug_housing.refresh_expeditions` the
  Claim Stone's; `grug_expeditions` calls it from `register_on_close` and
  `register_on_end`) and
  shown on the Claim Stone too (`expedition_rows`, `expedition_from_claim`,
  `expedition_actions`, `expedition_act`);
  `grug_home.show_waystones` opens the list from a stone outside the network
  (an Expedition's), since Round 72.1 with the Expeditions tab of the actions alone. The node `grug_mapgen:waystone` is registered in
  `grug_mapgen/world_nodes.lua` before the settlement content resolves.
  Fixture `tools/r29_w/portable_test.lua`, engine probe `tools/r29_w/probe.sh`.
  Rules: [world.md](../../design/world.md) §6,
  [home_travel.md](../../design/home_travel.md).

  Fuel arithmetic is fixed in housing.md §4 (26 160 s per lump; displayed
  stack `ceil`, pick-up return `floor`). Road and POI protection (Lane E)
  lives in the zone authority and `grug_core`, not in `grug_housing`.

## Mount runtime

- **Mount runtime**: ownership is player meta; the summoned controller and its
  visible child are ephemeral. The child (mount or boat hull) is attached
  with `forced_visible`, so its rider sees it in first person. The rider's
  camera (0.45.1) is the model's catalogue `camera`, applied by
  `grug_mounts.apply_camera` after the sit pose: the eye height is the
  first-person height (the engine puts an attached player's camera at the
  parent's position plus eye height plus eye offset), the eye offsets carry
  the rest; the mount's step only restores the sit pose and the camera if a
  pose change replaced them (one table read a step). grug_mounts also owns
  the camera mode (2026-10-27): third person on a summon, first on every
  dismount except leave and shutdown, each forced with `set_camera` and
  released to `any` after one second; another `set_camera` user must
  coordinate with it.
  `grug_mounts.dismount` is the shared cleanup path for manual, damage, death, leave, shutdown and external-detach exits and clears the
  runtime-only untimed `mount` status. Mounted players cannot attack. A land
  controller falls at the player's gravity and deals its rider the engine's
  player fall damage itself, 5 nodes shorter (peak height while airborne,
  `set_hp` with type `fall`, which keeps the rider mounted; mounts.md §3.1). A
  riding or flying mount entering a liquid (water or lava) ends in its step
  (hard dismount, "Mounts cannot enter water." / "... lava.") and is not
  summoned in one; a ground mount is summoned only on solid ground. Land
  controllers use nominal one-node step height; T1 is 6.4 nodes/s (+60%).
  Since Round 29 boats are the third mode, **water** (`grug_mounts.TIERS`
  5 and 6, `BOAT_TIERS`): the same ownership meta and dismount path, a
  surface controller, a once-per-second water-contact check, landing within
  2 nodes; another tier's summon replaces the active mount or boat
  (`grug_mounts.toggle`). Since Round 44 the quickbar (`grug_quickbar`, E)
  is the only summon path: one button per `owned_tier_ids` entry calls
  `toggle`; no mount item is handed out (`items.lua` aliases the six retired
  names to nothing, Round 81). The Riding Trainer dialogue is one service format
  (`grug_mounts.SERVICES`); `shipwright.lua` serves the `shipwright` socket
  role of the capital stable. Prices: `grug_mounts.PRICES` (E4,
  `tools/r29_e4/income.py --check`). Fixture `tools/r29_b` (boats, and since
  Round 30 section H the riding-tier purchases at the shipped prices). The
  flight-border sweep reads the faction once and each column's zone id
  (`grug_zones.id_at`), never a copied zone record per sample (Round 30).
  Since Round 72 `grug_mounts.enemy_town_at(faction, x, z, y)` (`entity.lua`)
  is the one enemy-town rule (mounts.md §4.4): a lazily built table from the
  hard `town` footprints to their settlement's faction, with a node at most
  `UNDER_TOWN` below the column's ground counting as in the town (without
  `y` the column alone), asked by `summon_position` after the summon guards
  and by the mount's step whenever it enters another node. Fixture `tools/r72_mounts`.

## Atlas

- **Atlas**: `grug_map` owns one whole-world cartographic atlas with 1x/2x/4x/8x
  zoom, native scrollbars and an independent marker layer. Since 0.60.1 it uses
  a larger version-6 real-coordinate window with the same navigation as the
  other inventory pages ([presentation contract](../ui-presentation.md)). Keep the zoom's wanted centre (since 0.45.1 the soft lock on
  the player until the player scrolls, `atlas.zoom_view` and
  `atlas.scroll_event`, [world_map.md](../../design/world_map.md#atlas-navigation)),
  fixed-size markers, clipping and hit bounds in the same transform. Live
  updates preserve zoom and scroll. Stable byte-encoded IDs own marker
  identity. Since Round 44 the map is its own window (`window.lua`; the Map
  tab's page, `page.lua`, only opens it, and the inventory goes back to its
  homepage). Its refresh is event-driven: a click, zoom, layer click, quest
  selection or quest change sends the window again, at most once per
  `SEND_GAP_US` (1 s) per player, an event inside the gap going out when it
  ends; in a party the arrows are checked every `PARTY_US` (1 s) and the
  window sent only when a member's arrow moved. A pass every 0.1 s does at
  most `CHECKS_PER_PASS` (8) party checks and `BUILDS_PER_PASS` (2) sends,
  the longest-waiting first (fixture `tools/r32_f4`). A scrollbar move never
  sends and holds every send for `QUIET_US` (0.5 s). The window counts as
  open until its quit or until any other form is shown (the death screen and
  the inventory too); its state (zoom, scroll, follow, selection, layer) is
  kept between opens until the player leaves. Return home lives on the Character page
  since Round 30 (`grug_inventory/pages.lua`, its 1 s pass re-sends that page
  only while the button text changes).

### The base image and its tiles

  Since Round 27 `base.lua` renders the base per `grug_map_quality` and sends
  it as 512 px tiles, plus a normal-size copy for the minimap (scaled down
  in the same pass at high, Round 37; at both qualities since Round 44).
  Since Round 51 the atlas is ±4050 × ±3600 (normal 1215 × 1080, high
  3600 × 3200) and the sea is coloured by depth: pass 1 asks
  `grug_zones.water_query_at` for planned-water pixels only (bay or lake)
  and counts the open sea's pixels per 16-node cell (blurred into the soft
  edge); pass 2 reads the depth from the relief grid's floor heights
  (fixture `tools/r51_map`).

### Baked icons and the minimap

  Since Round 44 the pure `bake.lua` draws into the map images: since
  Round 47 the world map's image carries only the region names (pixel font,
  dark halo; the window draws the places in its marker layers,
  `layers.lua`), and since Round 64 the minimap's copy carries no icons (its
  icons are separate shared 32 px markers). The art is Lua data (`baked_art.lua`, generated from
  `grug_map/art/*.png` by `tools/r44_mb/gen_baked_art.py`, `--check`), since
  the engine decodes no PNG for Lua. The cache key covers `bake.lua` (the
  layout), the art and font versions and every icon's kind and place (the
  icon list is still built though no image draws it; audit P1-05; fixture
  `tools/r44_mb`); `minimap.lua` (HUD state, marker slots, change-only
  `hud_change` per whole screen pixel; every server step only a cheap test,
  and the map, markers or party arrows placed again only when what they
  show changed, Round 37) and the pure
  `minimap_view.lua` (window, snap grid and per-cell disc texture, the
  seam-free scale and map corner under the centred arrow, bezel frame,
  placement, rim arrows) draw the gliding minimap in
  `grug_core.hud_layout.minimap_box`. Keep the texture and position change
  in the same step and the scale a whole multiple of 1/grid, or cell swaps
  jump. Round 32 halved the window (`V.WINDOW_NODES` 440) and the cell grid
  (`V.GRID` 2 base pixels at normal, 8 for a high-size base, which the game
  no longer passes since Round 37) so the bezel still covers
  the overhang (geometry in `tools/r27_minimap`); `tools/r32_f1/engine.sh`
  measures the traffic and the location sample on a player stand-in. Since Round 30 the window size, the frame-only elements and the
  location line are handled every 0.5 s or on a window change, and the
  static markers are re-asked on `grug_quests.register_on_markers_changed`
  and, when their key (quest version, home, waystones, faction) changed, at
  a 5 s check. The minimap asks the quest, service, home, waypoint (since
  Round 29), settlement, poi, boss and pvp marker providers
  (`minimap.lua` `PROVIDERS`, `atlas.collect_markers(player, only)`);
  since Round 44 trainers show one icon per profession
  (`grug_map.trainer_icon`); the
  `waypoint` provider shows the player's discovered waystones on both maps.
  Fixture:
  `tools/r27_minimap/portable_test.lua`; traffic comparison:
  `tools/r27_minimap/bench_glide.lua`.

### Claim mode

  **Claim mode** (0.50.2): `base.lua` `claim_overlay` renders one
  transparent overlay per faction at the minimap base's size from pass 1's
  arrays with grug_housing's `column_problem` and `placement_world`
  (`grug_map_claim_<faction>_*` tiles, cached with the base; the rules
  enter the cache key); `minimap.lua` switches on with the Claim Stone
  wielded and a faction, adds the overlay tiles and one clipped `[fill` per
  claim to the cell texture (`minimap_view.lua` `texture(v, ox, oy, mask,
  claim)`, `claim_rect`, never a `[fill` outside the image or of zero size)
  and shows the square (`claim_square`, `claim_square_texture`) at z 12.
  Fixture `tools/r502_cmap/portable_test.lua`; measurements
  `render_overlay.lua` (offline render and the "green, yet refused" check
  on a real world) and `bench_claim.lua`.

### Side elements

  **Side elements** (Round 48): the mail icon, the daytime band and the
  "Now playing" box are `state.side`, apart from the minimap's own
  `state.hud`: created at the first step, never removed while the player
  is online, placed by `minimap_view.lua` `side_layout(box, frame)` (one row,
  band then mail icon, equally high as the client draws them: left of the
  bezel and top-aligned with a frame, right-aligned in the box's top-right
  corner without one, "Now playing" below it) again
  whenever the window box or the mode changes. The globalstep reads the
  window box for both every 0.5 s and runs the side part also without a
  view (minimap unavailable) and with the minimap hidden; the band is
  recomputed on the 5 s check (`daytime_position(timeofday, start, end)`,
  pure: real seconds since 04:30, 40 steps over the two clock speeds) and
  sent only when its image changes. Other mods use
  `grug_map.minimap.set_mail_count(name, n)` (0 hides; grug_mail calls it on
  every unread change and at join; the count is kept per online player in
  `mail_counts`, so a call before grug_map's join callback still counts) and
  `set_now_playing(name, track)`. The images are finished files from
  `tools/r48_hud/gen_hud_textures.py` (`--check`; its parts in
  `tools/r48_hud/parts/`, the count's digits from `tools/r40_cd`). Fixtures
  `tools/r48_hud` (position, badge, the row's geometry over windows, the
  unavailable runtime) and `tools/r27_minimap` block H (beside the bezel, hide and
  show).

### Zone and town names

  Zone and town names (Round 28 M1): `location.lua` samples each player's
  location every second, writes the line under the minimap and the entry
  banner (until Round 44 it also placed one zone marker per zone at
  startup, with a zone-grid cache in the world folder; since Round 47 the
  map window's Zones layer places text labels by the same rule in
  `layers.lua`/`zone_labels.lua`, without a cache); the pure
  `location_view.lua` holds the rules (fixture `tools/r28_m1`). Since
  Round 32 each sample also takes the territory status
  (`grug_pvp.territory_at`, the PvP flag's own rule, never the flag): it
  colours the minimap line and the banner, the banner's second line
  ("Friendly Territory", …) replaces the PvP subtitle, and a status change
  shows the banner like a zone change (fixture `tools/r32_f1`). Since
  Round 34 the sample also records whether the player stands in a start
  town or capital (`location.in_town(name)`, by x/z only), which
  `grug_ambience` reads for the quieter bed; since Round 35 also the capital
  (`location.capital_of(name)`, the settlement key of a town row whose anchor
  slot is `capital`, kept while the city is within `L.CAPITAL_MARGIN` nodes:
  `location_view.lua` `capital_at`, up to eight footprint queries per sample
  only while leaving), which decides where music plays. Since Round 47 the
  sample hands a changed zone id (and the player's first sample) to
  `location.discovery`, the first-entry zone XP that `init.lua` installs
  from `zone_discovery.lua` (`D.new(api)` pure over its calls, fixture
  `tools/r47_nz`); a fixture that loads `location.lua` alone runs without it.

### NPC markers and map layers

  Round 31: NPC markers carry their NPC's faction and the service and
  quest-giver lists are split per viewer faction once at load.
  `settlement_icons.lua` (pure) maps a settlement's anchor slot to its icon
  kind and, since Round 47, to its map window layer, the same for every
  viewer (Round 44 ruling 5 ended Round 31's per-faction hiding). In Rounds
  44–46 settlements, camps, kings and dragons were only baked icons; since
  Round 47 the world map's image bakes the region names only (since Round 64
  the minimap also uses separate icons), and `layers.lua` (loaded by `window.lua`) builds the
  marker layers: the static rows of settlements, places and bosses once in
  its mods-loaded hook (providers `settlement`, `poi`, `pvp`, `boss`; boss
  levels through `grug_mobs.fixed_level`, the dragons' entities from
  `grug_mobs.dragon_map_markers`) and the zone labels (`zone_labels.lua`,
  pure: the grid sampled from the world authority, Round 28's pole
  placement). The map window builds its overlay per send from the session's
  layer, and the minimap re-asks its static markers on
  `register_on_faction_chosen`. Fixtures `tools/r31_n`, `tools/r31_m`,
  `tools/r44_mb`, `tools/r44_mq`.
  Current marker/travel/minimap rules: [world_map.md](../../design/world_map.md).

## World atlas rules

- **World atlas**: `docs/design/world_map.md` governs the cartographic map
  window (Z and the Map tab since Round 44), with no fog of war and
  independent markers. It needs no
  generated-terrain bitmap and never unlocks waypoint travel.
