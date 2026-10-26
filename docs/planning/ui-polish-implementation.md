# UI polish implementation — Atlas revision 04

Authorized by the user on 2026-10-26. Implementation starts on `ui-tab-hover`
after merging main `8eeddb0d` (0.63.0); main itself stays unchanged. Keep this
worktree, do not push or merge into main. The approved browser reference is
`tools/ui_polish_review` at `136af057`, published in
`~/projects/grudgelands-orchestration/ui-polish-review-2026-10-26-v4/`.

## Scope and rulings

Implement the one current proposal for every recorded UI family, preserving
native inventory transfers, list identities, session validation, permissions,
full text, existing timers, animated progress and refresh cadence. Keep special
slot ghosts, item images, cloak/effect/mount images and craftable counts.
Common inventory tabs share a wider frame; Map & Quests stays larger, 50/50
map and quest area, one layer selector and no redundant return button.
Navigation uses readable text and active underlines, with Creative categories
on their own row; no inaccessible privileged pages.

Inventory: grid left, Bags/Potion Belt/Money stacked right with aligned bottoms;
centered common hotbar with adjacent A/B. Subpages retain two inventory rows.
Talents: left menu matching artwork height, Points bottom aligned, full tree
artwork and only unlocked skills below. Help uses a left topic menu. Dialogs
retain clear list/detail or status/action hierarchy. Service windows and simple
travel/housing windows are compact without reducing text readability.
Containers/stations: unframed upper slots on inventory columns, four to six
visible player rows with remaining rows scrollable. Furnace input in column 1
(dual 1–2), fuel in 4, arrow spanning 5–6, 2×2 output in 7–8.

Explicit functional changes authorized with the design: Sell/Trade-in quantity
choices 1/5/10/All (whole lots and remainder rules preserved), Repair inside the
camp trader tabs (existing repair validation and quotes retained), and four
output slots for both shared and personal dual furnaces. Existing stored items
must survive output-list growth. No world/content redesign; the Shipwright
building and recovery scalability investigation remain backlog work.

## Work ownership

The coordinator integrates in the retained worktree. Bounded native agents
implement disjoint files there; this is the user's requested current-worktree
execution, with no agent touching main or staging another agent's files.

| Area | Ownership |
|---|---|
| Inventory/navigation/character/talents/help/creative/creation/party | Inventory lane |
| Crafting/operations/containers/furnaces and four-output persistence | Craft lane |
| Traders/repair/quest givers/profession and mount services | Services lane |
| Core presentation/map/mail/housing/travel/editors/capture/integration | Coordinator |

Shared geometry: inventory body 20 × 13.5 real units, header
about 1.5, native slots 1 unit with 1.25 pitch. Other pages consume frame/view geometry rather
than duplicate it. Capture-driven adjustments are recorded below. No polling helper or
new globalstep; scoped font and field styles only.

## Verification and completion gates

- Targeted portable fixtures for changed mechanisms, meaningful new checks for
  quantity validation, repair routing and preserved dual-furnace contents.
- `check_lua.sh` for every changed Lua file; fresh-server check; theme generator
  check if assets/styles require it; design validation where applicable.
- One complete fixtures run after integration through the existing r45 Lua
  queue, never more than eight Lua processes. One disposable headless boot,
  `LC_ALL=C LANG=C`; never the user's Luanti data directories.
- Capture all 69 recorded states in the real isolated client at 1035×696,
  1600×900 and 2560×1440; include bright-scene/GUI1.5 representative cases and
  added functional states. Inspect all screenshots, with at most two correction
  passes after initial completion. Preserve original screenshots and contact
  sheets. Browser study is not native/web acceptance.
- Independent source review, fixes and final clean worktree with commit/report.
  User retains final desktop/web GUI acceptance and merge control. Document any
  remaining native limitations honestly; collect fundamental unresolved issues
  at the end rather than invent complex optional mechanisms.

## Classification

The change is **compatible**. Dual output growth adds capacity without
changing list IDs or item formats. The existing shared-station initialization
and activation path grows its lists; personal-workspace restoration grows the
list after loading the saved contents. Fixtures verify old two-slot contents
and a newly filled fourth output survive restoration. No release version is allocated by this parallel UI lane; merge
coordinator owns the release record.

## Implementation outcome — 2026-10-26

Main `8eeddb0d` merged without conflicts as `31918c97`. The retained
`ui-tab-hover` worktree contains the implementation; no merge to main or push.
The presentation contract lives in [ui-presentation.md](../technical/ui-presentation.md).

