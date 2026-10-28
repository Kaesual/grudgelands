# Round 66 — polish: big and small screens, the two-handed swap, sent letters, priest symbols

Planned with the user on 2026-10-28 from their notes after playing 0.65.0.
**Started on the user's "go" on 2026-10-28; Claude coordinates.**
**Complete on 2026-10-28:** all six lanes merged (five independent reviews
MERGE, no fix rounds; the art study checked by the coordinator); **not
pushed**; GUI test pending, joining the joint test of 0.57–0.65
([completion](#completion-2026-10-28)).
Version: **0.66.0**. Classification: **compatible** (one new mod storage
key for sent letters, read as empty when missing; new textures; the map
cache key unchanged; no step). Delivery state: [STATUS](../STATUS.md).

## Why

The user's notes, each checked against the code at `7a68e871` while
planning (the lanes re-check them, round workflow §2.4):

- **Two-handers.** The hand rule refuses in both directions with a feed line
  (`allow_hands`, `grug_inventory/equipment.lua`), shift-click included. The
  feed sits near the player's bars and lasts 2.5 s; the Character page most
  likely covers it (unverified, no GUI here), so the player sees nothing
  happen. The empty offhand does not show that it is blocked.
- **Smite, Censure, Final Word** are motes only: Smite a five-mote beam and a
  ring, Censure one large mote (size 16) falling, Final Word a column of
  motes (`grug_core/particle_effects.lua`).
- **Mail** has no sent folder by design ([mail.md](../design/mail.md) §3:
  "there is no sent folder"); the user wants one now.
- **Fishing rod.** Already a Basic recipe of T1 material (3 Sticks, 2 Thread;
  Thread is a vendor supply and a Basic recipe from Linen Scrap), but it is
  listed only after the character has held Thread
  (`grug_jobs/basic_unlock.lua`, ruling 19's held-once rule).
- **Map icons on small screens.** Markers are `32 × real_hud_scaling` px in
  the map window and the minimap alike (`grug_map/markers.lua`
  `M.metrics`), whatever the map's pixel size; on a phone (HUD scaling 2–3)
  they cover much of the map. The user confirms the minimap shows the same.
- **UI on 4K.** Forms are fitted to a viewport capped at 1920×1080
  (`grug_core/ui_window.lua`, [ui-presentation.md](../technical/ui-presentation.md)).
  The inventory window uses about 90 % of the height at 1080p, 67 % at
  1440p and 45 % at 2160p. Form fonts do not grow with the form (they follow
  GUI scaling and density only), and `grug_core.ui.text_scale` never exceeds 1.
- **War camps** all use one red icon; the slot name carries the faction
  (`pvp_<faction>_<band>`), the camps under construction carry it in their
  catalog row. A camp never changes faction.
- **Character creation.** The faction buttons are meant to wear their
  faction's colour (`grug_classes/selection.lua`), but they go through the
  navigation style, which never applies it; what reads as "Throng is
  coloured" at the start is most likely the engine's focus or hover look on
  that button (unverified).

## 1. Lanes and order

| Wave | Lane | Worktree / branch | Result | Depends on |
|---|---|---|---|---|
| 1 | EQUIP — two-handed swap, blocked offhand, fishing rod | `r66-equip` | Shift-click 2-for-1 swap, a visibly blocked offhand, the refusal readable on the page, the rod known from the start | — |
| 1 | MAIL — sent letters | `r66-mail` | A read-only "Sent" tab | — |
| 1 | UI — 4K scaling, creation buttons | `r66-ui` | The viewport cap grows on tall screens, text grows with it; faction-coloured creation buttons | — |
| 1 | MAP — marker size, camp colours | `r66-map` | Markers sized by the map's pixel size in both maps; war camps and construction camps in faction colour | — (merges after UI) |
| 1 | ART — hammer and book (Astra) | `r66-art` | Two particle textures and a preview page | — |
| 2 | FX — priest effects | `r66-fx` | Smite, Censure and Final Word with the picked textures | ART merged and the user's pick |
| 3 | D — delivery documentation | coordinator | Completion, version, declaration, status owners, GUI checklist | all merged |

Merge order: **EQUIP, MAIL, UI, MAP, ART, FX**, then D. MAP merges main
into its branch after UI merged and before its review (the map window's
pixel size depends on UI's viewport). Any lane whose shared file (§7) moved
on main merges main before its review.

## 2. The user's rulings (2026-10-28)

1. **Two-handed shift-click swaps both hands.** Shift-clicking a two-hander
   while the offhand is occupied equips it and puts the offhand piece into
   the inventory; the old weapon (if any) takes the two-hander's cell as in
   today's swap. That needs one free inventory slot for the offhand piece;
   without one, nothing moves and the player is told. Drag and drop keeps
   the refusal (the allow callback may only allow or refuse, never move
   other items; `equipment.lua` "REFUSAL, not repair").
2. **The offhand is visibly blocked** while a two-hander is equipped.
3. **Sent letters:** text and a list of the attachments, which are never
   real items (nothing can be taken). No read receipt.
4. **4K:** the capped viewport is at least **two thirds of the screen**:
   its height is `min(H, max(1080, ⅔·H))`, its width scaled by the same
   factor, so a 2160p screen lays out like 1440p and nothing changes below
   1620 px. **Text grows with it.**
5. **Map markers** shrink with the map on small screens, in the **map window
   and the minimap**.
6. **Priest symbols, straight fall only:** a **hammer** for Smite; Censure
   and Final Word get symbols too, the second one a **book**.
7. **The fishing rod** is a Basic recipe known from the start.
8. **War camps by faction:** the Throng's stay red, the Accord's are blue
   (same symbol). **Camps under construction:** the cloth hanging on the
   scaffold takes the faction colour.
9. **Creation faction buttons:** both buttons wear their faction colour
   (red / blue), subdued while none is chosen; the chosen one in a strong
   colour.

**Coordinator defaults** (the user may overrule them; look and feel is
tuned after the first in-game look):

- **Symbols:** Smite = a small hammer, Final Word = the same hammer large
  (with its column kept), Censure = the book (it replaces the falling seal;
  the warning ring stays). Sizes about 5 (Smite), 12 (Final Word), 16
  (Censure) in particle size units; lit look (add blend, glow) like every
  skill effect. Smite's hammer falls from the beam's 3.2 m in about 0.15 s
  so it lands with the damage, which stays instant. Censure keeps its delay
  and fall timing.
- **Blocked offhand:** the empty offhand slot shows the equipped two-hander's
  image, dimmed further than a ghost, with the tooltip
  "Blocked: <Two-hander> is two-handed".
- **Refusal on the page:** the drag refusal names the way that works:
  "<Staff> is two-handed: take <Spellbook> out first, or shift-click the
  <Staff> to swap both."
- **Sent tab:** a fifth tab "Sent" after "Letters"; newest first, 8 per
  page like the other lists; at most 50 kept (the oldest dropped silently,
  never a refusal), 30-day expiry like letters; actions: open, Delete.
  Messages to the admin are not copied (the To the admin tab lists them).
- **Faction colours:** the existing ones, Accord `#3f6fce`, Throng `#c41e3a`
  (`grug_core.factions`), on the map icons and the buttons. Buttons: subdued
  at about 35–40 % strength, hover a little brighter, focus looks like the
  normal state, chosen at full strength with bold text.
- **Marker floor:** never below 16 px.

## 3. Shared conventions

- English UI strings; player-visible changes go into Help where a page owns
  the topic (EQUIP: the Character page's two-handed line; MAIL: the mail
  help; MAP: nothing new).
- A screen size the user did not mention keeps today's look: at 1920×1080
  and below, the forms, the map window and both maps' markers are
  unchanged (fixtures pin this, §6), except where a ruling changes them
  (markers on small screens).
- No new sound (sound approval gate); particle counts stay in the hundreds
  (one textured particle per symbol).
- Art follows the icon style: readable small, few details; the textures are
  white to pale gold so the lit look tints them.

## 4. Lane goals

### EQUIP — two-handed swap, blocked offhand, fishing rod

**Swap (ruling 1).** The shift-click route (`equip_by_shift`) equips a
two-hander over an occupied offhand by moving the offhand piece into the
inventory in the usual give order, after checking it fits; the weapon swap
stays as today. Both hands change in one step with one equipment-change
notification each (or one for both, whatever the notifier's contract says).
No room: nothing moves, one feed line ("No room in your inventory for
<piece>."). The drag refusal keeps its rule with the new wording (§2).

**Blocked offhand (ruling 2).** The Character page draws the blocked state
per §2 for every class with a two-hander (Warrior's Battle Axe, Mage's and
Priest's Staff); the Scout has none.

**The refusal is readable.** First establish (headless capture) whether the
feed is hidden behind the Character page. If it is, the refusal must be
visible while the page is open; the lane picks the way (a line on the page,
the feed drawn above the window, …) and reports it. A re-send of the
inventory form during a drag must not drop or duplicate an item.

**Fishing rod (ruling 7).** `grug_fishing:rod` joins the Basic starter set.
The leftover `core.register_craft` grid recipes in `grug_fishing/init.lua`
go if nothing reads them (the craft grid has size 0); the lane says what
read them, if anything.

**Docs.** [inventory_equipment.md](../design/inventory_equipment.md) (hand
count, shift-click), [combat_stats.md](../design/combat_stats.md) §7 if it
describes the refusal, [professions.md](../design/professions.md) or
wherever the starter set (ruling 19) is described.

### MAIL — sent letters

**Ruling 3.** At send, a text copy goes to the sender's sent list:
recipient, date, subject, body, postage and the attachments as names and
counts. Stored under its own mod storage key per player (not inside the
inbox box, which is read whole at every inbox access). Defaults per §2.
The tab bar is generalised from four fixed tabs to its caption list.
Admin letters and announcements (the admin side) are out of scope unless
the same path sends them; the lane says.

**Docs.** [mail.md](../design/mail.md): the Sent tab replaces "there is no
sent folder"; the storage layout comment in `store.lua`.

### UI — 4K scaling, creation buttons

**Viewport (ruling 4).** `ui_window.lua`'s cap follows the ruling; every
user of the capped viewport (padding, `window_information`, the map
window's layout, `text_scale`) gets it from the one place.

**Text (ruling 4).** On a screen where the cap grows, form text grows by the
same factor, so text and slots keep their 1080p proportions at the same GUI
scale. Where a control cannot be scaled (checkbox and dropdown captions keep
the client font), the lane lists it.

**Creation buttons (ruling 9).** The faction buttons get their own style
per §2 instead of the navigation style; the dead colour code goes. The
lane confirms or refutes the cause of today's look (focus or hover) in its
report.

**Docs.** [ui-presentation.md](../technical/ui-presentation.md) (the cap),
[character_visuals.md](../design/character_visuals.md) or wherever the
creation window is described.

### MAP — marker size, camp colours

**Size (ruling 5).** Marker pixels follow the drawn map's pixel size, at the
ratio a 1920×1080 desktop at HUD scale 1 has today (there: unchanged), never
above today's `32 × real_hud_scaling`, never below the floor. The same for
the minimap against its own drawn size. Hit areas and the overlap solve
already take any size; the lane measures the map's and the minimap's pixel
sizes for 1920×1080, 1280×720, 2560×1440, 3840×2160 and a phone profile
(for example 2400×1080 at HUD and GUI scale 2.5) and reports the marker size
before and after for each.

**Colours (ruling 8).** A blue Accord variant of the war camp icon (map
marker and both baked minimap sizes) and faction-coloured cloth on the
construction-camp icon, chosen by the camp's faction. The baked minimap
re-renders on its own (its cache key is `bake.lua`'s source). The icon
masks and the art generator (`tools/r44_mb/gen_baked_art.py`) follow; the
lane may recolour by palette, no new drawing needed. Fortresses are
unchanged.

**Docs.** [world_map.md](../design/world_map.md) (marker size rule, the PvP
layer's icons).

### ART — hammer and book (GPT-6 Astra)

Two particle textures per the icon style and §3: a hammer and a book, each
reading clearly as a falling silhouette at small and large sizes on dark
and bright ground. A preview page (both textures at the §2 sizes over
typical ground, lit and plain) for the user's pick; a second variant of each
is welcome. Design goals, not per-step specs (Astra brief rule).

### FX — priest effects (wave 2)

After the user's pick: Smite, Censure and Final Word per §2 with the picked
textures, in `particle_effects.lua` and in the catalogue tool
(`tools/r52_pfx/effects.py` carries the same numbers). Damage timing does
not change. The Round 53 hooks fixture (`tools/r53_hooks/portable_test.lua`)
follows. Docs: wherever the priest effects are described
([classes.md](../design/classes.md) or the effect catalogue notes).

## 5. Rules

- [Round workflow](../process/round-workflow.md) and AGENTS.md apply; lanes
  never push, merge, sync or touch the main checkout.
- Re-check first: every claim of this plan a lane acts on is checked against
  the code at the base commit and reported as confirmed, changed or refuted.
- Fixtures: your own plus the ones that test the behaviour you change; the
  full run once before your report; name what you ran and why.
- Headless runs only through `tools/luanti_headless.sh` (never the user's
  Luanti folder), `LC_ALL=C` for captures.
- A case the rulings do not cover is decided by the ruling's reason;
  otherwise stop that path and report under `## Blockers / questions`.

## 6. Verification

Per lane (round workflow §3): `check_lua.sh` on changed Lua,
`check_fresh_server.py`, the lane fixture `tools/r66_<lane>/portable_test.lua`,
the full fixture run once, one smoke boot, the upgrade classification in the
report, independent review (ART: review of the textures against the art
rules and the generator checks it touches).

Fixtures cover at least:

- **EQUIP:** shift-click staff with wand + spellbook equipped and one free
  slot (both swap), with no free slot (nothing moves, one line), with an
  empty weapon slot; drag refusal unchanged in both directions; the
  blocked-offhand drawing per class; the rod recipe known for a new
  character.
- **MAIL:** a sent copy per send with attachment names, no items; 50-cap
  drop of the oldest; expiry; delete; the tab bar with five tabs; nothing
  in the inbox format changes.
- **UI:** the cap and the text factor for 1280×720, 1920×1080, 2560×1440
  (all three unchanged, formspec output identical) and 3840×2160 (as
  1440p); the creation buttons' styles in all three states.
- **MAP:** marker sizes for the window profiles of §4 MAP (1920×1080
  unchanged); the camp icon per faction; the construction camp's cloth.
- **FX:** the three effects against their catalogue entries.

Round end on main: the gates of the round workflow §3, `check_upgrade.py`,
sync to Luanti.

### GUI checklist (desktop and web)

Refined by lane D from the lanes' excerpts and the reviewers' notes. Each
item on the desktop client and on the web client. Items marked *look* ask
for the user's verdict on a first-look default.

1. **Blocked offhand.** Mage or Priest with a Staff: the empty offhand slot
   shows the Staff dimmed (darker than an empty slot's ghost image) and its
   tooltip reads "Blocked: Staff is two-handed". Warrior with a Battle
   Axe: the same; the Scout has no two-hander. *Look:* the dim level.
2. **The refusal is readable with the page open.** Drag a Staff onto Weapon
   while a Spellbook is equipped: refused, and "Staff is two-handed: take
   Spellbook out first, or shift-click the Staff to swap both." shows for
   about 6 s in a strip at the top of the Equipment box (in place of its
   heading). Drag the Spellbook onto the blocked offhand: refused with
   "Staff is two-handed: equip a one-handed weapon to carry Spellbook
   too." Nothing is lost or doubled. *Look:* the 6 s and the place.
3. **Shift-click swap.** Wand and Spellbook equipped, shift-click a Staff in
   the bag: Staff in Weapon, Wand in the Staff's cell, Spellbook in the
   bag. With a full inventory: nothing moves and one line "No room in your
   inventory for Spellbook." With an empty Weapon slot and a full bag: the
   Spellbook takes the Staff's cell. Warrior: the same with Battle Axe,
   Sword and Shield. Shift-clicking a Spellbook while a Staff is equipped
   stays refused.
4. **Fishing rod.** A new character's Crafting → Basic lists the Fishing
   Rod at once, before any Thread was held; an existing character's too.
5. **Sent letters.** Mail a letter with two attachments: the second tab
   "Sent" lists "To <name> · date · 2 attachments"; opening it shows
   "To: <name>", the text, "Postage paid: …" and both item names, with no
   Take all, Reply or Report, and nothing can be taken. Delete removes the
   copy at once, without a dialog. Letters to the admin do not appear
   there. (One copy reads "1 sent letters", like "1 letters"; backlog.)
6. **Mail tab bar:** all five captions readable and unclipped, the
   underline under the active tab, at 1024×600, on a phone and at 4K.
7. **4K** (3840×2160, GUI scale 1): the inventory window fills about 60 %
   of the height (the viewport is two thirds, the window 90 % of it); tabs,
   labels, headings and buttons keep their 1080p proportion to the slots;
   nothing clipped in Crafting, Character stats, Mail, a quest giver, a
   vendor, Help, the Claim Stone, a chest and the map window. Expected to
   stay at the client font: item counts, tooltips, checkbox and dropdown
   captions, the welcome window, the vendored sign, book and mob dialogs.
   Known cosmetic notes: a textarea or prose block after the first one in a
   window may fall back to the client font; the map's quest titles wrap a
   little early. At 1920×1080 and 2560×1440: unchanged.
8. **Create Character:** both faction buttons subdued in blue and red at
   the start, neither looks chosen (also after Tab); hover a little
   brighter; the chosen one full colour with bold text, the other stays
   subdued; switching swaps them. *Look:* the strengths (38 / 50 / 62 /
   100 %).
9. **Map markers on small screens:** on a phone (web or Android, for
   example 2400×1080 at scale 2.5) and in a 1280×720 window, markers in the
   map window and the minimap keep the share of the map they have at
   1080p (about 32 px on the phone, 21 px at 1280×720), never below 16 px,
   and stay readable. 1920×1080 at HUD scale 1: unchanged (32 px). After a
   resize an open map is redrawn within about 2 s.
10. **Desktop HUD scaling above 1** (MAP question 1, open for the user):
    at 1920×1080 with HUD scale 2 the markers drop from 64 to 32 px in both
    maps, since HUD scaling now only caps them (the server cannot tell it
    from a phone's density); at 4K with HUD 2 the window draws 43 px and
    the minimap 64. Say whether 32 px at 1080p and HUD 2 is fine.
11. **Camps:** in the PvP layer and on the minimap, Accord war camps are
    blue and Throng ones red, with the same tent; camp sites under
    construction hang cloth in their faction's colour; fortresses are
    unchanged. Check the blue tent on dark sea (low contrast in the
    preview) and on snow.
12. **Smite** on a mob, once a second: a small hammer falls head first in
    about 0.15 s, then the gold ring springs out at the feet. Not annoying?
    *Look:* size 7.
13. **Final Word:** the large hammer falls inside the white column and lands
    with it, then the ring bursts. The hammer is visible only during its
    fall (about 0.1 s, six frames). *Look:* enough, or should it rest on
    the ground for about 0.15 s (one more particle)?
14. **Censure:** the gold warning ring, then the book (Book Q) falls and
    lands at 0.75 s, then the impact ring. The book sinks into the ground
    for its last two frames or so; say whether that shows.
15. **All three symbols** on grass, on snow and at night: they read by day
    and at night; snow and bright sky wash them to near-white (additive
    light). With the particle scale setting at 1.5 or more, two symbols
    draw on one spot (brighter). Web: no frame drops at Smite's rate.

## 7. Orchestration notes

- **Start state:** main `7a68e871` (0.65.0 plus the status note; one commit
  ahead of origin). The joint GUI test of 0.57–0.65 is pending and
  independent of this round.
- **Routing:** the user decides per session; latest: Claude coordinates,
  Opus implements and reviews, GPT-6 Astra the art lane. Every lane gets an
  independent review.
- **Process budget:** at most eight Lua processes through the shared queue;
  no wall-clock kills.
- **Expected classification: compatible.** MAIL adds a mod storage key
  (absent reads as empty, the inbox format unchanged); MAP's baked minimap
  re-renders by its cache key; the starter list is read at runtime. A lane
  that finds otherwise reports before building.
- **Shared files:** `mods/PLAYER/grug_inventory/help.lua` (EQUIP, MAIL),
  `docs/design/world_map.md` (MAP), `mods/PLAYER/grug_map/window.lua`
  (UI via the viewport, MAP), `mods/CORE/grug_core/particle_effects.lua`
  (FX only). Merge order per §1.
- **Lane D:** version 0.66.0 in `game.conf` and `tools/web_data/upgrade.json`,
  the completion section, STATUS, the AGENTS pointer, BACKLOG, README,
  CHANGELOG.
- **Decided during the round:** the user's art pick (between ART and FX);
  the coordinator defaults of §2 after the first in-game look.

## Completion (2026-10-28)

All six lanes are merged on main. MAIL, EQUIP, UI, MAP and FX were each
reviewed independently (Opus): all MERGE, no fix rounds. The art study ART
(tools only) was checked by the coordinator (`generate.py --check`); FX's
review checked the shipped hammer and the book's integration with the
stand-in book (Book F), which the coordinator then replaced by the picked
Book Q. This lane D (the
version, the declaration, this section, the GUI checklist, the status
owners) follows on main `ef368b95`. **0.66.0 is compatible:** MAIL adds one
mod storage key per sender, `sent:<name>` (a missing key reads as an empty
list, an empty list removes it; the inbox, ticket and broadcast formats are
unchanged); MAP adds three textures and leaves the map cache key unchanged
(`base.lua`, `bake.lua`, `baked_art.lua` untouched), so a 0.65.0 world
reuses its cached map; EQUIP's starter list is read at runtime and the
equip notice lives in the page context only; UI and FX touch no saved
state. No reset, no migration step. **Push:** not pushed; production is
still 0.55.1; origin/main is `7a68e871` (0.65.0 and its status note).
**GUI test:** pending; it joins the joint GUI test of 0.57–0.65
([checklist](#gui-checklist-desktop-and-web)). **Sync:** by the coordinator
after each merge.

### Lanes

Main's first-parent commits from the plan `5e50b4f4` (lane tip in
brackets), in merge order:

| Lane | Commit | What | Review |
|---|---|---|---|
| MAIL | `3ed99644` (`d71ec561`; `25e94c3c`, `8b7a52bd`) | A successful `send_letter` writes a text copy (recipient, date, subject, text, postage, attachment names such as "Iron Ingot x12", never item strings) under `sent:<name>`; `M.SENT_LIMIT` 50 (the oldest dropped silently), 30-day expiry through `M.prune`; `grug_mail.sent` / `delete_sent`. The tab bar is one caption list, Sent the second of five tabs, each tab as wide as its caption plus room for " (99)". The Sent pane: "To:", the text, "Postage paid:", the names, Delete (no dialog). Admin, NPC and broadcast letters get no copy. `mail.md`, Help, `module-guide.md`, `upgrade-contract.md`; fixture `tools/r66_mail` | MERGE, no findings |
| EQUIP | `dae8ccd1` (`c9a6a047`, main merged in; `ad3e4bd4`, `c36ca3d6`) | `equip_by_shift` swaps both hands for a two-hander after a `fits()` check, with one `equipment_changed(player, nil)`; "No room in your inventory for <piece>." otherwise. The blocked offhand draws the two-hander's image `^[multiply:#666666^[opacity:140` with "Blocked: <name> is two-handed". Every equip refusal also shows for 6 s on the Character page in place of the "Equipment" heading (the capture showed the feed covered by the page); the drag refusal names the shift-click. `grug_fishing:rod` in the Basic `STARTER` set; the grid recipes in `grug_fishing` removed. `r44_ch`, `r47_cr` follow; fixture `tools/r66_equip` | MERGE (one nit: a doubled word in `module-guide.md`, fixed by the coordinator in `4376cfd1`) |
| UI | `14f08b05` (`6e376088`; `a6d2934e` … `181b4662`, main merged in `9d75d498`, follow-ups `374c0c5e`, `a61973c3`, `b05ad7cf`) | `ui_window.lua`: the viewport ceiling `min(H, max(1080, ⅔·H))`, width `1920·k ≤ W`, `form_growth`; `grug_core.ui.text_growth`, `text_scale` × growth, `font_size(factor, growth)`; the form code of 23 files (the inventory pages and the service windows) passes the growth, Help's hypertext gets a `<global size>` prefix, the Claim Stone window and the vendored chest, furnace, bookshelf and vessels-shelf labels follow (`GRUG PATCH`, VENDOR.md). The creation faction buttons have their own `[fill` style in the faction colour (subdued 38 %, hover 50 %, pressed 62 %, chosen 100 % with bold text; focus = normal). `ui-presentation.md`, `world.md`; fixture `tools/r66_ui` (and `bytes.lua`); `r35_c`, `ui_window_cap` follow | MERGE, no findings (backlog notes) |
| MAP | `607545bf` (`5e9d651f`; `a01613a8`, `5728f76e`, `05aeb3fe`, main merged in `a1f52ca8`) | `markers.lua` `M.fit`: `round(32 · drawn / reference)` clamped to [16, 32 · HUD scale], in the map window (against the 1080p map) and the minimap (against the 1080p hole, 198 px); arrows and margins follow. Accord war camp blue, construction-camp cloth blue or red, chosen by the slot's or the race's faction (`settlement_icons.M.faction`); three new 32 px textures via `tools/r64_map/ship.py` and `tools/r66_map/recolor.py`. The map window's body text grows with the viewport. `world_map.md`, `ui-presentation.md`; fixture `tools/r66_map`; `r44_mq`, `r58_lift` follow | MERGE, no findings (question 1 open for the user) |
| ART | `65e74a4d` (`62775589`; six passes `358aff53` … `83dbc9bc`) | GPT-6 Astra's art study in `tools/r66_art/`: generator, candidates, preview, licence rows, `REPORT.md`; picks recorded | coordinator check (`generate.py --check`) |
| FX | `ef368b95` (`f41d247d`; `ffcd5b84` … `6d142444`) | `grug_core_fx_hammer.png` (Hammer C) and `grug_core_fx_book.png` (Book Q); `particle_effects.lua` `hammer()`: Smite a size-7 hammer from 3.2 m in 0.15 s (the beam gone, the ring after 0.15 s), Final Word a size-12 hammer down its column (column 26 → 25), Censure the size-16 book in place of the seal (delay and fall unchanged). `tools/r52_pfx/effects.py` and its data; `r541_glow` follows; `combat_stats.md`; fixture `tools/r66_fx` | MERGE (Low: the book's licence row; fixed at the book swap in `f41d247d`) |
| D | this section | version 0.66.0, the declaration, this completion, the GUI checklist, STATUS, AGENTS, BACKLOG, README, CHANGELOG | independent review |

Main has **291** portable fixtures (5 new: `r66_mail`, `r66_equip`,
`r66_ui`, `r66_map`, `r66_fx`). `mods/` against 0.65.0 (measured, `git
diff 7a68e871 ef368b95 -- mods`): 55 files, +985 −288 lines: 48 Lua files
(four of them vendored), five PNGs and two media ledgers.

### Decisions during the round

**The user:** the rulings of §2 (1–9), unchanged. **The art picks** (six
ART passes, previews on one private page):

1. Hammers A/B and closed books A/B: **Hammer A**; both books rejected,
   the user wants an open book, symmetric, front view.
2. Open books C/D: the open book wanted, tilted back; Hammer A too plain,
   redraw its shape.
3. Hammers C/D and tilted books E/F: **Hammer C**; F's tilt, but a
   straight, hard spine. Smite's hammer a bit small: size **5 → 7**.
4. Hardcover books G/H: shape and perspective settled; the pages should bow
   upward.
5. Bowed pages I–N, blank or with stylised writing that follows the page:
   **J** the favourite; a subtler dome and slightly wider pages.
6. J refined in three steps O/P/Q: **Book Q** (dome −24 %, width +7.5 %).

**The coordinator** (answers to lane questions and reviews; each built as
stated; the *look* items are on the GUI checklist):

- MAP Q1: HUD scaling above 1 only caps the markers (1920×1080 at HUD 2:
  64 → 32 px). Kept as ruled; **open for the user** at the GUI test
  (checklist item 10).
- EQUIP: shift-clicking a Spellbook over an equipped Staff stays refused
  (ruling 1 covers the two-hander; a swap would leave the character
  bare-handed).
- First-look defaults: the equip notice's 6 s and its place, the blocked
  offhand's dim level, the faction buttons' 38 / 50 / 62 / 100 %.
- MAIL: tab widths by caption length instead of five equal tabs (equal
  fifths clip "Announcements (99)" at 1024×600); accepted deviation.
- UI follow-ups after EQUIP and MAIL merged: Help's body growth, the Claim
  Stone window, the vendored chest, furnace and shelf labels with `GRUG
  PATCH` markers; the map window's body text moved to MAP; the vendored
  sign, book and mob dialogs went to the backlog.
- FX: Smite's ring waits for the hammer (`after = 0.15`); Final Word's
  column 26 → 25 keeps the effect at 46 particles; the hammer is visible
  only while it falls, pending the user's look (checklist item 13).
- Small fixes by the coordinator: the doubled word in `module-guide.md`
  (`4376cfd1`); a stray run report (`last.md`) dropped from ART
  (`62775589`); the Book Q swap into FX and its licence row (`f41d247d`).

### Deviations from the plan

- **Merge order:** MAIL merged before EQUIP (EQUIP was still running);
  EQUIP merged main before its review.
- **"Both baked minimap sizes"** (§4 MAP): refuted. Nothing bakes icons
  since Round 64; both maps draw camps from the 32 px marker textures, so
  three new 32 px textures replace the planned baked variants and the
  baked art stays unchanged (now dead art; backlog).
- **The chest, furnace and shelf labels** were vendored code, patched with
  `GRUG PATCH` markers and VENDOR.md entries.
- **What the text growth covers** (§4 UI): every grug form, Help's body,
  the Claim Stone window, the vendored box labels and the map window's
  body. It cannot reach checkbox and dropdown captions, item counts and
  tooltips (client font); the welcome window and the vendored sign, book
  and mob dialogs are not converted.
- **ART's review:** a coordinator check instead of an independent review;
  FX's review covered the shipped hammer and the book's integration (with
  the stand-in Book F; Book Q swapped in afterwards by the coordinator).
- **§7 start state:** origin already held `7a68e871` (pushed on
  2026-10-27), not one commit behind it.

### Numbers worth keeping

From the lanes' reports (measured there unless marked).

- **MAIL, the sent list at its cap** (50 copies of 4,000 characters with
  four names each, the engine's serializer): **203 KB** plain text,
  **593 KB** worst case (three-byte characters); a full inbox is 204 KB.
  Storage time per send: empty inbox 0.02 → 0.20 ms; a 49-letter inbox
  and a full sent list 0.99 → 1.40 ms. The widest caption's share of its
  tab: 42 % at 1080p and at 4K, worst 74 % at 800×600 (four equal tabs
  before: 93 %).
- **UI, viewport and text** (density 1; the window is 90 % of the
  viewport's height):

  | Screen | GUI | Viewport | text_scale | Growth | Window / height |
  |---|---|---|---|---|---|
  | 1280×720 | 1 | 1280×720 | 1.000 | 1 | 90 % |
  | 1920×1080 | 1 | 1920×1080 | 1.000 | 1 | 90 % |
  | 2560×1440 | 1 | 1920×1080 | 1.000 | 1 | 68 % |
  | 3840×2160 | 1 | 2560×1440 | 1.333 | 1.333 | **60 %** (was 45 %) |
  | 2400×1080 phone | 2.5 | 1920×1080 | 0.400 | 1 | 90 % |
  | 1080×2400 portrait | 2.5 | 1080×1600 | 0.400 | 1 | 30 % (width-bound) |

  The byte proof: every inventory-page and map-window string at 1280×720,
  1920×1080 and 2560×1440 (GUI 1 / 1.5 / 2, density 1 / 2) is identical
  to before; every 4K string differs.
- **MAP, marker size** (px; map window and minimap, before → after):

  | Profile | Map px | Window | Minimap hole px | Minimap |
  |---|---|---|---|---|
  | 1920×1080 | 762 | 32 → 32 | 198 | 32 → 32 |
  | 1280×720 | 496 | 32 → 21 | 132 | 32 → 21 |
  | 2560×1440 | 762 | 32 → 32 | 297 | 32 → 32 |
  | 3840×2160 (after UI) | 1016 | 32 → 32 | 429 | 32 → 32 |
  | 3840×2160, HUD 2 (after UI) | 1016 | 64 → 43 | 429 | 64 → 64 |
  | 1920×1080, HUD 2 | 762 | 64 → 32 | 198 | 64 → 32 |
  | phone 2400×1080 × 2.5 | 783 | 80 → 33 | 198 | 80 → 32 |

- **FX, particles per occurrence:** Smite 13 → **9**, Final Word 46 → 46
  (column 26 → 25), Censure fall 1 → 1, its warning and impact rings
  20 / 32 unchanged. Bytes per occurrence (`effects.py`'s cost model, an
  estimate, not the wire): Smite 497 → 418, Final Word 1 399 → 1 527; the
  50-player fight 21.1 → 20.8 KB/s per receiver.

### Checks

- MAIL: full run 287/0, smoke boot PASS (a copy through the real mod
  storage). Review: `r66_mail` (61 checks) and `r48_mail` PASS;
  `measure.lua` and `caption_widths.py` reproduced.
- EQUIP: full run 287/0, smoke boot and capture (E0–E3). Review: full run
  after the main merge 288/0.
- UI: full run after the main merge 289/0, smoke boot, 1080p and 4K
  captures. Review: six fixtures PASS, the byte proof rerun.
- MAP: full run after the main merge 290/0; phone and 4K capture boots
  clean. Review: six fixtures PASS, the byte proof on three trees.
- FX: full run 289/0, capture boot (nine views). Review: `r66_fx`,
  `r53_hooks`, `r541_glow`, `r40_px` PASS; `check_limits.lua` 62 cards.
- Main: `check_fresh_server.py` PASS after each merge; after FX `r66_fx`,
  `r53_hooks`, `r541_glow` PASS. This lane: `check_upgrade.py`,
  `check_fresh_server.py`; `r37_dc`, `r41_up` and `r43_gs` (they pin the
  version, the changelog, the README and CHANGELOG links and the
  declaration); the link and anchor check of the touched documents; the
  full run once, 291/0.
