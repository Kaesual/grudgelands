# UI modernization — implementation plan

Drafted 2026-10-24. **Merged into main on 2026-10-25 (`83f1afd3`) and released as 0.60.1 (compatible, no saved state, no reset); every pass independently reviewed (MERGE). The user picked the seven theme PNGs and the ten tab icons and accepted the quiver total beside the slot and the compact header (2026-10-25). Not pushed; the desktop/web GUI acceptance is part of the [joint GUI test](round60-plan.md#gui-checklist-rounds-57-58-59-60-61-the-ui-and-0611).** The receipts below record the isolated branch's state at their time.
The user expanded the brief from inventory pages to the game's other forms,
including privileged pages, containers and NPC services, and asked to plan
these together before building. The earlier inspector proposal is withdrawn.

Planning base: `8f41fb533bf4b00c62149dac16953ba79631bb8c`; implementation
baseline: main `0ab3aea0`. Branch:
`ui-modernization`, worktree `.claude/worktrees/ui-modernization/`.
Current integration base: main `a78518b7` (0.60.0), merged into this branch
with merge commit `f61b8c76`; the integration receipt is below.
The release is 0.60.1, written by the documentation lane UI-D after the
merge. Only the user pushes.

The approved browser reference is Atlas 03:
`~/projects/grudgelands-orchestration/ui-mockup-2026-10-24-v3/Grudgelands-UI-Atlas-03.html`
(SHA256 `6e67dece7960a739a163c23d70829a413ceea86ca7d239903ae3236985bb3912`).
The retained original visual study is
`~/projects/grudgelands-orchestration/ui-mockup-2026-10-24/Grudgelands-UI-Entwurf-01.html`
(SHA256 `34585e00a0c58e45642f90f5c1299c0db8977479ab5109b0641ad0e8fcff1868`).
It establishes appearance, not inventory capacity, example stats, gameplay
or a requirement to reproduce its inspector. Keep that original artifact.

The [surface census](ui-modernization-surfaces.md) owns the source inventory
and reachability notes. [Approved presentation rules](../design/inventory_equipment.md#ui-modernization-approved-direction)
record the visual decisions; detailed implementation choices are reversible defaults.

## 1. Lanes and waves

These are authorized delivery/review units following the user's go on
2026-10-24 and the [round workflow](../process/round-workflow.md).
Keep all implementation and review in isolated UI worktrees.

| Wave | Lane | Outcome | Dependency |
|---|---|---|---|
| 0 | PLAN / VISUAL | Surface and state census; browser studies of the remaining window families; settled navigation and geometry | discuss this plan |
| 1 | THEME | Shared palette, alpha assets, panel/button/text roles, common frame and navigation contract | approved visual decisions |
| 2 | INVENTORY | Inventory, Character, Talents & Skills, Party & PvP and Help, including embedded subviews | THEME |
| 2 | CRAFT | Crafting, details, sources, favourites, operations and queue | THEME |
| 2 | PRIVILEGED | Admin Mail and all five Creative categories; maximum-tab layout | THEME; common navigation frozen |
| 3 | CONTAINERS | Chests, furnaces/workspaces, shelves, Claim Stone inventory views | THEME; common inventory geometry frozen |
| 3 | SERVICES | Traders, repairs, crown service, trainers, home/travel, guild lift and housing manager | THEME |
| 3 | QUESTS / MAP | Quest-giver conversations and Map & Quests, including evolving quest subviews | THEME; agreed current quest baseline |
| 4 | AUXILIARY | Player mail, creation/welcome, quickbar, withdrawal, text editors, reachable maintenance forms | THEME |
| 5 | REVIEW / D | Integrated review, regression checks, design/technical docs, eventual numbered release and GUI checklist | all surfaces accounted for; integration slot agreed |

The table does not require concurrent workers. Before any lane starts its
brief assigns exact files and shared-file ownership. Different lanes may
operate sequentially in the isolated branch; separately delegated lanes use
the workflow's own worktrees. Model routing follows the user's session
choice and the [model policy](../process/agent-model-policy.md).

The former effort estimate was for inventory pages. This broader scope needs
a new estimate after the visual/layout decisions: common styling is shared,
but long text, dense admin screens, live containers and forms with different
coordinate systems each need adaptation and regression checking. Do not
present the earlier estimate as a commitment for all game forms.

## 2. User rulings and proposed visual direction

### Confirmed

1. Modernize the inventory and all tabs in the browser study's visual direction.
2. Plan isolated work alongside the ongoing quest rounds.
3. Include restricted/privileged UI, especially Admin Mail and Creative;
   containers such as chests and furnaces; NPC dialogs such as quest givers
   and Riding Trainers. Plan the whole scope calmly before implementation.
4. **Omit the item inspector.** No inspection toggle, duplicate item picker,
   replacement slot controls or new item-selection mechanics.
5. Ask before introducing a complex interaction to support an optional
   feature: omitting the feature may be the better choice. The lasting
   working rule is in [AGENTS.md](../../AGENTS.md).
6. Prepare browser views for every reachable UI family before game changes
   (2026-10-24). This authorizes the visual study, not implementation or
   acceptance of its proposed navigation and window dimensions.
7. Preserve the existing UI performance optimizations, particularly animated
   progress images and the deliberate absence of live seconds counters.
   Restyling must not introduce repeated formspec sends to animate progress
   (user feedback, 2026-10-24).
8. Map & Quests should open directly into the larger map view, with the shared
   tab bar remaining visible. No intermediate page requiring an Open click.
   This is the requested presentation direction; exact geometry and the
   navigation adapter still need implementation design and GUI validation.

9. The presentation may rearrange, regroup and reorder existing controls to
   improve appearance or usability. Preserve the underlying functions and
   mechanisms; this is not a requirement to copy today's coordinates. The
   user will inspect the finished browser revision before implementation.
10. Character creation stays on one page. Put the achievement pager at the
    bottom, give Active Hotbar the same heading hierarchy as the other
    quickbar sections, and place Gold/Silver/Copper in one row.
11. Do not add live processing percentages. Preparing your arrival is the
    explicit exception because it already shows percentages; it needs no
    animated progress strip. Preserve existing non-processing figures and
    timing rules rather than interpreting this as removing all numeric data.
12. Use the actual talent trees, backgrounds and available appearance choices;
    keep the skills strip clear of the tree and inventory. Include profession
    area switching, privileged tabs and existing service controls.
13. Remove invented item descriptions, per-letter category icons and the
    redundant mining-effect-slot explanation. Ordinary sample play-state
    data is acceptable when identified as illustrative; it must not imply
    new item lore or mechanics. Native Server Admin identification remains.

14. Atlas 03 is accepted as the implementation direction (user, 2026-10-24).
    Start implementation in the UI worktree. Window sizes may be chosen for
    appearance and usability; keep the non-map inventory tabs the same size
    and Map & Quests larger. This supersedes the former fixed-size ruling.
15. Use two rows of tabs when needed, with all allowed pages visible.
    Reversible details may be decided by the coordinator. Fundamental
    changes wait for the user while independent work continues.
16. Keep the map's real native scrollbars and client-side scroll containers;
    the browser range inputs are only placeholders, not a replacement.

### Approved visual direction

- One visual family: dark translucent window surfaces, small rounded corners,
  restrained brass accents, clear text hierarchy and consistent controls.
  Start the study near 88% panel opacity; readability decides the final value.
- Different layouts for different tasks: a stable inventory frame, a compact
  container/station frame, a readable NPC/service frame, and a dense editor
  frame for mail and administration. Shared styling need not mean equal sizes.
- More opaque reading and input surfaces where needed; character creation
  retains its intentional opaque world cover. No new player settings system
  for theme, opacity or background selection.
- Native inventory slots, quantities, hover tooltips and drag/shift-click
  behavior remain. Round the surrounding panels and buttons; do not simulate
  slot input to obtain rounded cells. Keep existing semantic colors for
  rarity, factions, talent states and quest statuses recognizable.
- Match the visual hierarchy using engine fonts and real game art. No custom
  client, browser renderer, background blur, new NPC portrait system or new
  artwork pipeline is needed for this plan.
- Proposed scope boundary: all **reachable game-authored forms** in the census.
  HUD, chat rendering, pause/settings/connect menus and external realm/admin
  websites are separate surfaces, outside this forms round. No new windows
  for decorative furniture or proximity-only workstations.

## 3. Shared conventions and technical contract

**Expected upgrade classification: compatible.** Presentation and navigation
change; item ids, inventories, claims, quests, professions, money, mail and
queue persistence do not. No migration or map reset is expected. Each lane
still checks and reports its classification against its actual changes.

### Shared styling without a second UI system

The current inventory helpers already serve containers. The expanded scope
also includes creation and early-loaded/vendor mods. Proposed ownership:
small, stateless palette/frame/control helpers in `grug_core.ui`; inventory
layout and sfinv navigation remain with `grug_inventory`. Existing dependency
order is `default -> grug_sounds -> grug_core -> player mods`. A vendor mod
must not depend back on grug_core: existing runtime seams or an explicit
post-load adapter can use helpers when forms are built. THEME checks the
callers and load order before freezing this contract. No event bus, generic
widget hierarchy or parallel session framework is warranted.

This is a presentation toolkit: shared frame, panels, typography,
button roles, spacing and navigation rendering. Existing mods continue to own
their forms' data, field handlers, sessions, validation, update triggers and
animation timing. Helpers build deterministic formspec fragments from their
inputs; they do not schedule updates or send forms. In particular, existing
crafting/furnace progress helpers remain the timing owners even if their
textures and geometry change. The toolkit API is not frozen by the mockup.

The shared theme must cover default's formspec prepend and preserve
`grug_sounds.CLICK_STYLE`. Explicit form-local colors and backgrounds can
override the prepend (Creative is one example), so a prepend replacement
alone is not completion. `no_prepend[]` forms must apply their own complete
style, including click sounds and readable inventory/tooltips. Character
creation keeps its opaque cover and its existing submission gating.

Use reusable, small alpha PNGs and nine-slice backgrounds for windows and
buttons. Prefer reproducibly generated simple geometry; record media
provenance. Read the pinned engine's relevant formspec implementation before
freezing capabilities. Version 6 is the target for new layouts; older forms
must deliberately convert coordinates or retain an explicit legacy wrapper.
Do not mix real and legacy coordinates implicitly.

No global rewriting of completed formspec strings and no new wrapper around
`core.show_formspec` to inject appearance. Existing wrappers manage lifetimes
for node forms, housing and map windows; preserve their ordering and cleanup.
Vendored edits, if necessary, are minimal, marked `GRUG PATCH` and recorded
in [VENDOR.md](../../VENDOR.md). Prefer existing extension seams.

### Navigation and inventory

- The baseline has seven ordinary tabs, optional Admin Mail and five Creative
  tabs: up to **13** visible main pages. Resolve overflow in the visual phase,
  including long labels and enlarged GUI scale. The 2026-10-24 ruling supersedes the old fixed-window size: choose one
  appropriate non-map frame and a larger map frame. Do not hide pages.
- Continue using registered sfinv pages, allowed navigation and lifecycle
  hooks. Keep inventory suspension during creation and safe map-window handoff.
  Validate navigation against current privileges/visibility; losing a
  privilege must leave the restricted page safely. Preserve the page order
  and contextual state unless a different design is approved.
- Map & Quests uses a larger layout with the same visible navigation; another
  tab returns to that tab's normal layout. Both the map tab and Z enter the
  map directly. The implementation removes the Open-button fallback and
  retains [window.lua](../../mods/PLAYER/grug_map/window.lua)'s session and
  update ownership. The navigation adapter stops map sends on tab exit and
  validates current tab visibility. The deferred `back_home` reset leaves a
  subsequently selected tab intact; the existing `shown_form` backstop still
  prevents stale map updates from reopening another window. These boundaries
  have fixture coverage and are documented in the
  [presentation contract](../technical/ui-presentation.md).
  All non-map tabs use one common frame size under the new ruling.
- Preserve four bag slots, actual belt/equipment slots, continuous eight-column
  bag flow, native list indices, full/short/station views and hotbars A/B.
  The prototype's simplified capacities are not authoritative. Establish
  native geometry before polishing; keep seven full-view rows and two
  short-view rows unless the user explicitly approves another trade-off.
- Preserve detached-list ownership, listring order, trash semantics and
  server inventory guards. Do not replace item lists with clickable images.
  The approved adjacent total label replaces the Scout quiver's old opaque
  count cover while retaining its native inventory slot.

### Dialogs, editing and live updates

- Style the existing service and quest states: no changes to costs, rewards,
  prerequisites, unlocking, quest text, purchasing or confirmation semantics.
  Shared action roles distinguish primary, secondary, unavailable and
  destructive controls; do not add extra confirmations merely for the theme.
- Keep form names, field contracts, session identity, range/faction/ownership
  checks and inventory return paths. Closing, opening another form, reconnecting
  or removing the NPC/node must retain the existing cleanup behavior.
- Long quest text, mail, multi-page lists and search results must wrap/scroll
  within their actual available area. Empty, locked, full and error states
  count as layouts. Escape dynamic labels, field defaults and rich text in
  the appropriate format; never bake body text into textures.
- Preserve typed drafts, current selections, scrolling and search focus on
  refresh. Retain the [inventory focus workaround](../technical/upstream-workarounds.md#6-set_focus-without-force-never-applies-to-the-player-inventory)
  and focus sinks that prevent unintended Enter actions.
- Existing furnace progress, crafting and mailbox updates keep their cadence.
  Appearance introduces no polling, globalstep or redraw on a pure scrollbar
  event. Hover/pressed styles are client-side. Avoid expensive full-catalog
  scans or replicated large textures when a window opens.

### Hover feasibility

The pinned Luanti API (`reference_projects/luanti/doc/lua_api.md`, style
properties/states) supports hovered/pressed button colors and images,
including nine-slice images. These states render client-side and need no
formspec send. The custom tab buttons proposed here can use the same states;
the native `tabheader[]` exposes much less styling. Preserve the navigation
adapter's lifecycle/permission checks. Do not promise CSS transitions, layout
movement, arbitrary web fonts or per-slot border styling. Native lists keep
their own hover/tooltip/input behavior.

### Progress animation and update contract

Source-checked after the user's feedback on 2026-10-24:

- [Crafting UI](../../mods/PLAYER/grug_jobs/ui.lua) explicitly uses
  `animated_image[]`, with 64 fill frames and 32 full frames as a lag buffer.
  Reopening/rebuilding starts at the elapsed fraction. Job start, finish,
  cancellation and existing structural events can send; ordinary delivered
  items use live inventory updates. There is no per-second countdown resend.
- [Furnace progress](../../mods/PLAYER/grug_inventory/furnace_progress.lua)
  keeps fuel and cooking animations independent, preserves paused/end states
  and end-frame buffers, and starts at the current elapsed fraction.
  `changed()` ignores advancing animation start frames but detects actual
  state changes, a new fuel/item and large catch-up jumps. Both the plain
  furnace and [workspaces](../../mods/PLAYER/grug_jobs/workspaces.lua) use it.
  Their process ticks must not become per-tick formspec sends during restyling.
- [Character Effects](../../mods/PLAYER/grug_inventory/pages.lua) retains
  the deliberately coarse remaining-time text from
  [status icons](../../mods/CORE/grug_core/status_icons.lua): whole minutes,
  hours or “under 1 min left”. Its changed-text key and the Return home
  cooldown text trigger the existing updates, not a new seconds countdown.
- [Map window](../../mods/PLAYER/grug_map/window.lua) retains its send gap,
  pending-event coalescing, scrollbar quiet period, changed-party-marker
  detection and per-pass budgets. Shared tabs must not introduce idle refresh.

Keep these timing and dirty-state rules, including stable animation field
names and comparison behavior, when changing visuals. Do not replace them
with server-stepped fills, elapsed-time text or live percentages. Static job
duration information and existing counters elsewhere are a separate matter;
this is not a blanket removal of time information. Arrival preparation retains its existing percentage display, without an
animated progress strip. Browser examples never authorize additional live
values or resends elsewhere.

Before converting each surface, its lane records the current update triggers,
what animates in the client, and which list changes need no form resend.
After conversion, compare the same interaction/process scenario: forms built,
forms sent, bytes and build cost. Decoration must not add periodic builds or
sends. Explain changed payload sizes from the new frame rather than silently
treating more bytes as more frequent updates. Reuse the existing probes and
fixtures; do not add a production telemetry or refresh subsystem for this.

## 4. Lane deliverables

Each implementation brief expands its assigned rows in the
[surface census](ui-modernization-surfaces.md) into exact producers, current
states and meaningful tests. No row can disappear merely because it is
privileged, infrequent or a nested fragment.

The approved Atlas03 direction authorizes implementation of all surfaces in
the isolated worktrees. Shared theme primitives establish the frame used by
inventory pages, containers and dialogs. Do not sync or interrupt the user's
current round. Final desktop/web visual acceptance remains the user's.

INVENTORY and CRAFT fit actual data and capacities rather than copy example
values from the HTML. PRIVILEGED tests all entitlement combinations and
revocation while open. CONTAINERS preserves actual lists, live updates,
locking and Claim Stone recovery behavior. SERVICES keeps each service's
transaction and refusal paths. QUESTS / MAP uses the latest agreed quest
implementation and changes presentation only. AUXILIARY closes the remaining
reachable forms, including text entry and rare maintenance tools.

REVIEW reconciles the census with final code and current main. D promotes
approved rules into [inventory_equipment.md](../design/inventory_equipment.md)
and affected topic owners, reconciling the prior
[UI/crafting rulings](ui-crafting-rework-plan.md), and updates technical seams,
media/vendor records, BACKLOG and the design tour where needed. It records remaining
GUI acceptance honestly. Release/status work waits for the integration slot;
it must not overwrite the concurrent quest coordinator's work.

## 5. Rules and boundaries

- **Implementation authorized.** Lua, generated theme textures and tests may
  change in the isolated UI worktrees. Do not modify quest content, main or
  the installed game. Preserve the browser artifacts.
- Treat the census as evidence at its base commit, not a permanent assumption
  about the still-evolving game. Repeat the delta census before integration.
- If a visual flourish requires new input mechanics, stop that feature path
  and ask whether to simplify or omit it. Continue unrelated authorized work.
- Do not rehabilitate removed vendor features just because dormant formspec
  strings remain. Any unrelated bug found during the audit is recorded
  separately; this plan is not authorization for gameplay/security redesign.
- No push. Main merges and Luanti sync are coordinated later with the user.

## 6. Verification and GUI checklist

Planning validation: source-check the census and dependencies, check touched
links, independently review this package. No game test can establish visual
acceptance of a document or browser study.

Implementation follows the [round gates](../process/round-workflow.md#3-gates):
plain Lua 5.1 syntax/global/sweep checks on changed Lua, relevant LuaJIT
fixtures during development, full fixture run at each lane's final report,
fresh-server check, one smoke boot, and upgrade checks when release metadata
changes. New navigation/event logic needs behavioral tests; decorative colors
do not need tests that merely copy their constants. Theme textures trigger
the web-data check where required. Worldgen fleets apply only as required by
the integration round; this theme adds no worldgen work.

Progress/update regression coverage includes the existing
[crafting fixture](../../tools/r45_ui/portable_test.lua) and
[furnace animation fixture](../../tools/r491_anim/portable_test.lua), plus the
current queue and map fixtures selected by their lanes. Check continuous
animation without extra sends, reopen at elapsed progress, paused/full output,
fuel/item transitions, lag/catch-up, cancellation/next job, and no refresh
after leaving the form. Preserve behavioral assertions when adapting expected
geometry. The new map navigation additionally exercises Z, all entitlements,
tab exit and a pending map update that must not reopen the map.

The workstation cap is eight Lua processes **across both coordinators**.
Agree available capacity before a test fleet; use the workflow's queue and
idle scheduling. No repeated full runs without a new reason.

The user's desktop **and web** GUI checklist includes:

- [ ] Ordinary player, mail_admin only, Creative only, both; all 13 pages
      reachable, selected state legible, live grants/revocations handled.
- [ ] Small window, larger GUI scale, long labels; text readable over bright,
      dark and busy world backgrounds; hover, pressed and keyboard focus visible.
- [ ] Full/empty bags, all four bags, belt, equipment, quiver and A/B; moving,
      shift-moving, splitting, scrolling, tooltips and item counts unchanged.
- [ ] Talents of all classes, graph/skill catalog scrolling and respec;
      party/member/leader/invite states and PvP; Character Effects/Achievements,
      cloak selection and housing status; every Help subpage including Sound.
- [ ] Craft search and Enter focus, favourites, details/sources, unavailable
      recipes, craft/enchant/upgrade operations, full queue and cancellation.
- [ ] Creative search, no results, page changes, item copies and trash;
      Admin Mail tickets, reply/broadcast composition and existing confirmations.
- [ ] Ordinary/locked chests with delayed open and their own lid/session state;
      shelves, idle/running/out-of-fuel furnaces,
      dual workspace; ownership/protection/range; simultaneous users;
      closing/replacing a form must not make a timer reopen it.
- [ ] Quest offer/progress/ready/completion, choice rewards and long story
      text; direct Map & Quests entry with persistent tabs, larger map layout,
      filters, quest panel, markers, resize and return to another tab.
- [ ] Vendor buy/sell/repair and guild trade-in/rank states; crown service;
      profession trainer, Riding Trainer and Shipwright with owned, locked
      and unaffordable rows; home binding, waystone travel and guild lift.
- [ ] Housing manager and Claim Stone draft/active/access/waypoints/belongings,
      pickup confirmation and notices; another player must not gain access.
- [ ] Mail read/write/report/attachments and To admin; preserve unfinished
      text on non-send actions, return attachments on close, no duplicate send.
- [ ] Creation and appearance choices, no writes before Create, opaque world
      cover; separate Preparing/ready/failure/retry window and reconnect during
      arrival; welcome links, quickbar, withdrawal, book/sign editing and the
      reachable maintenance dialogs. Escape/Enter follow existing behavior.
- [ ] Final census has a disposition for each row: styled and exercised, or
      confirmed unreachable; no silent exclusions. Review has no unresolved
      blockers. GUI acceptance is recorded separately from code completion.

## 7. Orchestration and integration

The main checkout was already receiving Round 59 merges at branch creation;
its status document still described Round 58. This plan does not reconcile
another coordinator's in-flight status. The existing Nether/depth TODOs do
not block a forms presentation round.

Known shared areas: quest NPC rendering and map quest panels, Help text,
crafting details, plus AGENTS.md and eventual release documents. Keep UI
changes localized to presentation. Before final review, bring the then-current
main into the UI branch, resolve conflicts there and repeat the affected
checks. The quest coordinator's new data and behavior must survive.

At the agreed integration slot, select a free round number, adopt the normal
numbered plan/lanes/fixture paths, update incoming links, and assign lane D.
If the change ships in one round, all reachable forms are completed together;
any staged release requires an explicit user decision about the temporary
mixed presentation. The unnumbered branch can remain isolated during several
quest rounds without claiming a release slot or GUI acceptance.

### Planning review receipt — 2026-10-24

Independent Opus review (`--model opus --effort xhigh`, read-only):
**MERGE AFTER FIXES**, three Medium and one Low documentation findings.
The coordinator checked and addressed them: chest-specific lifetime ownership,
explicitly overridden/dead builders, the existing frame-size/navigation
constraints, and the separate arrival-preparation form. The suggested chest
key-path coverage was refined after a caller search: the callback exists but
has no shipped trigger; the census records it without reviving it. Character
Effects/Achievements and Help's Sound fragment are also named explicitly.

Input/output hashes, full review, CLI metadata and correction notes are in
`~/projects/grudgelands-orchestration/ui-modernization/plan-review-2026-10-24/`.
Touched document links and whitespace were checked. This receipt covers the
planning artifact only; visual decisions, implementation and GUI acceptance
remain open. No game files or release declarations changed.

### Browser Atlas 02 — 2026-10-24

The user requested browser views for every UI family. The local, standalone
artifact is
`~/projects/grudgelands-orchestration/ui-mockup-2026-10-24-v2/Grudgelands-UI-Atlas-02.html`.
It contains **38 views and 116 sample states** covering the census, including
privileged tabs, containers, services, map entry/window, mail, creation,
arrival preparation and maintenance forms. The original study is unchanged.
Editable HTML/CSS/JS, media provenance, previews and validation records sit
beside the standalone file; its `manifest.json` records the package hashes.

Review aids select permissions, two-row/paged navigation, world background,
window opacity and zoom. They are not proposed player settings. Long Help
texts come from the frozen game source; other text and values are illustrative.
No item inspector, inventory simulation, server connection or game changes.

The proposed header and navigation enlarge the frame. At the study's mapping
of 60 pixels per real form unit, the existing frame is approximately 810 × 820;
Firefox measures 810 × 926 with paged tabs and 810 × 969 with two rows and all
13 tabs. These are alternatives for discussion, **not approved geometry**.
The full/short/station lists retain seven/two/three rows, with independent
storage samples and an adjacent quiver-total label in Character → Scout.

Firefox checked every sample state for script errors, missing images and
unintended panel overflow, plus navigation, draft isolation, reward selection,
queue actions and other local interactions. All passed. Captures include
1440 × 1050, 1280 × 800, 1920 × 1080 and a narrow 390 × 844 review viewport;
the latter tests the browser atlas, not Luanti mobile support.
This is a presentation artifact only: no upgrade declaration is needed.
The expected future game classification remains compatible. Visual approval,
implementation and Luanti desktop/web acceptance remain open.

Independent read-only review initially requested fixes; the focused re-review
returned **MERGE** after the navigation, geometry and sample-state corrections.
Minor visible follow-ups were checked separately in Firefox. Review inputs,
outputs, CLI receipts and correction notes are archived in
`~/projects/grudgelands-orchestration/ui-modernization/browser-review-2026-10-24/`.
These reviews assess the browser artifact, not a future Luanti implementation.

### Browser Atlas 03 — 2026-10-24

The user's functional-fidelity feedback is incorporated in
`~/projects/grudgelands-orchestration/ui-mockup-2026-10-24-v3/Grudgelands-UI-Atlas-03.html`.
The previous two studies remain preserved. Atlas 03 covers 38 families and
123 sample states, including a crafting output-overflow case and an operation
refusal away from the forge. The user explicitly permits rearrangement for
appearance/usability; basic functions and mechanisms must survive.

This revision uses all eight real talent graphs (109 nodes), their original
backgrounds, the six races' actual appearance options/textures and the real
achievement catalogue. Creation is one page; achievements page at the bottom;
Active Hotbar has a section heading; currency fields share a row. Invented
item-description prose and per-letter category icons are removed. Genuine
Server Admin identification, attachment counts and the mailbox balance stay.

The source audit also restores profession switches, ingredient alternatives,
the Search focus target, recipe/operation details, output overflow, the job
strip and separate waiting queue; Scout ranged/melee slots and equipment
labels; Claim Stone status; copyable About URLs; party/PvP state wording,
real guild stock, waystone availability and claim travel, and the map's
separate Quest HUD control. Primary crafting actions remain outside the
scrolling details. Map opens directly with shared tabs. Non-map inventory
pages share the same proposed frame height; the extra per-tab talent height
from an intermediate revision was removed.

Crafting and furnaces use the original progress sprite strips without live
processing percentages. Arrival retains its existing percentage and ETA
presentation, with a static proportional bar. Browser animation loops are
illustrative; they do not replace the production start-frame/buffer/dirty
rules above. The source-audit record beside the artifact names the owners.

As before, play-state values, prices, letter/quest contents and the fixed map
capture are examples. The atlas does not simulate inventory transfers, world
state or every server-side action. Review controls, including switching the
class shown by the talent examples, are outside the proposed game UI. The
proposed geometry and final visual acceptance still await user feedback.
No game changes or upgrade declaration; eventual UI-only work is expected
compatible. Desktop/web Luanti acceptance follows implementation, not this
browser review.

Validation: Firefox checked all 123 states for script errors, missing images
and unintended panel overflow. Fourteen interaction groups, 22 targeted
review-closure checks and nine final crafting checks passed; all eight trees
and all six races/five appearance categories were exercised. Captures cover
1440 × 1050, 1280 × 800, 1920 × 1080 and the browser-only 390 × 844 viewport.
A separate Effects check confirms the original coarse time presentation.
JavaScript syntax, original-media hashes, document links and whitespace were
checked. These results validate the browser study, not Luanti itself.

Independent read-only Opus review first returned **MERGE AFTER FIXES**. The
focused review of a frozen JS/CSS/doc snapshot returned **MERGE**, with a small
remaining craftable-count/filter correction explicitly allowed before the
receipt. That correction, the related quantity/source-detail presentation
fixes and two source-backed coarse Effects time labels were applied and
checked locally. The frozen reviewed snapshot and exact follow-up notes,
CLI result receipts and outputs are archived in
`~/projects/grudgelands-orchestration/ui-modernization/atlas03-review-2026-10-24/`.
The artifact's `manifest.json` identifies the final package; source, media
provenance, screenshots and browser reports are preserved beside it.

### Implementation start — 2026-10-24

The user approved Atlas 03 and the implementation start. The UI worktree has
merged main `0ab3aea0` before code changes (including Round 59 and the current
Round 60 changes). No main checkout files were changed. Initial order: shared
presentation helpers and navigation; then inventory, crafting/containers and
services in bounded ownership packages; map, mail, creation and remaining
forms; integrated independent review and checks. No numbered release is
claimed. All UI-only packages are **compatible**: no saved-state or worldgen
change. Pending GUI acceptance does not block isolated implementation.

### Implementation scope receipt — 2026-10-24

The [surface census](ui-modernization-surfaces.md) has these dispositions:

| Census families | Implementation |
|---|---|
| Inventory, Character, Effects/Achievements, Talents/Skills, Party/PvP, Help/Sound/About | Shared frame/navigation, rounded areas; Character equipment/model and details rearranged; actual trees/skills retained; real-coordinate Help including the Sound controls |
| Crafting, recipe/source details, enchants/upgrades, queue/overflow | Common controls/panels, balanced profession row, bounded queue notes; original algorithms and animation strips |
| Admin Mail; all five Creative categories | Common frame; owner refusal/audit paths retained; native catalog lists/search/pager/trash |
| Ordinary/locked chest, default furnace, bookshelf, vessels shelf | Existing per-viewer station builders inherit the new shared area/view theme; ownership, delayed opening/lids and live update owners unchanged |
| Profession furnace and dual workspace | Explicit input/fuel/output layout with original animated fire/arrow; shared station view |
| Claim Stone draft/active/access/waypoints/belongings/confirmation | Themed native tab buttons dispatch existing tab IDs; native lists and guards retained |
| Quest giver; Map & Quests | Shared panels and direct map navigation; native scrollbars, source text/rewards and pending-send cancellation |
| Trader/guild trade-in and stock, repairs, crown, profession/riding/ship trainers | Shared frames/headings and service rows; existing prices/conditions/transactions |
| Innkeeper, waystone, guild lift, housing manager | Shared service/destination presentation and existing travel/ownership paths |
| Player mail/read/write/report/To admin | Internal themed tab buttons; existing drafts, attachments, confirmation and stale-submit behavior |
| Character creation and arrival; welcome | One-page creation with original preview/choices; opaque background, unchanged commit gating; static percentage bar at existing progress cadence |
| Quickbar and withdrawal | Active Hotbar heading; one denomination row; existing input/actions |
| Sign, book, mob spawner, texture editor | Native themed real-coordinate editors; field names, protection/focus/save owners retained |

The prototype's fabricated play-state data is not shipped. No quest content,
item descriptions, inventory inspector, new update timer or client dependency
is added. The separate [toolkit contract](../technical/ui-presentation.md)
records the shared seams. [Traffic measurements](../../tools/ui_theme/measurements.md)
compare the same scenarios at main `0ab3aea0` and the isolated UI branch.
Final code review, full fixture results, smoke boot and GUI acceptance are
recorded separately below; no release number or main merge is implied.

### Implementation verification — 2026-10-24

The integrated branch remains based on main `0ab3aea0`; its UI changes are
**compatible**. Main, installed game files and release metadata are untouched.

- All **274 portable fixture packages** are covered: the full run passed 246;
  the remaining 28 passed after loading the real shared helpers in standalone
  fixtures and updating obsolete presentation assertions. The integrated
  targeted rerun passed all 28. Transaction, permission, session, focus,
  inventory and animation checks remain in place. After the code-review
  corrections, 19 affected fixture packages passed again on `3fff1faf`.
- All 45 changed production Lua files passed the plain-5.1 parser and every
  applicable sweep. All 102 changed Lua files, fixtures included, passed the
  parser and sweeps 1–4. The game-sandbox sweep reports 18 host-only
  `io.popen`/`os.exit` calls in existing fixtures; all 18 source lines were
  verified unchanged against `0ab3aea0`. No gate was weakened or bypassed.
- The fresh-server check, generated theme `--check`, web-data export
  `--check`, changed Markdown link targets/anchors and whitespace checks passed.
- One disposable headless engine boot passed (90 seconds, seed
  `5099651730322752340`, private port 39473). This is not a GUI test.
- The [traffic comparison](../../tools/ui_theme/measurements.md) retains
  furnace and crafting send counts; the existing map fixture retains idle
  and party update counts. Payload growth is reported separately. No client
  rendering or production-server timing claim is made.

Independent reviews and their follow-up findings are recorded below. Desktop/web visual and input acceptance remains open under the
checklist above; no numbered release, installation, main merge or push is
claimed by this receipt.

### Code review corrections — 2026-10-24

Both independent production reviews returned **MERGE AFTER FIXES**. Their
shared finding was the mixed-coordinate Sound island, now replaced with real
controls and an integration check against the actual Help and ambience
builders. The foundation review also found that the shared X button submitted
editable values. It now forwards a quit-only event through the existing owners
so cleanup survives without a dropdown action. A real Party-page test also
exposed its existing unconditional rebuild on Escape; the page now treats
both close routes as a quiet exit.

Smaller corrections cover the book header, creation-panel bounds, suspended
map exit, duplicate map close control, mail tab recognition, relative equipment
font, profession label widths, unavailable craft-button pointer states and
wrapped queue-note color. Obsolete API parameters/comments and documentation
were reconciled. The separate fixture-adaptation review returned **MERGE**;
its non-zero offset and refusal-hook coverage suggestions were included.

The chosen shared frame and larger map body stay as approved. Actual text
readability at small window sizes, selected-row contrast and desktop/web
rendering remain GUI checklist items. The focused state works with the pinned
engine independently of the form's version-6 declaration; no client change is
required. Theme-byte reproducibility depends on Pillow/zlib as documented.
Behavioral geometry, roles and native input are covered by the existing and
added fixtures.

The corrected production snapshot `3fff1faf` received **MERGE** in the focused
independent re-review. Both Medium findings are closed; no blocker remains.
The remaining legacy-default warning and close/draft comments were clarified
without behavior changes. The unavailable craft button retains its keyboard
focus indication; its pointer states stay muted.

Review prompts, frozen diffs/source hashes, complete CLI results and exit
receipts, corrections and validation logs are archived at
`~/projects/grudgelands-orchestration/ui-modernization/implementation-review-2026-10-24/`.
The code is ready for the user's desktop/web GUI acceptance in the isolated
worktree. Numbered release integration, installation and pushing remain open.

### Main 0.60.0 integration handoff — 2026-10-25

The user approved the quest coordinator's request to prepare this branch
before the next quest round. Merge `f61b8c76` has parents `07ce189e` (UI) and
`a78518b7` (main, 0.60.0); no rebase. The coordinator owns the new independent
review and any later merge into main. This receipt does not claim that review
or GUI acceptance. No release number was assigned to the UI change.

**Scope relative to main:**

- `grug_core/ui.lua`, its join prepend and seven generated textures supply
  translucent surfaces, rounded nine-slice panels and native button states.
  `grug_inventory/{ui,navigation,pages,help}.lua` supplies the stable normal
  frame and permission-aware navigation; `grug_classes`, `grug_skills`,
  `grug_achievements`, `grug_parties`, `grug_pvp` and `grug_ambience` adapt
  their existing contents. Actual talent graphs and skills remain.
- `grug_jobs` retains professions, recipe details, operations and queues;
  its workspaces and the shared inventory views theme containers, with
  `default/nodes.lua` for sign editing and the existing furnace/shelf paths.
  `grug_housing/stone_form.lua` themes Claim Stone tabs and confirmations.
- `grug_map/{page,window}.lua` opens the larger map directly with shared tabs;
  `grug_quests/npc.lua` themes the existing quest conversation. Mail/admin,
  all five Creative categories, traders, repair, trainers, home/waystones,
  guild lift, housing manager, creation/arrival, quickbar, withdrawal,
  books/signs and reachable mob maintenance editors share the theme.
- Desktop and web use the same server formspecs, native fonts, slots,
  scrollbars and input. No client fork, browser dependency or item inspector.
  The HUD and engine menus are outside this change.

**Persistence and interfaces:** UI-only classification is **compatible**;
no saved-state schema, player-meta key, item/quest ID, inventory list or
capacity changes. Main's 0.60.0 map-reset declaration remains unchanged and
belongs to the quest round. `grug_quests` logic/data APIs, `grug_map/quest_box.lua`,
HUD APIs and mail transactions/persistence are unchanged relative to main.
Top-level form names and sfinv page IDs remain; internal event fields change:
`grug_ui_tab_N`/`grug_ui_close`, `grug_mail_tab_N`, `stone_tab_N` replace the
rendered tabheaders, with existing legacy tab input routes still handled.
The obsolete `grug_map_open` control/handler and rendered `grug_map_close`
button are removed; the shared close button owns that presentation.

Presentation API changes are intentional: new `grug_core.ui` helpers and
`grug_inventory.navigation`/`navigation_target`, the refusal-only
`on_navigation_denied` page hook, `UI.header_h`/`window_h`; wrappers around
sfinv navigation/build hooks; `sfinv.make_formspec` no longer accepts its
unused custom-size argument; `grug_inventory.area_box` no longer takes a
color override and `BOX_COLOR` is removed. `grug_ambience.settings_formspec`
now emits real coordinates. In-repo consumers were adapted. New page content
must explicitly use real coordinates; panels must stay outside scroll
containers (see the presentation contract).

**Performance:** no new globalstep, timer, periodic pass or per-tick work.
There is one added join hook for the common prepend, and bounded navigation
work on form construction/input. Craft/furnace progress retains the original
client-animated strips and resend triggers; arrival alone retains its existing
percentage/ETA with a static bar. Prior same-scenario measurements (not new
0.60.0 benchmarks) are unchanged: Basic crafting 4499 to 5446 raw form bytes;
furnace 17432 to 18086 bytes/minute with six sends in both versions; Basic
form construction median 64.222 to 74.616 microseconds in the LuaJIT stand-in
probe. Client rendering remains unmeasured.

**Merge resolution:** all six overlapping files merged automatically; no
manual conflict resolution or production-code correction was needed.
`AGENTS.md` and `README.md` retain main's release/status/content changes,
including 0.60.0, alongside the UI rules/design-tour text. The four fixtures
retain main's quest rework, drop-capacity stand-in and the one Alchemy lesson
exception alongside the UI helper setup and geometry assertions. Stable
patch ID `cc369689c8267645e392f205f47c599ebe8d4328` is identical for
`0ab3aea0..07ce189e` and `a78518b7..f61b8c76`: the UI patch survived intact.

The five clean helper worktrees `ui-inventory`, `ui-services`,
`ui-craft-containers`, `ui-review`, `ui-review-final` were removed after each
HEAD was verified as an ancestor of the merged UI branch. Their implementation
branches remain. Only main and ui-modernization worktrees remain registered.

**Integration checks on `f61b8c76`:**

- `python3 tools/check_fresh_server.py`: PASS.
- `python3 tools/r28_design/validate.py --game`: 0 errors, 6 warnings
  (catalogue/quest warnings; no UI data edits).
- Targeted fixtures: **12 passed, 0 failed** — `r28_b4_quests`, `r28_q0`,
  `r30_p1`, `r45_st`, `ui_navigation`, `r44_mq`, `r48_admin`, `r48_mail`,
  `r491_anim`, `r57_craft`, `r60_bandquests`, `r60_capitals`. These cover the
  four overlaps, shared navigation/map/mail, unchanged progress and queues,
  and the newly integrated quest content.
- Full `tools/run_fixtures.sh`, run once after integration: **276 passed,
  0 failed**. No follow-up code or fixture fix was necessary.
- The four overlapping Lua fixtures pass the plain-5.1 parser and sweeps
  1–4. Sweep 5 flags three existing host-only `io.popen` source lines in
  `r28_b4_quests`, `r28_q0`, `r45_st`, verified unchanged against main.
  No sandbox rule was relaxed. Production Lua is unchanged from the prior
  reviewed UI implementation plus main.
- One `LC_ALL=C tools/luanti_headless.sh 90` boot: PASS, port 35800, seed
  `5099651730322752340`; no ERROR/ModError. The launcher staged everything
  in a disposable `/tmp/grudgelands-headless.*` tree and did not use the
  user's Luanti folder.
- The targeted fixtures, full suite and boot use
  `~/projects/grudgelands-orchestration/r45/lua_run.sh`, with four, five
  and one slots respectively. The full suite uses `JOBS=4`; its fifth slot
  covers `r30_p3` spawning two Lua processes. The workstation cap stays eight.
- Whitespace and this plan's local link targets: PASS.

Receipts, overlap diff, patch-ID comparison and final branch identity are
archived at
`~/projects/grudgelands-orchestration/ui-modernization/main-integration-2026-10-25/`.
The handoff commit after `f61b8c76` changes only this plan; the archive's
`completion.json` records its exact hash. Main stays at `a78518b7`, with no
merge into main, sync/install or push performed by this task.

**Remaining acceptance:** the coordinator's integrated review, then the
desktop/web checklist in section 6. Pay particular attention to readability
at small resolutions/high GUI scale, all 13 permission-dependent tabs,
native inventory/shift-click/scrolling, focus and Escape/X behavior, draft and
attachment handling, long Round 59/60 story text/choice rewards, map zoom and
tab switching without a delayed reopen, and craft/furnace progress. Existing
fixtures and the boot cannot establish visual quality. No known implementation
blocker is being deferred; release bookkeeping and installation stay with the
coordinator.

## Fidelity pass — 2026-10-25

The user approved the coordinator's follow-up: move the real forms toward
Atlas 03, within Luanti's controls, and fix obvious clipping after looking
at the real client. This is a **compatible, UI-only** follow-up to integrated
baseline `0d03734a`. It does not assign a release or merge into main. The
coordinator owns independent review of this delta; the user's texture/look
pick and interactive desktop/web acceptance remain pending.

The panel fill is now 94/255 alpha with a light border; the normal button
fill is 9/255, with gold selected and client hover/focus/pressed states.
The outer frame retains 231/255 alpha for bright-scene contrast. Navigation
uses small original line icons, text, a gold active underline and compact
captions, with full-title tooltips. Its header shows an emblem, faction,
character name/level and slim close mark. The header is 1.5 units for one
row, plus 0.54 per extra row; enlarged GUI fonts on narrow windows use four
tabs per row, never hide a page. All non-map pages share the resulting size.
Map reserves that header inside its whole-window budget, fixing overflow.

Scoped native fonts distinguish titles, section labels, achievement names
and muted descriptions. Dense fixed-layout summaries compensate enlarged
GUI fonts when Luanti shrinks the form. Crafting keeps five professions and
native checkbox routes, with short filter captions and full tooltips at
high GUI scale. Talent graphs/art, node actions and skill drag/drop remain;
smaller icon insets and separated hints improve their rendering.

No state/meta/list/capacity/item/quest ID, top-level form name or existing
field route changes. `grug_quests`, `quest_box`, HUD, mail and transactions
are untouched by this pass. Additive presentation seams are documented in
[the toolkit contract](../technical/ui-presentation.md). No new globalstep,
periodic work or resend trigger is added to the game. Animated craft/furnace
progress remains client-side. Additional icons/styles increase form bytes
at construction only; the capture receipt records same-scenario sizes.

The real-client loop uses `tools/ui_theme/capture.sh`, based on the existing
capture launchers, with an isolated staged game/world and private `/tmp`
client paths. Every engine process uses `LC_ALL=C LANG=C`; every run uses
the shared Lua queue. Before/after cover eight views (the requested seven
plus 13-tab privileged navigation), both dark stone/night and bright snow/day,
1035×696 and 1920×1080 at GUI 1, plus 1035×696 at GUI 1.5. These are desktop
client captures, not web-client execution. The probe uses real builders and
quest data with a disposable NPC position stand-in. The study's example
content is not reproduced as fabricated game data. Native HUD/chat remain
visible behind translucent forms. Contact sheets fit complete originals;
no screenshot painting or cropping.

Early setup attempts exposed a probe privilege/NPC-socket error and are
excluded. One intermediate GUI-1.5 client aborted with
`malloc(): unaligned tcache chunk detected`; its incomplete/black output is
excluded too. Global negative image-button padding from that iteration was
removed in favor of a two-pixel talent-only inset. This is not proof of the
crash's cause or an engine fix. Subsequent complete captures passed the
missing/blank-image check. A final local layout correction addresses the
13-tab header and Auto/Sort overlap at high GUI scale; translated tab-label
markup must not count toward visible width.

The private review package is
`~/projects/grudgelands-orchestration/ui-modernization/fidelity-2026-10-25/`:
`index.html`, eight `contact-sheets/*.png`, full-size before/after images,
Atlas originals, logs, hashes and the final completion receipt. Browser
CSS blur, letter spacing and custom font metrics are not emulated; native
fonts, alpha/nine-slice geometry and native state styling approximate them.
Native opaque text lists and scrollbars retain their engine appearance.

**Verification:** the full `tools/run_fixtures.sh` ran once through
`r45/lua_run.sh` with `JOBS=4` and five reserved slots: **270 passed, six
failed**. The six findings were checked at source: title helper expectations
(`r29_b`, `r58_lift`), shortened point-label expectations (`r53_live`), missing
real presentation helper loading (`r33_c3`, `r55_supporter`), and the generic
engine stand-in returning a table instead of absent window information
(`r57_details`). Only those expectations/stand-ins were corrected; mechanics
assertions remain. A final targeted run after those corrections and the local
header/Auto-Sort fix passed **28/28**, including all six failures and the four
main-integration overlaps:
`r25_interfaces`, `r28_a6_ui`, `r28_b4_quests`, `r28_q0`, `r29_b`, `r30_p1`,
`r33_c3`, `r35_c`, `r35_m`, `r44_ch`, `r44_fr`, `r44_mq`, `r44_pp`, `r44_ts`,
`r451_kf`, `r45_st`, `r45_ui`, `r48_admin`, `r48_mail`, `r491_anim`,
`r491_view`, `r52_graph`, `r53_live`, `r55_supporter`, `r57_craft`,
`r57_details`, `r58_lift`, `ui_navigation`. The full suite was not repeated;
its tested-source fingerprint and final correction diff are archived.

The final source passes `check_fresh_server.py`, design validation (0 errors,
6 existing content warnings), theme byte regeneration, shell syntax, Python
compilation and whitespace checks. Every changed Lua file, including the
probe, passes the plain-5.1 parser and sweeps 1–4. Production Lua passes all
sweeps; the combined host-fixture sweep 5 flags only the unchanged
`os.exit(1)` in `r29_b` (verified against `0d03734a`). No sandbox rule was
relaxed. Real-client capture boots provide engine-load coverage in disposable
worlds. The nil-player presentation default and invisible translation-markup
width regression also have explicit navigation-fixture checks.

**Acceptance focus:** the user chooses the regenerated texture look from
the contact sheets. Check readability/contrast in real snow, sand and dark
scenes; all permission-dependent tabs at enlarged GUI scales; native slot
and shift-click/drag behavior; long quest text/rewards; map zoom, scrolling
and tab return; live craft/furnace animation and focus/close behavior. The
smallest native controls remain constrained by client fonts and engine
widgets. No web-client execution or user's visual acceptance is claimed.

## Fidelity review fixes — 2026-10-25

The coordinator's independent review of `d6c7fe94` requested two corrections
(`ui-modernization/review-fidelity.md` in the private orchestration folder).
Both are addressed, **compatible and presentation-only**:

- Dense-text compensation uses the actual available-height / inventory-window-
  height ratio, capped at 1 and floored by the prior tested inverse real GUI
  scale. Density 2 / GUI 1 at 2560×1600 now retains about 0.99, instead of 0.5.
  Navigation fixtures use the engine's reported dimensions and retain factors
  1 at both existing GUI-1 capture sizes and 2/3 at 1035×696 / GUI 1.5.
- Zone-label placement and its small-window collision audit subtract the common
  navigation header from their reference map bodies. The map fixture checks
  both startup layouts against the actual body-height contract.

Checks: `ui_navigation`, `r44_mq`, `r57_details` **3/3 PASS**, through the shared
queue; plain-Lua-5.1 parser and all sweeps PASS for the four changed Lua files;
`check_fresh_server.py` PASS; whitespace PASS. No full-suite repeat was needed
for these two review fixes. One isolated real-client capture at 1035×696,
GUI 1, with the Zones layer enabled, and its headless boot passed. It used
`LC_ALL=C LANG=C`, disposable paths and two queued slots. Capture/check receipts
and the temporary one-map probe are archived under
`~/projects/grudgelands-orchestration/ui-modernization/fidelity-review-fixes-2026-10-25/`.

The map capture also records a remaining limit: at 1×, the small viewport
still has dense overlapping zone labels (73 overlapping pairs, 10 over baked
region names; reference 1920×1080: 3 pairs, 0 over names, seed
`5099651730322752340`). The corrected reference geometry does not establish
collision-free labels at every client size. The screenshot is evidence of
this limitation, not visual acceptance. The user's look pick and desktop/web
acceptance, and the coordinator's fix review, remain pending.

## Tab hover correction — 2026-10-25

Merged into main with the [dialog review](ui-dialog-review.md)'s work on
2026-10-25 (`e17c731d`) and released in 0.61.1 (compatible).

The user's post-merge screenshots exposed stretched hover corners, especially
on the full-width Admin Mail tab. On `ui-tab-hover`, based on main `1878c103`,
transparent navigation and close buttons retain the theme's six-pixel
nine-slice inset with zero net content padding. This is **compatible and
presentation-only**: textures, positions, routes, ids, state and update cadence
are unchanged. Native 1920×1080 / GUI 1 captures verify Talents hover, the wide
Admin Mail hover and pressed states, and close hover. Screenshots, the temporary
repro driver and logs are archived under
`~/projects/grudgelands-orchestration/ui-modernization/tab-hover-fix-2026-10-25/`.

Checks: `ui_navigation` and `r44_mq` **2/2 PASS**; the full queued fixture run
**276/276 PASS**; plain-Lua-5.1 parser and applicable sweeps, source audit,
whitespace and isolated client/engine capture PASS. Five fixture slots plus
two capture slots stayed within the shared limit. No personal client paths,
merge, install or push; desktop/web acceptance remains the user's.