- Inventory/navigation/character/talents/help/party/Creative: wider shared
  frame, text navigation, separate Creative category row, stacked utility
  column, centered hotbar, native slot ghosts and item/effect/cloak icons.
  Talent artwork fills its region beside the menu; unlocked skills follow it.
- Crafting/operations: icons, craftable counts, profession choices, quantities,
  target slots, enchant list, queue and generated sources retained; no nested
  operation card. Native item rendering retains 3D node previews.
- Containers/stations: aligned, unframed upper slots and bounded scrollable
  player inventory; both furnace variants have four outputs. Progress arrows
  are wider; their client animation and resend policy are unchanged.
- Services: compact trainer/travel/housing windows; vendor rows with quantity
  choices; Repair stays in the camp vendor's navigation. Quest givers use
  state/story icons, list/detail panes and the existing reward-choice flow.
- Mail/admin mail/editors: wider list/detail and compose layouts, slate input
  fields, top-aligned empty messages. Quickbar uses evenly spaced groups with
  framed mount/boat icons. Money withdrawal stays in one row.
- Map: equal map/quest columns, separate quest list/detail, one layer dropdown,
  minimap switch on the toolbar, centered undistorted 1× map and full viewport
  when zoomed. Center-preserving zoom and stale scrollbar events use the
  actual image/viewport geometry; follow-player behavior remains.

## State, routes and performance

No player-meta schema, quest state, achievement IDs, item IDs, HUD API or mail
persistence changes. Native inventory lists, transfer/shift-click routes and
permissions remain. Exceptions/extensions explicitly part of this work:

- Dual furnace output capacity grows from two to four, shared and personal;
  no items are discarded. No migration or map reset is needed for this change.
- Claim recovery's temporary detached list now has exactly one slot per
  recovered entry, without empty padding; saved recovery entries are unchanged.
- Sell adds quantity buttons; Trade-in adds `tradein1_`, `tradein5_`,
  `tradein10_` routes. `grug_guild.trade_in(player, item, requested_lots)`
  accepts an optional quantity; omitted retains All. Prices and rates do not
  change, and insufficient whole-lot requests fail before removal.
- Embedded repair uses the existing provider/quote checks and serial-prefixed
  action fields. `grug_repair.quote_formspec` is a shared renderer only;
  standalone service APIs remain. Vendor tab switches retain the vendor
  session and discard stale repair quotes.
- Quest-giver `quests` keeps its field name but is a native image/text table,
  so its event decoder uses table events. Accept/complete/reward routes and
  validation remain with `grug_quests`.
- Map adds `grug_map_layer` and stable dropdown indices; old layer buttons
  remain accepted. Geometry arguments on atlas helpers are optional. The
  quest_box interface and HUD ownership are unchanged.
- Core `frame` gains an optional fifth player argument; `readable_padding`
  and `input_background` build presentation fragments. Station forms accept
  an optional fifth visible-row count. Existing callers keep their defaults.

No new globalstep, ABM, LBM, per-tick pass or periodic formspec send. Window
information is read only while building an already requested form. Native
padding caps oversized WQHD geometry without switching off resize fitting.
Forms contain extra styles/backings and can have different byte sizes; this
is not a measured CPU/frame-rate improvement. Existing queue, animation,
scroll and send-throttle fixtures pass. No new CPU benchmark is claimed.

## Native visual audit

Artifact root:
`~/projects/grudgelands-orchestration/ui-polish-native-2026-10-26/`.
Open `final/index.html` for the consolidated gallery; original PNGs, contact
sheets, exact shown forms and capture logs remain under the pass directories.
The scenes use isolated disposable worlds and the real Flatpak client,
not HTML renderings. The user's Luanti folder was never opened.

- Initial implementation (`pass0`): 69 states at each of 1035×696,
  1600×900 and 2560×1440; all 207 images inspected.
- Correction 1 (`pass1`): 77 states at each resolution (231 images), plus
  12 representative bright-scene shots at 1035×696, GUI 1.5. All inspected,
  using contact sheets and original/cropped detail views. Fixed reward/hint
  overlaps, small navigation captions, effects bounds, field colors and
  disproportionate WQHD slot sizing.
- Correction 2 (`pass2`): 14 affected views at each resolution and at small
  GUI 1.5 (56 images). Inspected after widening/shortening craft and inventory
  buttons, moving the upgrade quantity field, separating repair durability
  from its button, moving the empty admin-ticket message to the top, and
  restoring Quickbar's left anchor before native padding.

A final state-only retake of Basic crafting and the empty Upgrade view
at all three standard resolutions removes probe state carried over from the
selected-enchant case; no runtime code changed for this retake.

