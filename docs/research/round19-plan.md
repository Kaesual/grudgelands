# Round 19 — Atlas navigation and interface fixes

Date: 2026-09-23. **Planning only; awaiting explicit user Go.**
Inspected baseline: `7ff76555` on main (Round 18 locally delivered).
Round 18 remote push remains blocked by automatic approval review pending renewed
confirmation; this plan does not claim remote delivery or authorize a workaround.

## Authority and boundaries

Latest user feedback in this conversation owns this proposed contract. The user
requests a new fix round and explicitly prohibits implementation before Go.
This file preserves the proposed implementation and routing across compaction;
it does not amend living decided mechanics until the round is approved.

Root: native GPT-6 Astra orchestrator. Native GPT-5.6 Sol for bounded UI/HUD work;
Astra for the atlas interaction and its independent review. No provider CLI,
Claude task, client fork, required client mod or new engine feature.
Fresh development worlds; no migrations or legacy readers. Preserve current
same-version persistence and explicitly saved user preferences.

Read AGENTS.md, docs/process/wp-workflow.md, agent-model-policy.md and
luanti-lua.md before implementation. Unexpected major complexity pauses only
that lane for discussion. This round adds no hotbar pages, quests, game balance,
new map markers, fog of war, waypoints, dynamic torch light or guard healing.

## A — Whole-world atlas with zoom and scrolling

**Owner: Astra.** Files: mods/PLAYER/grug_map/{atlas,page}.lua and related map
rendering/media tooling; targeted map fixtures. Other lanes do not edit these.

- Replace regional-view selection with a single whole-world atlas. Keep current
  world bounds, artwork style and registered marker providers.
- Every actual Map tab entry starts at full overview, zoom 1x and origin scroll.
  Closing still returns to Character so a later Map click is an explicit entry.
  No player-meta zoom/scroll persistence. During the current open session,
  marker refresh, tooltip/detail clicks and home-status changes preserve view.
- Use the available page area. Give the map viewport the world's 9:8 aspect
  ratio; adapt page dimensions and compact control bands so the 1x image fills
  that viewport without distortion, crop or a large unused band. Audit the
  existing mixture of legacy wrapper units and real-coordinate content: merely
  retaining the current 9:8 image ratio does not remove unused wrapper space.
  Navigation,
  +/- controls, marker detail and Return Home stay outside the clipped canvas.
- Proposed zoom stops: **1x, 2x, 4x**. +/- operate on these stops. Preserve the
  viewport's world center on zoom and clamp at edges; 1x always shows everything.
  No cursor-centered zoom, zoom animation, drag-to-pan or mousewheel-to-zoom.
- At zoom >1 use horizontal and vertical native scrollbars to reach every point
  of the whole map. No regional cutouts remain. Scrollbar gutters keep stable
  geometry; at 1x they can be disabled rather than changing canvas dimensions.
- All existing markers (including any boss/NPC/player marker provided by the
  current catalog) retain their current screen/UI size at every zoom. Only
  positions follow the scaled map. Map and markers share the clipped scrolling
  content; clipped markers must not leave clickable hitboxes over controls.
- Keep live player/party movement, headings, tooltips/click details, quest state,
  faction visibility and home behavior. Existing marker authorization remains
  authoritative. No close-marker clustering/overlap handling in this round.
- Use one adequately resolved full atlas texture, derived from authored map
  geometry by existing offline tooling if necessary. No runtime terrain render,
  world generation, dynamic tile cache or image-generation service is needed.
- Critical integration trap: sfinv.set_page calls on_leave/on_enter even for the
  same page. In-page redraws must not accidentally reset zoom. Use the existing
  refresh API without page transitions where appropriate; reset only real entry.
- Native scroll movement should remain client-side. Record changed positions
  for later live rebuilds, without rebuilding the complete form for every scroll
  event. Separate the render-change signature from scrollbar starting values;
  otherwise a scroll update alone triggers the existing 0.5-second form rebuild.
  Do not replace the rendered-state signature with a freshly computed unsent
  marker state while handling scroll, which could swallow real marker changes. Clamp/validate received values. Keep the existing throttled live updates
  only while the map is open; do not add a broad inventory polling loop.

