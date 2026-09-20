# Round 12 — planning checkpoint

Date: 2026-09-20. Baseline: `8d0d393e`.
Status: **independently reviewed, ready for the user's round Go**.
No gameplay, asset or runtime-installation changes have started.
The user accepted the proposed lanes and expanded farming, Skills and item art.
This record supersedes the earlier corn-only showcase and wand-only art scope.

## Binding user changes

- Farming is a full seventeen-family iteration: recognizable shapes and
  suitable growth/harvest mechanics, informed by pinned VoxeLibre, Lord of the
  Test and farming references, plus a source/license audit of Hades Revisited.
  Corn is one family, not the package's privileged showcase.
- Every food status lasts **300 seconds**. Existing tick frequency, instant
  heals, percentage rates, combat suspension and latest-food replacement stay.
- Unclassified held items get a **90-degree forward rotation fallback**;
  authored weapon/tool poses retain priority. Rotate around the grip, preserving
  attachment alignment, rather than blindly changing world Euler angles.
- A Skills inventory tab lists all currently available class/talent abilities
  and every owned mount tier. Dropping a skill representation deletes it without
  creating a dropped entity or losing entitlement. Recovery is drag-and-drop
  into the visible player inventory, allowed only when that skill is absent
  from carried inventory and all bags. Passive abilities are listed as passive,
  not represented as useless draggable activation items.
- Purchased T1/T3 mounts remain available after T2/T4 upgrades. Each retained
  tier keeps its original speed (explicit user answer); no appearance-based
  speed inheritance. Unbought tiers remain unavailable.
- Art review covers cooked foods/recipe results, wands and Greataxes at all
  tiers. Greataxes should be large double-bit axes. Accepted swords, one-handed
  axes, armor and raw crop icons are preserved. Inspect real assets individually
  and in catalog context; a tier tint is not sufficient dish differentiation.
- Basics: starter recipes visible immediately; others appear after acquisition
  of the main material. This never gates crafting. Station icons belong below
  the input/output arrow. Help starts with a concise playable introduction.
- Inventory/talent readability, food findability, remaining original-class
  talent consumers and a separate **report-only** newcomer UX audit are in scope.

## Execution authority and limits

Root Astra coordinates; native Sol normally plans, implements and reviews.
Astra may handle difficult shared authority or geometry work. Never invoke
Codex CLI for native agents. No Claude tasks in this session. At most three
active workers beside root; the plan's lanes are logical packages, not a claim
that all run at once. Every nontrivial package receives independent review.

Fresh-development mode: no migrations or legacy aliases; normal persistence,
reconnects and unloading/reloading current-version objects remain required.
Do not edit user worlds or repin existing references. If Hades becomes a lasting
source, add it as a deliberately pinned reference with verified license records;
never import code/media based solely on aggregate repository or ContentDB labels.

Interpreter planning follows `docs/research/luanti-lua.md`'s interpreter section.
The continuing session override is no PUC runtime; retain plain-5.1 parser,
SETGLOBAL and all five sweeps on changed Lua including tools. Use only focused
LuaJIT behavioral fixtures. No broad mapgen census, seed fleet or PERF rerun.
Any required native-engine probe uses an isolated disposable test world, a
verified LuaJIT build, bounded scripted scenarios and an explicit timeout; never
run the user's GUI world or a full terrain population for these packages.
At most seven interpreter processes workstation-wide; parallel independent
processes use idle scheduling and separate immutable inputs/output paths.

## Package annexes

- [FARM: all seventeen families](farming.md), including verified Hades research.
- [SKILLS / POSE](skills-pose.md): WP47 and generic held orientation.
  [Bound inventory research](bound-inventory-research.md) verifies the engine
  transaction needed for delete-on-drop plus external-storage refusal.
- [RECIPES / UI / TALENTS / ART / UX](interface-art-talents.md).

The coordinator integration contract below resolves cross-annex ownership and
supersedes any stale file ownership list in an annex. Existing design numbers
remain authoritative; agents cannot invent new class balance.

## Integration contract

- SKILLS owns `grug_abilities/init.lua`, mount state/items/trainer integration
  and the new `grug_skills` mod including its destination-bound inventory policy.
  Creative destination guard edits are passed serially to the UI owner. Freeze `is_unlocked`, `unlocked_ids` and
  side-effect-free `stack_for` before TALENTS consumes them. Recovery neither
  grants talents nor resets combat state. Start characters receive their base
  kit once; later unlocks/purchases only add catalog entries and notifications.
