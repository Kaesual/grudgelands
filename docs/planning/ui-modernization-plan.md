# UI modernization — proposed round

Drafted 2026-10-24. **Planning only; no game implementation has started.**
The user expanded the brief from inventory pages to the game's other forms,
including privileged pages, containers and NPC services, and asked to plan
these together before building. The earlier inspector proposal is withdrawn.

Base: `8f41fb533bf4b00c62149dac16953ba79631bb8c`. Branch:
`ui-modernization`, worktree `.claude/worktrees/ui-modernization/`.
The release number remains unassigned: the quest coordinator owns Round 59
and its following quest rounds. This branch does not update main's status,
release metadata or installed game. Only the user pushes.

The user's positively received visual study is
`~/projects/grudgelands-orchestration/ui-mockup-2026-10-24/Grudgelands-UI-Entwurf-01.html`
(SHA256 `34585e00a0c58e45642f90f5c1299c0db8977479ab5109b0641ad0e8fcff1868`).
It establishes appearance, not inventory capacity, example stats, gameplay
or a requirement to reproduce its inspector. Keep that original artifact.

The [surface census](ui-modernization-surfaces.md) owns the source inventory
and reachability notes. [Open visual decisions](../../TODO-ui-modernization.md)
are proposals to discuss with the user, not approved game design.

## 1. Lanes and waves

These are proposed delivery/review units, **not permission to launch them**.
The next milestone is agreement on scope and representative browser layouts.
Implementation follows the user's go and the [round workflow](../process/round-workflow.md).

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

### Proposals for the next visual discussion

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
  including long labels and enlarged GUI scale. The TODO records the existing
  fixed-window ruling and header/dispatch constraints; any size change needs
  an explicit decision. Do not silently hide pages.
- Continue using registered sfinv pages, allowed navigation and lifecycle
  hooks. Keep inventory suspension during creation and map-window handoff.
  Validate navigation against current privileges/visibility; losing a
  privilege must leave the restricted page safely. Preserve the page order
  and contextual state unless a different design is approved.
- Preserve four bag slots, actual belt/equipment slots, continuous eight-column
  bag flow, native list indices, full/short/station views and hotbars A/B.
  The prototype's simplified capacities are not authoritative. Establish
  native geometry before polishing; keep seven full-view rows and two
  short-view rows unless the user explicitly approves another trade-off.
- Preserve detached-list ownership, listring order, trash semantics and
  server inventory guards. Do not replace item lists with clickable images.
  Adapt the Scout quiver's old opaque count-cover assumption explicitly; the
  TODO proposes the documented adjacent-label fallback for visual approval.

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

## 4. Lane deliverables

Each implementation brief expands its assigned rows in the
[surface census](ui-modernization-surfaces.md) into exact producers, current
states and meaningful tests. No row can disappear merely because it is
privileged, infrequent or a nested fragment.

THEME establishes a small demonstrator in real Luanti after visual approval:
one inventory page, one chest and one dialog. The user's desktop/web check
then verifies whether the browser direction translates well before every
page is migrated. This is a proposed early milestone, not permission to sync
or interrupt the user's current round.

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

- **Planning now.** No Lua, textures, live game, quest data or installed-game
  edits as part of this planning pass. Browser follow-ups are the next proposed
  review artifact; the original mockup stays intact.
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
      text; map filters, quest panel, markers, resize and return to inventory.
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
