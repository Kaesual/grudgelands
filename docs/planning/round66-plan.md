# Round 66 — polish: big and small screens, the two-handed swap, sent letters, priest symbols

Planned with the user on 2026-10-28 from their notes after playing 0.65.0.
**Started on the user's "go" on 2026-10-28; Claude coordinates.**
Version: **0.66.0**. Expected classification: **compatible** (see §7; each
lane states its own).

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

### GUI checklist (draft; lane D refines it)

1. Priest/Mage with Staff, Spellbook in the inventory: the offhand slot
   shows the dimmed Staff and the "Blocked" tooltip.
2. Dragging the Spellbook onto it: refused, and the reason is readable
   with the page open.
3. Wand + Spellbook equipped, shift-click a Staff: Staff in Weapon, Wand
   where the Staff was, Spellbook in the bag. With a full inventory: nothing
   moves, one line. Warrior: the same with Battle Axe and Shield.
4. New character: the Fishing Rod is in the Basics list at once.
5. Send a letter with two attachments: it appears under Sent with its
   text and the attachment names; nothing can be taken; Delete removes it.
6. On the 4K screen: the inventory window fills about two thirds of the
   height; text in proportion; nothing clipped. On 1080p: unchanged.
7. Phone (web client or Android): map and minimap markers no longer cover
   the map; still readable.
8. War camps: Accord blue, Throng red, on map and minimap; construction
   camps with the cloth in faction colour.
9. Create Character: both faction buttons subdued in their colours at the
   start, neither looks chosen; the chosen one strong; hover and focus do
   not look like a choice.
10. Smite, Censure, Final Word: the symbols fall and land with the hit;
    readable on snow and in the dark; Smite once a second not annoying.

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
