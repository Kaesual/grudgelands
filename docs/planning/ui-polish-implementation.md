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
Containers/stations: upper slots on inventory columns with the same panel as
inventory/hotbar (user follow-up, 2026-10-26), four to six
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
- Core `frame` and `input_background` build presentation fragments. The
  initial window-dependent padding helper was removed after GUI feedback
  (see the playtest correction below). Station forms accept
  an optional fifth visible-row count. Existing callers keep their defaults.

No new globalstep, ABM, LBM, per-tick pass or periodic formspec send. Window
information is read only while building an already requested form. Native
client fitting controls geometry, without server-side window-dependent padding.
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
  and HiDPI. Initial opening, tab switches and resizing should use the same
  native fitting, without polling or size caps based on window reports.
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


## Playtest correction — 2026-10-26

The user found first-open/tab-switch size jumps, an excessive WQHD size cap,
Sort still in Money, and button/menu styling unlike the intended flat design.
The user's clarification takes precedence over the older browser CSS outlines.

- Removed the server-window-dependent padding helper and every caller. Native
  fitting now applies before and after window information arrives and when
  resizing, without any additional formspec send or timer.
- Moved Sort to a dedicated full-inventory heading; eight visible rows and
  the aligned right-column bottom remain. Sort behavior/cooldown is unchanged.
- Action backgrounds have no perimeter outline. Normal, hover, keyboard focus,
  selected and pressed fills remain distinguishable; selected text is gold.
- Help, Talents and race choices use flat side-menu selection and a left
  marker. Local horizontal navigation uses active underlines. Native button
  labels stay centered; this is an approximation of the browser's left-aligned
  menu text, without a separate click/label mechanism.

The earlier screenshot series and correction counts describe the initial
delivery. This additional correction is explicitly requested by the user's
subsequent playtest. Classification remains compatible: no saved-state, list
capacity, field routes, permission checks or refresh cadence changes.

Correction verification: 20 targeted fixtures pass (`ui_navigation`, `r44_fr`,
`r44_qb`, `r44_ch`, `r44_ts`, `r52_graph`, `r53_live`, `r45_ui`, `r45_eu`,
`r451_cu`, `r48_mail`, `r48_admin`, `r451_tr`, `r58_campnpc`, `r451_mz`,
`r44_mq`, `r491_view`, `r35_f`, `r35_m`, `r25_interfaces`). Old button-style
assertions were updated; the crafting action's vertical-spacing assertion
no longer assumes a stale 2.6-unit width. Lua 5.1 parsing and sweeps 1–4 pass;
sweep 5 reports only the existing `os.exit` in `r45_eu` (also present in
`28fa1aac`). Fresh-server audit, theme regeneration check and whitespace check
pass. Independent native-agent delta review passes, compatible.

Inspected 27 real-client shots (nine views at 1035×696, 1600×900 and
2560×1440), plus three corrected creation-menu captures and five bright-scene
shots at 1035×696 / GUI 1.5. The final gallery selects 32 current shots. Shared
inventory sizing headers agree across all captured inventory pages and
resolutions; regression tests also cover missing initial window reports,
subsequent tab switches, GUI scaling and density 2. Artifacts and exact forms:
`~/projects/grudgelands-orchestration/ui-playtest-fixes-2026-10-26/`.
The user authorized synchronizing this branch into local Luanti for playtest;
only game files are copied, no worlds and no merge into main.


## Typography and fidelity correction after the next playtest (2026-10-26)

The user's screenshots exposed an insufficient fidelity review: earlier
captures had primarily checked containment and routes, while small native
fonts and the old Party arrangement remained. This correction compares the
actual Revision 04 browser renders with native captures, including originals
at 100%, rather than treating small contact sheets as typography evidence.

- Main and mailbox tabs use 1.1× text; ordinary action/body text uses 1×
  instead of 0.8–0.85×. Section headings use 0.9× bold; reading text 1.05×.
- Party stacks current members, online players and invitations on the left,
  with status, action and statistics in a full-height right column. Empty
  states start at the top; native lists are transparent. The short PvP rules
  fit without a scrollbar at the inspected settings.
