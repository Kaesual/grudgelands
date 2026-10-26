# Atlas 03 dialog review

**Merged into main on 2026-10-25 (`e17c731d`, with the tab hover correction
and the review fixes) and released as 0.61.1 (compatible, no saved state, no
reset). Not pushed; its GUI points are items 97–106 of the
[joint GUI test](round60-plan.md#gui-checklist-rounds-57-58-59-60-61-62-the-ui-and-0611),
its remaining limits in the
[BACKLOG](../../BACKLOG.md#ui-dialogs-carry-overs).** The sections below
record the lane's state at their time.

2026-10-25. The user approved implementation of the refreshed views **18–34**
(the archive remains reference only), followed by a typography and scaling
audit of every current game window. This is a compatible presentation change,
with no saved-state or gameplay changes. The focus includes
vendors and quest givers, while preserving the existing mechanisms. They also
reported oversized purchase icons in 0.60.1. Keep the `ui-tab-hover` worktree;
its separate hover correction is commit `0727925c`.

## Review artifact

Private, offline browser bundle:
`~/projects/grudgelands-orchestration/ui-atlas03-dialogreview-2026-10-25/Grudgelands-UI-Atlas-03-Dialogreview.html`.
Editable sources, asset provenance, source notes and screenshots are alongside
it. The original Atlas 03 remains unchanged in `ui-mockup-2026-10-24-v3`.
The new comparison covers main `c3861491` / 0.60.1. Views outside 18–34 are
explicitly archived, not refreshed representations of the current client.

Every reviewed view has a collapsible comparison outside the game mockup:
proposed presentation, retained mechanics, implementation cautions and source
owners. The scenario controls are review tools, not new player settings.

## Proposals to evaluate

- **Vendor:** compact two-column cards with small icons, readable item names
  and prices, and an explicit direct Buy button. Long catalogues scroll within
  the offer pane. Keep one existing purchase operation per click, every offer,
  the vendor-specific shelf, race discount, exact stack tooltips, and the
  existing sell/lot/remainder rules. No cart, quantity selector or confirmation
  step. Ordinary money shops and reputation-only camp shops remain distinct.
- **Quest giver:** narrower categorized list beside prose, objectives and
  rewards; actions stay below, chosen reward details remain readable. Use
  actual quest text and the current giver/turn-in logic. Completion text is
  shown before turn-in; there is no added completion screen. A styled list
  needs an adapter to the existing selection route and Close focus behavior.
- **Other dialogs:** retain the stronger Atlas layouts while correcting
  mismatches: repair durability and total cost; primary-profession versus
  additional Alchemy rules; mount predecessor/level/owned states; complete
  Claim Stone instructions; mail deletion with attachments; quickbar item use
  and closure; Welcome dismissal. Creation stays one page, and withdrawal
  keeps three coin fields in one row.

The General shelf uses all 14 current base offers; the T1 mockup explicitly
shows a four-offer excerpt, not a capacity change. Highcourt quest text and
reward formulas use repository data. Player inventories/progress, mail,
repair/sale prices and lift floors are examples. Some icons/tints approximate
runtime composition. These limits are documented in the artifact's README
and review notes; the browser is not an economy or persistence simulator.

## Constraints and acceptance

No change to native slots, drag/shift-click, saved state, ids, capacities,
validation, travel ownership, mail attachment handling or profession rules.
Keep current animation strips and send cadence; no new progress timers.
Preparation retains its existing percentage and static bar. Repair percentages
are existing durability snapshots, not countdowns.

Browser checks: **52 states across 17 views**, no script errors, broken images
or detected horizontal content overflow; **9 interaction assertions pass**.
Screenshots cover each view, vendor/quest variants, and key windows at
1035×696 and 1920×1080. Images were inspected, including compact vendor offers,
reputation stock, quest choices, multiple quests, trainers and Housing Steward.
Browser fit scales text with the canvas; use 100% to assess typography. Native
Luanti small-window font behavior, input/focus and desktop/web acceptance still
need implementation-time checks. No Luanti changes or personal installation
were made for this review.

Implementation is authorized in the retained `ui-tab-hover` worktree.
The existing shared UI helpers should remain the rendering foundation; the
service mods keep their current mechanics and authoritative data.

## Implementation and visual acceptance

- Use the shared presentation helpers; retain service-owned sessions, fields,
  action validation, native inventories and update cadence.
- Correct source labels to show each zone's own level band; do not change
  plant placement. Balance crafting list/detail type and tier status.
- Allocate Map & Quests approximately half the width to each side.
- Capture every window family in a disposable actual client at 1035×696,
  1600×900 and 2560×1440, GUI scale 1. Inspect all images.
- Complete the first implementation before the visual correction passes;
  at most two correction passes, then the user's GUI acceptance.
- Keep screenshots and a coverage/iteration log with the capture artifact.
  Run the affected fixtures, Lua checks, fresh-server audit, independent
  review and the full fixture suite once on the final implementation.
- Keep the worktree. Do not merge, push or install into the user's client.

## Implementation review, 2026-10-25

Implemented on `ui-tab-hover`, compatible. The shared UI module adds only
presentation helpers for service headers and wrapping read-only prose. Service
owners retain their sessions and validation; no saved keys, formspec ids,
inventory lists/capacities or existing public APIs change. No globalstep,
per-tick work, new countdown or faster form resend was added. Vendor cards add
presentation elements to their existing bounded catalogue; scrolling is client
side. Zone-label placement remains a single startup pass.

- **Trade and services:** two-column vendor cards with small icons, item
  names, prices and direct Buy actions; smaller reputation-shop icons; repair
  durability and totals; Crown previews; common service headers for trainers,
  innkeepers, waystones, mining lifts and the Housing Steward. Every tier,
  destination, restriction and transaction route remains the owner's.
- **Quests:** categorized native list beside conversation/objectives and a
  separate reward panel. Chosen enchanted reward details still head the text;
  native text scrolling and item tooltips remain available. Accept/Complete
  and Close keep their field routes and safe initial focus.
- **Other windows:** balanced mailbox reading/list widths and subject-first
  list rows, full sender/date in the selected letter, existing attachment-loss
  confirmation with wrapping text; smaller admin-mail text and shorter compose
  actions; one-page creation, two-column Welcome, compact quickbar and the
  three coin fields in one row.
- **Existing UI audit:** crafting details match list typography; tier status
  is more legible; gather sources show zone bands instead of plant placement
  filters. Map/quest columns use half the body width each. Compact zone labels
  enter the existing 2× zoom when selected from an overview; manual 1× remains
  possible. Tabs omit decorative icons only when their captions need the room.
  Claim fuel instructions and Sound controls no longer collide at small size.

### Visual passes

Initial implementation was frozen before captures; then exactly **two** visual
correction passes were made. Initial coverage: 67 views at each of 1035×696,
1600×900 and 2560×1440 (201 actual-client frames), all inspected. The first pass
fixed vendor backgrounds that did not follow their scroll parent, reward-panel
height, housing/Welcome text fit, mail-list width, and compact legacy labels.
The second fixed the mail deletion warning, admin compose captions, narrow tab
icons and the crowded zone view. The already identified Crown empty-state
position was corrected in this second pass as well.

Final coverage adds admin compose and attachment deletion (69 views per
resolution), plus a bright snow scene at the small size. Original PNGs, exact
formspec strings, manifests and engine logs are retained with the offline
inspection gallery. Extra small-window captures cover chosen quest rewards,
a running crafting queue, the empty Crown list and selected GUI-scale-1.5 views.

Independent read-only code review found no correctness/mechanism blockers after
fixes. It specifically checked focus, guild/Alchemy rules, mail input and
confirmation routes, quest choices, tab mappings, travel and map zoom.

### Practical limits and user acceptance

The browser's CSS layout is approximated with native formspec widgets; there
is no browser-style automatic layout or variable row height. Long quest and
reward texts keep native client scrolling. The manually selected 1× Zones
overview can still overlap; 2× is the readable entry view. Native font settings
remain authoritative: WQHD at GUI scale 1 keeps the client's pixel font size
while widgets grow. No global font rewriting was introduced.

The extra 1035×696 / GUI-scale-1.5 audit found remaining clipping/overlap in
mail tabs, admin preview labels and mailbox footer labels; Welcome needs more
scrolling and some crafting buttons are tight. These are visible review items,
not a claim that every font/GUI setting now fits. The two authorized visual
correction passes are exhausted; no third redesign was started. WQHD's native
pixel fonts still look small relative to the larger panels.

The bright scene follows the dark scene in the same temporary player session.
It intentionally exposes retained page state (for example Admin Mail compose
and the manually reset 1× Zones view); it is a contrast audit, not a reset-state
comparison. The dark series covers the default entry states at all three sizes.

Final inspection artifact:
`~/projects/grudgelands-orchestration/ui-modernization/dialogs-2026-10-25/final/index.html`.
It contains **289 inspected frames**: 69 at each requested resolution, 69
additional bright-scene frames, three transaction/queue/empty-state examples
and ten GUI-scale-1.5 examples. The parent folder retains initial/pass-one
snapshots, contact sheets, exact formspecs and logs; `atlas-comparisons/` has
17 browser/client pairs. The offline gallery's count, scene, resolution and
search filters were checked in a separate headless Firefox profile.

The native implementation deliberately simplifies the browser study: service
windows use one service header rather than duplicating the inventory header;
quest selection retains the native categorized text list; narrative and reward
text use scrollable native text areas; vendor windows retain their existing
transaction context instead of adding an inventory strip. No additional item
inspection mode or new workflow was introduced.

The desktop Flatpak client was rendered in isolated test worlds. This is not
a web-build execution claim; the user's desktop/web acceptance remains open.
Inspect vendor hover/purchase scrolling, quest reward selection, mail with
attachments, and personal font/GUI settings. No merge, push or personal Luanti
installation is part of this work; keep the worktree for the user's review.

### Verification

- Final targeted fixtures: `ui_navigation`, `r44_mq`, `r57_qsys`,
  `r57_details`, `r48_mail`, `r50_pgame`, `r44_qb`, `r58_lift`: **8 passed**.
  Earlier affected checks also passed: `r451_mc`, `r451_sc`, `r45_ui`,
  `r502_home`. Geometry/text expectations were updated to the new rendering;
  transaction assertions remain. New checks cover actual zone bands and
  entering/leaving the 2× Zones view through existing field routes.
- `check_fresh_server.py`: PASS. `r28_design/validate.py --game`:
  **0 errors**, six existing Rift quest/spawn warnings.
- Every changed Lua file parses as Lua 5.1. `check_lua.sh` sweeps pass on
  changed production files, the capture probe and the other changed fixtures.
  Five CLI fixtures retain pre-existing sweep-5 findings: `r27_quest_item_names`
  and `r57_qsys/quest_test.lua` use `io.popen` for fixture directory discovery;
  `r29_b` and `r451_nq` use `os.exit`; `r35_f` uses both. This patch changes
  their rendering assertions only; runtime mods have no such addition.
  All five execute successfully under LuaJIT.
- Python compilation, shell syntax and `git diff --check`: PASS.
  All capture boots completed without server errors. Client logs contain
  only the expected shutdown disconnect (`fidelity capture complete`), no
  invalid-formspec warnings. All worlds and client profiles were isolated;
  engine runs used `LC_ALL=C LANG=C` and the shared Lua queue.
- The full suite was run **once**, `JOBS=4` with five reserved slots (one
  fixture runs two seeds). It reported **266 passed, 10 failed**; each failure
  was traced to an old layout/text extraction assertion. Updated fixtures:
  `r25_interfaces`, `r27_quest_item_names`, `r28_a6_ui`, `r29_b`, `r35_f`,
  `r451_nq`, `r451_tr`, `r48_admin`, `r57_craft`, `r58_campnpc`. All ten
  subsequently passed targeted reruns; no runtime changes were needed.
  The final result covers **all 276 fixtures**. A second independent review
  checked these adaptations, retaining transaction/state assertions and the
  quest-item-name checks across the newly separated text panes.


## Pre-merge review fixes — 2026-10-25

The user's approved follow-up to Opus's review of `a849d18f` is compatible:
no saved-state, meta, item/list, capacity or field-id changes. The vendor
remembers its offer scroll position in the existing ephemeral session for
both CHG and VAL events, clamps it to the current shelf, and resets it on
mode/tab changes. Scroll-only events send no replacement form. Its native
scrollbar thumb now represents the visible share of the catalogue.

The user reaffirmed **single-line zone names and bands**. The existing
startup placement still nudges labels in both axes; 1× uses smaller type
(0.65), 2× and above use 0.85. Geometry and drawing share those metrics.
The 2026-10-13 choice and original collision measurements are restored in
`world_map.md` and explicitly distinguished from the current layout.
Mail's prose calls now restore the owning form's 0.85 textarea font scale;
other callers retain the previous default 1.0 restoration. Read-only prose
and editable field names are unchanged.

Validation: `r48_sell` (including repeated lower-row buys, CHG/VAL, malformed
values, shrinking stock, shelf/mode changes and reopening), `r44_mq`,
`r48_mail`, `r48_admin`, `r56_small`, `r57_vendormat`, `r58_campnpc`,
`r58_rep` and `ui_navigation`: **9 passed**. The map fixture's assertions now
measure one line; its edge-clamp sample was moved to the actual edge for the
shorter box. Changed Lua files pass the Lua 5.1 parser and sweeps 1–5;
`check_fresh_server.py` and `git diff --check` pass. Independent Sol review
of the bounded runtime/test delta: **no findings**. The full suite was not
repeated for this narrow delta; the coordinator owns the final merge gates.

Four actual desktop-client captures at 1035×696 (GUI 1), inspected directly:
Zones at 1×/2×, General merchant, and T1 merchant. Artifacts:
`~/projects/grudgelands-orchestration/ui-modernization/dialog-review-fixes-2026-10-25/1035x696/`.
The isolated capture boot completed without server/invalid-formspec errors.
At seed 12345 the startup diagnostic reports 0 overlapping zone-label pairs
and 2 over a region name at 1920×1080; at 1035×696, 9 and 3. These are
estimated label-box diagnostics, not a guarantee of collision-free text.
The small 1× overview remains dense; zoom 2× is the readable detailed view.
No personal Luanti data or web client was opened, and no merge/push was done.