Acceptance: overview fits; all corners reachable at all zooms; fixed-size marker
and hitbox geometry; positions/heading correct while scrolling; live refresh
preserves scroll; close/reenter resets; Return Home and tooltip details work.
Escalate if native nested scrolling and periodic form updates cannot coexist
reliably without a substantial alternative UI architecture.

## B — Character, Talents and Skills clarity

**Owner: Sol.** Files: grug_inventory/pages.lua, grug_classes/talents_ui.lua,
grug_skills/page.lua and bounded UI fixtures.

- Remove Character's entire "Pool and armor details" section. Keep concise
  usable totals: HP, mana/rage, armor rating and same-level reduction, money,
  and add effective Crit/Dodge values. No duplicated Armor summary.
- Move general formulas/explanations to Help, with wrapping and plain labels.
  Keep raw/cap detail in Help or concise tooltips if useful; do not recreate the
  removed equation-heavy section under another name. No stat formula changes.
- Talents contains class/tree selection, point/rank state, descriptions and
  respec controls, not Crit/Armor/Dodge statistics.
- First click on an available talent purchases **one rank**. Continue to show
  descriptions on hover; current class/tree, prerequisites, points and max rank
  are revalidated by the authoritative purchase API. Repeated deliberate clicks
  may buy further ranks. No additional purchase confirmation; existing respec
  confirmation and costs stay unchanged.
- Replace select-then-click-again instructions and branch; retain useful selected
  highlighting/last-purchased description without requiring a preselection click.
- Skills instruction: **"Drop skills to remove them. Drag them back from here."**
  Short and visibly placed above or next to the catalog. Existing one-copy rule,
  entitlement, recovery and purchased mounts remain unchanged.
- Confirmed cause of reported error: grug_skills/page.lua concatenates an
  unescaped literal semicolon in "never the unlock; recover..." into textarea.
  The engine reads a sixth field and rejects it. Escape all assembled visible
  text and verify the actual serialized element, not only text presence in Lua.
- Do a bounded check of text elements touched by this lane for the same escaping
  error. No broad unrelated formspec rewrite.

Acceptance: Skills hint displays with no invalid-textarea log; actual skill drag
recovery remains; Character has concise totals; Talents has no combat stats and
buys one allowed rank on first click, zero on denied/stale/forged requests;
respec confirmation unchanged. Check layouts at normal and smaller window sizes.

## C — Party default, buff placement and Sprint status

**Owner: Sol.** Files: grug_parties preference/UI/HUD fallback, grug_core
hud_layout/status/movement only as needed, grug_abilities/scout.lua.

- Missing/unset party color preference defaults to **by_class** consistently in
  accessor, dropdown and HUD. Explicit all_green remains respected. No migration
  or overwrite of existing explicit preference; class palette unchanged.
- Proposed simple placement: move buffs/debuffs to **top center**, with consistent
  edge padding. Native minimap stays top right; party/quest HUDs stay vertically
  centered left/right; the top-left chat area remains free. Avoid a dependency
  on the client's chosen minimap size.
  Keep the existing status cap and throttle; wrap long lines if needed without
  a general HUD drag/layout editor. Check the status block against the party HUD
  and transient center notices on common window sizes, including a full list
  of statuses. This is a fixed layout proposal, not an all-resolutions collision
  solver; escalate rather than build a general solver.
- Scout Sprint appears as **Sprint (+50% Speed)** with remaining duration for
  its existing 10-second effect. No change to cost, cooldown or movement math.
  A same-duration display-only status is sufficient; it must never own/clear
  the movement effect, and reads can suppress it if that effect is absent.
  HUD is a reflection of the movement effect, not a second speed modifier.
  Reuse authoritative lifecycle/expiry where possible; remove on expiry/death/
  disconnect and explicit effect removal, with no extra independent per-frame
  polling system. Do not expand this into a universal effect-system rewrite.

Acceptance: fresh preference gives class colors, explicit green survives
reconnect; buff list avoids minimap; Sprint has one entry with correct lifetime
and no extra speed/lingering status after death or expiry.