- Quest givers use an 18.8×12.2 frame, enlarged title/list text and reward
  icons. Full narrative, objectives, choice stats and selected reward tooltip
  remain in native scrollable read-only fields. The oversized inner reward
  panel is replaced by a separator.
- Mail tables use 1.15× text, increasing native row height. The list has more
  horizontal space and deliberately abbreviated subject/sender columns; full
  text remains in the reading pane. The To the admin introduction wraps within
  its column. Admin compose/editor fonts restore the owning form's scale.
- Existing `text_scale` fitting passes through scoped native font helpers for
  Party, Mail and quests, and through Help/Talent side menus. This prevents
  GUI 1.5 text from overrunning a form shrunk by the client. Checkboxes and
  dropdowns retain the client's font; Party uses the shorter Invitations label
  with an explanatory tooltip. Geometry and first-open sizing stay unchanged.

This is compatible: no saved-state, player-meta, inventory-capacity, formspec
identity, transaction or permission changes. Existing table event mappings,
party callbacks, quest choice validation and mail sessions remain. No new
polling, timers, globalsteps or refresh sends. The toolkit adds optional font
scales and `fonts(scale)`; existing callers keep working.

Native tables do not provide independent row padding; their height follows
font height plus four pixels. Consequently the browser's two-line mail cards
and generous row padding are still an approximation, not completed fidelity.
Long quest/reward text still scrolls. Font family, rasterization and some native
control fonts remain client-owned. Desktop rendering is checked here; web
interaction acceptance remains the user's.

Validation: 27 distinct targeted fixtures pass: `ui_navigation`, `r44_pp`,
`r31_p2`, `r31_pvp`, `r48_mail`, `r48_admin`, `r451_nq`,
`r27_quest_item_names`, `r29_q1`, `r30_p1`, `r57_qsys`, `r44_fr`, `r44_ch`,
`r45_ui`, `r45_eu`, `r491_view`, `r44_ts`, `r52_graph`, `r53_live`, `r44_qb`,
`r451_tr`, `r58_campnpc`, `r451_mz`, `r44_mq`, `r35_f`, `r35_m`,
`r25_interfaces`. Geometry assertions were updated without dropping behavioral
checks. New checks cover scoped font restoration. Lua 5.1 parsing and sweeps
1–4 pass; sweep 5 only reports the pre-existing standalone fixture `io.popen`
and `os.exit` uses. Runtime Lua files pass all sweeps. Fresh-server source audit,
theme asset check and whitespace check pass. Independent delta review: PASS.
The full fixture suite was not repeated for this correction.

The final gallery contains 67 selected native screenshots: fourteen views at
1035×696, 1600×900 and 2560×1440, the same fourteen in a bright scene at small
GUI 1.5, and eleven neighboring views at small GUI 1. Two correction passes
follow the first targeted render, plus an isolated final mail-hint check.
Exact forms, raw run logs, contact sheets and the browser comparison are at
`~/projects/grudgelands-orchestration/ui-readability-2026-10-26/`.
The worktree is retained; no merge into main and no push.


## Character model size adjustment (2026-10-26)

The user's next playtest requested approximately 40% more model height, near
the height of the four equipment slots. The native model viewport grows from
3.0×4.7 to 4.2×6.58, centered horizontally between the equipment columns and
vertically on their midpoint. Rotation, mesh/texture selection, slot geometry
and input routes are unchanged. This is a compatible presentation-only change.
Window size caps remain discussion only; no sizing or refresh logic changes.

The existing `r44_ch` fixture passes all 343 checks, with its old model-width
bound updated to the real equipment-column boundary. Both changed Lua files
pass the Lua 5.1 parser and all checker sweeps. Native Character captures at
1035×696, 1600×900 and 2560×1440 are stored in
`~/projects/grudgelands-orchestration/ui-character-model-2026-10-26/`.


## Full-HD ceiling, selectable rows and container panels — 2026-10-26

