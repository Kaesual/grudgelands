# Partial plan — mail, mailboxes and admin mail

> **Scheduled in Round 48** ([round48-plan.md](round48-plan.md)). Its §2
> rulings and §3 interfaces override this file where they differ.

Status: **partial plan for Round 48**, not yet scheduled. The user approved
the concept in chat on 2026-10-14; a coordinator folds this file into the
round plan together with the other partial plans. Rulings in §2 are the
user's; §3 lists the defaults this draft chose, which the lanes build unless
the user overrides them. File facts are against main `6a8afb9f`. The user's
wireframes (a private canvas artifact, "Mail Wireframes") show the windows;
where they and this file differ, this file wins.

## 1. Goals and reasons

**What we want.** Players get a mailbox: they read letters, write to other
players by name (online or offline), attach up to four item stacks, and
write to the server admin, with feedback and bug reports explicitly
welcome. Server admins answer from an inventory tab, wherever they stand,
and send letters that are unmistakably "from the admin". Two small features
use the system: a starter quest that sends every character to a mailbox,
with a welcome letter waiting, and letters at level 15 (the Riding Trainer)
and level 20 (the Housing Steward).

**What exists (read-only study, chat 2026-10-14).**

- Nothing named mail exists. Three decided texts rule against it and change
  with this plan: `quests.md:107` ("Avoid adding mail/escrow systems", meant
  for quest rewards), `parties.md:50` ("No offline mailbox", meant for
  invitations) and the comment `grug_housing/soulbound.lua:8` ("there is no
  mail"). `housing.md:101` already lists mail among the places a soulbound
  item cannot go.
- `grug_inventory.INBOX_LIST` (`inbox.lua:27`) is the hidden shift-click
  list, not mail. Mail code says "mail"/"mailbox", never "inbox", in ids,
  lists and feed keys.
- Offline player meta cannot be written (`ObjectRef:get_meta` needs a live
  object, `l_object.cpp:1725-1733`), so mail lives in mod storage. The
  direct precedent is `grug_home/claim_home.lua:76-129` (an offline notice
  in mod storage, delivered at join).
- The quest system assumes an NPC for giving and turning in
  (`validate.lua:322`, `registry.lua:91-95`, `npc.lua:152-153`); the log
  holds 20 quests (`state.lua:306`).
- Every capital core and every starting village has exactly one waystone,
  and all twelve are written by one function, `dressing.waystone`
  (`wp13/dressing.lua:200`): the six capitals call it directly (e.g.
  `dur_brannoc.lua:402`), the six starts through `dressing.waypoint_pad`
  (`dressing.lua:209-233`). No other settlement calls it.

## 2. Rulings (user, 2026-10-14)

1. **Mailboxes** stand in every capital core and every starting village,
   one each, **placed by the world generator** (the deployment carries a map
   reset anyway): **on the waystone's pad, to its side, a few nodes away
   from the stone** (not directly beside it). Players read, write and
   contact the admin there.
2. **Postage:** **5c** per letter plus **30c per attached item stack**, up
   to **4** stacks ("one item" means one stack: a stack of 12 ingots costs
   30c like a single axe). Mail to the admin is free and carries no items.
3. **Letters from the admin** are marked unmistakably (a shield badge in
   the list, a banner in the letter). Players see "Server Admin", never the
   admin's own name.
4. **Mail to the admin** has a topic (Feedback, Bug report, Question,
   Player report, Other). The game version and the mailbox it was sent
   from ("Sent from Mailbox in Dur Brannoc") are always attached, never a
   checkbox.
5. **Admin privilege:** a new privilege opens an **Admin Mail** inventory
   tab: read and answer the shared admin inbox, write to one player or to
   **all players**. Admin letters carry **no items** (admins have `/give`).
6. **Broadcasts ("All players")** are stored once, centrally, and shown to
   players in **their own list**, separate from letters. Every player marks
   them read for themselves.
7. **Limits:** a player's mailbox holds **50 player letters**; a full
   mailbox refuses player mail. **Admin and system letters are always
   delivered**, beyond the limit. The admin inbox has **no limit**. A player
   has at most **5 open** messages to the admin.
8. **Expiry:** every letter, ticket and broadcast is **deleted 30 days**
   after it arrived, in every mailbox, attachments included, with no
   return to the sender. A small hint says so.
9. **Lists are paginated.**
10. **Mail to the admin is a ticket.** The player keeps seeing their own
    messages to the admin with their state (open or answered) and can
    delete them; **deleting removes the ticket for everyone** (the server
    log keeps every message). Letters to other players vanish for the
    sender once sent.
11. **An admin's answer arrives as an ordinary admin letter** ("Re: …") in
    the player's Letters and closes the ticket. Admin tickets have two
    states, open and closed; an admin can also close one without an
    answer.
12. **Read state is automatic:** opening a letter (clicking it) marks it
    read. There is no manual "mark read".
13. **Report:** a received letter can be reported, with a reason and a
    confirmation ("Really report?").
14. **Unread icon** next to the minimap with a digit 1–9, "9+" above, gone
    when nothing is unread. It counts unread letters (admin letters and
    answers included) and unread broadcasts. It always stands at the same
    place, also with the minimap hidden.
15. **Starter quest** "Use a mailbox in one of the cities" (the user's
    title) for new and existing characters; a full quest log skips it.
    Every character finds a welcome letter ("Welcome to Grudgelands, …").
16. **Level letters:** at **15** from the **Riding Trainer** (come and get a
    mount), at **20** from the **Housing Steward** (the king has heard of
    your progress; you may settle; visit me in your capital).
17. **Answers to the open questions (all as recommended):**
    1. Player mail only **within one's own faction**; admin mail reaches
       everyone.
    2. The starter quest is a **system quest** without NPC and without
       objectives: accepted automatically, turned in by opening any
       mailbox, through the normal turn-in path. Reward: a little XP and
       **25c** (the first letter is paid).
    3. Level letters are **sent late to existing characters only if still
       useful**: the riding letter only without an owned riding tier, the
       steward letter only if the character never had a Claim Stone.
    4. The **Bag of Coins may be attached** (an ordinary item at 30c).
    5. The digit shows **from one** unread letter.
    6. **GPT-6 Astra writes the letter texts** (quest-text rules), with an
       Opus review round and a proposal page for the user.
    7. **GPT-6 Astra designs the mailbox block and the mail icon**, three
       proposals each for the user's pick.
18. **Accepted proposals from the wireframes:** the topic dropdown, the
    "All players" broadcast, the ticket view ("Your messages to the
    admin"), the admin inbox's filters (Open / All) and the sender's level,
    faction and position on each admin message.
19. **No sound** for new letters for now.
20. **Attachments go into a 4-slot list of the player's own inventory**
    (dragged in like any slot), not chosen by clicks in a drawn inventory
    (§3.9).

## 3. Defaults chosen by this draft

The user may overrule any of these; the lanes build them otherwise.

1. **Mailbox window.** Right-click on the mailbox opens one window
   (formspec v6, real coordinates, its own formname) with four tabs:
   **Letters**, **Announcements** (broadcasts), **Write**, **To the admin**
   (the player's tickets plus the "new message" form). Tab captions carry
   the unread count, e.g. "Letters (2)". Every action re-checks that the
   node at the opening position is still a mailbox and the player stands
   within 6 nodes of it.
2. **Page size 8** rows in every list, with Previous/Next and "page 2 / 4".
3. **Text limits:** subject 60 characters, body 1,500, report note 200.
   Everything shown passes `core.formspec_escape`.
4. **Reply** on a player letter opens Write with the sender, "Re: …" and
   the quoted text; it costs postage as usual. Reply on an admin letter or
   a broadcast opens a new ticket with "Re: …". NPC letters have no Reply
   and no Report.
5. **The 5-open cap** counts the player's open tickets (reports included).
6. **Every message to the admin is also written to the server log**
   (`core.log("action", …)`), so it survives deletion and expiry. Answers
   and closings are logged with the admin's real name, which only admins
   see in the tab ("Closed by").
7. **Report.** Reasons: Spam, Insult or harassment, Scam, Other, plus an
   optional note. The report becomes a "Player report" ticket holding a
   frozen copy of the letter (sender, time, text, attachment names). A
   letter can be reported once. Admin letters, NPC letters and broadcasts
   cannot be reported.
8. **Recipients.** A name must belong to a created character of the
   sender's faction. The mod keeps its own name→faction index in mod
   storage, filled by `grug_factions.register_on_faction_chosen` and at
   every join. Known limit: a character that has not joined since the
   update cannot receive player mail yet ("There is no player called X in
   your faction."); admin mail reaches it. Sending to oneself is refused.
9. **Attachment list** `grug_mail_out`, four slots in the player's own
   inventory (sized at join, like `grug_inventory.INBOX_LIST`,
   `inbox.lua:58`), shown on the Write tab next to the player's carried
   lists. The existing guards already refuse what must not go there:
   soulbound items live only in `main` (`grug_housing/soulbound.lua`),
   skill items only on the hotbar and mount items only in `main` and bags
   (`grug_skills/bound_items.lua`); the lane confirms both by fixture.
   Items there stay saved with the player, so a disconnect loses nothing
   (the module guide's rule against detached lists in trade UIs does not
   apply). **Send** takes postage and the four slots in one
   `grug_money.take_with_inventory` call. Closing the window without
   sending returns the stacks through `grug_inventory.give`; what does not
   fit stays in the list and shows at the next mailbox. Stacks are stored
   in the letter as `ItemStack:to_string()`; item meta (quality, enchants,
   crown, wear) survives. **Take all** takes every attachment or none
   (`grug_inventory.fits`, then `give`); otherwise the items stay in the
   letter. Deleting a letter with attachments asks first.
10. **Storage** (mod storage of `grug_mail`, `core.serialize`): one key per
    player mailbox, one for the admin inbox (tickets), one for broadcasts,
    one for the faction index, one id counter. The per-player broadcast
    read set lives in player meta (`grug_mail:` prefix; the player is
    online whenever it changes). Expired entries are pruned lazily when a
    list is read and at join — no pass over every player. Expiry uses
    `os.time()` (calendar time across restarts, as the home-travel cooldown
    does). A map reset clears nothing of mail (not map-bound).
11. **Unread count** = unread letters + unread broadcasts, recomputed on
    every change and at join. A broadcast shows to every character while it
    has not expired, including characters created after it was sent.
12. **Notice:** a letter arriving for an online player raises a feed line
    (`grug_core.feed`, kind "notice", key "mail"): "New letter from X". No
    sound (ruling 19).
13. **HUD icon:** one image element left of the minimap bezel,
    top-aligned with it, at the same place whether the minimap shows or
    not. It goes through a small `grug_map.minimap` API next to
    `set_now_playing` (`minimap.lua:553`), e.g. `set_mail_count(name, n)`,
    because that module already tracks the window size; it must draw even
    while the minimap is hidden (today nothing is drawn then,
    `minimap.lua:489-491`). The digit badge is part of the image's texture
    (`[combine` with the cooldown digits,
    `grug_abilities/cooldown_math.lua:40-96`, plus a new "+" glyph from
    `tools/r40_cd/gen_cooldown_textures.py`).
14. **Privilege** `mail_admin` (`give_to_admin = true`). The tab "Admin
    Mail" is a sfinv page with `is_in_nav` checking the privilege, without
    the player inventory (`show_inv = false`, like Party & PvP), placed
    after Help in `TAB_ORDER`. The privilege's `on_grant`/`on_revoke`
    refresh the inventory formspec (`sfinv.set_player_inventory_formspec`;
    leave the page if it is open) and return nothing, so the global
    privilege callbacks still run (`builtin/game/register.lua:482-492`).
15. **Admin message header:** sender, level, faction, race and class,
    position, the mailbox ("Sent from Mailbox in …"), game version
    (`core.get_game_info()` + `game.conf`, as `world_version.lua:215-216`
    reads it), date.
16. **Mailbox name:** the label of the settlement whose `waypoint` socket
    lies within a few nodes of the mailbox (`grug_core.settlement_sockets_at`
    over the capitals and starts, collected at mods-loaded). No new socket
    role.
17. **No separate map marker.** The mailbox stands on the waystone's pad,
    which the map already shows (discovered waystones, `grug_map/providers.lua:164`)
    inside a marked capital or starting village; the quest text and the
    Help page say "beside the waystone".
18. **Starter quest** `mailbox_visit` (one id for both factions), level 1,
    `min_level` 1, **no objectives** and no NPC. Granted at arrival
    (`grug_classes.register_on_arrival`) and at every join for characters
    without the flag `grug_mail:quest_granted`; the flag is set on success
    and also when the log is full (skipped for good, ruling 15). Opening
    any mailbox turns it in. The quest log and tracker read "Open a mailbox
    beside the waystone of a capital or a starting village" instead of
    "Return to <NPC>".
19. **Welcome letter**: an admin-kind letter (shield badge), sent once per
    character at arrival or at the first join after the update (flag
    `grug_mail:welcome_sent`). The text names the player and says that
    feedback and bug reports are welcome.
20. **Level letters** come through `grug_xp.register_on_level_change` (it
    fires once per jump and at every join with `old_level = nil`,
    `grug_xp/init.lua:146-148,270-282`), with flags
    `grug_mail:letter_riding` / `grug_mail:letter_housing`. Conditions:
    level ≥ 15 and no owned riding tier (`grug_mounts.owned_tier_ids`);
    level ≥ 20 and `grug_housing.player_claim(name)` in state "never". NPC
    kind, sender "Riding Trainer" / "Housing Steward", the capital as a
    placeholder filled at send time (quest-text rule: no fixed places in
    text).
21. **Help:** one short Help page "Mail" (`grug_inventory/help.lua`):
    the mailboxes beside the waystones, postage, the 50-letter and 30-day
    rules, writing to the admin.

## 4. Lanes

Suggested split: **MAIL** (the mod, the player windows and the HUD icon),
**ADMIN** (privilege, tab, the admin side of tickets, broadcasts),
**QUEST** (the system quest, welcome and level letters), **WORLD** (the
mailbox node and its placement), **ART** and **TEXT** (GPT-6 Astra), and the
round's docs lane. Waves: §7.

### 4.1 Lane MAIL — `grug_mail` and the mailbox window

A new mod `mods/PLAYER/grug_mail` (one global `grug_mail`). Depends on
`grug_core`, `grug_money`, `grug_inventory`, `grug_factions`,
`grug_classes`, `grug_map`, `sfinv`; the lane checks the load order against
the mod map.

- **Pure model** (`model.lua`, no engine calls, like `price_rules.lua`):
  letters, tickets, broadcasts, limits (§2.7), expiry (§2.8), pagination,
  postage (`5 + 30 × stacks`), unread count, report state. The portable
  fixture tests this file.
- **Storage and API** used by the other lanes; the names are the contract:
  - `grug_mail.send_letter(player, to_name, subject, body)` — player mail;
    postage and the `grug_mail_out` stacks;
  - `grug_mail.send_system(to_name, kind, from_label, subject, body)` —
    `kind` "admin" or "npc"; always delivered, ignores limit and faction;
  - `grug_mail.open_mailbox(player, pos)` — the node's right-click;
  - `grug_mail.register_on_mailbox_open(fn(player, pos))` — QUEST turns
    the starter quest in here;
  - `grug_mail.unread_count(name)` and an internal refresh of the HUD icon;
  - the ticket store with `close_ticket(id, admin_name)` for ADMIN.
- **Windows** Letters, Announcements, Write, To the admin (§3.1–§3.9): the
  ticket list shows subject, topic and state, and Delete; the report
  dialog with its confirmation; the delete confirmation for letters with
  attachments; the expiry hint ("Letters are deleted 30 days after they
  arrive, attachments too.") and the admin hint on "To the admin" (from
  the wireframes: "Questions, problems or a player to report? Feedback on
  the game and bug reports are very welcome too. Mail to the admin is
  free.").
- **Attachment list** (§3.9).
- **HUD icon** (§3.13) with a placeholder texture until ART merges; the
  feed notice (§3.12).
- The comment at `grug_housing/soulbound.lua:8`.
- The Help page (§3.21).
- **Postage** is a new copper sink: an `economy.md` §4 row (docs lane);
  `tools/r29_e4/income.py --check` does not cover it (it checks mounts,
  respec and the crown fee only).

### 4.2 Lane ADMIN — privilege, Admin Mail tab, broadcasts

Builds on MAIL's storage (wave 2).

- Privilege `mail_admin` and the tab (§3.14).
- Inbox with filters Open / All, paginated; the selected message with its
  header (§3.15); answer box with **Send answer** (sends an admin letter
  "Re: <subject>" through `send_system` and closes the ticket) and
  **Close** (without answer); "Closed by" for admins. A Player report
  shows the frozen letter copy.
- **New admin letter**: to one player or to **All players** (a
  broadcast), text only, with a preview of how it appears in the player's
  mailbox.
- Logging (§3.6).

### 4.3 Lane QUEST — system quest, welcome and level letters

Builds on MAIL's API (wave 2). The quest system has no quest without an
NPC; this lane adds the smallest **system quest** kind:

- a code-registered quest with a `system` flag, **no objectives** and no
  `npc` / `turnin_npc`; `register_quest`, `validate_registry`, the quest
  log, the tracker HUD (`hud.lua:38-42`), the map's quest box
  (`quest_box.lua:56-68,152`) and `window.lua:221` accept the missing NPC
  and the empty objective list. The Python quest tools read only the zone
  JSON files (`tools/r28_design/r28common.py:204`) and stay untouched;
- accepted through `Q.accept` from the grant (§3.18), turned in through
  the existing `Q.turn_in` from `grug_mail.register_on_mailbox_open` —
  the one completion path (AGENTS.md "Quests"), so
  `register_on_turn_in` listeners and achievements see it;
- the welcome letter (§3.19) and the level letters (§3.20), texts from
  TEXT (placeholder texts until it merges).

### 4.4 Lane WORLD — the mailbox node and its placement

- Node `grug_mapgen:mailbox` registered in `grug_mapgen/world_nodes.lua`
  like the waystone (`:45-70`): not diggable, no drop, `on_blast` no-op,
  right-click → `grug_mail.open_mailbox` looked up at runtime (grug_mapgen
  loads before grug_mail). Shape and textures from ART; a placeholder
  nodebox until then. A stable id from day one.
- **Placement in one place:** `dressing.waystone` (`wp13/dressing.lua:200`)
  also writes the mailbox, so all twelve settlements get it and no other
  settlement does. One fixed offset on the pad, to the waystone's side and
  a few nodes from it (ruling 1), off the pad's cross arms so the ways to
  the stone stay free, facing the stone or the main approach. The capital
  pads differ in size from the starts' reach-3 pad (`dressing.lua:209`);
  the offset must lie on open pad ground in all twelve. If one capital
  cannot take the common offset, that capital passes its own offset; no
  other exception.
- Decor-kit rules hold (AGENTS.md "Decor is a kit"): no blocked way,
  window or door; bounds and sockets unchanged; `tools/r36_w` with an
  updated baseline if its node counts move. No seed-fleet run (a change
  that only places nodes needs none, AGENTS.md "World generation").
- Screenshots of all twelve pads (headless capture) for the review.
- **Upgrade class: map reset** (world generation). The round declares one
  anyway; the coordinator writes the declaration.

### 4.5 Lane ART — mailbox block and icons (GPT-6 Astra)

Three proposals each, on a review page for the user's pick (the user's
iteration style: first version by feel, the user proposes fixes):

- the **mailbox block** (nodebox or a static node mesh at the game's
  texture scale; reads as a mailbox from ten nodes away; fits the capitals
  of both factions and the starting villages and stands well on the
  waystone pad);
- the **HUD mail icon** (readable at the minimap's scale, works on bright
  and dark terrain; the badge stays the digit set);
- derived from the picks: the **admin shield badge** and the **NPC seal**
  for the windows, and the "+" glyph through the cooldown digit generator.

Licences: own work (CC0) or licensed sources, one `LICENSE-media.md` row
per file. No sound work (ruling 19).

### 4.6 Lane TEXT — letter and quest texts (GPT-6 Astra)

The welcome letter, the Riding Trainer's letter, the Housing Steward's
letter, and the starter quest's text (its title is the user's, ruling 15).
Quest-text rules: placeholders for player name and capital, no fixed
places or directions, no tooltip texts, no reference to existing games.
Short: a letter fits the reading pane without scrolling (about 600
characters). Opus review round, then a proposal page for the user. Window
labels and hints stay with MAIL (not Astra).

### 4.7 Docs (the round's docs lane)

- New `docs/design/mail.md` (the rules of §2 and §3) and its design-tour
  entry.
- `quests.md:107` (the sentence is about quest rewards; mail now exists)
  and the system quest kind; `parties.md:50` (invitations only);
  `economy.md` §4 (postage as a sink); `housing.md:101` stays;
  `settlements.md` (the mailbox on the waystone pad).
- Module guide: a "Mail" section (storage keys, the API, the reach check,
  the attachment list); the mod map row for `grug_mail`; the system quest
  in the quests section.
- Upgrade contract or module guide: **a future item-removal migration
  also scans mail storage** (stored stack strings) and the
  `grug_mail_out` list.
- CHANGELOG and README current state.

## 5. Rules

- No mail outside mailboxes for players (no chat command, no inventory
  tab); the Admin Mail tab is the one exception (ruling 5).
- No cash-on-delivery, no auction or trade escrow, no sending money as a
  number. A Bag of Coins is the way to send money.
- No detached inventory for attachments.
- Upgrade class: mail itself is **compatible** (new mod, new mod storage
  and player-meta keys, a new player list); the mailbox placement is a
  **map reset**. No migration: existing characters get quest and letters
  at their next join.
- Player meta keys use the prefix `grug_mail:` and never collide with the
  keys the realm website reads (module guide "Player meta read by external
  tools").

## 6. Verification

**Fixtures** (only the ones that test the changed behaviour; the full set
once per lane):

- model (MAIL): postage 5c / 35c / 125c for 0 / 1 / 4 stacks; the
  50-letter limit refuses player mail and admits admin/system mail; expiry
  at 30 days removes letters, tickets and broadcasts with attachments;
  pagination; unread count over letters and broadcasts; opening marks
  read; the 5-open cap; deleting a ticket removes it; one report per
  letter; no report on admin, NPC or broadcast letters;
- sending (MAIL): money and the `grug_mail_out` stacks leave in one step,
  a changed slot refuses with nothing lost; soulbound, skill and mount
  items cannot enter `grug_mail_out`; closing returns the stacks, leftovers
  stay; an item with quality, enchant and wear arrives identical; Take all
  refuses without room and keeps the items; faction and unknown-name
  refusals;
- ADMIN: privilege gates the tab; a broadcast is stored once and read per
  player; Send answer delivers an admin letter and closes the ticket;
  Close closes without a letter; the header carries version and mailbox;
- QUEST: grant at arrival and at join, once; full log → skipped and
  flagged; turn-in on opening a mailbox pays XP and 25c; quest log and
  tracker show the system text; `validate.py --game` passes; level
  letters once each, with their conditions, also on a jump 14 → 21 (both
  letters);
- WORLD: `tools/r36_w`; twelve mailboxes on the twelve pads, none
  elsewhere; each resolves to its settlement's label.

**GUI checklist (the user):**

1. New character: the quest "Use a mailbox in one of the cities" is in
   the log, the mail icon shows "1". Walk to the starting village's
   waystone, open the mailbox on its pad: the quest completes (+25c), the
   welcome letter opens on click, the icon vanishes.
2. An existing character on its first join after the update: the same
   quest and letter.
3. Write to a second character of the same faction, drag two stacks into
   the attachment slots: 65c are taken, the stacks leave; the recipient
   (offline at the time) sees the icon at login and takes the items with
   Take all. Close a Write tab with a stack in a slot: it comes back.
4. Try a character of the other faction, an unknown name, a Claim Stone or
   a skill in an attachment slot, a full inventory on Take all: each
   refused with a clear message, nothing lost.
5. Write to the admin with topic Bug report; the ticket shows as open in
   "To the admin". With `mail_admin`, the Admin Mail tab shows it with
   version and "Sent from Mailbox in …"; answer it: the player gets an
   admin letter "Re: …", the icon lights, the ticket shows answered.
6. Send an "All players" letter; both characters find it under
   Announcements with the shield badge; reading it on one does not mark it
   read on the other.
7. Report a player letter (reason, confirm); the report appears in the
   admin inbox with the letter's copy.
8. Level a character from 14 to 15 and to 20 (`/xp`): the Riding Trainer's
   and the Housing Steward's letters arrive.
9. More than nine unread letters: the icon shows "9+"; hide the minimap:
   the icon stays where it was.
10. Mailboxes on the pads of a capital of each faction and of a starting
    village; desktop and web build.

## 7. Orchestration notes

- **Waves:** wave 1 MAIL, WORLD, ART, TEXT; wave 2 ADMIN and QUEST on
  merged MAIL (QUEST also needs WORLD's right-click hook, which only calls
  MAIL's `open_mailbox`). MAIL and WORLD ship placeholders and never wait
  on ART or TEXT; ART and TEXT replace them after the user's picks.
- **Review:** MAIL, ADMIN, QUEST and WORLD change game logic or world
  generation → independent review is mandatory; fix deltas with logic are
  reviewed again. ART on the user's picks; TEXT through the Opus review
  round and the user's proposal page.
- **Shared files with other work:** `grug_map/minimap.lua` and
  `minimap_view.lua`, `grug_inventory/ui.lua` (`TAB_ORDER`) and
  `help.lua`, `grug_quests` (registry, validate, state, hud),
  `grug_map/quest_box.lua` and `window.lua`, `wp13/dressing.lua`,
  `grug_mapgen/world_nodes.lua`, `tools/r36_w/baseline.tsv`,
  `docs/design/quests.md`, `economy.md`, `settlements.md`. The coordinator
  checks the other partial plans for these.
- **Size:** this is the round's larger package; ADMIN and QUEST are small
  once MAIL's model and storage stand.
- **Decided during the round:** the mailbox offset on the pad (WORLD
  proposes with screenshots, the coordinator checks, the user can change
  it in the GUI test); the art picks and the letter texts (the user).