## D — Dragon overhead health-bar placement

**Owner: Sol, queued after C (same reviewer-independent implementation lane may
own both).** Files: grug_core/tag_carrier.lua and dragon presentation metadata
only where required; compact attachment geometry fixture.

- Inspect current engine attachment units/parent scale and actual dragon
  selection/collision geometry before choosing an offset. The report concerns
  excessive height and apparent small size; do not assume model bounds are the
  visible head height.
- Place the injured dragon bar near its visible upper body/head, at a readable
  dragon-appropriate size. Prefer a small explicit presentation override for
  the two dragon models if generic bounds cannot describe them accurately.
- Preserve current injured-only visibility, HP fraction, distance/hysteresis,
  observer filtering, settings and entity cleanup. Ordinary mobs/guards must
  retain their current positioning unless a verified general unit bug requires
  correcting their conversion too.
- Keep perspective sizing. No screen-space constant-size boss bar, new global
  boss HUD, distance-dependent scaling system or per-bone animation tracker.

Acceptance: both dragons' damaged bars sit close to the visible model and are
readable at combat distance; rat/humanoid/guard bars remain correct; full HP,
unload/reload and removal leave no floating stale sprite.

## Routing and sequencing

After explicit Go:

1. Freeze approved refinements here and fold decided rules into living docs.
2. Run A/Astra, B/Sol, C/Sol in parallel using isolated worktrees. Root handles
   shared documentation, interface coordination and integration. With four
   available native slots this means three implementers plus root.
3. Queue D/Sol on C's lane or an available slot; keep shared tag/HUD ownership
   explicit. Native agents only; no workaround through CLI.
4. Independent Astra reviews A's geometry/refresh and D's attachment boundary;
   independent Sol reviews B/C authority, lifecycle and UI output. Reviewers must
   not have authored their reviewed scope. A bounded final visual/layout and
   living-doc drift pass checks the integrated candidate.
5. Correct verified findings, focus re-review on High/Critical corrections,
   freeze candidate, run bounded final gates, then merge/sync for user playtest.
   Remote push is a separate currently blocked permission step; do not claim it
   succeeded or bypass automatic approval review.

## Validation budget and delivery

Read luanti-lua.md "Interpreter and test strategy" before scheduling runtime.
Use plain Lua 5.1 parser, SETGLOBAL inventory and all five sweeps for changed
Lua, explicitly including tools. LuaJIT owns targeted development checks.
On frozen final bytes run one compact PUC-5.1 process and the same fixture once
under LuaJIT with byte-identical canonical output. No intermediate PUC runtime,
full-world generation, seed fleet or PERF campaign. Reuse accepted unrelated
Round 18 evidence; do not rerun it for reassurance.

Fixtures focus on actual formspec field parsing/escaping, first-click purchase,
map projection/scroll/session state, preferences, Sprint lifecycle and attachment
conversion. A server-only harness cannot certify client layout or scrolling;
GUI acceptance remains explicitly user-run. If a bounded headless integration
check adds necessary evidence, run it in an isolated disposable world without
starting map generation, not against the user's world.

Deliver a concise completion receipt, independent reports, exact gate results,
updated living docs/status and a short fresh-world GUI checklist. No migration
or personal world edits. No implementation has started at this planning stage.

## Planning evidence (read-only)

- `r19_map_preflight`, native Sol: actual atlas/source and native scroll-container
  APIs; nesting/clipping, scrollbar CHG/VAL events, sfinv entry behavior and
  half-second live-refresh trap. No code edits or tests.
- `r19_hud_preflight`, native Sol: party preference fallbacks, status anchor,
  actual dragon boxes/eye heights and engine attachment inheritance, Sprint
  movement lifetime. No code edits or tests.
- Root Astra: verified raw semicolon in Skills hint against the engine textarea
  parser; inspected Character/Talents layout and first-click purchase branch.
  Selected top-center buffs to avoid both minimap and top-left chat without
  client-minimap-size probing. All three zoom stops and this placement remain
  proposed implementation choices until user Go.