The user approved the custom-row variant for quest givers, Map quests and
Mailbox letters, plus a maximum scale equivalent to the current Full-HD
rendering of each window and matching upper panels on containers/stations.
This follow-up supersedes the earlier decision to leave upper slots unframed.

Implementation is compatible: transient presentation state and field routing
only; no saved inventory, quest/mail data, capacities or world changes. Shared
rows retain real status/story/provenance icons, unread state, attachment counts,
selection, scroll position and full-text tooltips. Mail announcements share the
letter renderer. Existing action validation, reward choice, read/attachment/
delete behavior and Map tracking/abandon remain in their owners. Map scroll
holds use its existing quiet period; no new polling or redraw cadence.

The ceiling is evaluated on existing builds using the reported viewport and
native padding, preserving the client's GUI and density settings. Below Full
HD fitting is unchanged. Initial/stale reports are deliberately not polled:
a cached initial inventory can open uncapped until the next existing rebuild.
There is no hard live-resize guarantee. Native Tab/Shift-Tab + Enter operates
row buttons; the old table/textlist arrow-selection behavior is replaced.

Upper panels use the existing station_box/area_box helper, covering both chests,
shelves and all furnace workspaces without changing slot geometry or animation.
The existing Claim Stone belongings helper also gets its consistent panel.

Verification:

- One complete shared-queue run (`JOBS=7`, eight slots including the two-seed
  fixture): 282 fixtures passed; `r26_status_icons` had two stale expectations
  from earlier UI changes (Effects navigation styling and Party coordinates).
  Its unchanged runtime owners were checked, the assertions were refreshed to
  test selected styling and member content, and its 412 checks then passed.
  No full-suite repeat. Final Map typography correction also passed `r44_mq`.
- New `ui_rows` covers selection/header rejection, transient scrolling,
  clamping, initial reveal, UTF-8 and scrollbar thumb sizing. New
  `ui_window_cap` passes 261 checks across resolutions, GUI1/1.5, density1/2,
  absent reports and rebuilds. `ui_navigation`, `r48_mail`, `r451_nq`,
  `r44_mq` and all quest fixtures pass; Map's 693 checks include pending
  quest/party updates while dragging. Mail covers no resend on scroll,
  selection preserving position, page reset and invalid indices.
- All 28 changed runtime Lua files pass parser and all sweeps. Changed
  fixture files parse and pass sweeps1–4; sweep5 flags only their existing
  `io.popen`/`os.exit` test harness calls. New fixtures and capture probe pass
  all sweeps. Fresh-server and theme audits pass; design validation reports
  zero errors and 17 existing content warnings.
- Isolated native clients at 1035×696, 1920×1080 and 2560×1440, plus bright
  GUI1.5 captures. Shared-queue runs never exceed eight Lua processes. Native
  boots have no server errors or formspec parse errors; the client shutdown
  message `fidelity capture complete` is intentional. Contact sheets and
  original-size long-title captures were inspected; Full-HD/WQHD centered
  comparisons keep the same physical pixels to verify the ceiling.
- Independent read-only review passed after fixing Map's drag quiet period,
  explicit subtitle truncation and documentation. No new globalstep or timer;
  row construction/payload grows with the existing rendered page size.

Artifacts: `/home/jan/projects/grudgelands-orchestration/ui-rows-cap-2026-10-26/`
contains 40 published screenshots, contact sheets, comparisons, formspecs and
test logs (earlier Full-HD GUI1.5 captures are archived separately). Final
Desktop/Web interactive acceptance remains with the user, especially keyboard
row navigation, resizing and first inventory opening. Worktree retained;
no main merge or push.

### Character sub-tabs — 2026-10-27

User-approved follow-up: Stats, Effects and Achievements now divide the mode
panel equally, with 0.2-unit outer margins and 0.1-unit gaps. Geometry derives
from the panel width; labels, font sizes and field routes remain unchanged.
Compatible presentation-only change. Runtime Lua checks and the existing
`r44_ch` / `r26_status_icons` fixtures pass.