- TALENTS owns `grug_abilities/kits.lua` and original-class effect consumers,
  `grug_classes/talents.lua`/`stats.lua` and required core combat seams. Any
  shared abilities-init hook is supplied as a reviewed patch to SKILLS, never
  edited concurrently. Scout and delivered Ironbound/Unbroken remain intact.
- UI owns shared sfinv geometry, all `grug_inventory/pages.lua` changes including
  Help, and `talents_ui.lua`. SKILLS builds page content against the UI owner's
  common content/inventory boundaries. RECIPES supplies onboarding text to UI.
  R12-R and R12-U are executed by one worker or serially where ownership overlaps.
- RECIPES owns jobs discovery/catalog/book UI and audited per-route main-material
  declarations. Professional provenance filtering runs before starter/discovery;
  no Cooking dish, including Bread, leaks into Basics. Content registration
  changes are isolated declaration modules or passed through their current owner.
- FOOD owns `grug_food/init.lua` duration and public description values. UI owns
  Creative Food filtering. ART owns only result/weapon media, metadata mappings
  and provenance; deliver cooking/gear registration patches serially if RECIPES
  is writing the same file. Do not turn a visual pass into recipe or nutrition
  rebalance.
- FARM alone owns crop lifecycle, profiles, stage art, `crop_visual.lua` and the
  wild visual call boundary. The ART reviewer assesses FARM plates as well but
  does not independently edit crop files. Retain bounded wild renewal and its
  source counts; no mapgen terrain or density revision is part of this round.
- POSE owns `wield_geometry.lua`/`apply.lua` after ART publishes grip conventions.
  It changes the third-person/world attachment fallback, not the independent
  engine first-person wieldmesh. Existing authored poses win.
- UX is independent and report-only. It distinguishes source/heuristic review,
  rendered visual evidence and actual GUI observations; no claim of completed
  new-player usability testing without a real observed session.

## Package graph

1. SPEC: reconcile accepted decisions with living docs and define shared Skills,
   talent eligibility and plant-family contracts before implementation.
2. Parallel first wave: FARM family mechanics; SKILLS lifecycle/catalog; ART
   actual-image audit and candidate production. Reserve independent review slots.
3. TALENTS may start against the frozen skill eligibility seam without editing
   the Skills owner files. UI/RECIPES owns shared inventory layouts and integrates
   the Skills page through an explicit page-content interface. POSE owns only
   held transforms and their applicability; ART supplies grip metadata/assets.
4. FOOD changes duration and findability without modifying recipe nutrition or
   art ownership; this small slice can share the UI/RECIPES worker if bounded.
5. UX observes the integrated candidate, reports friction and recommendations,
   and does not expand implementation beyond approved fixes.
6. Independent reviews, bounded integration checks, main merge, runtime sync,
   authorized GitHub push, before/after art gallery and next-playtest checklist.

Every package brief must identify exact source files, frozen interfaces,
acceptance scenarios, exclusions, evidence and stop conditions. Do not allow
independent authors to rewrite a shared inventory or ability lifecycle file.
Shared-file changes land serially or through the designated owner.

## Confirmed clarifications

All three questions answered by the user: retained mounts keep original tier
speed; cultivated crops receive family-specific regrowth (wild renewal remains
separate); art selection is autonomous with an independent visual reviewer and
a before/after gallery at delivery. No intermediate art approval is required.
Detailed annexes and the [independent review](review.md) are complete.
No further user design question remains; await the explicit round Go.


## Resume checkpoint

Read this README, its three package annexes and review before assigning work.
All planning workers are finished. No implementation agent is running. The
installed runtime is still Round 11 (`8d0d393e` repository baseline); this
planning package changes documentation only and must not trigger a runtime sync.
The next permitted step is the user's round Go, followed by SPEC and the waves
above. Do not infer that Go from a plan commit, merge or GitHub push.

Calibration: root GPT-6 Astra coordination; three native GPT-5.6 Sol planning
workers; independent native GPT-5.6 Sol reviewer, without planning authorship.
Review found 1 High and 3 Medium issues, all resolved in one review correction
round; final open Critical/High/Medium/Low counts are 0/0/0/0. Coordinator also
corrected cross-lane ownership, profession recipe provenance, Creative filter
scope and test-budget drift before independent review. Observed elapsed wall
time unknown. Frozen plan input hashes accompany this record; no runtime tests
were executed for this documentation-only planning step.