Two correction passes were used, as requested. No third design pass follows
before the user's review. Captures cover a maximum-bag inventory, active
status icons, party membership, a ready quest, enchant candidates, upgrade
targets, book reading and embedded repair in addition to the default atlas.
Native fonts and scrollbars remain client-controlled; long lists/descriptions
are scrollable. Screenshots demonstrate presentation, not full interaction
acceptance or web-client rendering.

## Checks and independent review

All executable Lua tests/captures ran through the r45 Lua queue, at most eight
Lua processes. Headless/client runs use `LC_ALL=C LANG=C` and disposable paths.

- Complete fixtures run **once**: 274 passed, 7 failed. All seven failures were
  assertions tied to the old layout in `r26_status_icons`,
  `r27_quest_item_names`, `r29_q1`, `r30_p1`, `r35_f`, `r35_m`, `r44_qb`.
  Their expectations were updated without removing behavior checks; all seven
  passed on the targeted rerun. The full run is not described as initially green.
- Final integrated delta run: **19 passed, 0 failed** (`r25_interfaces`,
  `r26_status_icons`, `r27_quest_item_names`, `r28_a6_ui`, `r29_q1`, `r30_p1`,
  `r35_f`, `r35_m`, `r44_qb`, `r44_ch`, `r44_mq`, `r451_mz`, `r451_tr`,
  `r48_mail`, `r48_admin`, `r491_view`, `r50_pgame`, `r58_campnpc`,
  `ui_navigation`). Final correction checks additionally passed `r44_fr`
  (993), `r48_mail` (237), `r45_eu` (958), `r45_ui` (305), `r451_cu` (78),
  `r57_craft` (305), `r451_tr`, `r58_campnpc`, `r44_qb` (150).
- Focused implementation checks also passed `r44_ts`, `r44_pp`, `r52_graph`,
  `r53_live`, `r45_st`, `r491_anim`, `r46_id`, `r57_details`, `r451_nq`,
  `r48_sell`, `r57_qsys`, `r58_rep`, `r46_rp`, `r33_c5`, `r35_e`, `r35_t`,
  `r451_kf`, `r50_hotbar`, `r451_mc`.
- `check_fresh_server.py`: PASS. `ui_theme/build.py --check`: PASS.
  `r28_design/validate.py --game`: **0 errors, 17 existing warnings**.
  Disposable headless boot: PASS (90 seconds). `git diff --check`: PASS.
- `check_lua.sh` on all 81 changed Lua files: Lua 5.1 parsing passes;
  sweeps 1–4 pass. Sweep 5 retains **63 identical pre-existing hits**, in
  vendored `minetest.*` calls and historical fixture `io.popen`/`os.exit`.
  An exact baseline comparison against `31918c97` found **zero new hits**.
  These unrelated files/calls were not rewritten to hide the lint result.
- Independent source reviews crossed the implementation lanes: inventory
  reviewed services; services reviewed crafting and parent service/input
  plumbing; crafting reviewed inventory/mail/map and the padding helper
  against the engine parser. Findings were fixed and rechecked. Parent
  inspected every capture and integrated the fixes.

## User GUI review and remaining limitations

Desktop and web GUI acceptance is still pending. In particular, exercise:

- Navigation with Admin Mail and Creative together; resize/reopen, GUI scaling
  and HiDPI. WQHD padding uses the information available at form construction;
  reopening after resizing recomputes it, without polling.
- Drag/shift-click with maximum bags, the last scrolled rows, hotbar A/B and
  special slot backgrounds; fourth dual-furnace output after reopening.
- Enchant selection, upgrade quantities and an active queue; animation should
  advance without frequent full-window refreshes.
- Buy/Sell/Trade-in/Repair tab switching, quantities, all-item repair prices,
  scrolling after purchase and closing/reopening a service.
- Quest/story icons, reward choice, completion and long descriptions; map
  layers, zoom, pan, active quest selection and returning to inventory.
- Mail compose/discard/send, attachments and admin permissions.

Known presentation edges remain at the extra stress size **1035×696 with
GUI 1.5**: the explanatory text in **To the admin** can spill into the right
column; several narrow auxiliary crafting captions (**Kinds**, **Open**,
**Back to recipe**) clip. Primary action captions were corrected; these
remaining cases are recorded for the user's review after the requested two
passes. At GUI 1 the inspected versions of these views fit. Long quest titles
also truncate in the list, with the full title/content in the detail area.

The Shipwright building/annex and large-claim recovery scalability remain the
separately recorded backlog topics. No fundamental design question blocks this
implementation; final appearance and the remaining stress-size edges are for
the user's next GUI review.

